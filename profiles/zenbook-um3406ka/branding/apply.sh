#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
BRANDING_CONFIG="${CONFIG_HOME}/omarchy/branding"
BRANDING_DATA="${DATA_HOME}/zenbook-omarchy/branding"
HOOK_DIR="${CONFIG_HOME}/omarchy/hooks/post-update.d"
HOOK_TARGET="${HOOK_DIR}/zenbook-omarchy-branding"
BACKUP_DIR="${STATE_HOME}/omarchy-profiles/backups/branding/original"
PLYMOUTH_LOGO="/usr/share/plymouth/themes/omarchy/logo.png"
SDDM_LOGO="/usr/share/sddm/themes/omarchy/logo.png"

ACTION=check

die() { printf 'branding-omarchy: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: profiles/zenbook-um3406ka/branding/apply.sh [--check|--apply]

--check     validate repository assets only; no system changes
--apply     install user branding, system logos and the post-update hook
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --apply) ACTION=apply ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ ${EUID} -ne 0 ]] || die 'run as the normal Omarchy user, not root'

for asset in about.txt screensaver.txt shubin.svg boot-login.png post-update-hook; do
  [[ -r "${SCRIPT_DIR}/${asset}" ]] || die "missing branding asset: ${SCRIPT_DIR}/${asset}"
done

bash -n "${SCRIPT_DIR}/post-update-hook"

if [[ "$ACTION" == check ]]; then
  printf '%s\n' 'branding check: PASS (repository assets valid; no system changes made)'
  exit 0
fi

need_sudo() { command -v sudo >/dev/null 2>&1 || die 'sudo is required for Plymouth and SDDM logos'; }

backup_once() {
  local source=$1 name=$2
  [[ -e "$source" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  [[ -e "$BACKUP_DIR/$name" ]] || cp -a -- "$source" "$BACKUP_DIR/$name"
}

backup_if_changed() {
  local target=$1 source=$2 name=$3
  [[ -e "$target" ]] || return 0
  cmp -s "$source" "$target" || backup_once "$target" "$name"
}

install_user_if_changed() {
  local source=$1 target=$2 mode=$3
  if [[ ! -e "$target" ]] || ! cmp -s "$source" "$target"; then
    mkdir -p "$(dirname -- "$target")"
    install -m "$mode" "$source" "$target"
  fi
}

install_system_if_changed() {
  local source=$1 target=$2
  if [[ ! -e "$target" ]] || ! cmp -s "$source" "$target"; then
    sudo install -m 0644 "$source" "$target"
  fi
}

need_sudo
backup_if_changed "${BRANDING_CONFIG}/screensaver.txt" "${SCRIPT_DIR}/screensaver.txt" screensaver.txt
backup_if_changed "${BRANDING_CONFIG}/about.txt" "${SCRIPT_DIR}/about.txt" about.txt
backup_if_changed "$PLYMOUTH_LOGO" "${SCRIPT_DIR}/boot-login.png" plymouth-logo.png
backup_if_changed "$SDDM_LOGO" "${SCRIPT_DIR}/boot-login.png" sddm-logo.png

install_user_if_changed "${SCRIPT_DIR}/screensaver.txt" "${BRANDING_CONFIG}/screensaver.txt" 0644
install_user_if_changed "${SCRIPT_DIR}/about.txt" "${BRANDING_CONFIG}/about.txt" 0644
install_user_if_changed "${SCRIPT_DIR}/shubin.svg" "${BRANDING_CONFIG}/screensaver.svg" 0644
install_user_if_changed "${SCRIPT_DIR}/screensaver.txt" "${BRANDING_DATA}/screensaver.txt" 0644
install_user_if_changed "${SCRIPT_DIR}/about.txt" "${BRANDING_DATA}/about.txt" 0644
install_user_if_changed "${SCRIPT_DIR}/boot-login.png" "${BRANDING_DATA}/boot-login.png" 0644
install_user_if_changed "${SCRIPT_DIR}/shubin.svg" "${BRANDING_DATA}/shubin.svg" 0644
install_user_if_changed "${SCRIPT_DIR}/post-update-hook" "$HOOK_TARGET" 0755
install_system_if_changed "${SCRIPT_DIR}/boot-login.png" "$PLYMOUTH_LOGO"
install_system_if_changed "${SCRIPT_DIR}/boot-login.png" "$SDDM_LOGO"

cmp -s "${SCRIPT_DIR}/screensaver.txt" "${BRANDING_CONFIG}/screensaver.txt"
cmp -s "${SCRIPT_DIR}/about.txt" "${BRANDING_CONFIG}/about.txt"
cmp -s "${SCRIPT_DIR}/boot-login.png" "$PLYMOUTH_LOGO"
cmp -s "${SCRIPT_DIR}/boot-login.png" "$SDDM_LOGO"

printf 'branding-omarchy: applied SHUBIN assets and post-update hook\n'
