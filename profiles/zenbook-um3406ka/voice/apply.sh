#!/usr/bin/env bash
set -Eeuo pipefail

# Native, user-scoped voice integration for Omarchy. This script intentionally
# does not call the Ubuntu installer from zenbook-voice and never edits stock
# files under /usr/share/omarchy.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd -P)"
PROFILE_DIR="${OMARCHY_PROFILE_DIR:-${ROOT_DIR}/profiles/zenbook-um3406ka}"
PROFILE_FILE="${VOICE_PROFILE_FILE:-${PROFILE_DIR}/voice/voxtype-omarchy.env.example}"
TEMPLATE="${VOICE_TEMPLATE:-${PROFILE_DIR}/voice/pipewire-echo-cancel.conf.tmpl}"
VOXTYPE_TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/voxtype/config.toml"
PIPEWIRE_TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/pipewire/pipewire-pulse.conf.d/90-omarchy-voice.conf"
LEGACY_PIPEWIRE_TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/pipewire/pipewire-pulse.conf.d/90-zenbook-omarchy-voice.conf"
BACKUP_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/omarchy-profiles/backups/voice"

ACTION=check
BACKUP_ID=""
APPLY_STARTED=0
CHECK_FAILURES=0
CURRENT_DEFAULT_SOURCE=""

die() { printf 'voice-omarchy: %s\n' "$*" >&2; exit 1; }
warn() { printf 'voice-omarchy warning: %s\n' "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat <<'EOF'
Usage: profiles/<id>/voice/apply.sh [--check|--apply|--rollback]

The default is a read-only check. --apply installs the native user-scoped
PipeWire/Voxtype profile with a timestamped backup. --rollback restores the
latest voice backup. The user-session default source is pointed at the
filtered microphone because Voxtype 1.0.1 accepts the PipeWire host as
`default`, not the virtual source name; the original source is backed up and
restored. No stock Omarchy file, monitor setting, VPN setting or sink routing
is changed.
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
[[ -r "${TEMPLATE}" ]] || die "template is not readable: ${TEMPLATE}"
# shellcheck disable=SC1090
source "${PROFILE_FILE}"

: "${VOICE_AUDIO_DEVICE:=default}"
: "${VOICE_MODEL:=base}"
: "${VOICE_LANGUAGE:=auto}"
: "${VOICE_VAD_THRESHOLD:=0.5}"
: "${VOICE_PRE_TYPE_DELAY_MS:=300}"
: "${VOICE_PIPEWIRE_SOURCE_MASTER:=}"
: "${VOICE_PIPEWIRE_SINK_MASTER:=}"

safe_name() {
  [[ "$1" =~ ^[A-Za-z0-9_.:-]+$ ]] || die "unsafe PipeWire node name: $1"
}

get_masters() {
  local default_source default_sink
  default_source="$(pactl get-default-source)"
  default_sink="$(pactl get-default-sink)"
  CURRENT_DEFAULT_SOURCE="${default_source}"
  if [[ -z "${VOICE_PIPEWIRE_SOURCE_MASTER}" ]]; then
    if [[ "${default_source}" == alsa_input.* && "${default_source}" != *.monitor ]]; then
      VOICE_PIPEWIRE_SOURCE_MASTER="${default_source}"
    else
      VOICE_PIPEWIRE_SOURCE_MASTER="$(pactl list short sources | awk '$2 ~ /^alsa_input\./ && $2 !~ /\.monitor$/ {print $2; exit}')"
    fi
  fi
  if [[ -z "${VOICE_PIPEWIRE_SINK_MASTER}" ]]; then
    if [[ "${default_sink}" == alsa_output.* && "${default_sink}" != *.monitor ]]; then
      VOICE_PIPEWIRE_SINK_MASTER="${default_sink}"
    else
      VOICE_PIPEWIRE_SINK_MASTER="$(pactl list short sinks | awk '$2 ~ /^alsa_output\./ && $2 !~ /\.monitor$/ {print $2; exit}')"
    fi
  fi
  [[ -n "${VOICE_PIPEWIRE_SOURCE_MASTER}" ]] || die 'no physical ALSA source found'
  [[ -n "${VOICE_PIPEWIRE_SINK_MASTER}" ]] || die 'no physical ALSA sink found'
  safe_name "${VOICE_PIPEWIRE_SOURCE_MASTER}"
  safe_name "${VOICE_PIPEWIRE_SINK_MASTER}"
}

render_pipewire() {
  local content temporary directory
  directory="$(dirname -- "${PIPEWIRE_TARGET}")"
  mkdir -p "${directory}"
  content="$(<"${TEMPLATE}")"
  content="${content//@SOURCE_MASTER@/${VOICE_PIPEWIRE_SOURCE_MASTER}}"
  content="${content//@SINK_MASTER@/${VOICE_PIPEWIRE_SINK_MASTER}}"
  temporary="$(mktemp "${PIPEWIRE_TARGET}.tmp.XXXXXX")"
  printf '%s\n' "${content}" >"${temporary}"
  chmod 0644 "${temporary}"
  mv -f -- "${temporary}" "${PIPEWIRE_TARGET}"
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

restore_backup() {
  [[ -n "${BACKUP_ID}" ]] || die 'backup id is not selected'
  restore_one "${VOXTYPE_TARGET}" voxtype.config.toml
  restore_one "${PIPEWIRE_TARGET}" pipewire.conf
  restore_one "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf
  systemctl --user restart pipewire-pulse.service
  local restore_source
  restore_source="$(sed -n 's/^default_source=//p' "${BACKUP_ROOT}/${BACKUP_ID}/metadata" 2>/dev/null || true)"
  if [[ -n "${restore_source}" ]]; then
    safe_name "${restore_source}"
    if pactl list short sources | awk -v target="${restore_source}" '$2 == target {found=1} END {exit !found}'; then
      pactl set-default-source "${restore_source}"
    else
      warn "original default source is unavailable: ${restore_source}"
    fi
  fi
  systemctl --user restart voxtype.service
  printf 'voice-omarchy: restored backup %s\n' "${BACKUP_ID}"
}

rollback_on_error() {
  local status=$?
  if (( APPLY_STARTED )) && [[ -n "${BACKUP_ID}" ]]; then
    warn "apply failed; restoring backup ${BACKUP_ID}"
    restore_backup || warn 'automatic rollback was incomplete; run --rollback explicitly'
  fi
  exit "${status}"
}

select_latest_backup() {
  [[ -d "${BACKUP_ROOT}" ]] || die "no voice backups found under ${BACKUP_ROOT}"
  BACKUP_ID="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n 1)"
  [[ -n "${BACKUP_ID}" ]] || die 'no voice backups found'
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
  check_native_bindings
  get_masters
  printf 'voice-omarchy check\n'
  printf 'physical_source=%s\nphysical_sink=%s\n' "${VOICE_PIPEWIRE_SOURCE_MASTER}" "${VOICE_PIPEWIRE_SINK_MASTER}"
  check_value() {
    local label="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
      printf 'PASS %s=%s\n' "${label}" "${expected}"
    else
      printf 'FAIL %s=%s expected=%s\n' "${label}" "${actual:-missing}" "${expected}"
      CHECK_FAILURES=$((CHECK_FAILURES + 1))
    fi
  }
  check_value audio.device "${VOICE_AUDIO_DEVICE}" "$(voxtype config get audio.device 2>/dev/null || true)"
  check_value whisper.model "${VOICE_MODEL}" "$(voxtype config get whisper.model 2>/dev/null || true)"
  check_value whisper.language "${VOICE_LANGUAGE}" "$(voxtype config get whisper.language 2>/dev/null || true)"
  check_value output.mode paste "$(voxtype config get output.mode 2>/dev/null || true)"
  check_value vad.enabled true "$(voxtype config get vad.enabled 2>/dev/null || true)"
  if systemctl --user is-active --quiet voxtype.service; then
    printf 'PASS voxtype.service active\n'
  else
    printf 'FAIL voxtype.service inactive\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}'; then
    printf 'PASS filtered source present\n'
  else
    printf 'FAIL filtered source missing\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  printf 'global_default_source=%s\n' "$(pactl get-default-source)"
  printf 'global_default_sink=%s\n' "$(pactl get-default-sink)"
  default_source="$(pactl get-default-source)"
  if [[ "${default_source}" == voxtype_noise_suppressed ]]; then
    printf 'PASS global_default_source=filtered\n'
  else
    printf 'FAIL global_default_source is not filtered\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if [[ -f "${PIPEWIRE_TARGET}" ]]; then
    printf 'PASS PipeWire drop-in present\n'
  else
    printf 'FAIL PipeWire drop-in missing\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if [[ ! -e "${LEGACY_PIPEWIRE_TARGET}" && ! -L "${LEGACY_PIPEWIRE_TARGET}" ]]; then
    printf 'PASS legacy PipeWire drop-in absent\n'
  else
    printf 'FAIL legacy PipeWire drop-in is still present\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  printf 'result=%s\n' "$([[ ${CHECK_FAILURES} -eq 0 ]] && printf PASS || printf FAIL)"
  return "${CHECK_FAILURES}"
}

apply_profile() {
  need voxtype
  need pactl
  need systemctl
  check_native_bindings
  get_masters
  [[ -r "${HOME}/.local/share/voxtype/models/ggml-${VOICE_MODEL}.bin" ]] || die "Voxtype model is missing: ggml-${VOICE_MODEL}.bin; download it before apply"
  [[ "${VOICE_AUDIO_DEVICE}" == default ]] || die 'profile must use the supported PipeWire host: default'
  [[ "${VOICE_LANGUAGE}" == auto ]] || die 'this profile requires language=auto'

  BACKUP_ID="$(date -u +%Y%m%dT%H%M%S%N)-${BASHPID}"
  mkdir -p "${BACKUP_ROOT}/${BACKUP_ID}"
  backup_target "${VOXTYPE_TARGET}" voxtype.config.toml
  backup_target "${PIPEWIRE_TARGET}" pipewire.conf
  backup_target "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf
  printf 'default_source=%s\nsource_master=%s\nsink_master=%s\n' "${CURRENT_DEFAULT_SOURCE}" "${VOICE_PIPEWIRE_SOURCE_MASTER}" "${VOICE_PIPEWIRE_SINK_MASTER}" >"${BACKUP_ROOT}/${BACKUP_ID}/metadata"
  APPLY_STARTED=1
  trap rollback_on_error ERR

  render_pipewire
  if [[ -e "${LEGACY_PIPEWIRE_TARGET}" || -L "${LEGACY_PIPEWIRE_TARGET}" ]]; then
    rm -f -- "${LEGACY_PIPEWIRE_TARGET}"
  fi
  voxtype config set audio.device "${VOICE_AUDIO_DEVICE}"
  voxtype config set whisper.model "${VOICE_MODEL}"
  voxtype config set whisper.language "${VOICE_LANGUAGE}"
  voxtype config set whisper.translate false
  voxtype config set vad.enabled true
  voxtype config set vad.backend whisper
  voxtype config set vad.threshold "${VOICE_VAD_THRESHOLD}"
  voxtype config set output.mode paste
  voxtype config set output.fallback_to_clipboard true
  voxtype config set output.pre_type_delay_ms "${VOICE_PRE_TYPE_DELAY_MS}"

  systemctl --user restart pipewire-pulse.service
  for _ in {1..20}; do
    if pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}'; then break; fi
    sleep 0.25
  done
  pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}' || die 'filtered PipeWire source did not appear after restart'
  pactl set-default-source voxtype_noise_suppressed
  systemctl --user restart voxtype.service
  trap - ERR
  printf 'voice-omarchy: applied backup=%s source=%s sink=%s\n' "${BACKUP_ID}" "${VOICE_PIPEWIRE_SOURCE_MASTER}" "${VOICE_PIPEWIRE_SINK_MASTER}"
}

case "${ACTION}" in
  check) check_state ;;
  apply) apply_profile; check_state ;;
  rollback) select_latest_backup; restore_backup; check_native_bindings ;;
esac
