#!/usr/bin/env bash
set -euo pipefail

# Reapply this machine's public Omarchy profile after a clean installation.
# Secrets, AdGuard credentials and raw telemetry intentionally stay outside Git.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONFIG_SOURCE="$ROOT_DIR/config/monitors.lua"
PACKAGE_SOURCES=(
  "$ROOT_DIR/config/packages-platform.txt"
  "$ROOT_DIR/config/packages-diagnostics.txt"
)
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/zenbook-omarchy/backups"
VPN_CLI="${ADGUARD_VPN_CLI:-}"
VPN_LOCATION="${ADGUARD_VPN_LOCATION:-}"
DO_PACKAGES=1
DO_MONITOR=1
DO_VPN=0
DO_SYSTEM_UPDATE=0
DO_TELEMETRY=0
DO_VPN_CLI_UPDATE=0
DO_CHECK=0

usage() {
  cat <<'EOF'
Usage: install/bootstrap.sh [options]

Reapplies the public Zenbook Omarchy profile. It uses Omarchy's package helper
and update command; it does not import credentials, VPN config, or raw logs.

Options:
  --vpn                 Connect an existing AdGuard VPN CLI session first.
  --vpn-location NAME   Use an AdGuard location or ISO code for this run.
  --update-vpn-cli      Ask the installed AdGuard VPN CLI to update itself.
  --update-system       Run `omarchy update` after applying the profile.
  --enable-telemetry    Install and enable the local user telemetry service.
  --check               Validate files and commands without changing the system.
  --no-packages         Skip diagnostic package installation.
  --no-monitor          Skip the monitor configuration and mirror cleanup.
  -h, --help            Show this help.

The AdGuard CLI must already be installed and logged in. The official vendor
installer is documented in docs/BOOTSTRAP.md; this script never handles login.
EOF
}

die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

find_vpn_cli() {
  if [[ -n "$VPN_CLI" && -x "$VPN_CLI" ]]; then
    return 0
  fi
  for candidate in "$(command -v adguardvpn-cli 2>/dev/null || true)" \
                  /usr/local/bin/adguardvpn-cli \
                  /opt/adguardvpn_cli/adguardvpn-cli; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      VPN_CLI="$candidate"
      return 0
    fi
  done
  return 1
}

connect_vpn() {
  find_vpn_cli || die "AdGuard VPN CLI is not installed; see docs/BOOTSTRAP.md"
  printf 'bootstrap: checking AdGuard VPN CLI status\n'
  local status
  status="$($VPN_CLI status 2>/dev/null || true)"
  if grep -Eiq '(^|[^[:alpha:]])connected([^[:alpha:]]|$)|protected' <<<"$status"; then
    printf 'bootstrap: AdGuard VPN is already connected\n'
    return 0
  fi

  local args=(connect -y)
  if [[ -n "$VPN_LOCATION" ]]; then
    args+=(--location "$VPN_LOCATION")
  else
    # The official CLI documents this as the last used location fallback.
    args+=(--fastest)
  fi
  printf 'bootstrap: connecting AdGuard VPN\n'
  "$VPN_CLI" "${args[@]}"
}

install_packages() {
  need_command omarchy-pkg-add
  local manifest
  local -a packages=()
  for manifest in "${PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      packages+=("$package")
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  ((${#packages[@]})) || die "package manifests are empty"
  printf 'bootstrap: installing/verifying %d Omarchy packages\n' "${#packages[@]}"
  omarchy-pkg-add "${packages[@]}"
}

backup_and_install_monitor() {
  [[ -f "$CONFIG_SOURCE" ]] || die "missing monitor profile: $CONFIG_SOURCE"
  local target="$HOME/.config/hypr/monitors.lua"
  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="$BACKUP_ROOT/$stamp"
  mkdir -p "$backup" "$(dirname -- "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    cp -a -- "$target" "$backup/monitors.lua"
  fi
  install -m 0644 "$CONFIG_SOURCE" "$target"

  # Use the supported Omarchy command instead of touching /usr/share/omarchy.
  if command -v omarchy >/dev/null 2>&1; then
    omarchy hyprland monitor internal mirror off >/dev/null
  fi
  printf 'bootstrap: installed %s (backup: %s)\n' "$target" "$backup"
}

install_telemetry() {
  local bin="$HOME/.local/bin/omarchy-monitor-telemetry"
  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$(dirname -- "$bin")" "$unit_dir"
  install -m 0755 "$ROOT_DIR/tools/omarchy-monitor-telemetry.py" "$bin"
  install -m 0644 "$ROOT_DIR/config/omarchy-monitor-telemetry.service" \
    "$unit_dir/omarchy-monitor-telemetry.service"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-monitor-telemetry.service
  printf 'bootstrap: enabled local telemetry under %s\n' \
    "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/monitor-telemetry"
}

update_vpn_cli() {
  find_vpn_cli || die "AdGuard VPN CLI is not installed; see docs/BOOTSTRAP.md"
  printf 'bootstrap: checking for an AdGuard VPN CLI update\n'
  "$VPN_CLI" update -y
}

check_profile() {
  need_command omarchy
  need_command omarchy-pkg-add
  [[ -f "$CONFIG_SOURCE" ]] || die "missing monitor profile: $CONFIG_SOURCE"
  local manifest count=0 package
  for manifest in "${PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      [[ -n "$package" ]] && ((count += 1))
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  ((count > 0)) || die "package manifests are empty"
  grep -q 'output = "DP-1"' "$CONFIG_SOURCE" || die "DP-1 rule is missing"
  grep -q '239.97' "$CONFIG_SOURCE" || die "240 Hz rule is missing"
  printf 'bootstrap check: PASS (%d package entries; no system changes made)\n' "$count"
}

while (($#)); do
  case "$1" in
    --vpn) DO_VPN=1 ;;
    --vpn-location) shift; (($#)) || die "--vpn-location needs a value"; VPN_LOCATION="$1"; DO_VPN=1 ;;
    --update-vpn-cli) DO_VPN_CLI_UPDATE=1; DO_VPN=1 ;;
    --update-system) DO_SYSTEM_UPDATE=1 ;;
    --enable-telemetry) DO_TELEMETRY=1 ;;
    --check) DO_CHECK=1 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --no-monitor) DO_MONITOR=0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ "$EUID" -ne 0 ]] || die "run as the normal user; Omarchy helpers request privilege when needed"
[[ -d "$HOME" ]] || die "HOME is not available"

if ((DO_CHECK)); then
  check_profile
  exit 0
fi

if ((DO_VPN)); then connect_vpn; fi
if ((DO_VPN_CLI_UPDATE)); then update_vpn_cli; fi
if ((DO_PACKAGES)); then install_packages; fi
if ((DO_MONITOR)); then backup_and_install_monitor; fi
if ((DO_TELEMETRY)); then install_telemetry; fi

if ((DO_SYSTEM_UPDATE)); then
  need_command omarchy
  printf 'bootstrap: running the supported full Omarchy update\n'
  omarchy update
fi

printf 'bootstrap: complete\n'
