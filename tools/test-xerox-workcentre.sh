#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="$ROOT_DIR/scripts/xerox-workcentre.sh"

output="$("$INSTALLER" --check --host scanner.example.test)"
grep -Fq 'packages: cups cups-filters sane sane-airscan simple-scan' <<<"$output"
grep -Fq 'printer URI: ipp://scanner.example.test/ipp/print' <<<"$output"
grep -Fq 'scanner URL: http://scanner.example.test:8018/wsd/scan' <<<"$output"
grep -Fq 'default queue: xerox-workcentre-3025' <<<"$output"
grep -Fq 'check: no changes made' <<<"$output"

if "$INSTALLER" --check --host 'not a host' >/dev/null 2>&1; then
  printf '%s\n' 'test-xerox-workcentre: invalid host was accepted' >&2
  exit 1
fi

printf '%s\n' 'test-xerox-workcentre: PASS'
