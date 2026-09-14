#!/usr/bin/env bash
set -euo pipefail

# Lightweight pre-publish check. It is intentionally conservative and does not
# replace a human review of new diagnostics or GitHub secret scanning.
root="$(git rev-parse --show-toplevel)"
cd "$root"

command -v rg >/dev/null 2>&1 || {
  printf '%s\n' 'public-repo-check: rg is required' >&2
  exit 2
}

secret_pattern='(-----BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|sk-[A-Za-z0-9]{20,})'
private_path_pattern='/(home|root)/[[:alnum:]_.-]+([/]|$)'

# Scan both the worktree and the index. The publication checklist asks for a
# staged review, and git grep without --cached can miss content staged before a
# later worktree edit.
if git ls-files -co --exclude-standard -z |
   xargs -0 -r rg -nI --regexp "${secret_pattern}|${private_path_pattern}" --; then
  printf '%s\n' 'public-repo-check: possible secret or private path pattern found' >&2
  exit 1
fi

if ! git diff --cached --quiet --; then
  if git grep --cached -nI -E "${secret_pattern}|${private_path_pattern}" -- .; then
    printf '%s\n' 'public-repo-check: possible secret or private path pattern found in index' >&2
    exit 1
  fi
fi

if git ls-files -c | awk '$0 ~ /(^|\/)runs\// && $0 !~ /(^|\/)runs\/\.gitkeep$/ {print}' | grep -q .; then
  printf '%s\n' 'public-repo-check: raw run artifacts are tracked under runs/' >&2
  exit 1
fi

printf '%s\n' 'public-repo-check: no known key/token patterns or tracked raw runs'
