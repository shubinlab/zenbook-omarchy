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
PROFILE_DIAGNOSTIC_MANIFESTS=""
PACKAGE_SOURCES=()
DIAGNOSTIC_SOURCES=()
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
MANIFEST=0
NON_INTERACTIVE=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_RED=$'\033[31m'
  C_RESET=$'\033[0m'
else
  C_CYAN=''
  C_GREEN=''
  C_RED=''
  C_RESET=''
fi

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
  --update-system       Run `omarchy update` after applying the profile (opt-in).
  --stage NAME          Run one stage: all, vpn, display, packages, voice,
                        diagnostics, terminal, update or doctor. Default: all.
  --manifest            Print the stage manifest as JSON and exit.
  --non-interactive     Refuse prompts and stop before interactive setup.
  --no-terminal         Skip the profile's user-scoped terminal extension.
  --no-voice            Skip the profile's native Omarchy Voxtype setup.
  --check               Validate profile files without changing the system.
  --no-packages         Skip package installation.
  --no-monitor          Skip the monitor configuration.
  -h, --help            Show this help.
HELP
}

die() {
  printf '%sERROR%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
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
  DIAGNOSTIC_SOURCES=()
  for manifest in $PROFILE_DIAGNOSTIC_MANIFESTS; do
    DIAGNOSTIC_SOURCES+=("$PROFILE_DIR/$manifest")
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
  ((NON_INTERACTIVE == 0)) || die 'AdGuard VPN installation may need confirmation; rerun without --non-interactive from a terminal'
  [[ -r /dev/tty ]] || die 'AdGuard VPN installation needs a terminal for confirmation'
  sh "$installer" -v </dev/tty
  rm -f "$installer"
  find_vpn_cli || die "AdGuard VPN CLI installer completed without an executable"
  if ((PROFILE_LOGIN_AFTER_VPN_INSTALL)); then
    printf 'bootstrap: complete the one-time AdGuard login\n'
    if [[ -r /dev/tty ]]; then
      "$VPN_CLI" login </dev/tty
    else
      die 'AdGuard login needs a terminal; rerun without --non-interactive from a terminal'
    fi
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

install_package_set() {
  local label="$1"
  shift
  local manifest package
  local -a packages=()
  for manifest in "$@"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      packages+=("$package")
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  if ((${#packages[@]} == 0)); then
    printf 'bootstrap: profile %s has no %s package entries\n' "$PROFILE_ID" "$label"
    return 0
  fi
  need_command omarchy-pkg-add
  printf 'bootstrap: installing/verifying %d %s package entries for %s\n' \
    "${#packages[@]}" "$label" "$PROFILE_ID"
  omarchy-pkg-add "${packages[@]}"
}

install_packages() {
  install_package_set profile "${PACKAGE_SOURCES[@]}"
}

install_diagnostics() {
  if ((${#DIAGNOSTIC_SOURCES[@]})); then
    ensure_vpn_for_network_stage
  fi
  install_package_set diagnostic "${DIAGNOSTIC_SOURCES[@]}"
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
    ((NON_INTERACTIVE == 0)) || die 'native Voxtype setup needs confirmation; rerun without --non-interactive from a terminal'
    [[ -r /dev/tty ]] || die 'native Voxtype setup needs a terminal for confirmation'
    omarchy voxtype install </dev/tty
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
  local manifest count=0 diagnostic_count=0 package
  for manifest in "${PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      if [[ -n "$package" ]]; then
        ((count += 1))
      fi
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  for manifest in "${DIAGNOSTIC_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing diagnostic manifest: $manifest"
    while IFS= read -r package; do
      if [[ -n "$package" ]]; then
        ((diagnostic_count += 1))
      fi
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
  printf 'bootstrap check: PASS profile=%s packages=%d diagnostics=%d monitor=%s vpn=%s (no system changes made)\n' \
    "$PROFILE_ID" "$count" "$diagnostic_count" "${MONITOR_SOURCE:+yes}" "$DO_VPN"
}

print_manifest() {
  printf '{"protocol_version":1,"profile":"%s","stages":[' "$PROFILE_ID"
  printf '{"name":"vpn","title":"Connect AdGuard VPN","category":"network","needs_user_input":true},'
  printf '{"name":"display","title":"Apply tested display settings","category":"configuration","needs_user_input":false},'
  printf '{"name":"packages","title":"Install profile packages","category":"runtime","needs_user_input":false},'
  printf '{"name":"diagnostics","title":"Install optional diagnostic packages","category":"optional","needs_user_input":false},'
  printf '{"name":"voice","title":"Install native Omarchy Voxtype","category":"runtime","needs_user_input":true},'
  printf '{"name":"terminal","title":"Apply terminal settings","category":"configuration","needs_user_input":false},'
  printf '{"name":"update","title":"Run supported Omarchy update","category":"runtime","needs_user_input":true},'
  printf '{"name":"doctor","title":"Check the installed profile","category":"diagnostics","needs_user_input":false}]}'
  printf '\n'
}

run_doctor() {
  local failures=0 version status errors
  printf '\n%sOmarchy profile doctor%s (read-only)\n' "$C_CYAN" "$C_RESET"
  printf 'Profile: %s\n' "$PROFILE_ID"

  if command -v omarchy >/dev/null 2>&1; then
    version="$(omarchy version 2>/dev/null || true)"
    printf '%sOK%s Omarchy%s\n' "$C_GREEN" "$C_RESET" "${version:+: $version}"
  else
    printf '%sFAIL%s Omarchy command is missing\n' "$C_RED" "$C_RESET"
    failures=$((failures + 1))
  fi

  if ((DO_VOICE)) && [[ -n "$VOICE_SOURCE" ]]; then
    if "$VOICE_SOURCE" --check; then
      printf '%sOK%s native voice\n' "$C_GREEN" "$C_RESET"
    else
      printf '%sFAIL%s native voice\n' "$C_RED" "$C_RESET"
      failures=$((failures + 1))
    fi
  fi

  if ((DO_TERMINAL)) && [[ -n "$TERMINAL_SOURCE" ]] && command -v terminal-doctor >/dev/null 2>&1; then
    if terminal-doctor; then
      printf '%sOK%s terminal\n' "$C_GREEN" "$C_RESET"
    else
      printf '%sFAIL%s terminal\n' "$C_RED" "$C_RESET"
      failures=$((failures + 1))
    fi
  fi

  if command -v hyprctl >/dev/null 2>&1; then
    errors="$(hyprctl configerrors 2>/dev/null || true)"
    if [[ -z "$errors" ]]; then
      printf '%sOK%s Hyprland configuration\n' "$C_GREEN" "$C_RESET"
    else
      printf '%sFAIL%s Hyprland configuration errors:\n%s\n' "$C_RED" "$C_RESET" "$errors"
      failures=$((failures + 1))
    fi
  else
    printf 'WARN Hyprland session is not available; skipped compositor check\n'
  fi

  if ((DO_VPN)); then
    if find_vpn_cli; then
      status="$($VPN_CLI status 2>/dev/null || true)"
      if grep -Eiq '(^|[^[:alpha:]])connected([^[:alpha:]]|$)|protected' <<<"$status"; then
        printf '%sOK%s AdGuard VPN connected\n' "$C_GREEN" "$C_RESET"
      else
        printf 'WARN AdGuard VPN is installed but not connected\n'
      fi
    else
      printf 'WARN AdGuard VPN CLI is not installed\n'
    fi
  fi

  if ((failures == 0)); then
    printf '\n%sRESULT%s PASS\n' "$C_GREEN" "$C_RESET"
  else
    printf '\n%sRESULT%s FAIL (%d check(s))\n' "$C_RED" "$C_RESET" "$failures"
  fi
  return "$failures"
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
    --manifest) MANIFEST=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
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

if ((MANIFEST)); then
  print_manifest
  exit 0
fi
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
      if ((DO_SYSTEM_UPDATE)); then
        stage_note '6/7' 'System: supported Omarchy update'
        apply_update
        stage_note '7/7' 'Doctor: verify the installed profile'
      else
        stage_note '6/6' 'Doctor: verify the installed profile'
      fi
      run_doctor
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
      if ((${#PACKAGE_SOURCES[@]})); then
        ensure_vpn_for_network_stage
      fi
      install_packages
      ;;
    diagnostics)
      stage_note '1/1' 'Optional diagnostics: package tools'
      install_diagnostics
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
    doctor)
      run_doctor
      ;;
    *)
      die "unknown stage: $STAGE (use all, vpn, display, packages, diagnostics, voice, terminal, update or doctor)"
      ;;
  esac
}

printf '\n%sOmarchy Zenbook setup%s\nProfile: %s\n' "$C_CYAN" "$C_RESET" "$PROFILE_LABEL"
run_stage
printf '\n%sDONE%s profile=%s stage=%s\n' "$C_GREEN" "$C_RESET" "$PROFILE_ID" "$STAGE"
