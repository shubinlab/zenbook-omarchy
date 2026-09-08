#!/usr/bin/env bash
set -Eeuo pipefail

# Remove only Voxtype model artifacts that are provably unused by this profile.
# The active transcription path is remote Lemonade/FLM on the NPU. This file
# deliberately stays outside the clean-install flow: native Omarchy owns its
# model download and may recreate the stock model on a future reinstall.

CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
MODELS_DIR="${DATA_HOME}/voxtype/models"
BACKUP_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/omarchy-profiles/backups/voice-model-cleanup"
ACTION=check

die() { printf 'voice-model-cleanup: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat <<'EOF'
Usage: profiles/zenbook-um3406ka/voice/cleanup-unused-models.sh [--check|--apply]

--check  verify the active remote/NPU policy and list removable files (default)
--apply  move base, base.en and Silero VAD files to a recoverable backup

The script refuses to run unless Voxtype is in remote Whisper mode, has no
secondary local model, and VAD is disabled. It never removes the active
large-v3-turbo artifact or any Lemonade model.
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --apply) ACTION=apply ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ ${EUID} -ne 0 ]] || die 'run as the normal Omarchy user, not root'
need voxtype
need systemctl
need curl
need jq

[[ "$(voxtype config get engine 2>/dev/null || true)" == whisper ]] ||
  die 'active Voxtype engine is not whisper'
[[ "$(voxtype config get whisper.mode 2>/dev/null || true)" == remote ]] ||
  die 'Voxtype is not in remote mode; refusing local model cleanup'
remote_endpoint="$(voxtype config get whisper.remote_endpoint 2>/dev/null || true)"
remote_model="$(voxtype config get whisper.remote_model 2>/dev/null || true)"
[[ ${remote_endpoint} == http://127.0.0.1:* ]] ||
  die 'remote endpoint is not loopback; refusing local model cleanup'
curl --fail --silent --show-error --max-time 10 \
  "${remote_endpoint}/api/v1/health" |
  jq -e --arg model "${remote_model}" '
    .telemetry.enabled == false and
    ([.all_models_loaded[]? | select(
      .model_name == $model and .recipe == "flm" and
      .device == "npu" and .backend_health == "ready" and .loaded == true
    )] | length == 1)
  ' >/dev/null || die 'Lemonade NPU model is not ready; refusing local model cleanup'
secondary_model="$(voxtype config get whisper.secondary_model 2>/dev/null || true)"
[[ -z ${secondary_model} || ${secondary_model} == null || ${secondary_model} == unset ]] ||
  die "secondary local model is configured: ${secondary_model}"
[[ "$(voxtype config get vad.enabled 2>/dev/null || true)" == false ]] ||
  die 'Voxtype VAD is enabled; refusing to remove its model'

targets=(
  "${MODELS_DIR}/ggml-base.bin"
  "${MODELS_DIR}/ggml-base.en.bin"
  "${MODELS_DIR}/ggml-silero-vad.bin"
)

printf 'voice-model-cleanup: active path remote Whisper -> Lemonade/FLM NPU\n'
printf 'voice-model-cleanup: verified %s model on the live NPU endpoint\n' "${remote_model}"
printf 'voice-model-cleanup: VAD disabled; large-v3-turbo is not a cleanup target\n'
found=0
for target in "${targets[@]}"; do
  if [[ -L ${target} ]]; then
    die "refusing to move symlink: ${target}"
  elif [[ -f ${target} ]]; then
    printf 'FOUND %s (%s bytes)\n' "${target}" "$(stat -c '%s' -- "${target}")"
    found=1
  else
    printf 'ABSENT %s\n' "${target}"
  fi
done

if [[ ${ACTION} == check ]]; then
  printf 'result=CHECK (no files changed)\n'
  exit 0
fi

((found)) || { printf 'result=PASS (nothing to move)\n'; exit 0; }
if [[ "$(voxtype status 2>/dev/null || true)" != idle ]]; then
  die 'Voxtype is recording or transcribing; stop it before cleanup'
fi

was_active=0
if systemctl --user is-active --quiet voxtype.service; then
  was_active=1
  systemctl --user stop voxtype.service
fi

BACKUP_ID="$(date -u +%Y%m%dT%H%M%S%N)-${BASHPID}"
backup_dir="${BACKUP_ROOT}/${BACKUP_ID}/models"
mkdir -p "${backup_dir}"
restore_on_error() {
  local backup
  for backup in "${backup_dir}"/*; do
    [[ -e ${backup} ]] || continue
    mv -- "${backup}" "${MODELS_DIR}/$(basename -- "${backup}")"
  done
  if ((was_active)); then
    systemctl --user start voxtype.service || true
  fi
}
trap restore_on_error ERR

for target in "${targets[@]}"; do
  if [[ -f ${target} ]]; then
    mv -- "${target}" "${backup_dir}/$(basename -- "${target}")"
  fi
done
printf 'backup=%s\n' "${backup_dir}"

if ((was_active)); then
  systemctl --user start voxtype.service
fi
trap - ERR
printf 'result=PASS (unused files moved to recoverable backup)\n'
