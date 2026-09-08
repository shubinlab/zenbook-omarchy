#!/usr/bin/env bash
set -euo pipefail

# Short entry point. The generic engine selects a profile after cloning.
repo_url="https://github.com/shubinlab/zenbook-omarchy.git"
repo_dir="${OMARCHY_DIR:-$HOME/zenbook-omarchy}"
check_only=0

for arg in "$@"; do
  case "$arg" in
    --check) check_only=1 ;;
    -h|--help)
      cat <<'HELP'
Omarchy Zenbook installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash

Useful options:
  --check                 Verify the published repository without changes.
  --stage NAME            Run one stage: vpn, display, packages, voice,
                          terminal, update or doctor.
  --manifest              Print the stage manifest as JSON.
  --non-interactive       Stop before stages that need terminal input.
  --no-vpn                Skip VPN connection for this run.
  --no-voice              Skip native Voxtype setup.
  --no-terminal           Skip terminal settings.
  --profile ID            Select a profile explicitly.
HELP
      exit 0
      ;;
  esac
done

command -v git >/dev/null 2>&1 || {
  printf '%s\n' 'omarchy-profiles: git is required' >&2
  exit 1
}

if ((check_only)); then
  command -v curl >/dev/null 2>&1 || {
    printf '%s\n' 'omarchy-profiles check: curl is required' >&2
    exit 1
  }
  check_dir="$(mktemp -d)"
  trap 'rm -rf "$check_dir"' EXIT
  printf '%s\n' 'omarchy-profiles check: cloning the published repository'
  git clone --depth=1 "$repo_url" "$check_dir/repo" >/dev/null
  bash -n "$check_dir/repo/install.sh" "$check_dir/repo/scripts/bootstrap.sh"
  "$check_dir/repo/scripts/bootstrap.sh" --profile auto --check
  printf '%s\n' 'omarchy-profiles check: PASS (no system changes made)'
  exit 0
fi

if [[ -d "$repo_dir/.git" ]]; then
  if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
    printf '%s\n' "omarchy-profiles: refusing to update a modified checkout: $repo_dir" >&2
    printf '%s\n' 'omarchy-profiles: commit, stash or remove local changes, then retry' >&2
    exit 1
  fi
  printf 'omarchy-profiles: updating %s\n' "$repo_dir"
  git -C "$repo_dir" pull --ff-only
else
  printf 'omarchy-profiles: cloning into %s\n' "$repo_dir"
  git clone --depth=1 "$repo_url" "$repo_dir"
fi

exec "$repo_dir/scripts/bootstrap.sh" --profile auto --update-system "$@"
