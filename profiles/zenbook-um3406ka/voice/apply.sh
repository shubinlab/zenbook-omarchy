#!/usr/bin/env bash
set -Eeuo pipefail

# Native Omarchy voice profile.
# Omarchy owns installation, the Voxtype user service and Hyprland bindings.
# This profile only keeps the useful multilingual policy for this host.
# It never edits package-owned files under /usr/share/omarchy.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE_FILE="${VOICE_PROFILE_FILE:-${SCRIPT_DIR}/voxtype-omarchy.env.example}"
NATIVE_CONFIG="/usr/share/omarchy/default/voxtype/config.toml"
VOXTYPE_TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/voxtype/config.toml"
# Kept only so rollback remains compatible with backups from older profile
# revisions. The clean apply path never reads, writes or removes these files.
PIPEWIRE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/pipewire/pipewire-pulse.conf.d"
PIPEWIRE_TARGET="${PIPEWIRE_DIR}/90-omarchy-voice.conf"
LEGACY_PIPEWIRE_TARGET="${PIPEWIRE_DIR}/90-zenbook-omarchy-voice.conf"
BACKUP_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/omarchy-profiles/backups/voice"

ACTION=check
BACKUP_ID=""
CHECK_FAILURES=0

die() { printf 'voice-omarchy: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat <<'EOF'
Usage: profiles/<id>/voice/apply.sh [--check|--apply|--rollback]

The default is a read-only check. --apply keeps Omarchy's native Voxtype
installation and applies this host's local Lemonade/NPU route, auto-language
policy, native OSD and start/stop audio feedback. It restores a physical ALSA
microphone as the user-session default. Every apply is backed up.
--rollback restores it.
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --apply) ACTION=apply ;;
    --rollback) ACTION=rollback ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ "${EUID}" -ne 0 ]] || die 'run as the normal Omarchy user, not root'
[[ -r "${PROFILE_FILE}" ]] || die "profile is not readable: ${PROFILE_FILE}"
[[ -r "${NATIVE_CONFIG}" ]] || die "native Omarchy Voxtype config is missing: ${NATIVE_CONFIG}"
# shellcheck disable=SC1090
source "${PROFILE_FILE}"
: "${VOICE_LANGUAGE:=auto}"
: "${VOICE_TYPE_DELAY_MS:=10}"
: "${VOICE_MODE:=remote}"
: "${VOICE_REMOTE_ENDPOINT:=http://127.0.0.1:13305}"
: "${VOICE_REMOTE_MODEL:=whisper-v3-turbo-FLM}"
[[ "${VOICE_TYPE_DELAY_MS}" =~ ^[0-9]+$ ]] || die 'VOICE_TYPE_DELAY_MS must be an integer'
[[ "${VOICE_MODE}" == remote ]] || die 'this profile requires the Lemonade remote mode'
[[ "${VOICE_REMOTE_ENDPOINT}" == http://127.0.0.1:* ]] || die 'Lemonade endpoint must stay on localhost'

safe_name() {
  [[ "$1" =~ ^[A-Za-z0-9_.:-]+$ ]] || die "unsafe PipeWire node name: $1"
}

physical_source() {
  local source
  source="$(pactl get-default-source 2>/dev/null || true)"
  if [[ "${source}" =~ ^alsa_input\..* && "${source}" != *.monitor ]]; then
    printf '%s\n' "${source}"
    return
  fi
  pactl list short sources | awk '$2 ~ /^alsa_input\./ && $2 !~ /\.monitor$/ {print $2; exit}'
}

output_config_value() {
  local key="$1"
  awk -v key="${key}" '
    BEGIN { in_output = 0 }
    /^\[output\][[:space:]]*$/ { in_output = 1; next }
    /^\[/ { in_output = 0 }
    in_output && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/[[:space:]]+#.*$/, "")
      gsub(/"/, "")
      print
      exit
    }
  ' "${VOXTYPE_TARGET}"
}

lemonade_health() {
  curl --fail --silent --show-error --max-time 10 \
    "${VOICE_REMOTE_ENDPOINT}/api/v1/health"
}

lemonade_npu_loaded() {
  lemonade_health | jq -e --arg model "${VOICE_REMOTE_MODEL}" '
    .all_models_loaded[]?
    | select(
        .model_name == $model and
        .recipe == "flm" and
        .device == "npu" and
        .backend_health == "ready" and
        .loaded == true
      )
  ' >/dev/null
}

wait_lemonade_npu_loaded() {
  for _ in {1..30}; do
    if lemonade_npu_loaded; then
      return 0
    fi
    sleep 1
  done
  return 1
}

ensure_lemonade_server() {
  need lemonade
  need curl
  need jq
  if lemonade_health >/dev/null 2>&1 &&
     systemctl is-enabled --quiet lemond.service 2>/dev/null &&
     systemctl is-active --quiet lemond.service 2>/dev/null; then
    return 0
  fi
  need systemctl
  need sudo
  [[ -r /dev/tty ]] || die 'Lemonade needs a terminal to start its system service'
  printf 'voice-omarchy: starting the native Lemonade system service\n'
  sudo systemctl enable --now lemond.service </dev/tty
  for _ in {1..30}; do
    if lemonade_health >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  die 'Lemonade server did not become ready on 127.0.0.1:13305'
}

ensure_lemonade_npu() {
  ensure_lemonade_server

  if ! lemonade_health | jq -e '.telemetry.enabled == false' >/dev/null; then
    printf 'voice-omarchy: Lemonade telemetry is enabled; refusing to use it for voice\n' >&2
    die 'disable Lemonade telemetry before enabling NPU voice'
  fi

  # Keep the package-owned service local and quiet. Lemonade 11.8 uses the
  # positive `broadcast` key; older Arch packages use `no_broadcast`.
  if ! lemonade config set broadcast=false >/dev/null 2>&1; then
    lemonade config set no_broadcast=true >/dev/null ||
      die 'could not disable Lemonade LAN broadcast discovery'
  fi

  if ! curl --fail --silent --show-error --max-time 10 \
      "${VOICE_REMOTE_ENDPOINT}/api/v1/system-info" |
      jq -e '.recipes.flm.backends.npu.state == "installed"' >/dev/null; then
    printf 'voice-omarchy: installing Lemonade FLM NPU backend\n'
    lemonade backends install flm:npu
  fi

  if ! curl --fail --silent --show-error --max-time 10 \
      "${VOICE_REMOTE_ENDPOINT}/api/v1/models?show_all=true" |
      jq -e --arg model "${VOICE_REMOTE_MODEL}" '
        .data[]? | select(.id == $model and .downloaded == true)
      ' >/dev/null; then
    printf 'voice-omarchy: downloading Lemonade model %s\n' "${VOICE_REMOTE_MODEL}"
    lemonade pull "${VOICE_REMOTE_MODEL}"
  fi

  if ! lemonade_npu_loaded; then
    printf 'voice-omarchy: loading %s on the AMD XDNA2 NPU\n' "${VOICE_REMOTE_MODEL}"
    lemonade load "${VOICE_REMOTE_MODEL}"
  fi
  wait_lemonade_npu_loaded ||
    die 'Lemonade did not expose the voice model as ready on device=npu'
}

set_type_delay() {
  local temporary
  temporary="$(mktemp "${VOXTYPE_TARGET}.tmp.XXXXXX")"
  if ! awk -v delay="${VOICE_TYPE_DELAY_MS}" '
      BEGIN { in_output = 0; found = 0 }
      /^\[output\][[:space:]]*$/ { in_output = 1 }
      /^\[/ && $0 !~ /^\[output\][[:space:]]*$/ { in_output = 0 }
      in_output && /^[[:space:]]*type_delay_ms[[:space:]]*=/ {
        sub(/=.*/, "= " delay)
        found = 1
      }
      { print }
      END { exit(found ? 0 : 1) }
    ' "${VOXTYPE_TARGET}" >"${temporary}"; then
    rm -f -- "${temporary}"
    die 'native Voxtype config has no output.type_delay_ms entry'
  fi
  install -m 0644 "${temporary}" "${VOXTYPE_TARGET}"
  rm -f -- "${temporary}"
}

backup_target() {
  local target="$1" name="$2"
  if [[ -e "${target}" || -L "${target}" ]]; then
    cp -a -- "${target}" "${BACKUP_ROOT}/${BACKUP_ID}/${name}"
  else
    : >"${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent"
  fi
}

restore_one() {
  local target="$1" backup_name="$2"
  if [[ -e "${BACKUP_ROOT}/${BACKUP_ID}/${backup_name}" ]]; then
    mkdir -p "$(dirname -- "${target}")"
    cp -a -- "${BACKUP_ROOT}/${BACKUP_ID}/${backup_name}" "${target}"
  elif [[ -e "${BACKUP_ROOT}/${BACKUP_ID}/${backup_name}.absent" ]]; then
    rm -f -- "${target}"
  else
    die "incomplete backup: ${backup_name}"
  fi
}

restore_if_backed_up() {
  local target="$1" backup_name="$2"
  if [[ -e "${BACKUP_ROOT}/${BACKUP_ID}/${backup_name}" || \
        -e "${BACKUP_ROOT}/${BACKUP_ID}/${backup_name}.absent" ]]; then
    restore_one "${target}" "${backup_name}"
    return 0
  fi
  return 1
}

check_native_bindings() {
  local binding="/usr/share/omarchy/default/hypr/bindings/voxtype.lua"
  [[ -r "${binding}" ]] || die "Omarchy Voxtype binding is missing: ${binding}"
  grep -F 'SUPER + CTRL + X' "${binding}" >/dev/null || die 'native toggle binding is missing'
  grep -F 'F9' "${binding}" >/dev/null || die 'native push-to-talk binding is missing'
  if [[ -r "${HOME}/.config/hypr/bindings.lua" ]] && grep -Eq '^[[:space:]]*[^-[:space:]].*omarchy_default_bindings[[:space:]]*=[[:space:]]*false' "${HOME}/.config/hypr/bindings.lua"; then
    die 'user config disables Omarchy default bindings'
  fi
}

check_state() {
  need voxtype
  need pactl
  need systemctl
  need wtype
  need curl
  need jq
  check_native_bindings

  local default_source default_sink
  default_source="$(pactl get-default-source)"
  default_sink="$(pactl get-default-sink)"

  printf 'voice-omarchy native check\n'
  check_value() {
    local label="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
      printf 'PASS %s=%s\n' "${label}" "${expected}"
    else
      printf 'FAIL %s=%s expected=%s\n' "${label}" "${actual:-missing}" "${expected}"
      CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi
  }
  check_value audio.device default "$(voxtype config get audio.device 2>/dev/null || true)"
  check_value whisper.mode remote "$(voxtype config get whisper.mode 2>/dev/null || true)"
  check_value whisper.language "${VOICE_LANGUAGE}" "$(voxtype config get whisper.language 2>/dev/null || true)"
  check_value whisper.translate false "$(voxtype config get whisper.translate 2>/dev/null || true)"
  check_value whisper.remote_endpoint "${VOICE_REMOTE_ENDPOINT}" "$(voxtype config get whisper.remote_endpoint 2>/dev/null || true)"
  check_value whisper.remote_model "${VOICE_REMOTE_MODEL}" "$(voxtype config get whisper.remote_model 2>/dev/null || true)"
  check_value output.mode type "$(voxtype config get output.mode 2>/dev/null || true)"
  check_value output.type_delay_ms "${VOICE_TYPE_DELAY_MS}" "$(output_config_value type_delay_ms)"
  check_value output.pre_type_delay_ms 300 "$(voxtype config get output.pre_type_delay_ms 2>/dev/null || true)"
  check_value audio.feedback.enabled true "$(voxtype config get audio.feedback.enabled 2>/dev/null || true)"
  check_value osd.enabled true "$(voxtype config get osd.enabled 2>/dev/null || true)"
  if systemctl --user is-active --quiet voxtype.service; then
    printf 'PASS voxtype.service active\n'
  else
    printf 'FAIL voxtype.service inactive\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if [[ "${default_source}" =~ ^alsa_input\..* && "${default_source}" != *.monitor ]]; then
    printf 'PASS physical default source=%s\n' "${default_source}"
  else
    printf 'FAIL default source is not physical=%s\n' "${default_source}"
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if [[ -n "${default_sink}" ]]; then
    printf 'PASS default sink available=%s\n' "${default_sink}"
  else
    printf 'FAIL default sink is unavailable\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  local source_volume sink_volume source_mute sink_mute source_percent sink_percent
  source_volume="$(pactl get-source-volume "${default_source}" 2>/dev/null || true)"
  sink_volume="$(pactl get-sink-volume "${default_sink}" 2>/dev/null || true)"
  source_mute="$(pactl get-source-mute "${default_source}" 2>/dev/null || true)"
  sink_mute="$(pactl get-sink-mute "${default_sink}" 2>/dev/null || true)"
  source_percent="$(grep -oE '[0-9]+%' <<<"${source_volume}" | head -n 1 | tr -d '%' || true)"
  sink_percent="$(grep -oE '[0-9]+%' <<<"${sink_volume}" | head -n 1 | tr -d '%' || true)"
  printf 'INFO microphone volume=%s%% mute=%s\n' "${source_percent:-unknown}" "${source_mute:-unknown}"
  printf 'INFO feedback sink=%s volume=%s%% mute=%s\n' \
    "${default_sink:-unavailable}" "${sink_percent:-unknown}" "${sink_mute:-unknown}"
  if [[ "${source_mute}" == yes ]]; then
    printf 'WARN microphone is muted; transcription cannot be reliable\n'
  elif [[ -n "${source_percent}" && "${source_percent}" -lt 20 ]]; then
    printf 'WARN microphone input is very quiet (%s%%); check gain before changing ASR settings\n' "${source_percent}"
  fi
  if [[ "${sink_mute}" == yes ]]; then
    printf 'WARN feedback sink is muted; start/stop sounds cannot be heard\n'
  fi
  if [[ "$(voxtype config get output.fallback_to_clipboard 2>/dev/null || true)" == true ]]; then
    printf 'WARN output fallback_to_clipboard=true; failed wtype insertion may invoke clipboard fallback\n'
  fi
  if lemonade_npu_loaded; then
    printf 'PASS Lemonade FLM voice model device=npu\n'
  else
    printf 'FAIL Lemonade FLM voice model is not ready on device=npu\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if lemonade_health | jq -e '.telemetry.enabled == false' >/dev/null; then
    printf 'PASS Lemonade telemetry disabled\n'
  else
    printf 'FAIL Lemonade telemetry is enabled\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  printf 'result=%s\n' "$([[ ${CHECK_FAILURES} -eq 0 ]] && printf PASS || printf FAIL)"
  return "${CHECK_FAILURES}"
}

apply_profile() {
  need voxtype
  need pactl
  need systemctl
  need wtype
  check_native_bindings
  [[ "${VOICE_LANGUAGE}" == auto ]] || die 'this profile requires language=auto'
  ensure_lemonade_npu

  if (check_state >/dev/null 2>&1); then
    # A previous apply may have written a valid config immediately before an
    # interrupted restart. Reload it even when the resulting state is already
    # correct, so the running daemon cannot retain stale settings.
    systemctl --user restart voxtype.service
    printf 'voice-omarchy: native profile already applied\n'
    check_state
    return 0
  fi

  local source
  source="$(physical_source)"
  [[ -n "${source}" ]] || die 'no physical ALSA source found'
  safe_name "${source}"

  BACKUP_ID="$(date -u +%Y%m%dT%H%M%S%N)-${BASHPID}"
  mkdir -p "${BACKUP_ROOT}/${BACKUP_ID}"
  backup_target "${VOXTYPE_TARGET}" voxtype.config.toml
  printf 'default_source=%s\ndefault_sink=%s\nphysical_source=%s\n' \
    "$(pactl get-default-source)" "$(pactl get-default-sink)" "${source}" \
    >"${BACKUP_ROOT}/${BACKUP_ID}/metadata"

  # Keep the native output/audio path and apply only this host's useful
  # multilingual policy plus native feedback/OSD.
  voxtype config set audio.device default
  voxtype config set whisper.mode remote
  voxtype config set whisper.language "${VOICE_LANGUAGE}"
  voxtype config set whisper.translate false
  voxtype config set whisper.remote_endpoint "${VOICE_REMOTE_ENDPOINT}"
  voxtype config set whisper.remote_model "${VOICE_REMOTE_MODEL}"
  voxtype config set output.mode type
  voxtype config set output.fallback_to_clipboard true
  set_type_delay
  voxtype config set output.pre_type_delay_ms 300
  voxtype config set audio.feedback.enabled true
  voxtype config set audio.feedback.theme default
  voxtype config set audio.feedback.volume 0.7
  voxtype config set osd.enabled true
  voxtype config set osd.frontend gtk4

  pactl set-default-source "${source}"
  systemctl --user restart voxtype.service
  printf 'voice-omarchy: native profile applied; backup=%s source=%s\n' "${BACKUP_ID}" "${source}"
}

select_latest_backup() {
  [[ -d "${BACKUP_ROOT}" ]] || die "no voice backups found under ${BACKUP_ROOT}"
  BACKUP_ID="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n 1)"
  [[ -n "${BACKUP_ID}" ]] || die 'no voice backups found'
}

rollback_profile() {
  select_latest_backup
  restore_one "${VOXTYPE_TARGET}" voxtype.config.toml
  local restore_pipewire=0
  if restore_if_backed_up "${PIPEWIRE_TARGET}" pipewire.conf; then
    restore_pipewire=1
  fi
  if restore_if_backed_up "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf; then
    restore_pipewire=1
  fi
  if ((restore_pipewire)); then
    systemctl --user restart pipewire-pulse.service
  fi
  local restore_source restore_sink
  restore_source="$(sed -n 's/^default_source=//p' "${BACKUP_ROOT}/${BACKUP_ID}/metadata" 2>/dev/null || true)"
  restore_sink="$(sed -n 's/^default_sink=//p' "${BACKUP_ROOT}/${BACKUP_ID}/metadata" 2>/dev/null || true)"
  if [[ -n "${restore_source}" ]] && pactl list short sources | awk -v target="${restore_source}" '$2 == target {found=1} END {exit !found}'; then
    safe_name "${restore_source}"
    pactl set-default-source "${restore_source}"
  fi
  if [[ -n "${restore_sink}" ]] && pactl list short sinks | awk -v target="${restore_sink}" '$2 == target {found=1} END {exit !found}'; then
    safe_name "${restore_sink}"
    pactl set-default-sink "${restore_sink}"
  fi
  systemctl --user restart voxtype.service
  printf 'voice-omarchy: restored backup %s\n' "${BACKUP_ID}"
}

case "${ACTION}" in
  check) check_state ;;
  apply) apply_profile; check_state ;;
  rollback) rollback_profile; check_native_bindings ;;
esac
