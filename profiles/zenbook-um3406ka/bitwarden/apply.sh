#!/usr/bin/env bash
set -Eeuo pipefail

# Minimal, native Wayland Bitwarden integration for Omarchy.
# Credentials, API keys and vault data never belong in this repository.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
BACKUP_ROOT="${STATE_HOME}/omarchy-profiles/backups/bitwarden"
LAUNCHER="${HOME}/.local/bin/omarchy-bitwarden"
BINDINGS="${CONFIG_HOME}/hypr/bindings.lua"
RBW_CONFIG="${CONFIG_HOME}/rbw/config.json"
PINENTRY="/usr/bin/pinentry-gnome3"
LOCK_TIMEOUT="${OMARCHY_BITWARDEN_LOCK_TIMEOUT:-600}"
SYNC_INTERVAL="${OMARCHY_BITWARDEN_SYNC_INTERVAL:-3600}"
FORCE_CHROMIUM_EXTENSION="${OMARCHY_BITWARDEN_FORCE_CHROMIUM_EXTENSION:-0}"
MARKER="zenbook-omarchy Bitwarden (managed)"
CHROMIUM_POLICY_DIR="/etc/chromium/policies/managed"
CHROMIUM_POLICY_FILE="${CHROMIUM_POLICY_DIR}/zenbook-omarchy-bitwarden.json"
BITWARDEN_EXTENSION_ID="nngceckbapebfimnlniiiahkandclblb"
BITWARDEN_EXTENSION_UPDATE_URL="https://clients2.google.com/service/update2/crx"

ACTION=check
BACKUP_ID=""
BINDINGS_CHANGED=0

die() { printf 'bitwarden-omarchy: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat <<'EOF'
Usage: profiles/zenbook-um3406ka/bitwarden/apply.sh [--check|--apply|--rollback]

--check     validate repository assets only; no system changes
--apply     install the native Wayland launcher, settings and Chromium policy
--rollback  restore the latest Bitwarden integration backup
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --apply) ACTION=apply ;;
    --rollback) ACTION=rollback ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ ${EUID} -ne 0 ]] || die 'run as the normal Omarchy user, not root'
[[ -d ${HOME} ]] || die 'HOME is not available'

check_repository() {
  [[ -x ${SCRIPT_DIR}/launcher ]] || die 'Bitwarden launcher asset is missing or not executable'
  bash -n "${SCRIPT_DIR}/launcher"
  [[ ${LOCK_TIMEOUT} =~ ^[0-9]+$ ]] || die 'lock timeout must be an integer'
  [[ ${SYNC_INTERVAL} =~ ^[0-9]+$ ]] || die 'sync interval must be an integer'
  [[ ${FORCE_CHROMIUM_EXTENSION} == 0 || ${FORCE_CHROMIUM_EXTENSION} == 1 ]] ||
    die 'OMARCHY_BITWARDEN_FORCE_CHROMIUM_EXTENSION must be 0 or 1'
  [[ ${PINENTRY} == /usr/bin/pinentry-gnome3 ]] || die 'pinentry path is not the expected native default'
  [[ ${BITWARDEN_EXTENSION_ID} =~ ^[a-z]{32}$ ]] || die 'Bitwarden extension ID is invalid'
  printf 'bitwarden check: PASS (native Wayland assets valid; no system changes made)\n'
}

chromium_is_default() {
  command -v xdg-settings >/dev/null 2>&1 || return 1
  case "$(xdg-settings get default-web-browser 2>/dev/null || true)" in
    chromium.desktop|*chromium*) return 0 ;;
    *) return 1 ;;
  esac
}

chromium_bitwarden_installed() {
  local chromium_config_home="${CONFIG_HOME}/chromium"
  [[ -d ${chromium_config_home} ]] || return 1
  find "${chromium_config_home}" -mindepth 3 -maxdepth 3 -type d \
    -name "${BITWARDEN_EXTENSION_ID}" -print -quit 2>/dev/null | grep -q .
}

write_chromium_policy() {
  printf '{"ExtensionInstallForcelist":["%s;%s"]}\n' \
    "$BITWARDEN_EXTENSION_ID" "$BITWARDEN_EXTENSION_UPDATE_URL"
}

install_chromium_policy() {
  if [[ ${FORCE_CHROMIUM_EXTENSION} != 1 ]]; then
    printf 'bitwarden-omarchy: Chromium extension auto-install is opt-in; manual Web Store setup remains available\n'
    return 0
  fi
  chromium_is_default || {
    printf 'bitwarden-omarchy: Chromium is not the default browser; automatic Chromium extension install skipped\n'
    return 0
  }
  need chromium
  if chromium_bitwarden_installed; then
    printf 'bitwarden-omarchy: Bitwarden extension already exists in Chromium; policy install skipped\n'
    return 0
  fi

  local policy_tmp
  policy_tmp="$(mktemp)"
  write_chromium_policy >"$policy_tmp"
  if [[ -e ${CHROMIUM_POLICY_FILE} ]]; then
    if cmp -s "$policy_tmp" "$CHROMIUM_POLICY_FILE"; then
      printf 'bitwarden-omarchy: Chromium auto-install policy is already present\n'
    else
      rm -f -- "$policy_tmp"
      die "refusing to overwrite existing Chromium policy: ${CHROMIUM_POLICY_FILE}"
    fi
    rm -f -- "$policy_tmp"
    return 0
  fi

  need sudo
  sudo install -d -m 0755 "${CHROMIUM_POLICY_DIR}"
  sudo install -m 0644 "$policy_tmp" "${CHROMIUM_POLICY_FILE}"
  rm -f -- "$policy_tmp"
  printf 'bitwarden-omarchy: Chromium will auto-install the official Bitwarden extension via policy\n'
}

backup_target() {
  local target=$1 name=$2
  if [[ -e ${target} || -L ${target} ]]; then
    cp -a -- "${target}" "${BACKUP_ROOT}/${BACKUP_ID}/${name}"
  else
    : >"${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent"
  fi
}

backup_once() {
  [[ -n ${BACKUP_ID} ]] && return
  BACKUP_ID="$(date -u +%Y%m%dT%H%M%S)-${BASHPID}"
  install -d -m 0700 "${BACKUP_ROOT}/${BACKUP_ID}"
  backup_target "${BINDINGS}" bindings.lua
  backup_target "${RBW_CONFIG}" rbw-config.json
  backup_target "${LAUNCHER}" launcher
}

legacy_binding_present() {
  [[ -r ${BINDINGS} ]] || return 1
  grep -Fqx -- '-- Native Wayland Bitwarden launcher. The Omarchy default password binding' "${BINDINGS}" &&
    grep -Fqx -- '-- points to 1Password; keep the key but use rbw + fuzzel instead.' "${BINDINGS}" &&
    grep -Fqx -- 'hl.unbind("SUPER + SHIFT + SLASH")' "${BINDINGS}" &&
    grep -Fqx -- 'o.bind("SUPER + SHIFT + SLASH", "Passwords", "rofi-rbw --selector fuzzel --clipboarder wl-copy --typer wtype")' "${BINDINGS}"
}

remove_legacy_binding() {
  legacy_binding_present || return 0
  backup_once
  local temporary
  temporary="$(mktemp "${BINDINGS}.tmp.XXXXXX")"
  sed '/^-- Native Wayland Bitwarden launcher\. The Omarchy default password binding$/,/^o\.bind("SUPER + SHIFT + SLASH", "Passwords", "rofi-rbw --selector fuzzel --clipboarder wl-copy --typer wtype")$/d' \
    "${BINDINGS}" >"${temporary}"
  install -m0644 "${temporary}" "${BINDINGS}"
  rm -f -- "${temporary}"
  BINDINGS_CHANGED=1
  printf 'bitwarden-omarchy: removed the older unmanaged Bitwarden binding\n'
}

apply_launcher() {
  if [[ -e ${LAUNCHER} ]] && cmp -s "${SCRIPT_DIR}/launcher" "${LAUNCHER}"; then
    return 0
  fi
  backup_once
  install -Dm0755 "${SCRIPT_DIR}/launcher" "${LAUNCHER}"
}

apply_rbw_config() {
  need rbw
  need "${PINENTRY##*/}"
  mkdir -p -m 0700 "${CONFIG_HOME}/rbw"
  if [[ ! -r ${RBW_CONFIG} ]] ||
     ! grep -Fq -- "\"pinentry\":\"${PINENTRY}\"" "${RBW_CONFIG}" ||
     ! grep -Fq -- "\"lock_timeout\":${LOCK_TIMEOUT}" "${RBW_CONFIG}" ||
     ! grep -Fq -- "\"sync_interval\":${SYNC_INTERVAL}" "${RBW_CONFIG}" ||
     [[ $(stat -c '%a' "${RBW_CONFIG}" 2>/dev/null || true) != 600 ]]; then
    backup_once
  fi
  rbw config set pinentry "${PINENTRY}"
  rbw config set lock_timeout "${LOCK_TIMEOUT}"
  rbw config set sync_interval "${SYNC_INTERVAL}"
  [[ -f ${RBW_CONFIG} ]] || die 'rbw did not create its user configuration'
  chmod 600 "${RBW_CONFIG}"
}

apply_binding() {
  mkdir -p "$(dirname -- "${BINDINGS}")"
  remove_legacy_binding
  if (( $(grep -Fc -- 'o.bind("SUPER + SHIFT + SLASH", "Passwords", "omarchy-bitwarden")' "$BINDINGS" 2>/dev/null || true) > 1 )); then
    deduplicate_managed_bindings
  fi
  if grep -Fq -- "${MARKER}" "${BINDINGS}" 2>/dev/null; then
    return 0
  fi
  backup_once
  cat >>"${BINDINGS}" <<'EOF'

-- >>> zenbook-omarchy Bitwarden (managed) >>>
-- Replace Omarchy's default password-manager binding with the native Wayland launcher.
hl.unbind("SUPER + SHIFT + SLASH")
o.bind("SUPER + SHIFT + SLASH", "Passwords", "omarchy-bitwarden")
-- <<< zenbook-omarchy Bitwarden (managed) <<<
EOF
  BINDINGS_CHANGED=1
}

remove_managed_binding() {
  [[ -r ${BINDINGS} ]] || return 0
  local temporary
  temporary="$(mktemp "${BINDINGS}.tmp.XXXXXX")"
  sed '/^-- >>> zenbook-omarchy Bitwarden (managed) >>>$/,/^-- <<< zenbook-omarchy Bitwarden (managed) <<<$/{d;}' \
    "${BINDINGS}" >"${temporary}"
  install -m0644 "${temporary}" "${BINDINGS}"
  rm -f -- "${temporary}"
  remove_legacy_binding
}

deduplicate_managed_bindings() {
  local temporary
  backup_once
  temporary="$(mktemp "$BINDINGS.tmp.XXXXXX")"
  awk '
    /^-- >>> zenbook-omarchy Bitwarden \(managed\) >>>$/ {
      block_count += 1
      if (block_count > 1) {
        skip = 1
        next
      }
    }
    /^-- <<< zenbook-omarchy Bitwarden \(managed\) <<</ {
      if (skip) {
        skip = 0
        next
      }
    }
    !skip { print }
  ' "$BINDINGS" >"$temporary"
  install -m0644 "$temporary" "$BINDINGS"
  rm -f -- "$temporary"
  BINDINGS_CHANGED=1
  printf 'bitwarden-omarchy: removed duplicate managed bindings\n'
}

apply_profile() {
  install_chromium_policy
  apply_rbw_config
  apply_launcher
  apply_binding
  if ((BINDINGS_CHANGED)) && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null
    local errors
    errors="$(hyprctl configerrors 2>/dev/null || true)"
    [[ -z ${errors} ]] || die "Hyprland configuration errors after Bitwarden binding update: ${errors}"
  fi
  printf 'bitwarden-omarchy: applied native Wayland integration (backup: %s)\n' \
    "${BACKUP_ID:-none; no files needed changing}"
}

remove_chromium_policy() {
  [[ -e ${CHROMIUM_POLICY_FILE} ]] || return 0
  local policy_tmp
  policy_tmp="$(mktemp)"
  write_chromium_policy >"$policy_tmp"
  if cmp -s "$policy_tmp" "$CHROMIUM_POLICY_FILE"; then
    need sudo
    sudo rm -f -- "$CHROMIUM_POLICY_FILE"
    printf 'bitwarden-omarchy: removed its Chromium auto-install policy\n'
  else
    printf 'bitwarden-omarchy: kept a different Chromium policy untouched: %s\n' "$CHROMIUM_POLICY_FILE"
  fi
  rm -f -- "$policy_tmp"
}

select_latest_backup() {
  [[ -d ${BACKUP_ROOT} ]] || die "no Bitwarden backups found under ${BACKUP_ROOT}"
  BACKUP_ID="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n 1)"
  [[ -n ${BACKUP_ID} ]] || die 'no Bitwarden backups found'
}

restore_target() {
  local target=$1 name=$2
  if [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/${name} ]]; then
    mkdir -p "$(dirname -- "${target}")"
    cp -a -- "${BACKUP_ROOT}/${BACKUP_ID}/${name}" "${target}"
  elif [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent ]]; then
    rm -f -- "${target}"
  else
    die "incomplete Bitwarden backup: ${name}"
  fi
}

rollback_profile() {
  remove_chromium_policy
  if [[ -d ${BACKUP_ROOT} ]]; then
    select_latest_backup
    # Do not restore the whole shared Hyprland file: terminal and other
    # profile components may have added independent managed blocks since this
    # backup was created. Remove only Bitwarden-owned blocks.
    remove_managed_binding
    restore_target "${RBW_CONFIG}" rbw-config.json
    restore_target "${LAUNCHER}" launcher
    printf 'bitwarden-omarchy: restored backup %s\n' "${BACKUP_ID}"
  else
    printf 'bitwarden-omarchy: no user configuration backup found\n'
  fi
}

case ${ACTION} in
  check) check_repository ;;
  apply) check_repository; apply_profile ;;
  rollback) rollback_profile ;;
esac
