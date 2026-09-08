#!/usr/bin/env bash
set -euo pipefail

# Apply one selected Omarchy profile. Profile data is declarative; credentials
# and backups stay out of the repository.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE_REQUEST="${OMARCHY_PROFILE:-auto}"
PROFILE_DIR=""
PROFILE_ID=""
PROFILE_LABEL=""
PROFILE_ENABLE_VPN=0
PROFILE_INSTALL_VPN_CLI=0
PROFILE_LOGIN_AFTER_VPN_INSTALL=0
PROFILE_MONITOR_CONFIG=""
PROFILE_TERMINAL_EXTENSION=""
PROFILE_VOICE_INSTALL=0
PROFILE_VOICE_EXTENSION=""
PROFILE_PACKAGE_MANIFESTS=""
PACKAGE_SOURCES=()
MONITOR_SOURCE=""
TERMINAL_SOURCE=""
VOICE_SOURCE=""
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-profiles"
VPN_CLI="${ADGUARD_VPN_CLI:-}"
VPN_LOCATION="${ADGUARD_VPN_LOCATION:-}"
ADGUARD_INSTALLER_URL="https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/HEAD/scripts/release/install.sh"
DO_PACKAGES=1
DO_MONITOR=1
DO_VPN=0
DO_SYSTEM_UPDATE=0
DO_TERMINAL=1
DO_VOICE=0
DO_VPN_CLI_UPDATE=0
DO_CHECK=0
VPN_OPTION_SET=0
VOICE_OPTION_SET=0
STAGE=all

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
  --stage NAME          Run one stage: all, vpn, display, packages, voice,
                        terminal or update. Default: all.
  --no-terminal         Skip the profile's user-scoped terminal extension.
  --no-voice            Skip the profile's native Omarchy Voxtype setup.
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
  if [[ -n "$PROFILE_TERMINAL_EXTENSION" ]]; then
    TERMINAL_SOURCE="$PROFILE_DIR/$PROFILE_TERMINAL_EXTENSION"
  fi
  if [[ -n "$PROFILE_VOICE_EXTENSION" ]]; then
    VOICE_SOURCE="$PROFILE_DIR/$PROFILE_VOICE_EXTENSION"
  fi
  if ((VPN_OPTION_SET == 0)); then
    DO_VPN="$PROFILE_ENABLE_VPN"
  fi
  if ((VOICE_OPTION_SET == 0)); then
    DO_VOICE="$PROFILE_VOICE_INSTALL"
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

install_voice() {
  [[ "$DO_VOICE" -eq 1 ]] || return 0
  need_command omarchy
  local native_installer="/usr/share/omarchy/bin/omarchy-voxtype-install"
  [[ -x "$native_installer" ]] || die "native Omarchy Voxtype installer is missing: $native_installer"
  [[ -n "$VOICE_SOURCE" && -x "$VOICE_SOURCE" ]] || die "missing voice extension: $VOICE_SOURCE"

  # The stock installer remains authoritative for package/model/service setup.
  # Skip its interactive prompt on reruns once its user-scoped setup exists.
  if [[ ! -f "$HOME/.config/voxtype/config.toml" || \
        ! -f "$HOME/.config/systemd/user/voxtype.service" ]] || \
     ! command -v voxtype >/dev/null 2>&1 || \
     ! command -v wtype >/dev/null 2>&1; then
    printf 'bootstrap: running the native Omarchy Voxtype installer\n'
    omarchy voxtype install
  else
    printf 'bootstrap: native Omarchy Voxtype setup already exists\n'
  fi
  [[ -f "$HOME/.config/voxtype/config.toml" ]] || die 'native Voxtype setup did not create ~/.config/voxtype/config.toml; rerun without --no-voice and accept the native prompt'
  "$VOICE_SOURCE" --apply
}

backup_and_install_monitor() {
  if [[ -z "$MONITOR_SOURCE" ]]; then
    printf 'bootstrap: profile %s does not define a monitor override\n' "$PROFILE_ID"
    return 0
  fi
  [[ -f "$MONITOR_SOURCE" ]] || die "missing monitor profile: $MONITOR_SOURCE"
  local target="$HOME/.config/hypr/monitors.lua"
  if [[ -f "$target" ]] && cmp -s "$MONITOR_SOURCE" "$target"; then
    printf 'bootstrap: display settings already applied\n'
    return 0
  fi
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
  if [[ -n "$TERMINAL_SOURCE" ]]; then
    [[ -x "$TERMINAL_SOURCE" ]] || die "missing terminal extension: $TERMINAL_SOURCE"
    "$TERMINAL_SOURCE" --check
  fi
  if ((DO_VOICE)); then
    command -v omarchy >/dev/null 2>&1 || die 'native Omarchy command is missing'
    [[ -x "/usr/share/omarchy/bin/omarchy-voxtype-install" ]] || die 'native Omarchy Voxtype installer is missing'
    [[ -n "$VOICE_SOURCE" && -x "$VOICE_SOURCE" ]] || die "missing voice extension: $VOICE_SOURCE"
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
    --stage) shift; (($#)) || die "--stage needs a value"; STAGE="$1" ;;
    --no-terminal) DO_TERMINAL=0 ;;
    --no-voice) DO_VOICE=0; VOICE_OPTION_SET=1 ;;
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
apply_terminal() {
  if ((DO_TERMINAL)) && [[ -n "$TERMINAL_SOURCE" ]]; then
    "$TERMINAL_SOURCE" --apply
  else
    printf 'bootstrap: terminal extension not configured; skipped\n'
  fi
}

apply_update() {
  need_command omarchy
  printf 'bootstrap: running the supported full Omarchy update\n'
  omarchy update
}

ensure_vpn_for_network_stage() {
  if ((DO_VPN)); then
    connect_vpn
  fi
}

stage_note() {
  printf '\n[%s] %s\n' "$1" "$2"
}

run_stage() {
  case "$STAGE" in
    all)
      # Keep the least surprising clean-install order: network first, then
      # simple tested user settings, then package/model/service work.
      stage_note '1/6' 'Network: AdGuard VPN'
      if ((DO_VPN)); then connect_vpn; else printf 'bootstrap: VPN disabled\n'; fi
      if ((DO_VPN_CLI_UPDATE)); then update_vpn_cli; fi
      stage_note '2/6' 'Display: tested user settings'
      if ((DO_MONITOR)); then backup_and_install_monitor; else printf 'bootstrap: display stage skipped\n'; fi
      stage_note '3/6' 'Packages: profile requirements'
      if ((DO_PACKAGES)); then install_packages; else printf 'bootstrap: package stage skipped\n'; fi
      stage_note '4/6' 'Voice: native Omarchy Voxtype'
      if ((DO_VOICE)); then install_voice; else printf 'bootstrap: voice stage skipped\n'; fi
      stage_note '5/6' 'Terminal: user settings'
      apply_terminal
      stage_note '6/6' 'System: supported Omarchy update'
      if ((DO_SYSTEM_UPDATE)); then apply_update; else printf 'bootstrap: system update skipped\n'; fi
      ;;
    vpn)
      stage_note '1/1' 'Network: AdGuard VPN'
      ((DO_VPN)) || die 'VPN stage is disabled; use the Zenbook profile or --vpn'
      connect_vpn
      if ((DO_VPN_CLI_UPDATE)); then update_vpn_cli; fi
      ;;
    display)
      stage_note '1/1' 'Display: tested user settings'
      ((DO_MONITOR)) || die 'display stage is disabled by --no-monitor'
      backup_and_install_monitor
      ;;
    packages)
      stage_note '1/1' 'Packages: profile requirements'
      ((DO_PACKAGES)) || die 'package stage is disabled by --no-packages'
      ensure_vpn_for_network_stage
      install_packages
      ;;
    voice)
      stage_note '1/1' 'Voice: native Omarchy Voxtype'
      ((DO_VOICE)) || die 'voice stage is disabled by --no-voice or this profile'
      ensure_vpn_for_network_stage
      install_voice
      ;;
    terminal)
      stage_note '1/1' 'Terminal: user settings'
      [[ -n "$TERMINAL_SOURCE" ]] || die "profile $PROFILE_ID has no terminal stage"
      ((DO_TERMINAL)) || die 'terminal stage is disabled by --no-terminal'
      ensure_vpn_for_network_stage
      apply_terminal
      ;;
    update)
      stage_note '1/1' 'System: supported Omarchy update'
      ensure_vpn_for_network_stage
      apply_update
      ;;
    *)
      die "unknown stage: $STAGE (use all, vpn, display, packages, voice, terminal or update)"
      ;;
  esac
}

run_stage
printf '\nDONE: profile=%s stage=%s\n' "$PROFILE_ID" "$STAGE"
