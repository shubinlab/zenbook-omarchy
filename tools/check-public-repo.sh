#!/usr/bin/env bash
set -euo pipefail

# Lightweight pre-publish check. It is intentionally conservative and does not
# replace a human review of new diagnostics or GitHub secret scanning.
root="$(git rev-parse --show-toplevel)"
cd "$root"

secret_pattern='(-----BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|sk-[A-Za-z0-9]{20,})'

# Scan both the worktree and the index. The publication checklist asks for a
# staged review, and git grep without --cached can miss content staged before a
# later worktree edit.
if git grep -nI -E "$secret_pattern" -- . ||
   git grep --cached -nI -E "$secret_pattern" -- .; then
  printf '%s\n' 'public-repo-check: possible secret pattern found' >&2
  exit 1
fi

if git ls-files | awk '$0 ~ /^runs\// && $0 !~ /^runs\/\.gitkeep$/ {print}' | grep -q .; then
  printf '%s\n' 'public-repo-check: raw run artifacts are tracked under runs/' >&2
  exit 1
fi

printf '%s\n' 'public-repo-check: no known key/token patterns or tracked raw runs'
