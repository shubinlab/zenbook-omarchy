#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

bash -n install.sh scripts/*.sh tools/*.sh profiles/*/display-doctor.sh profiles/*/input/*.sh profiles/*/voice/*.sh profiles/*/search/*.sh profiles/*/tools/*.sh profiles/*/terminal/*.sh profiles/*/terminal/omarchy-fzf-preview profiles/*/terminal/terminal-doctor profiles/*/bitwarden/*.sh profiles/*/bitwarden/launcher profiles/*/branding/*.sh profiles/*/branding/post-update-hook
python -m py_compile profiles/*/input/*.py profiles/*/search/*.py profiles/*/tools/*.py tools/update-package-wiki.py
./profiles/zenbook-um3406ka/input/test_input_policy.sh
./tools/check-public-repo.sh
./tools/red-team-check.sh
git diff --check
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./profiles/zenbook-um3406ka/search/test_unit_contract.sh
./tools/test-voice-policy.sh
python profiles/zenbook-um3406ka/search/test_searxng_search.py -v
./tools/test-xerox-workcentre.sh

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
