#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
UNIT_NAME="searxng.service"
UNIT_SOURCE="${SCRIPT_DIR}/${UNIT_NAME}"
UNIT_TARGET="/etc/systemd/system/${UNIT_NAME}"
SEARXNG_DIR="${SEARXNG_DIR:-${HOME}/.local/share/searxng}"
STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
BACKUP_ROOT="${STATE_HOME}/omarchy-profiles/backups/search"
ACTION=check
RENDERED_UNIT=""
VERIFY_OUTPUT=""

usage() {
  cat <<'EOF'
Usage: profiles/zenbook-um3406ka/search/apply.sh [--check|--apply]

Installs the root-owned systemd lifecycle owner for the loopback-only
SearXNG Compose stack. The default is a read-only check.
SEARXNG_DIR may override the local Compose directory for this run.
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --apply) ACTION=apply ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'search: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

fail() { printf 'FAIL search: %s\n' "$*" >&2; exit 1; }
cleanup() { rm -f -- "${RENDERED_UNIT}" "${VERIFY_OUTPUT}"; }
trap cleanup EXIT

[[ "${EUID}" -ne 0 ]] || fail 'run as the normal Omarchy user, not root'
[[ -r "${UNIT_SOURCE}" ]] || fail "missing unit template: ${UNIT_SOURCE}"
[[ "${SEARXNG_DIR}" =~ ^/[A-Za-z0-9._/@+-]+$ ]] ||
  fail 'SEARXNG_DIR must be an absolute path without whitespace or unit metacharacters'

RENDERED_UNIT="$(mktemp --suffix=.service)"
VERIFY_OUTPUT="$(mktemp)"
sed "s|@SEARXNG_DIR@|${SEARXNG_DIR}|g" "${UNIT_SOURCE}" >"${RENDERED_UNIT}"
systemd-analyze verify "${RENDERED_UNIT}" >"${VERIFY_OUTPUT}" 2>&1 || {
  cat "${VERIFY_OUTPUT}" >&2
  fail 'unit verification failed'
}

check_runtime() {
  [[ "$(systemctl is-enabled "${UNIT_NAME}" 2>/dev/null || true)" == enabled ]] || fail "${UNIT_NAME} is not enabled"
  [[ "$(systemctl is-active "${UNIT_NAME}" 2>/dev/null || true)" == active ]] || fail "${UNIT_NAME} is not active"
  [[ "$(systemctl is-active docker.service 2>/dev/null || true)" == active ]] || fail 'docker.service is not active'
  curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8080/healthz >/dev/null ||
    fail 'SearXNG /healthz is not ready'
  if ss -ltn 2>/dev/null | awk '$4 ~ /127\.0\.0\.1:8080$/ { found=1 } END { exit !found }'; then
    :
  else
    fail 'port 8080 is not loopback-only'
  fi
  printf '%s\n' 'OK search: systemd owner, Docker, readiness, and loopback binding are healthy'
}

if [[ "${ACTION}" == check ]]; then
  [[ -e "${UNIT_TARGET}" ]] || fail "missing ${UNIT_TARGET} (run --apply with visible pkexec authentication)"
  check_runtime
  exit 0
fi

command -v pkexec >/dev/null 2>&1 || fail 'pkexec is required for system installation'
command -v docker >/dev/null 2>&1 || fail 'docker is required'
command -v curl >/dev/null 2>&1 || fail 'curl is required'
mkdir -p "${BACKUP_ROOT}"
backup_id="$(date -u +%Y%m%dT%H%M%SZ)-${BASHPID}"
backup_dir="${BACKUP_ROOT}/${backup_id}"
mkdir -p -m 0700 "${backup_dir}"
if pkexec test -e "${UNIT_TARGET}"; then
  pkexec cp -a -- "${UNIT_TARGET}" "${backup_dir}/${UNIT_NAME}"
  pkexec chown "$(id -u):$(id -g)" "${backup_dir}/${UNIT_NAME}"
fi

pkexec install -D -m 0644 "${RENDERED_UNIT}" "${UNIT_TARGET}"
pkexec systemctl daemon-reload
pkexec systemctl enable --now docker.service
pkexec systemctl enable --now "${UNIT_NAME}"

for _ in $(seq 1 60); do
  if curl --fail --silent --show-error --max-time 3 http://127.0.0.1:8080/healthz >/dev/null; then
    check_runtime
    printf 'search: applied (backup: %s)\n' "${backup_dir}"
    exit 0
  fi
  sleep 2
done

systemctl status "${UNIT_NAME}" --no-pager >&2 || true
fail 'SearXNG did not become ready within 120 seconds'
