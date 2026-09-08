#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

bash -n install.sh install/bootstrap.sh tools/*.sh
python -m py_compile tools/*.py
./tools/check-public-repo.sh
git diff --check

printf '%s\n' 'ci-check: PASS'
