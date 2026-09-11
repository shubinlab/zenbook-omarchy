#!/usr/bin/env bash
set -euo pipefail

# Reproduce the user-scoped Xerox WorkCentre 3025 print/scan setup on Omarchy.
# Network identity is supplied at install time and is never stored here.

readonly QUEUE_NAME="xerox-workcentre-3025"
readonly SCANNER_NAME="Xerox WorkCentre 3025 (WSD)"
readonly BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-profiles/xerox-workcentre-3025"
readonly -a PACKAGES=(cups cups-filters sane sane-airscan simple-scan)

HOST=""
PRINTER_URI=""
SCANNER_URL=""
NO_PRINTER=0
NO_SCANNER=0
CHECK_ONLY=0

usage() {
  cat <<'HELP'
Usage: scripts/xerox-workcentre.sh [options]

Install the Omarchy print/scan stack and configure a Xerox WorkCentre 3025.
The printer is configured through driverless IPP and the scanner through WSD.
No test page is printed.

Options:
  --host HOST          Use HOST for both print and scan defaults.
  --printer-uri URI    Override the IPP printer URI.
  --scanner-url URL    Override the WSD scan URL.
  --no-printer         Install scanner support only.
  --no-scanner         Install printer support only.
  --check              Print the plan and make no changes.
  -h, --help           Show this help.

Examples:
  scripts/xerox-workcentre.sh --host xerox.local
  scripts/xerox-workcentre.sh --printer-uri ipp://printer.local/ipp/print \
    --scanner-url http://printer.local:8018/wsd/scan
  scripts/xerox-workcentre.sh --check --host 192.0.2.10

If --host is omitted during an apply, an existing queue with the default name
is used to derive the printer host. A clean install therefore needs --host or
both explicit URI options.
HELP
}

die() {
  printf 'xerox-workcentre: ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'xerox-workcentre: WARNING: %s\n' "$*" >&2
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_host() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
    die "invalid host: $1"
}

validate_printer_uri() {
  case "$1" in
    ipp://*|ipps://*) ;;
    *) die "printer URI must use ipp:// or ipps://" ;;
  esac
}

validate_scanner_url() {
  case "$1" in
    http://*|https://*) ;;
    *) die "scanner URL must use http:// or https://" ;;
  esac
}

host_from_uri() {
  local authority
  authority="${1#*://}"
  authority="${authority%%/*}"
  authority="${authority##*@}"
  authority="${authority%%:*}"
  [[ -n "$authority" ]] || die "cannot derive host from printer URI"
  validate_host "$authority"
  printf '%s\n' "$authority"
}

existing_printer_uri() {
  lpstat -v "$QUEUE_NAME" 2>/dev/null |
    sed "s/^device for ${QUEUE_NAME}: //" | head -n 1
}

resolve_targets() {
  local existing_uri=""

  if ((NO_PRINTER == 0)) && [[ -z "$PRINTER_URI" ]]; then
    if [[ -n "$HOST" ]]; then
      PRINTER_URI="ipp://${HOST}/ipp/print"
    else
      existing_uri="$(existing_printer_uri || true)"
      if [[ -n "$existing_uri" ]]; then
        PRINTER_URI="$existing_uri"
      else
        die 'printer target is missing; pass --host or --printer-uri'
      fi
    fi
  fi

  if [[ -z "$HOST" && -n "$PRINTER_URI" ]]; then
    HOST="$(host_from_uri "$PRINTER_URI")"
  fi

  if ((NO_SCANNER == 0)) && [[ -z "$SCANNER_URL" ]]; then
    [[ -n "$HOST" ]] || die 'scanner target is missing; pass --host or --scanner-url'
    SCANNER_URL="http://${HOST}:8018/wsd/scan"
  fi

  if [[ -n "$HOST" ]]; then
    validate_host "$HOST"
  fi
  if [[ -n "$PRINTER_URI" ]]; then
    validate_printer_uri "$PRINTER_URI"
  fi
  if [[ -n "$SCANNER_URL" ]]; then
    validate_scanner_url "$SCANNER_URL"
  fi
}

print_plan() {
  printf 'packages: %s\n' "${PACKAGES[*]}"
  if ((NO_PRINTER)); then
    printf '%s\n' 'printer: skipped'
  else
    printf 'printer URI: %s\n' "$PRINTER_URI"
    printf 'default queue: %s\n' "$QUEUE_NAME"
  fi
  if ((NO_SCANNER)); then
    printf '%s\n' 'scanner: skipped'
  else
    printf 'scanner URL: %s\n' "$SCANNER_URL"
    printf 'scanner name: %s\n' "$SCANNER_NAME"
  fi
  if ((CHECK_ONLY)); then
    printf '%s\n' 'check: no changes made'
  fi
}

run_as_root() {
  if ((EUID == 0)); then
    "$@"
  elif [[ -t 0 || -t 1 ]]; then
    need_command sudo
    sudo "$@"
  else
    need_command pkexec
    pkexec "$@"
  fi
}

install_packages() {
  need_command omarchy
  omarchy pkg add "${PACKAGES[@]}"
}

backup_if_changed() {
  local source="$1" target="$2" stamp backup
  if [[ -e "$target" ]] && cmp -s "$source" "$target"; then
    return 1
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$BACKUP_ROOT/backups/$stamp"
    mkdir -p "$backup"
    cp -a -- "$target" "$backup/"
    printf 'backup: %s\n' "$backup/$(basename -- "$target")"
  fi
  return 0
}

install_text_file() {
  local target="$1" content="$2" temp
  temp="$(mktemp)"
  printf '%s\n' "$content" >"$temp"
  if backup_if_changed "$temp" "$target"; then
    install -D -m 0644 "$temp" "$target"
    printf 'installed: %s\n' "$target"
  else
    printf 'unchanged: %s\n' "$target"
  fi
  rm -f -- "$temp"
}

configure_sane() {
  local sane_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sane"
  local environment_dir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
  local config_file="$sane_dir/airscan.conf"
  local environment_file="$environment_dir/90-sane-airscan.conf"

  install_text_file "$config_file" "[options]
discovery = disable

[devices]
\"$SCANNER_NAME\" = $SCANNER_URL, WSD"
  install_text_file "$environment_file" "SANE_CONFIG_DIR=$sane_dir:/etc/sane.d"

  export SANE_CONFIG_DIR="$sane_dir:/etc/sane.d"
  if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user import-environment SANE_CONFIG_DIR || true
  fi
  if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd SANE_CONFIG_DIR="$SANE_CONFIG_DIR" || true
  fi
}

configure_cups() {
  need_command lpadmin
  need_command lpstat
  if ! systemctl is-active --quiet cups.service; then
    run_as_root systemctl enable --now cups.service
  fi
  run_as_root lpadmin -p "$QUEUE_NAME" -E -v "$PRINTER_URI" -m everywhere \
    -o printer-is-shared=false
  run_as_root lpadmin -d "$QUEUE_NAME"
  printf 'configured: CUPS queue %s (default)\n' "$QUEUE_NAME"
}

verify_packages() {
  local package
  for package in "${PACKAGES[@]}"; do
    pacman -Q "$package" >/dev/null 2>&1 || die "package is missing after install: $package"
  done
}

verify_cups() {
  local default_destination queue_uri
  default_destination="$(lpstat -d 2>/dev/null || true)"
  queue_uri="$(existing_printer_uri || true)"
  grep -Fq "system default destination: $QUEUE_NAME" <<<"$default_destination" ||
    die 'CUPS default destination verification failed'
  [[ "$queue_uri" == "$PRINTER_URI" ]] ||
    die 'CUPS printer URI verification failed'
  printf '%s\n' 'verify: CUPS queue and default passed (no print submitted)'
}

verify_sane() {
  local devices=""
  if ! command -v scanimage >/dev/null 2>&1; then
    warn 'scanimage is unavailable; SANE enumeration was not tested'
    return 0
  fi
  if devices="$(timeout 15s env SANE_CONFIG_DIR="$SANE_CONFIG_DIR" scanimage -L 2>/dev/null)" &&
     grep -Fq 'airscan:' <<<"$devices"; then
    printf '%s\n' 'verify: SANE enumerated the configured Xerox WSD device'
  else
    warn 'SANE did not enumerate the WSD device within 15 seconds'
  fi
}

apply_setup() {
  install_packages
  if ((NO_SCANNER == 0)); then
    configure_sane
  fi
  if ((NO_PRINTER == 0)); then
    configure_cups
  fi
  verify_packages
  if ((NO_SCANNER == 0)); then
    verify_sane
  fi
  if ((NO_PRINTER == 0)); then
    verify_cups
  fi
}

while (($#)); do
  case "$1" in
    --host)
      (($# >= 2)) || die '--host requires a value'
      HOST="$2"
      shift 2
      ;;
    --printer-uri)
      (($# >= 2)) || die '--printer-uri requires a value'
      PRINTER_URI="$2"
      shift 2
      ;;
    --scanner-url)
      (($# >= 2)) || die '--scanner-url requires a value'
      SCANNER_URL="$2"
      shift 2
      ;;
    --no-printer)
      NO_PRINTER=1
      shift
      ;;
    --no-scanner)
      NO_SCANNER=1
      shift
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if ((NO_PRINTER && NO_SCANNER)); then
  die '--no-printer and --no-scanner cannot be used together'
fi

resolve_targets
print_plan

if ((CHECK_ONLY)); then
  exit 0
fi

apply_setup
