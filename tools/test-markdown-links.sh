#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
python3 "$root/tools/check-markdown-links.py" --root "$root"
