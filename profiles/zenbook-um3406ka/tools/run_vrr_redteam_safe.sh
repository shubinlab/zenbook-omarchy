#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec systemd-inhibit \
  --what=idle:sleep:handle-lid-switch \
  --who=zenbook-omarchy-test \
  --why='Hold display/idle/lid state stable during VRR measurements' \
  --mode=block \
  python3 "$script_dir/run_vrr_redteam.py" "$@"
