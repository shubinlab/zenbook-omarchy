#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
exec "$ROOT_DIR/profiles/zenbook-um3406ka/voice/repair-legacy.sh" "$@"
