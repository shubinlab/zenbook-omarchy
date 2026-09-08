#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

bash -n install.sh scripts/*.sh tools/*.sh profiles/*/voice/*.sh profiles/*/tools/*.sh profiles/*/terminal/*.sh profiles/*/terminal/omarchy-fzf-preview profiles/*/terminal/terminal-doctor profiles/*/bitwarden/*.sh profiles/*/bitwarden/launcher
python -m py_compile profiles/*/tools/*.py tools/update-package-wiki.py
./tools/check-public-repo.sh
git diff --check

printf '%s\n' 'ci-check: PASS'
