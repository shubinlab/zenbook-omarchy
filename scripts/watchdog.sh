#!/usr/bin/env bash
set -euo pipefail

# Installs the tested, journal-only NVMe watchdog and its Hermes Telegram bridge.
# Credentials, chat IDs, host identifiers, and runtime backups stay outside Git.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
NVME_DEVICE="/dev/nvme0"
SMARTD_CONFIG="/etc/smartd-zenbook.conf"
SMARTD_DEFAULTS="/etc/conf.d/smartd"
SMARTD_ARGS_LINE='SMARTD_ARGS="-c /etc/smartd-zenbook.conf -i 1800"'
HERMES_JOB_NAME="zenbook-nvme-telegram-alerts"
HERMES_SCRIPT_NAME="zenbook-smartd-alert.sh"
HERMES_SCRIPT_SOURCE="$ROOT_DIR/scripts/$HERMES_SCRIPT_NAME"
HERMES_SCRIPT_DEST="${HOME}/.hermes/scripts/$HERMES_SCRIPT_NAME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-profiles/watchdog"
BACKUP_POINTER="$STATE_DIR/current-backup"
PACKAGES=(fwupd smartmontools nvme-cli)
ACTION="plan"
CHECK_FAILED=0

usage() {
  cat <<'HELP'
Usage: scripts/watchdog.sh [--plan|--check|--install|--uninstall] [--device /dev/nvmeN]

Actions:
  --plan       Show the changes without touching the system (default).
  --check      Verify packages, smartd, Hermes job, and the alert script.
  --install    Install packages if missing and apply the tested watchdog setup.
  --uninstall  Remove this watchdog and restore the saved pre-install state.

The installer uses Omarchy package helpers, pkexec for system files, the existing
Hermes Telegram configuration, and a private backup under ~/.local/state.
It never sends a real alert during installation.
HELP
}

die() {
  printf 'watchdog: ERROR: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

root() {
  pkexec "$@"
}

validate_device() {
  [[ "$NVME_DEVICE" =~ ^/dev/nvme[0-9]+$ ]] || die "invalid NVMe device: $NVME_DEVICE"
}

validate_sources() {
  [[ -f "$HERMES_SCRIPT_SOURCE" ]] || die "missing repository file: $HERMES_SCRIPT_SOURCE"
  bash -n "$HERMES_SCRIPT_SOURCE"
}

package_install() {
  local missing=()
  local package
  for package in "${PACKAGES[@]}"; do
    if ! omarchy pkg present "$package" >/dev/null 2>&1; then
      missing+=("$package")
    fi
  done
  if ((${#missing[@]})); then
    printf 'watchdog: installing missing packages through omarchy: %s\n' "${missing[*]}"
    omarchy pkg add "${missing[@]}"
  fi
}

hermes_job_id() {
  python - "$HERMES_JOB_NAME" <<'PY'
import json
import sys
from pathlib import Path

jobs_file = Path.home() / ".hermes" / "cron" / "jobs.json"
try:
    jobs = json.loads(jobs_file.read_text()).get("jobs", [])
except (FileNotFoundError, OSError, json.JSONDecodeError):
    raise SystemExit(0)
for job in jobs:
    if job.get("name") == sys.argv[1]:
        print(job.get("id", ""))
        break
PY
}

hermes_job_matches() {
  local job_id="$1"
  python - "$HERMES_JOB_NAME" "$job_id" <<'PY'
import json
import sys
from pathlib import Path

jobs_file = Path.home() / ".hermes" / "cron" / "jobs.json"
try:
    jobs = json.loads(jobs_file.read_text()).get("jobs", [])
except (FileNotFoundError, OSError, json.JSONDecodeError):
    raise SystemExit(1)
for job in jobs:
    if job.get("name") == sys.argv[1] and job.get("id") == sys.argv[2]:
        schedule = job.get("schedule", {})
        expected = (
            job.get("script") == "zenbook-smartd-alert.sh"
            and job.get("no_agent") is True
            and job.get("deliver") == "telegram"
            and job.get("enabled") is True
            and schedule.get("kind") == "interval"
            and schedule.get("minutes") == 15
        )
        raise SystemExit(0 if expected else 1)
raise SystemExit(1)
PY
}

backup_path() {
  [[ -r "$BACKUP_POINTER" ]] || return 1
  local path
  path=$(<"$BACKUP_POINTER")
  [[ "$path" == "$STATE_DIR/backups/"* && -d "$path" ]] || return 1
  printf '%s\n' "$path"
}

backup_once() {
  local current
  if current=$(backup_path); then
    printf 'watchdog: preserving existing rollback backup: %s\n' "$current"
    return 0
  fi

  local backup_dir
  backup_dir="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  if [[ -e "$SMARTD_CONFIG" ]]; then
    cp -a "$SMARTD_CONFIG" "$backup_dir/smartd-zenbook.conf"
  else
    : > "$backup_dir/smartd-zenbook.conf.absent"
  fi
  if [[ -e "$SMARTD_DEFAULTS" ]]; then
    cp -a "$SMARTD_DEFAULTS" "$backup_dir/smartd"
  else
    : > "$backup_dir/smartd.absent"
  fi
  if [[ -e "$HERMES_SCRIPT_DEST" ]]; then
    cp -a "$HERMES_SCRIPT_DEST" "$backup_dir/hermes-alert.sh"
  else
    : > "$backup_dir/hermes-alert.sh.absent"
  fi
  if systemctl is-enabled --quiet smartd.service 2>/dev/null; then
    printf 'enabled\n' > "$backup_dir/smartd.enabled"
  else
    printf 'disabled\n' > "$backup_dir/smartd.enabled"
  fi
  if systemctl is-active --quiet smartd.service 2>/dev/null; then
    printf 'active\n' > "$backup_dir/smartd.active"
  else
    printf 'inactive\n' > "$backup_dir/smartd.active"
  fi
  printf '%s\n' "$backup_dir" > "$BACKUP_POINTER"
  chmod 600 "$BACKUP_POINTER"
  printf 'watchdog: rollback backup: %s\n' "$backup_dir"
}

write_smartd_config() {
  local temp
  temp=$(mktemp)
  printf '%s\n' \
    '# Minimal read-only monitoring for the internal NVMe controller.' \
    '# Journal only: no mail transport and no automatic device changes.' \
    "$NVME_DEVICE -d nvme -H -l error -W 5,70,80" > "$temp"
  root install -o root -g root -m 0644 "$temp" "$SMARTD_CONFIG"
  unlink "$temp"
}

write_smartd_defaults() {
  local temp
  temp=$(mktemp)
  awk -v replacement="$SMARTD_ARGS_LINE" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*SMARTD_ARGS=/ {
      if (!replaced) {
        print replacement
        replaced = 1
      }
      next
    }
    { print }
    END {
      if (!replaced) print replacement
    }
  ' "$SMARTD_DEFAULTS" > "$temp"
  root install -o root -g root -m 0644 "$temp" "$SMARTD_DEFAULTS"
  unlink "$temp"
}

install_hermes_bridge() {
  [[ -d "$HOME/.hermes" ]] || die "Hermes configuration is missing: $HOME/.hermes"
  mkdir -p "${HERMES_SCRIPT_DEST%/*}"
  install -m 0700 "$HERMES_SCRIPT_SOURCE" "$HERMES_SCRIPT_DEST"

  local job_id
  job_id=$(hermes_job_id || true)
  if [[ -n "$job_id" ]] && hermes_job_matches "$job_id"; then
    printf 'watchdog: Hermes cron already matches the tested configuration\n'
    return 0
  fi
  if [[ -n "$job_id" ]]; then
    printf 'watchdog: replacing stale Hermes job %s\n' "$job_id"
    hermes cron remove "$job_id"
  fi
  hermes cron create 'every 15m' \
    --name "$HERMES_JOB_NAME" \
    --deliver telegram \
    --no-agent \
    --script "$HERMES_SCRIPT_NAME"
}

check_one() {
  local label="$1"
  shift
  if "$@"; then
    printf 'PASS: %s\n' "$label"
  else
    printf 'FAIL: %s\n' "$label"
    CHECK_FAILED=1
  fi
}

check_installation() {
  validate_device
  validate_sources
  need omarchy
  need hermes
  need python
  need systemctl
  check_one "packages" bash -c 'for package in "$@"; do omarchy pkg present "$package" >/dev/null 2>&1 || exit 1; done' _ "${PACKAGES[@]}"
  check_one "NVMe controller $NVME_DEVICE" test -c "$NVME_DEVICE"
  check_one "smartd configuration" test -r "$SMARTD_CONFIG"
  check_one "smartd device rule" grep -Fqx "$NVME_DEVICE -d nvme -H -l error -W 5,70,80" "$SMARTD_CONFIG"
  check_one "smartd arguments" grep -Fqx "$SMARTD_ARGS_LINE" "$SMARTD_DEFAULTS"
  check_one "smartd enabled" systemctl is-enabled --quiet smartd.service
  check_one "smartd active" systemctl is-active --quiet smartd.service
  check_one "Hermes alert script" cmp -s "$HERMES_SCRIPT_SOURCE" "$HERMES_SCRIPT_DEST"
  check_one "Hermes alert script mode" bash -c '[[ "$(stat -c %a "$1")" == 700 ]]' _ "$HERMES_SCRIPT_DEST"
  local job_id
  job_id=$(hermes_job_id || true)
  check_one "Hermes cron job exists" test -n "$job_id"
  if [[ -n "$job_id" ]]; then
    check_one "Hermes cron job matches" hermes_job_matches "$job_id"
  fi
  if ((CHECK_FAILED)); then
    printf '%s\n' 'watchdog: RESULT FAIL'
    return 1
  fi
  printf '%s\n' 'watchdog: RESULT PASS'
}

plan() {
  validate_device
  validate_sources
  printf '%s\n' 'watchdog plan (no changes)'
  printf '  device: %s\n' "$NVME_DEVICE"
  printf '  packages: %s\n' "${PACKAGES[*]}"
  printf '  system config: %s\n' "$SMARTD_CONFIG"
  printf '  smartd defaults: %s\n' "$SMARTD_DEFAULTS"
  printf '  smartd interval: 1800 seconds\n'
  printf '  Hermes script: %s\n' "$HERMES_SCRIPT_DEST"
  printf '  Hermes job: %s / every 15m / no-agent / telegram\n' "$HERMES_JOB_NAME"
  printf '  rollback state: %s\n' "$STATE_DIR"
}

install_watchdog() {
  validate_device
  validate_sources
  need omarchy
  need hermes
  need python
  need pkexec
  need systemctl
  [[ -c "$NVME_DEVICE" ]] || die "NVMe controller not found: $NVME_DEVICE"
  package_install
  backup_once
  write_smartd_config
  write_smartd_defaults
  root systemctl enable --now smartd.service
  root smartd -q onecheck -c "$SMARTD_CONFIG" -r nvmeioctl 2>&1 \
    | sed -E 's/S\/N:[^, ]+/<redacted>/g'
  install_hermes_bridge
  ZENBOOK_WATCHDOG_SELFTEST=1 "$HERMES_SCRIPT_DEST"
  check_installation
}

restore_file() {
  local backup_dir="$1"
  local backup_name="$2"
  local target="$3"
  if [[ -f "$backup_dir/$backup_name" ]]; then
    root install -o root -g root -m 0644 "$backup_dir/$backup_name" "$target"
  elif [[ -e "$backup_dir/$backup_name.absent" && -e "$target" ]]; then
    root unlink "$target"
  fi
}

uninstall_watchdog() {
  need python
  need systemctl
  need pkexec
  local backup_dir
  backup_dir=$(backup_path || true)
  if [[ -z "$backup_dir" ]]; then
    printf '%s\n' 'watchdog: no rollback backup found; refusing to change the installation' >&2
    return 1
  fi

  if command -v hermes >/dev/null 2>&1; then
    local job_id
    job_id=$(hermes_job_id || true)
    if [[ -n "$job_id" ]]; then
      hermes cron remove "$job_id"
    fi
  else
    printf '%s\n' 'watchdog: Hermes is missing; cron job was not changed' >&2
  fi
  if [[ -e "$HERMES_SCRIPT_DEST" ]]; then
    if cmp -s "$HERMES_SCRIPT_SOURCE" "$HERMES_SCRIPT_DEST"; then
      if [[ -f "$backup_dir/hermes-alert.sh" ]]; then
        install -m 0700 "$backup_dir/hermes-alert.sh" "$HERMES_SCRIPT_DEST"
      elif [[ -e "$backup_dir/hermes-alert.sh.absent" ]]; then
        unlink "$HERMES_SCRIPT_DEST"
      fi
    else
      printf '%s\n' "watchdog: preserving modified Hermes script: $HERMES_SCRIPT_DEST" >&2
    fi
  elif [[ -f "$backup_dir/hermes-alert.sh" ]]; then
    mkdir -p "${HERMES_SCRIPT_DEST%/*}"
    install -m 0700 "$backup_dir/hermes-alert.sh" "$HERMES_SCRIPT_DEST"
  fi

  root systemctl disable --now smartd.service || true
  restore_file "$backup_dir" smartd-zenbook.conf "$SMARTD_CONFIG"
  restore_file "$backup_dir" smartd "$SMARTD_DEFAULTS"
  if [[ -f "$backup_dir/smartd.enabled" ]] && [[ $(<"$backup_dir/smartd.enabled") == enabled ]]; then
    root systemctl enable smartd.service
  fi
  if [[ -f "$backup_dir/smartd.active" ]] && [[ $(<"$backup_dir/smartd.active") == active ]]; then
    root systemctl start smartd.service
  fi
  printf 'watchdog: restored rollback backup: %s\n' "$backup_dir"
  printf '%s\n' 'watchdog: uninstall complete; packages were intentionally left installed'
}

while (($#)); do
  case "$1" in
    --plan) ACTION=plan; shift ;;
    --check) ACTION=check; shift ;;
    --install|--apply) ACTION=install; shift ;;
    --uninstall|--remove) ACTION=uninstall; shift ;;
    --device)
      (($# >= 2)) || die '--device needs a value'
      NVME_DEVICE="$2"
      shift 2
      ;;
    --device=*) NVME_DEVICE="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$ACTION" in
  plan) plan ;;
  check) check_installation ;;
  install) install_watchdog ;;
  uninstall) uninstall_watchdog ;;
esac
