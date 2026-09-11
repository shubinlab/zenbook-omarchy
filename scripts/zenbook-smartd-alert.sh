#!/usr/bin/env bash
set -euo pipefail

umask 077
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hermes"
state_file="$state_dir/zenbook-smartd-alert.last"
mkdir -p "$state_dir"

if [[ "${ZENBOOK_WATCHDOG_SELFTEST:-0}" == 1 ]]; then
  printf '🚨 Zenbook watchdog self-test: Telegram delivery path is configured.\n'
  exit 0
fi

now=$(date +%s)
last=$(cat "$state_file" 2>/dev/null || date -d '20 minutes ago' +%s)
printf '%s\n' "$now" > "$state_file"

smartd_lines=$(journalctl -u smartd.service --since "@$last" --until now --no-pager -o short-iso 2>/dev/null || true)
kernel_lines=$(journalctl -k --since "@$last" --until now --no-pager -o short-iso 2>/dev/null \
  | rg -i 'nvme.*(timeout|reset|I/O error|failed)|BTRFS error|AER:.*(Corrected|Uncorrected|Fatal)' || true)

alert_lines=$(printf '%s\n%s\n' "$smartd_lines" "$kernel_lines" \
  | rg -i 'Critical Warning|Media and Data Integrity Errors|SMART.*(fail|error)|Error Information Log entries increased|device-related|temperature.*(7[0-9]|8[0-9]|9[0-9])|nvme.*(timeout|reset|I/O error|failed)|BTRFS error|AER:.*(Corrected|Uncorrected|Fatal)' \
  | sed -E 's/S\/N:[^, ]+/<redacted>/g' \
  | tail -20 || true)

if [[ -n "$alert_lines" ]]; then
  printf '🚨 Zenbook storage alert\n%s\n\n%s\n' "$(date --iso-8601=seconds)" "$alert_lines"
fi
