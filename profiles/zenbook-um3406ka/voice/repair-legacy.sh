#!/usr/bin/env bash
set -Eeuo pipefail

# One-time repair for installations made by older Zenbook profile versions.
# This is intentionally not called by the clean-install flow.

CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
VOXTYPE_TARGET="${CONFIG_HOME}/voxtype/config.toml"
PIPEWIRE_DIR="${CONFIG_HOME}/pipewire/pipewire-pulse.conf.d"
PIPEWIRE_TARGET="${PIPEWIRE_DIR}/90-omarchy-voice.conf"
LEGACY_PIPEWIRE_TARGET="${PIPEWIRE_DIR}/90-zenbook-omarchy-voice.conf"
BACKUP_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/omarchy-profiles/backups/voice-legacy"
ACTION=check

die() { printf 'voice-legacy-repair: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat <<'EOF'
Usage: profiles/<id>/voice/repair-legacy.sh [--check|--apply|--rollback]

--check     report legacy voice state without changing anything
--apply     remove only the old profile drop-ins and VAD keys, with backup
--rollback  restore the latest repair backup

This command is for upgrades from older Zenbook profile revisions. It is not
part of a clean Omarchy installation.
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

[[ ${EUID} -ne 0 ]] || die 'run as the normal Omarchy user, not root'

physical_source() {
  local source
  source="$(pactl get-default-source 2>/dev/null || true)"
  if [[ ${source} =~ ^alsa_input\..* && ${source} != *.monitor ]]; then
    printf '%s\n' "${source}"
    return
  fi
  pactl list short sources | awk '$2 ~ /^alsa_input\./ && $2 !~ /\.monitor$/ {print $2; exit}'
}

safe_name() {
  [[ $1 =~ ^[A-Za-z0-9_.:-]+$ ]] || die "unsafe PipeWire node name: $1"
}

legacy_files_present() {
  [[ -e ${PIPEWIRE_TARGET} || -L ${PIPEWIRE_TARGET} ||
     -e ${LEGACY_PIPEWIRE_TARGET} || -L ${LEGACY_PIPEWIRE_TARGET} ]]
}

legacy_vad_present() {
  [[ -r ${VOXTYPE_TARGET} ]] || return 1
  awk '
    BEGIN { in_vad = 0; found = 0 }
    /^\[vad\][[:space:]]*$/ { in_vad = 1; next }
    /^\[/ { in_vad = 0 }
    in_vad && /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*=/ { found = 1 }
    END { exit !found }
  ' "${VOXTYPE_TARGET}"
}

legacy_nodes_present() {
  pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}' ||
    pactl list short sinks | awk '$2 == "voxtype_echo_cancel_sink" {found=1} END {exit !found}'
}

report_state() {
  local found=0
  if legacy_files_present; then
    printf 'FOUND legacy PipeWire drop-in\n'
    found=1
  else
    printf 'PASS legacy PipeWire drop-ins absent\n'
  fi
  if legacy_vad_present; then
    printf 'FOUND legacy Voxtype VAD keys\n'
    found=1
  else
    printf 'PASS legacy Voxtype VAD keys absent\n'
  fi
  if legacy_nodes_present; then
    printf 'FOUND legacy virtual audio nodes\n'
    found=1
  else
    printf 'PASS legacy virtual audio nodes absent\n'
  fi
  return "${found}"
}

backup_target() {
  local target=$1 name=$2
  if [[ -e ${target} || -L ${target} ]]; then
    cp -a -- "${target}" "${BACKUP_ROOT}/${BACKUP_ID}/${name}"
  else
    : >"${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent"
  fi
}

restore_target() {
  local target=$1 name=$2
  if [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/${name} ]]; then
    mkdir -p "$(dirname -- "${target}")"
    cp -a -- "${BACKUP_ROOT}/${BACKUP_ID}/${name}" "${target}"
  elif [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent ]]; then
    rm -f -- "${target}"
  else
    die "incomplete repair backup: ${name}"
  fi
}

apply_repair() {
  need voxtype
  need pactl
  need systemctl
  if ! legacy_files_present && ! legacy_vad_present && ! legacy_nodes_present; then
    printf 'voice-legacy-repair: nothing to repair\n'
    return 0
  fi

  BACKUP_ID="$(date -u +%Y%m%dT%H%M%S%N)-${BASHPID}"
  mkdir -p "${BACKUP_ROOT}/${BACKUP_ID}"
  backup_target "${VOXTYPE_TARGET}" voxtype.config.toml
  backup_target "${PIPEWIRE_TARGET}" pipewire.conf
  backup_target "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf
  printf 'default_source=%s\ndefault_sink=%s\n' \
    "$(pactl get-default-source)" "$(pactl get-default-sink)" \
    >"${BACKUP_ROOT}/${BACKUP_ID}/metadata"

  voxtype config unset vad.enabled || true
  voxtype config unset vad.backend || true
  voxtype config unset vad.threshold || true
  rm -f -- "${PIPEWIRE_TARGET}" "${LEGACY_PIPEWIRE_TARGET}"
  systemctl --user restart pipewire-pulse.service

  local source
  source="$(physical_source)"
  if [[ -n ${source} ]]; then
    safe_name "${source}"
    pactl set-default-source "${source}"
  fi
  systemctl --user restart voxtype.service
  printf 'voice-legacy-repair: applied; backup=%s\n' "${BACKUP_ID}"
}

select_latest_backup() {
  [[ -d ${BACKUP_ROOT} ]] || die "no repair backups found under ${BACKUP_ROOT}"
  BACKUP_ID="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n 1)"
  [[ -n ${BACKUP_ID} ]] || die 'no repair backups found'
}

rollback_repair() {
  need pactl
  need systemctl
  select_latest_backup
  restore_target "${VOXTYPE_TARGET}" voxtype.config.toml
  restore_target "${PIPEWIRE_TARGET}" pipewire.conf
  restore_target "${LEGACY_PIPEWIRE_TARGET}" legacy.pipewire.conf
  systemctl --user restart pipewire-pulse.service

  local source sink
  source="$(sed -n 's/^default_source=//p' "${BACKUP_ROOT}/${BACKUP_ID}/metadata" 2>/dev/null || true)"
  sink="$(sed -n 's/^default_sink=//p' "${BACKUP_ROOT}/${BACKUP_ID}/metadata" 2>/dev/null || true)"
  if [[ -n ${source} ]] && pactl list short sources | awk -v target="${source}" '$2 == target {found=1} END {exit !found}'; then
    safe_name "${source}"
    pactl set-default-source "${source}"
  fi
  if [[ -n ${sink} ]] && pactl list short sinks | awk -v target="${sink}" '$2 == target {found=1} END {exit !found}'; then
    safe_name "${sink}"
    pactl set-default-sink "${sink}"
  fi
  systemctl --user restart voxtype.service
  printf 'voice-legacy-repair: restored backup %s\n' "${BACKUP_ID}"
}

case ${ACTION} in
  check) need voxtype; need pactl; report_state ;;
  apply) apply_repair; report_state ;;
  rollback) rollback_repair ;;
esac
