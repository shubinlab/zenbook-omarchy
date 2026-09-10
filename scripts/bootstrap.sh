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
PROFILE_DISPLAY_DOCTOR=""
PROFILE_TERMINAL_EXTENSION=""
PROFILE_VOICE_INSTALL=0
PROFILE_VOICE_EXTENSION=""
PROFILE_BITWARDEN_INSTALL=0
PROFILE_BITWARDEN_EXTENSION=""
PROFILE_BITWARDEN_DOCTOR=""
PROFILE_BITWARDEN_ONBOARD=""
PROFILE_BITWARDEN_PACKAGE_MANIFESTS=""
PROFILE_PACKAGE_MANIFESTS=""
PROFILE_VOICE_PACKAGE_MANIFESTS=""
PROFILE_DIAGNOSTIC_MANIFESTS=""
PACKAGE_SOURCES=()
VOICE_PACKAGE_SOURCES=()
BITWARDEN_PACKAGE_SOURCES=()
DIAGNOSTIC_SOURCES=()
COMPONENTS_REQUEST=""
MONITOR_SOURCE=""
DISPLAY_DOCTOR=""
TERMINAL_SOURCE=""
VOICE_SOURCE=""
BITWARDEN_SOURCE=""
BITWARDEN_DOCTOR=""
BITWARDEN_ONBOARD=""
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-profiles"
BITWARDEN_ONBOARDING_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-profiles/bitwarden/onboarding-complete"
VPN_CLI="${ADGUARD_VPN_CLI:-}"
VPN_LOCATION="${ADGUARD_VPN_LOCATION:-}"
ADGUARD_INSTALLER_URL="https://raw.githubusercontent.com/AdguardTeam/AdGuardCLI/release/install.sh"
DO_PACKAGES=1
DO_MONITOR=1
DO_VPN=0
DO_SYSTEM_UPDATE=0
DO_TERMINAL=1
DO_VOICE=0
DO_BITWARDEN=0
DO_DIAGNOSTICS=0
DO_VPN_CLI_UPDATE=0
DO_CHECK=0
VPN_OPTION_SET=0
VOICE_OPTION_SET=0
BITWARDEN_OPTION_SET=0
STAGE=all
MANIFEST=0
PLAN_ONLY=0
NON_INTERACTIVE=0
CURRENT_STAGE='startup'

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
  --update-system       Run `omarchy update` as a separate explicit stage (opt-in).
  --stage NAME          Run one stage: all, selected, vpn, display, packages,
                        bitwarden, voice, diagnostics, terminal, update or
                        doctor. Default: all.
  --components LIST     For --stage selected, comma-separated components;
                        dependencies are added automatically.
  --manifest            Print the stage manifest as JSON and exit.
  --plan                Show the selected actions and native/user boundaries.
  --verbose             Show detailed component output instead of the compact view.
  --non-interactive     Refuse prompts and stop before interactive setup.
  --no-terminal         Skip the profile's user-scoped terminal extension.
  --no-voice            Skip the profile's native Omarchy Voxtype setup.
  --no-bitwarden        Skip the profile's native Wayland Bitwarden setup.
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
  VOICE_PACKAGE_SOURCES=()
  for manifest in $PROFILE_VOICE_PACKAGE_MANIFESTS; do
    VOICE_PACKAGE_SOURCES+=("$PROFILE_DIR/$manifest")
  done
  BITWARDEN_PACKAGE_SOURCES=()
  for manifest in $PROFILE_BITWARDEN_PACKAGE_MANIFESTS; do
    BITWARDEN_PACKAGE_SOURCES+=("$PROFILE_DIR/$manifest")
  done
  DIAGNOSTIC_SOURCES=()
  for manifest in $PROFILE_DIAGNOSTIC_MANIFESTS; do
    DIAGNOSTIC_SOURCES+=("$PROFILE_DIR/$manifest")
  done
  if [[ -n "$PROFILE_MONITOR_CONFIG" ]]; then
    MONITOR_SOURCE="$PROFILE_DIR/$PROFILE_MONITOR_CONFIG"
  fi
  if [[ -n "$PROFILE_DISPLAY_DOCTOR" ]]; then
    DISPLAY_DOCTOR="$PROFILE_DIR/$PROFILE_DISPLAY_DOCTOR"
  fi
  if [[ -n "$PROFILE_TERMINAL_EXTENSION" ]]; then
    TERMINAL_SOURCE="$PROFILE_DIR/$PROFILE_TERMINAL_EXTENSION"
  fi
  if [[ -n "$PROFILE_VOICE_EXTENSION" ]]; then
    VOICE_SOURCE="$PROFILE_DIR/$PROFILE_VOICE_EXTENSION"
  fi
  if [[ -n "$PROFILE_BITWARDEN_EXTENSION" ]]; then
    BITWARDEN_SOURCE="$PROFILE_DIR/$PROFILE_BITWARDEN_EXTENSION"
  fi
  if [[ -n "$PROFILE_BITWARDEN_DOCTOR" ]]; then
    BITWARDEN_DOCTOR="$PROFILE_DIR/$PROFILE_BITWARDEN_DOCTOR"
  fi
  if [[ -n "$PROFILE_BITWARDEN_ONBOARD" ]]; then
    BITWARDEN_ONBOARD="$PROFILE_DIR/$PROFILE_BITWARDEN_ONBOARD"
  fi
  if ((VPN_OPTION_SET == 0)); then
    DO_VPN="$PROFILE_ENABLE_VPN"
  fi
  if ((VOICE_OPTION_SET == 0)); then
    DO_VOICE="$PROFILE_VOICE_INSTALL"
  fi
  if ((BITWARDEN_OPTION_SET == 0)); then
    DO_BITWARDEN="$PROFILE_BITWARDEN_INSTALL"
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
  # Do not match the substring in "unprotected".
  if grep -Eiq '(^|[^[:alpha:]])connected([^[:alpha:]]|$)' <<<"$status"; then
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
  if [[ "${OMARCHY_COMPACT_OUTPUT:-0}" == 1 ]]; then
    printf 'bootstrap: %s runtime ready (%d packages)\n' "$label" "${#packages[@]}"
  else
    printf 'bootstrap: installing/verifying %d %s package entries for %s\n' \
      "${#packages[@]}" "$label" "$PROFILE_ID"
  fi
  omarchy-pkg-add "${packages[@]}"
}

install_packages() {
  if ((${#PACKAGE_SOURCES[@]})); then
    install_package_set profile "${PACKAGE_SOURCES[@]}"
  fi
}

install_bitwarden_packages() {
  if ((DO_BITWARDEN)); then
    install_package_set bitwarden "${BITWARDEN_PACKAGE_SOURCES[@]}"
  else
    printf 'bootstrap: Bitwarden package set skipped (--no-bitwarden)\n'
  fi
}

install_bitwarden() {
  [[ "$DO_BITWARDEN" -eq 1 ]] || return 0
  [[ -n "$BITWARDEN_SOURCE" && -x "$BITWARDEN_SOURCE" ]] ||
    die "missing Bitwarden extension: $BITWARDEN_SOURCE"
  [[ -n "$BITWARDEN_ONBOARD" && -x "$BITWARDEN_ONBOARD" ]] ||
    die "missing Bitwarden onboarding: $BITWARDEN_ONBOARD"
  install_bitwarden_packages
  "$BITWARDEN_SOURCE" --apply
  if ((NON_INTERACTIVE)); then
    "$BITWARDEN_ONBOARD" --non-interactive
  else
    "$BITWARDEN_ONBOARD" --run
  fi
}

install_voice_packages() {
  if ((DO_VOICE)); then
    install_package_set voice "${VOICE_PACKAGE_SOURCES[@]}"
  else
    printf 'bootstrap: voice package set skipped (--no-voice)\n'
  fi
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
  local manifest count=0 voice_count=0 bitwarden_count=0 diagnostic_count=0 package
  for manifest in "${PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing package manifest: $manifest"
    while IFS= read -r package; do
      if [[ -n "$package" ]]; then
        ((count += 1))
      fi
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  for manifest in "${BITWARDEN_PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing Bitwarden package manifest: $manifest"
    if ((DO_BITWARDEN)); then
      while IFS= read -r package; do
        if [[ -n "$package" ]]; then
          ((bitwarden_count += 1))
        fi
      done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
    fi
  done
  for manifest in "${VOICE_PACKAGE_SOURCES[@]}"; do
    [[ -f "$manifest" ]] || die "missing voice package manifest: $manifest"
    if ((DO_VOICE)); then
      while IFS= read -r package; do
        if [[ -n "$package" ]]; then
          ((voice_count += 1))
        fi
      done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
    fi
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
  if [[ -n "$DISPLAY_DOCTOR" ]]; then
    [[ -x "$DISPLAY_DOCTOR" ]] || die "missing display doctor: $DISPLAY_DOCTOR"
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
  if ((DO_BITWARDEN)); then
    [[ -n "$BITWARDEN_SOURCE" && -x "$BITWARDEN_SOURCE" ]] || die "missing Bitwarden extension: $BITWARDEN_SOURCE"
    [[ -n "$BITWARDEN_DOCTOR" && -x "$BITWARDEN_DOCTOR" ]] || die "missing Bitwarden doctor: $BITWARDEN_DOCTOR"
    [[ -n "$BITWARDEN_ONBOARD" && -x "$BITWARDEN_ONBOARD" ]] || die "missing Bitwarden onboarding: $BITWARDEN_ONBOARD"
    "$BITWARDEN_SOURCE" --check
    "$BITWARDEN_ONBOARD" --check
  fi
  printf 'bootstrap check: PASS profile=%s packages=%d bitwarden_packages=%d voice_packages=%d diagnostics=%d monitor=%s vpn=%s (no system changes made)\n' \
    "$PROFILE_ID" "$count" "$bitwarden_count" "$voice_count" "$diagnostic_count" "${MONITOR_SOURCE:+yes}" "$DO_VPN"
}

print_manifest() {
  local vpn_enabled=false monitor_enabled=false packages_enabled=false bitwarden_enabled=false voice_enabled=false
  ((DO_VPN)) && vpn_enabled=true
  ((DO_MONITOR)) && monitor_enabled=true
  ((DO_PACKAGES)) && packages_enabled=true
  ((DO_BITWARDEN)) && bitwarden_enabled=true
  ((DO_VOICE)) && voice_enabled=true
  printf '{"protocol_version":1,"profile":"%s","stages":[' "$PROFILE_ID"
  printf '{"name":"vpn","enabled":%s,"title":"Connect AdGuard VPN","category":"network","needs_user_input":true},' "$vpn_enabled"
  printf '{"name":"display","enabled":%s,"title":"Apply tested display settings","category":"configuration","needs_user_input":false},' "$monitor_enabled"
  printf '{"name":"packages","enabled":%s,"title":"Install profile packages and native runtimes","category":"runtime","needs_user_input":false},' "$packages_enabled"
  printf '{"name":"voice","enabled":%s,"requires":["packages"],"title":"Install native Voxtype and activate NPU voice","category":"runtime","needs_user_input":true},' "$voice_enabled"
  printf '{"name":"terminal","title":"Apply terminal settings","category":"configuration","needs_user_input":false},'
  printf '{"name":"update","title":"Run supported Omarchy update","category":"runtime","needs_user_input":true},'
  printf '{"name":"bitwarden","enabled":%s,"requires":["packages"],"title":"Install native Wayland Bitwarden launcher","category":"security","needs_user_input":true},' "$bitwarden_enabled"
  printf '{"name":"doctor","title":"Check the installed profile","category":"diagnostics","needs_user_input":false}]}'
  printf '\n'
}

manifest_entry_count() {
  local manifest package count=0
  for manifest in "$@"; do
    [[ -f "$manifest" ]] || continue
    while IFS= read -r package; do
      [[ -n "$package" ]] && count=$((count + 1))
    done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
  done
  printf '%s' "$count"
}

print_plan() {
  local plan_title='full restore'
  local show_monitor=$DO_MONITOR show_voice=$DO_VOICE show_terminal=$DO_TERMINAL
  local show_bitwarden=$DO_BITWARDEN show_diagnostics=$DO_DIAGNOSTICS show_packages=0
  local show_update=$DO_SYSTEM_UPDATE
  [[ "$STAGE" == selected ]] && plan_title='selected components'
  [[ "$STAGE" != all && "$STAGE" != selected ]] && plan_title="$STAGE stage"
  if [[ "$STAGE" != all && "$STAGE" != selected ]]; then
    show_monitor=0
    show_voice=0
    show_terminal=0
    show_bitwarden=0
    show_diagnostics=0
    show_update=0
    case "$STAGE" in
      display) show_monitor=1 ;;
      voice) show_voice=1 ;;
      terminal) show_terminal=1 ;;
      bitwarden) show_bitwarden=1 ;;
      diagnostics) show_diagnostics=1 ;;
      packages) show_packages=1 ;;
      update) show_update=1 ;;
      vpn) : ;;
    esac
  fi
  printf '\nPlan: %s\n' "$plan_title"
  printf '  Profile: %s\n' "$PROFILE_ID"
  if ((DO_VPN)); then
    printf '  Network: ensure AdGuard VPN is connected before downloads\n'
  else
    printf '  Network: VPN disabled for this run\n'
  fi
  ((show_monitor)) && printf '  Display: apply tested user monitor layout; back up existing file\n'
  if ((show_packages)); then
    if ((${#PACKAGE_SOURCES[@]})); then
      printf "  Runtime: install %s base package entries through Omarchy's package helper\n" \
        "$(manifest_entry_count "${PACKAGE_SOURCES[@]}")"
    else
      printf '  Runtime: no standalone package entries for this profile\n'
    fi
  fi
  if ((show_voice)); then
    printf '  Voice: keep native Omarchy Voxtype; add %s Lemonade/NPU package entries and user policy\n' \
      "$(manifest_entry_count "${VOICE_PACKAGE_SOURCES[@]}")"
  fi
  ((show_terminal)) && printf '  Terminal: apply user-scoped Foot, Sixel, fzf and shell integration\n'
  if ((show_bitwarden)); then
    printf '  Bitwarden: native Wayland launcher and %s package entries; onboarding only when needed\n' \
      "$(manifest_entry_count "${BITWARDEN_PACKAGE_SOURCES[@]}")"
  fi
  ((show_diagnostics)) && printf '  Diagnostics: install optional hardware tools\n'
  if ((show_update)); then
    printf '  Update: run supported `omarchy update` as an explicit standalone action\n'
  else
    printf '  Update: not included\n'
  fi
  printf '  Native boundary: no edits to /usr/share/omarchy; native installers/services/bindings stay authoritative\n'
  printf '  Recovery: user-file backups go under %s\n' "$BACKUP_ROOT"
  if [[ "$STAGE" == all || "$STAGE" == selected ]]; then
    printf '  Verify: read-only doctor runs after a multi-stage install\n'
  else
    printf '  Verify: this standalone stage does not run doctor automatically\n'
  fi
}

print_run_summary() {
  local -a steps=()
  local step
  ((DO_VPN)) && steps+=(VPN)
  ((DO_MONITOR)) && steps+=(Display)
  ((DO_VOICE)) && steps+=(Voice/NPU)
  ((DO_TERMINAL)) && steps+=(Terminal)
  ((DO_BITWARDEN)) && steps+=(Bitwarden)
  ((DO_DIAGNOSTICS)) && steps+=(Diagnostics)
  printf '  Mode: %s\n' "$([[ "$STAGE" == selected ]] && printf 'selected restore' || printf 'full restore')"
  printf '  Flow:'
  if ((${#steps[@]})); then
    for step in "${steps[@]}"; do
      printf ' %s →' "$step"
    done
  fi
  printf ' Verify\n'
  printf '  Native: Omarchy installers, services and bindings remain authoritative; profile changes stay user-scoped\n'
}

selected_component() {
  [[ ",${COMPONENTS_REQUEST}," == *",$1,"* ]]
}

configure_selected_components() {
  [[ "$STAGE" == selected ]] || return 0
  [[ -n "$COMPONENTS_REQUEST" ]] || die '--stage selected requires --components'
  local component
  local -a requested=()
  IFS=',' read -r -a requested <<<"$COMPONENTS_REQUEST"
  for component in "${requested[@]}"; do
    case "$component" in
      vpn|display|voice|bitwarden|diagnostics|terminal|update|doctor) ;;
      *) die "unknown selected component: $component" ;;
    esac
  done
  if selected_component update && [[ "$COMPONENTS_REQUEST" != update ]]; then
    die 'system update must be selected alone; re-apply the profile after it'
  fi

  DO_VPN=0
  DO_MONITOR=0
  DO_PACKAGES=0
  DO_TERMINAL=0
  DO_VOICE=0
  DO_BITWARDEN=0
  DO_DIAGNOSTICS=0
  if selected_component vpn && ((VPN_OPTION_SET == 0)); then DO_VPN=1; fi
  if selected_component display; then DO_MONITOR=1; fi
  if selected_component terminal; then DO_TERMINAL=1; fi
  if selected_component voice; then DO_VOICE=1; DO_PACKAGES=1; fi
  if selected_component bitwarden; then DO_BITWARDEN=1; DO_PACKAGES=1; fi
  if selected_component diagnostics; then DO_DIAGNOSTICS=1; fi

  # Package/model, diagnostic and update work is network-dependent. A
  # terminal-only run still lets its own stage decide whether ble.sh is needed,
  # preserving the no-VPN fast path when local prerequisites are ready.
  if ((VPN_OPTION_SET == 0)) && ((DO_VPN == 0)) &&
     { ((DO_PACKAGES)) || ((DO_DIAGNOSTICS)) || ((DO_TERMINAL)) || selected_component update; }; then
    DO_VPN="$PROFILE_ENABLE_VPN"
  fi
}

compact_check() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    if grep -q '^WARN' <<<"${output}"; then
      printf '  ! %s\n' "${label}"
      grep '^WARN' <<<"${output}" | head -n 2 | sed 's/^/    /'
      COMPACT_WARNINGS=$((COMPACT_WARNINGS + 1))
    else
      printf '  ✓ %s\n' "${label}"
    fi
  else
    printf '  ✗ %s\n' "${label}"
    grep -E '^(FAIL|WARN|result=)' <<<"${output}" | head -n 4 | sed 's/^/    /'
    COMPACT_FAILURES=$((COMPACT_FAILURES + 1))
  fi
}

run_doctor_compact() {
  local failures=0 version status errors
  COMPACT_FAILURES=0
  COMPACT_WARNINGS=0
  printf '\n%sVerification%s (read-only)\n' "$C_CYAN" "$C_RESET"
  printf '  Profile: %s\n' "$PROFILE_ID"

  if command -v omarchy >/dev/null 2>&1; then
    version="$(omarchy version 2>/dev/null || true)"
    printf '  ✓ Omarchy%s\n' "${version:+ ${version}}"
  else
    printf '  ✗ Omarchy command is missing\n'
    COMPACT_FAILURES=$((COMPACT_FAILURES + 1))
  fi
  if ((DO_VOICE)) && [[ -n "$VOICE_SOURCE" ]]; then
    compact_check 'Voice / NPU' "$VOICE_SOURCE" --check
  fi
  if ((DO_TERMINAL)) && [[ -n "$TERMINAL_SOURCE" ]] && command -v terminal-doctor >/dev/null 2>&1; then
    compact_check 'Terminal' terminal-doctor
  fi
  if ((DO_BITWARDEN)) && [[ -n "$BITWARDEN_DOCTOR" ]]; then
    if [[ -e "${HOME}/.local/bin/omarchy-bitwarden" ||
          -e "${XDG_CONFIG_HOME:-${HOME}/.config}/rbw/config.json" ]]; then
      compact_check 'Bitwarden' "$BITWARDEN_DOCTOR"
    else
      printf '  ! Bitwarden (setup deferred)\n'
      COMPACT_WARNINGS=$((COMPACT_WARNINGS + 1))
    fi
  fi
  if [[ -n "$DISPLAY_DOCTOR" ]]; then
    compact_check 'Display' "$DISPLAY_DOCTOR"
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    if errors="$(hyprctl configerrors 2>/dev/null)"; then
      if [[ -z "$errors" ]]; then
        printf '  ✓ Hyprland configuration\n'
      else
        printf '  ✗ Hyprland configuration\n'
        printf '%s\n' "$errors" | head -n 4 | sed 's/^/    /'
        COMPACT_FAILURES=$((COMPACT_FAILURES + 1))
      fi
    else
      printf '  ! Hyprland session is unavailable\n'
      COMPACT_WARNINGS=$((COMPACT_WARNINGS + 1))
    fi
  else
    printf '  ! Hyprland check unavailable\n'
    COMPACT_WARNINGS=$((COMPACT_WARNINGS + 1))
  fi
  if ((DO_VPN)); then
    if find_vpn_cli; then
      status="$($VPN_CLI status 2>/dev/null || true)"
      if grep -Eiq '(^|[^[:alpha:]])connected([^[:alpha:]]|$)|protected' <<<"$status"; then
        printf '  ✓ AdGuard VPN connected\n'
      else
        printf '  ! AdGuard VPN is not connected\n'
        COMPACT_WARNINGS=$((COMPACT_WARNINGS + 1))
      fi
    else
      printf '  ! AdGuard VPN CLI is not installed\n'
      COMPACT_WARNINGS=$((COMPACT_WARNINGS + 1))
    fi
  fi

  failures=$COMPACT_FAILURES
  if ((failures == 0)); then
    printf '\n%s✓ Complete%s' "$C_GREEN" "$C_RESET"
    if ((COMPACT_WARNINGS)); then
      printf ' (%d warning(s))' "$COMPACT_WARNINGS"
    fi
    printf '\n'
  else
    printf '\n%s✗ Failed%s (%d check(s))\n' "$C_RED" "$C_RESET" "$failures"
  fi
  return "$failures"
}

run_doctor() {
  if [[ "${OMARCHY_COMPACT_OUTPUT:-0}" == 1 ]]; then
    run_doctor_compact
    return
  fi
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

  if ((DO_BITWARDEN)) && [[ -n "$BITWARDEN_DOCTOR" ]]; then
    if [[ -e "${HOME}/.local/bin/omarchy-bitwarden" ||
          -e "${XDG_CONFIG_HOME:-${HOME}/.config}/rbw/config.json" ]]; then
      if "$BITWARDEN_DOCTOR"; then
        printf '%sOK%s native Bitwarden\n' "$C_GREEN" "$C_RESET"
      else
        printf '%sFAIL%s native Bitwarden\n' "$C_RED" "$C_RESET"
        failures=$((failures + 1))
      fi
    else
      printf 'WARN Bitwarden setup was deferred; run --stage bitwarden when ready\n'
    fi
  fi

  if [[ -n "$DISPLAY_DOCTOR" ]]; then
    if "$DISPLAY_DOCTOR"; then
      printf '%sOK%s display profile\n' "$C_GREEN" "$C_RESET"
    else
      printf '%sFAIL%s display profile\n' "$C_RED" "$C_RESET"
      failures=$((failures + 1))
    fi
  fi

  if command -v hyprctl >/dev/null 2>&1; then
    if errors="$(hyprctl configerrors 2>/dev/null)"; then
      if [[ -z "$errors" ]]; then
        printf '%sOK%s Hyprland configuration\n' "$C_GREEN" "$C_RESET"
      else
        printf '%sFAIL%s Hyprland configuration errors:\n%s\n' "$C_RED" "$C_RESET" "$errors"
        failures=$((failures + 1))
      fi
    else
      printf 'WARN Hyprland session is not available; skipped compositor check\n'
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
    --components) shift; (($#)) || die "--components needs a value"; COMPONENTS_REQUEST="$1" ;;
    --manifest) MANIFEST=1 ;;
    --plan) PLAN_ONLY=1 ;;
    --verbose) export OMARCHY_VERBOSE=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    --no-terminal) DO_TERMINAL=0 ;;
    --no-voice) DO_VOICE=0; VOICE_OPTION_SET=1 ;;
    --no-bitwarden) DO_BITWARDEN=0; BITWARDEN_OPTION_SET=1 ;;
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
if [[ "$STAGE" == packages ]]; then
  # Keep the compatibility package-only stage genuinely package-only. Profile
  # defaults for voice and Bitwarden must not leak into its checks or actions.
  DO_VOICE=0
  DO_BITWARDEN=0
fi
configure_selected_components

if ((DO_VOICE && !DO_PACKAGES)); then
  die 'voice requires the package stage; remove --no-packages or add --no-voice'
fi
if ((DO_SYSTEM_UPDATE)) && [[ "$STAGE" == all ]]; then
  die '--update-system must be run separately with --stage update; apply the profile again after the Omarchy update'
fi
if ((DO_BITWARDEN && !DO_PACKAGES)); then
  die 'Bitwarden requires the package stage; remove --no-packages or add --no-bitwarden'
fi

if ((MANIFEST)); then
  print_manifest
  exit 0
fi
if ((PLAN_ONLY)); then
  print_plan
  printf '\nNo system changes made.\n'
  exit 0
fi
if ((DO_CHECK)); then
  check_profile
  exit 0
fi
if [[ "${OMARCHY_VERBOSE:-0}" != 1 && ( "$STAGE" == all || "$STAGE" == selected ) ]]; then
  export OMARCHY_COMPACT_OUTPUT=1
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

preflight_non_interactive() {
  ((NON_INTERACTIVE)) || return 0
  if ((DO_VPN)) && ! find_vpn_cli; then
    die '--non-interactive cannot install/login AdGuard VPN; run from a terminal first'
  fi
  if ((DO_VOICE)); then
    if [[ ! -f "$HOME/.config/voxtype/config.toml" ||
          ! -f "$HOME/.config/systemd/user/voxtype.service" ]] ||
       ! command -v voxtype >/dev/null 2>&1 ||
       ! command -v wtype >/dev/null 2>&1; then
      die '--non-interactive needs an existing native Voxtype setup; run once from a terminal'
    fi
  fi
}

preflight_non_interactive

ensure_vpn_for_network_stage() {
  if ((DO_VPN)); then
    connect_vpn
  fi
}

voice_network_needed() {
  command -v pacman >/dev/null 2>&1 || return 0
  pacman -Q lemonade-server fastflowlm >/dev/null 2>&1 || return 0
  [[ -f "${HOME}/.config/voxtype/config.toml" ]] || return 0
  [[ -f "${HOME}/.local/share/voxtype/models/ggml-silero-vad.bin" ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  curl --fail --silent --show-error --max-time 5 \
    http://127.0.0.1:13305/api/v1/health |
    jq -e '.all_models_loaded[]? | select(.model_name == "whisper-v3-turbo-FLM" and .device == "npu" and .backend_health == "ready" and .loaded == true)' \
    >/dev/null 2>&1 || return 0
  return 1
}

terminal_network_needed() {
  command -v chafa >/dev/null 2>&1 || return 0
  [[ -r "${HOME}/.local/share/blesh/ble.sh" ]] || return 0
  return 1
}

stage_note() {
  CURRENT_STAGE="$2"
  printf '\n[%s] %s\n' "$1" "$2"
}

on_error() {
  local exit_code=$?
  printf '\n%s✗ Failed%s during %s\n' "$C_RED" "$C_RESET" "$CURRENT_STAGE" >&2
  printf '  Next: open zenbook-omarchy and choose the failed component to retry.\n' >&2
  exit "$exit_code"
}

trap on_error ERR

ask_bitwarden_install() {
  ((NON_INTERACTIVE == 0)) || return 1
  if [[ -e "$BITWARDEN_ONBOARDING_STATE" ]]; then
    printf 'bootstrap: Bitwarden onboarding already complete; continuing without a prompt\n'
    return 0
  fi
  [[ -r /dev/tty ]] || return 1
  printf '\nBitwarden: install the native Wayland launcher and start the guided setup now? [y/N] '
  local answer
  IFS= read -r answer </dev/tty || return 1
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

run_stage() {
  case "$STAGE" in
    all)
      # Keep the least surprising clean-install order: network first, then
      # simple tested user settings, then package/model/service work.
      stage_note 'network' 'AdGuard VPN'
      if ((DO_VPN)); then connect_vpn; else printf 'bootstrap: VPN disabled\n'; fi
      if ((DO_VPN_CLI_UPDATE)); then update_vpn_cli; fi
      stage_note 'display' 'Display settings'
      if ((DO_MONITOR)); then backup_and_install_monitor; else printf 'bootstrap: display stage skipped\n'; fi
      if ((${#PACKAGE_SOURCES[@]})); then
        stage_note 'packages' 'Base runtime dependencies'
        install_packages
      fi
      stage_note 'voice' 'Voice / NPU transcription'
      if ((DO_VOICE)); then install_voice_packages; install_voice; else printf 'bootstrap: voice stage skipped\n'; fi
      stage_note 'terminal' 'Terminal enhancements'
      apply_terminal
      if ((DO_SYSTEM_UPDATE)); then
        stage_note 'update' 'Omarchy system update'
        apply_update
        stage_note 'bitwarden' 'Bitwarden passwords'
        if ((DO_BITWARDEN)) && ask_bitwarden_install; then install_bitwarden; else DO_BITWARDEN=0; printf 'bootstrap: Bitwarden setup deferred\n'; fi
        stage_note 'verify' 'Verification'
      else
        stage_note 'bitwarden' 'Bitwarden passwords'
        if ((DO_BITWARDEN)) && ask_bitwarden_install; then install_bitwarden; else DO_BITWARDEN=0; printf 'bootstrap: Bitwarden setup deferred\n'; fi
        stage_note 'verify' 'Verification'
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
      stage_note 'packages' 'Base runtime dependencies'
      ((DO_PACKAGES)) || die 'package stage is disabled by --no-packages'
      if ((${#PACKAGE_SOURCES[@]})); then
        ensure_vpn_for_network_stage
        install_packages
      else
        printf 'bootstrap: no standalone profile packages for this profile\n'
      fi
      ;;
    bitwarden)
      stage_note '1/1' 'Bitwarden: native Wayland launcher'
      ((DO_BITWARDEN)) || die 'Bitwarden stage is disabled by --no-bitwarden or this profile'
      ((DO_PACKAGES)) || die 'Bitwarden requires packages; remove --no-packages'
      ensure_vpn_for_network_stage
      install_bitwarden
      ;;
    diagnostics)
      stage_note '1/1' 'Optional diagnostics: package tools'
      install_diagnostics
      ;;
    voice)
      stage_note '1/1' 'Voice: native Voxtype + NPU inference'
      ((DO_VOICE)) || die 'voice stage is disabled by --no-voice or this profile'
      ((DO_PACKAGES)) || die 'voice requires packages; remove --no-packages'
      if voice_network_needed; then
        ensure_vpn_for_network_stage
      else
        printf 'bootstrap: local NPU voice prerequisites already ready; VPN not required\n'
      fi
      install_voice_packages
      install_voice
      ;;
    terminal)
      stage_note '1/1' 'Terminal: user settings'
      [[ -n "$TERMINAL_SOURCE" ]] || die "profile $PROFILE_ID has no terminal stage"
      ((DO_TERMINAL)) || die 'terminal stage is disabled by --no-terminal'
      if terminal_network_needed; then
        ensure_vpn_for_network_stage
      else
        printf 'bootstrap: local terminal prerequisites already ready; VPN not required\n'
      fi
      apply_terminal
      ;;
    update)
      stage_note '1/1' 'System: supported Omarchy update'
      ensure_vpn_for_network_stage
      apply_update
      ;;
    selected)
      [[ -n "$COMPONENTS_REQUEST" ]] || die 'selected stage requires --components'
      local selected_network=0
      if ((DO_VPN)) && selected_component vpn; then selected_network=1; fi
      if ((DO_VPN)) && {
        ((DO_PACKAGES)) || ((DO_DIAGNOSTICS)) || selected_component update
      }; then selected_network=1; fi
      stage_note 'network' 'AdGuard VPN'
      if ((selected_network)); then
        connect_vpn
      else
        printf 'bootstrap: VPN not selected or not required\n'
      fi
      stage_note 'display' 'Display settings'
      if ((DO_MONITOR)); then backup_and_install_monitor; else printf 'bootstrap: display stage skipped\n'; fi
      if ((${#PACKAGE_SOURCES[@]})); then
        stage_note 'packages' 'Base runtime dependencies'
        install_packages
      fi
      stage_note 'voice' 'Voice / NPU transcription'
      if ((DO_VOICE)); then install_voice_packages; install_voice; else printf 'bootstrap: voice stage skipped\n'; fi
      stage_note 'terminal' 'Terminal enhancements'
      if ((DO_TERMINAL)); then apply_terminal; else printf 'bootstrap: terminal stage skipped\n'; fi
      stage_note 'bitwarden' 'Bitwarden passwords'
      if ((DO_BITWARDEN)); then install_bitwarden; else printf 'bootstrap: Bitwarden stage skipped\n'; fi
      if ((DO_DIAGNOSTICS)); then
        stage_note 'diagnostics' 'Optional hardware diagnostics'
        install_diagnostics
      else
        stage_note 'verify' 'Verification'
      fi
      run_doctor
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
if [[ "$STAGE" == all || "$STAGE" == selected ]]; then
  print_run_summary
fi
run_stage
if [[ "${OMARCHY_COMPACT_OUTPUT:-0}" == 1 ]]; then
  :
else
  printf '\n%sDONE%s profile=%s stage=%s\n' "$C_GREEN" "$C_RESET" "$PROFILE_ID" "$STAGE"
fi
