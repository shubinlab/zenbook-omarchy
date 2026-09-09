#!/usr/bin/env bash
set -euo pipefail

# Short entry point. The generic engine selects a profile after cloning.
repo_url="https://github.com/shubinlab/zenbook-omarchy.git"
repo_dir="${OMARCHY_DIR:-$HOME/zenbook-omarchy}"
repo_ref="${OMARCHY_REF:-main}"
check_only=0
manifest_only=0
plan_only=0

for arg in "$@"; do
  case "$arg" in
    --check) check_only=1 ;;
    --manifest) manifest_only=1 ;;
    --plan) plan_only=1 ;;
    -h|--help)
      cat <<'HELP'
Omarchy Zenbook installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash

Useful options:
  --check                 Verify the published repository without changes.
  --stage NAME            Run one stage: vpn, display, packages, bitwarden,
                          voice, diagnostics, terminal, update or doctor.
  --manifest              Print the stage manifest as JSON.
  --update-system         Run `omarchy update` explicitly after the profile.
  --non-interactive       Stop before stages that need terminal input.
  --no-vpn                Skip VPN connection for this run.
  --no-voice              Skip native Voxtype setup.
  --no-bitwarden          Skip native Wayland Bitwarden setup.
  --no-terminal           Skip terminal settings.
  --profile ID            Select a profile explicitly.
  OMARCHY_REF=NAME        Use a reviewed Git branch or tag (default: main).

For normal installation, run this command without any arguments.
HELP
      exit 0
      ;;
  esac
done

command -v git >/dev/null 2>&1 || {
  printf '%s\n' 'omarchy-profiles: git is required' >&2
  exit 1
}

git check-ref-format --branch "$repo_ref" >/dev/null 2>&1 || {
  printf '%s\n' "omarchy-profiles: invalid OMARCHY_REF: $repo_ref" >&2
  exit 1
}

if ((check_only || plan_only)); then
  command -v curl >/dev/null 2>&1 || {
    printf '%s\n' 'omarchy-profiles check: curl is required' >&2
    exit 1
  }
  check_dir="$(mktemp -d)"
  trap 'rm -rf "$check_dir"' EXIT
  printf 'omarchy-profiles: cloning published %s for %s\n' "$repo_ref" \
    "$([[ $plan_only -eq 1 ]] && printf 'plan' || printf 'check')"
  git clone --depth=1 --branch "$repo_ref" "$repo_url" "$check_dir/repo" >/dev/null
  bash -n "$check_dir/repo/install.sh" "$check_dir/repo/scripts/bootstrap.sh"
  if ((plan_only)); then
    "$check_dir/repo/scripts/bootstrap.sh" --profile auto --plan
    printf '%s\n' 'omarchy-profiles plan: PASS (no system changes made)'
  else
    "$check_dir/repo/scripts/bootstrap.sh" --profile auto --check
    printf '%s\n' 'omarchy-profiles check: PASS (no system changes made)'
  fi
  exit 0
fi

if [[ -d "$repo_dir/.git" ]]; then
  actual_repo_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  [[ "$actual_repo_url" == "$repo_url" ]] || {
    printf '%s\n' "omarchy-profiles: refusing unexpected origin: ${actual_repo_url:-missing}" >&2
    printf '%s\n' "omarchy-profiles: expected origin $repo_url" >&2
    exit 1
  }
  if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
    printf '%s\n' "omarchy-profiles: refusing to update a modified checkout: $repo_dir" >&2
    printf '%s\n' 'omarchy-profiles: commit, stash or remove local changes, then retry' >&2
    exit 1
  fi
  current_ref="$(git -C "$repo_dir" symbolic-ref --short -q HEAD || true)"
  [[ -n "$current_ref" ]] || {
    printf '%s\n' "omarchy-profiles: checkout is detached; expected ref $repo_ref" >&2
    exit 1
  }
  [[ "$current_ref" == "$repo_ref" ]] || {
    printf '%s\n' "omarchy-profiles: checkout uses $current_ref, expected $repo_ref" >&2
    printf '%s\n' 'omarchy-profiles: set OMARCHY_REF to that branch or use a clean checkout' >&2
    exit 1
  }
  if ((manifest_only)); then
    git -C "$repo_dir" pull --ff-only --quiet origin "$repo_ref"
  else
    printf 'omarchy-profiles: checking updates... '
    git -C "$repo_dir" pull --ff-only --quiet origin "$repo_ref"
    printf '%s\n' 'up to date'
  fi
else
  if ((manifest_only)); then
    git clone --depth=1 --branch "$repo_ref" --quiet "$repo_url" "$repo_dir"
  else
    printf 'omarchy-profiles: cloning into %s\n' "$repo_dir"
    git clone --depth=1 --branch "$repo_ref" "$repo_url" "$repo_dir"
  fi
fi

printf 'omarchy-profiles: source %s@%s\n' "$repo_ref" \
  "$(git -C "$repo_dir" rev-parse --short=12 HEAD)"

mkdir -p "$HOME/.local/bin"
if [[ -e "$HOME/.local/bin/zenbook-omarchy" ]] &&
   cmp -s "$repo_dir/scripts/zenbook-omarchy" "$HOME/.local/bin/zenbook-omarchy"; then
  printf '%s\n' 'omarchy-profiles: launcher ready (zenbook-omarchy)'
else
  install -m0755 "$repo_dir/scripts/zenbook-omarchy" "$HOME/.local/bin/zenbook-omarchy"
  printf '%s\n' 'omarchy-profiles: launcher installed (zenbook-omarchy)'
fi

exec "$repo_dir/scripts/bootstrap.sh" --profile auto "$@"
