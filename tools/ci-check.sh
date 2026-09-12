#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

bash -n install.sh scripts/*.sh tools/*.sh profiles/*/display-doctor.sh profiles/*/input/*.sh profiles/*/voice/*.sh profiles/*/tools/*.sh profiles/*/terminal/*.sh profiles/*/terminal/omarchy-fzf-preview profiles/*/terminal/terminal-doctor profiles/*/bitwarden/*.sh profiles/*/bitwarden/launcher profiles/*/branding/*.sh profiles/*/branding/post-update-hook
python -m py_compile profiles/*/input/*.py profiles/*/tools/*.py tools/update-package-wiki.py
./tools/check-public-repo.sh
./tools/red-team-check.sh
git diff --check

plan_output="$(./scripts/bootstrap.sh --profile zenbook-um3406ka --stage all \
  --plan --no-vpn --no-bitwarden)"
grep -q 'Native boundary: no edits to /usr/share/omarchy' <<<"$plan_output"
grep -q 'Input: apply us,ru XKB with bidirectional Alt+Shift' <<<"$plan_output"
grep -q 'Voice: keep native Omarchy Voxtype; add 2 Lemonade/NPU package entries' <<<"$plan_output"
package_plan="$(./scripts/bootstrap.sh --profile zenbook-um3406ka --stage packages \
  --plan --no-vpn)"
! grep -q '^  Display:' <<<"$package_plan"
! grep -q '^  Terminal:' <<<"$package_plan"

printf '%s\n' 'ci-check: PASS'
