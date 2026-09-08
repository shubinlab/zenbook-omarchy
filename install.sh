#!/usr/bin/env bash
set -euo pipefail

# Friendly one-command entry point. The full logic lives in the cloned repo.
repo_url="https://github.com/shubinlab/zenbook-omarchy.git"
repo_dir="${ZENBOOK_OMARCHY_DIR:-$HOME/zenbook-omarchy}"
adguard_installer_url="https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/HEAD/scripts/release/install.sh"
adguard_installed_now=0

command -v git >/dev/null 2>&1 || {
  printf '%s\n' 'zenbook-omarchy: git is required' >&2
  exit 1
}

if ! command -v adguardvpn-cli >/dev/null 2>&1 && [[ ! -x /opt/adguardvpn_cli/adguardvpn-cli ]]; then
  command -v curl >/dev/null 2>&1 || {
    printf '%s\n' 'zenbook-omarchy: curl is required to install AdGuard VPN CLI' >&2
    exit 1
  }
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  printf '%s\n' 'zenbook-omarchy: installing the official AdGuard VPN CLI'
  curl -fsSL "$adguard_installer_url" -o "$installer"
  sh "$installer" -v
  rm -f "$installer"
  trap - EXIT
  adguard_installed_now=1
fi

if ((adguard_installed_now)); then
  adguard_cli="$(command -v adguardvpn-cli 2>/dev/null || true)"
  [[ -n "$adguard_cli" ]] || adguard_cli="/opt/adguardvpn_cli/adguardvpn-cli"
  printf '%s\n' 'zenbook-omarchy: complete the one-time AdGuard login'
  "$adguard_cli" login
fi

if [[ -d "$repo_dir/.git" ]]; then
  printf 'zenbook-omarchy: updating %s\n' "$repo_dir"
  git -C "$repo_dir" pull --ff-only
else
  printf 'zenbook-omarchy: cloning into %s\n' "$repo_dir"
  git clone --depth=1 "$repo_url" "$repo_dir"
fi

exec "$repo_dir/install/bootstrap.sh" --vpn --update-system "$@"
