#!/usr/bin/env bash
set -euo pipefail

# Compatibility entry point. Keep one authoritative native voice check.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec "${SCRIPT_DIR}/apply.sh" --check "$@"
