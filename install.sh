#!/usr/bin/env bash
set -euo pipefail

# Friendly one-command entry point. The full logic lives in the cloned repo.
repo_url="https://github.com/shubinlab/zenbook-omarchy.git"
repo_dir="${ZENBOOK_OMARCHY_DIR:-$HOME/zenbook-omarchy}"

command -v git >/dev/null 2>&1 || {
  printf '%s\n' 'zenbook-omarchy: git is required' >&2
  exit 1
}

if [[ -d "$repo_dir/.git" ]]; then
  printf 'zenbook-omarchy: updating %s\n' "$repo_dir"
  git -C "$repo_dir" pull --ff-only
else
  printf 'zenbook-omarchy: cloning into %s\n' "$repo_dir"
  git clone --depth=1 "$repo_url" "$repo_dir"
fi

exec "$repo_dir/install/bootstrap.sh" --vpn --update-system "$@"
