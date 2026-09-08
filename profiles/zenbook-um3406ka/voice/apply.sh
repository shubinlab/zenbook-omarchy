#!/usr/bin/env bash
set -Eeuo pipefail

# Native Omarchy voice profile.
# Omarchy owns installation, the Voxtype user service and Hyprland bindings.
# This profile only keeps the useful multilingual policy for this host and
# removes the older profile's optional PipeWire/VAD layer if it is present.
# It never edits package-owned files under /usr/share/omarchy.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE_FILE="${VOICE_PROFILE_FILE:-${SCRIPT_DIR}/voxtype-omarchy.env.example}"
NATIVE_CONFIG="/usr/share/omarchy/default/voxtype/config.toml"
VOXTYPE_TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/voxtype/config.toml"
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
installation and applies this host's multilingual model/language policy,
native OSD and start/stop audio feedback. It also removes the older optional
PipeWire echo-cancel/VAD layer and restores a physical ALSA microphone as the
user-session default. Every apply is backed up. --rollback restores it.
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
: "${VOICE_MODEL:=large-v3-turbo}"
: "${VOICE_LANGUAGE:=auto}"

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

physical_sink() {
  local sink
  sink="$(pactl get-default-sink 2>/dev/null || true)"
  if [[ "${sink}" =~ ^alsa_output\..* && "${sink}" != *.monitor ]]; then
    printf '%s\n' "${sink}"
    return
  fi
  pactl list short sinks | awk '$2 ~ /^alsa_output\./ && $2 !~ /\.monitor$/ {print $2; exit}'
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
  check_native_bindings

  local default_source default_sink vad_enabled
  default_source="$(pactl get-default-source)"
  default_sink="$(pactl get-default-sink)"
  vad_enabled="$(voxtype config get vad.enabled 2>/dev/null || true)"

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
  check_value whisper.model "${VOICE_MODEL}" "$(voxtype config get whisper.model 2>/dev/null || true)"
  check_value whisper.language "${VOICE_LANGUAGE}" "$(voxtype config get whisper.language 2>/dev/null || true)"
  check_value whisper.translate false "$(voxtype config get whisper.translate 2>/dev/null || true)"
  check_value output.mode type "$(voxtype config get output.mode 2>/dev/null || true)"
  check_value output.pre_type_delay_ms 300 "$(voxtype config get output.pre_type_delay_ms 2>/dev/null || true)"
  check_value audio.feedback.enabled true "$(voxtype config get audio.feedback.enabled 2>/dev/null || true)"
  check_value osd.enabled true "$(voxtype config get osd.enabled 2>/dev/null || true)"
  if [[ "${vad_enabled}" != true ]]; then
    printf 'PASS optional Voxtype VAD disabled/unset\n'
  else
    printf 'FAIL optional Voxtype VAD is enabled\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if systemctl --user is-active --quiet voxtype.service; then
    printf 'PASS voxtype.service active\n'
  else
    printf 'FAIL voxtype.service inactive\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}'; then
    printf 'FAIL obsolete filtered source present\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  else
    printf 'PASS obsolete filtered source absent\n'
  fi
  if pactl list short sinks | awk '$2 == "voxtype_echo_cancel_sink" {found=1} END {exit !found}'; then
    printf 'FAIL obsolete echo-cancel sink present\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  else
    printf 'PASS obsolete echo-cancel sink absent\n'
  fi
  if [[ ! -e "${PIPEWIRE_TARGET}" && ! -L "${PIPEWIRE_TARGET}" && ! -e "${LEGACY_PIPEWIRE_TARGET}" && ! -L "${LEGACY_PIPEWIRE_TARGET}" ]]; then
    printf 'PASS profile PipeWire drop-ins absent\n'
  else
    printf 'FAIL profile PipeWire drop-in remains\n'
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if [[ "${default_source}" =~ ^alsa_input\..* && "${default_source}" != *.monitor ]]; then
    printf 'PASS physical default source=%s\n' "${default_source}"
  else
    printf 'FAIL default source is not physical=%s\n' "${default_source}"
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
  if [[ "${default_sink}" != voxtype_echo_cancel_sink ]]; then
    printf 'PASS default sink preserved=%s\n' "${default_sink}"
  else
    printf 'FAIL default sink is obsolete virtual sink\n'
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
  [[ -r "${HOME}/.local/share/voxtype/models/ggml-${VOICE_MODEL}.bin" ]] || die "Voxtype model is missing: ggml-${VOICE_MODEL}.bin"
  [[ "${VOICE_LANGUAGE}" == auto ]] || die 'this profile requires language=auto'

  local source sink
  source="$(physical_source)"
  sink="$(physical_sink)"
  [[ -n "${source}" ]] || die 'no physical ALSA source found'
  [[ -n "${sink}" ]] || die 'no physical ALSA sink found'
  safe_name "${source}"
  safe_name "${sink}"

  BACKUP_ID="$(date -u +%Y%m%dT%H%M%S%N)-${BASHPID}"
  mkdir -p "${BACKUP_ROOT}/${BACKUP_ID}"
  backup_target "${VOXTYPE_TARGET}" voxtype.config.toml
  backup_target "${PIPEWIRE_TARGET}" pipewire.conf
  backup_target "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf
  printf 'default_source=%s\ndefault_sink=%s\nphysical_source=%s\nphysical_sink=%s\n' \
    "$(pactl get-default-source)" "$(pactl get-default-sink)" "${source}" "${sink}" \
    >"${BACKUP_ROOT}/${BACKUP_ID}/metadata"

  # Keep the native output/audio path and only apply this host's useful
  # multilingual policy plus native feedback/OSD. Remove the old optional VAD.
  voxtype config set audio.device default
  voxtype config set whisper.model "${VOICE_MODEL}"
  voxtype config set whisper.language "${VOICE_LANGUAGE}"
  voxtype config set whisper.translate false
  voxtype config set output.mode type
  voxtype config set output.fallback_to_clipboard true
  voxtype config set output.pre_type_delay_ms 300
  voxtype config set audio.feedback.enabled true
  voxtype config set audio.feedback.theme default
  voxtype config set audio.feedback.volume 0.7
  voxtype config set osd.enabled true
  voxtype config set osd.frontend gtk4
  voxtype config unset vad.enabled || true
  voxtype config unset vad.backend || true
  voxtype config unset vad.threshold || true

  rm -f -- "${PIPEWIRE_TARGET}" "${LEGACY_PIPEWIRE_TARGET}"
  systemctl --user restart pipewire-pulse.service
  for _ in {1..20}; do
    if pactl list short sources | awk -v target="${source}" '$2 == target {found=1} END {exit !found}'; then break; fi
    sleep 0.25
  done
  pactl list short sources | awk -v target="${source}" '$2 == target {found=1} END {exit !found}' || die "physical source did not appear after PipeWire restart: ${source}"
  pactl set-default-source "${source}"
  systemctl --user restart voxtype.service
  printf 'voice-omarchy: native profile applied; backup=%s source=%s sink=%s\n' "${BACKUP_ID}" "${source}" "${sink}"
}

select_latest_backup() {
  [[ -d "${BACKUP_ROOT}" ]] || die "no voice backups found under ${BACKUP_ROOT}"
  BACKUP_ID="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n 1)"
  [[ -n "${BACKUP_ID}" ]] || die 'no voice backups found'
}

rollback_profile() {
  select_latest_backup
  restore_one "${VOXTYPE_TARGET}" voxtype.config.toml
  restore_one "${PIPEWIRE_TARGET}" pipewire.conf
  restore_one "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf
  systemctl --user restart pipewire-pulse.service
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
