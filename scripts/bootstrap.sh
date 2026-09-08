#!/usr/bin/env bash
set -euo pipefail

# Apply one selected Omarchy profile. Profile data is declarative; credentials,
# backups and live telemetry stay in the user's state directories.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE_REQUEST="${OMARCHY_PROFILE:-auto}"
PROFILE_DIR=""
PROFILE_ID=""
PROFILE_LABEL=""
PROFILE_ENABLE_VPN=0
PROFILE_INSTALL_VPN_CLI=0
PROFILE_LOGIN_AFTER_VPN_INSTALL=0
PROFILE_MONITOR_CONFIG=""
PROFILE_TELEMETRY_SERVICE=""
PROFILE_TELEMETRY_COLLECTOR=""
PROFILE_PACKAGE_MANIFESTS=""
PACKAGE_SOURCES=()
MONITOR_SOURCE=""
TELEMETRY_SERVICE_SOURCE=""
TELEMETRY_COLLECTOR_SOURCE=""
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-profiles"
VPN_CLI="${ADGUARD_VPN_CLI:-}"
VPN_LOCATION="${ADGUARD_VPN_LOCATION:-}"
ADGUARD_INSTALLER_URL="https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/HEAD/scripts/release/install.sh"
DO_PACKAGES=1
DO_MONITOR=1
DO_VPN=0
DO_SYSTEM_UPDATE=0
DO_TELEMETRY=0
DO_VPN_CLI_UPDATE=0
DO_CHECK=0
VPN_OPTION_SET=0

usage() {
  cat <<'HELP'
Usage: scripts/bootstrap.sh [options]

Selects an Omarchy profile, installs its declared packages, and applies only
the profile capabilities. `auto` chooses by DMI and falls back to `generic`.

Options:
  --profile ID          Select a profile explicitly.
  --vpn                 Connect AdGuard VPN before a system update.
  --no-vpn              Do not use VPN, even when the profile enables it.
  --vpn-location NAME   Use an AdGuard location or ISO code for this run.
  --update-vpn-cli      Update the installed AdGuard VPN CLI.
  --update-system       Run `omarchy update` after applying the profile.
  --enable-telemetry    Install and enable the profile telemetry service.
  --check               Validate profile files without changing the system.
  --no-packages         Skip package installation.
  --no-monitor          Skip the monitor configuration.
  -h, --help            Show this help.
HELP
}

die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

detect_profile() {
  if [[ "$PROFILE_REQUEST" != auto ]]; then
    PROFILE_ID="$PROFILE_REQUEST"
  else
    local product
    product="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
    if grep -qi 'UM3406KA' <<<"$product"; then
      PROFILE_ID="zenbook-um3406ka"
    else
      PROFILE_ID="generic"
    fi
  fi
  [[ "$PROFILE_ID" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid profile id: $PROFILE_ID"
  PROFILE_DIR="$ROOT_DIR/profiles/$PROFILE_ID"
  [[ -f "$PROFILE_DIR/profile.env" ]] || die "profile not found: $PROFILE_ID"
  # shellcheck disable=SC1090
  source "$PROFILE_DIR/profile.env"
  PACKAGE_SOURCES=()
  local manifest
  for manifest in $PROFILE_PACKAGE_MANIFESTS; do
    PACKAGE_SOURCES+=("$PROFILE_DIR/$manifest")
  done
  if [[ -n "$PROFILE_MONITOR_CONFIG" ]]; then
    MONITOR_SOURCE="$PROFILE_DIR/$PROFILE_MONITOR_CONFIG"
  fi
  if [[ -n "$PROFILE_TELEMETRY_SERVICE" ]]; then
    TELEMETRY_SERVICE_SOURCE="$PROFILE_DIR/$PROFILE_TELEMETRY_SERVICE"
  fi
  if [[ -n "$PROFILE_TELEMETRY_COLLECTOR" ]]; then
    TELEMETRY_COLLECTOR_SOURCE="$PROFILE_DIR/$PROFILE_TELEMETRY_COLLECTOR"
  fi
  if ((VPN_OPTION_SET == 0)); then
    DO_VPN="$PROFILE_ENABLE_VPN"
  fi
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

install_vpn_cli() {
  ((PROFILE_INSTALL_VPN_CLI)) || die "AdGuard VPN CLI is not installed for profile $PROFILE_ID"
  need_command curl
  local installer
  installer="$(mktemp)"
  printf 'bootstrap: installing the official AdGuard VPN CLI\n'
  curl -fsSL "$ADGUARD_INSTALLER_URL" -o "$installer"
  sh "$installer" -v
  rm -f "$installer"
  find_vpn_cli || die "AdGuard VPN CLI installer completed without an executable"
  if ((PROFILE_LOGIN_AFTER_VPN_INSTALL)); then
    printf 'bootstrap: complete the one-time AdGuard login\n'
    "$VPN_CLI" login
  fi
}

connect_vpn() {
  find_vpn_cli || install_vpn_cli
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
    args+=(--fastest)
  fi
  printf 'bootstrap: connecting AdGuard VPN\n'
  "$VPN_CLI" "${args[@]}"
}

install_packages() {
  need_command omarchy-pkg-add
  local manifest package
  local -a packages=()
  for manifest in "${PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      packages+=("$package")
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  if ((${#packages[@]} == 0)); then
    printf 'bootstrap: profile %s has no package entries\n' "$PROFILE_ID"
    return 0
  fi
  printf 'bootstrap: installing/verifying %d package entries for %s\n' \
    "${#packages[@]}" "$PROFILE_ID"
  omarchy-pkg-add "${packages[@]}"
}

backup_and_install_monitor() {
  if [[ -z "$MONITOR_SOURCE" ]]; then
    printf 'bootstrap: profile %s does not define a monitor override\n' "$PROFILE_ID"
    return 0
  fi
  [[ -f "$MONITOR_SOURCE" ]] || die "missing monitor profile: $MONITOR_SOURCE"
  local target="$HOME/.config/hypr/monitors.lua"
  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="$BACKUP_ROOT/$PROFILE_ID/backups/$stamp"
  mkdir -p "$backup" "$(dirname -- "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    cp -a -- "$target" "$backup/monitors.lua"
  fi
  install -m 0644 "$MONITOR_SOURCE" "$target"
  if command -v omarchy >/dev/null 2>&1; then
    omarchy hyprland monitor internal mirror off >/dev/null
  fi
  printf 'bootstrap: installed %s (backup: %s)\n' "$target" "$backup"
}

install_telemetry() {
  [[ -n "$TELEMETRY_SERVICE_SOURCE" && -f "$TELEMETRY_SERVICE_SOURCE" ]] || \
    die "profile $PROFILE_ID has no telemetry service"
  local bin="$HOME/.local/bin/omarchy-monitor-telemetry"
  [[ -n "$TELEMETRY_COLLECTOR_SOURCE" && -f "$TELEMETRY_COLLECTOR_SOURCE" ]] || \
    die "profile $PROFILE_ID has no telemetry collector"
  local collector="$TELEMETRY_COLLECTOR_SOURCE"
  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$(dirname -- "$bin")" "$unit_dir"
  install -m 0755 "$collector" "$bin"
  install -m 0644 "$TELEMETRY_SERVICE_SOURCE" \
    "$unit_dir/omarchy-monitor-telemetry.service"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-monitor-telemetry.service
  printf 'bootstrap: enabled local telemetry under %s\n' \
    "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/monitor-telemetry"
}

update_vpn_cli() {
  find_vpn_cli || die "AdGuard VPN CLI is not installed"
  printf 'bootstrap: checking for an AdGuard VPN CLI update\n'
  "$VPN_CLI" update -y
}

check_profile() {
  [[ -f "$PROFILE_DIR/profile.env" ]] || die "missing profile metadata"
  local manifest count=0 package
  for manifest in "${PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      [[ -n "$package" ]] && ((count += 1))
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  if [[ -n "$MONITOR_SOURCE" ]]; then
    [[ -f "$MONITOR_SOURCE" ]] || die "missing monitor profile: $MONITOR_SOURCE"
    grep -q 'hl.monitor' "$MONITOR_SOURCE" || die "monitor rules are missing"
  fi
  if [[ -n "$TELEMETRY_SERVICE_SOURCE" ]]; then
    [[ -f "$TELEMETRY_SERVICE_SOURCE" ]] || die "missing telemetry service"
  fi
  if [[ -n "$TELEMETRY_COLLECTOR_SOURCE" ]]; then
    [[ -f "$TELEMETRY_COLLECTOR_SOURCE" ]] || die "missing telemetry collector"
  fi
  printf 'bootstrap check: PASS profile=%s packages=%d monitor=%s vpn=%s (no system changes made)\n' \
    "$PROFILE_ID" "$count" "${MONITOR_SOURCE:+yes}" "$DO_VPN"
}

while (($#)); do
  case "$1" in
    --profile) shift; (($#)) || die "--profile needs a value"; PROFILE_REQUEST="$1" ;;
    --vpn) DO_VPN=1; VPN_OPTION_SET=1 ;;
    --no-vpn) DO_VPN=0; VPN_OPTION_SET=1 ;;
    --vpn-location) shift; (($#)) || die "--vpn-location needs a value"; VPN_LOCATION="$1"; DO_VPN=1; VPN_OPTION_SET=1 ;;
    --update-vpn-cli) DO_VPN_CLI_UPDATE=1; DO_VPN=1; VPN_OPTION_SET=1 ;;
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
detect_profile

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
printf 'bootstrap: complete profile=%s\n' "$PROFILE_ID"
