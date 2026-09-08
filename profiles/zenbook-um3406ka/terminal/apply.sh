#!/usr/bin/env bash
set -Eeuo pipefail

# Native, user-scoped terminal integration for Omarchy.
# Never edits /usr/share/omarchy and never replaces a complete user config.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd -P)"
DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
BACKUP_ROOT="${STATE_HOME}/omarchy-profiles/backups/terminal"
BLE_DIR="${DATA_HOME}/blesh"
BLE_URL="https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly-20260907%2B690b315.tar.xz"
BLE_SHA256="b376301fd63d60e1659ba74dbc3ec91bd4084d8e09b33d5740ae38c5026fe402"

ACTION=check
BACKUP_ID=""
BINDINGS_CHANGED=0

die() { printf 'terminal-omarchy: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

usage() {
  cat <<'EOF'
Usage: profiles/zenbook-um3406ka/terminal/apply.sh [--check|--apply|--rollback]

--check     validate repository assets only; no system changes
--apply     install chafa if needed and apply user-scoped terminal settings
--rollback  restore the latest terminal backup
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

for asset in \
  "${SCRIPT_DIR}/bashrc" \
  "${SCRIPT_DIR}/blerc" \
  "${SCRIPT_DIR}/omarchy-fzf-preview" \
  "${SCRIPT_DIR}/terminal-doctor"; do
  [[ -r ${asset} ]] || die "missing terminal asset: ${asset}"
done

check_repository() {
  bash -n "${SCRIPT_DIR}/terminal-doctor"
  bash -n "${SCRIPT_DIR}/omarchy-fzf-preview"
  [[ ${BLE_URL} == https://github.com/akinomyoga/ble.sh/releases/download/nightly/* ]] ||
    die 'ble.sh source is not pinned to the official GitHub release path'
  [[ ${BLE_SHA256} =~ ^[0-9a-f]{64}$ ]] || die 'ble.sh SHA-256 is invalid'
  printf 'terminal check: PASS (repository assets valid; no system changes made)\n'
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
  mkdir -p "${BACKUP_ROOT}/${BACKUP_ID}"
  backup_target "${HOME}/.bashrc" bashrc
  backup_target "${HOME}/.blerc" blerc
  backup_target "${CONFIG_HOME}/foot/foot.ini" foot.ini
  backup_target "${CONFIG_HOME}/hypr/bindings.lua" bindings.lua
  backup_target "${HOME}/.local/bin/omarchy-fzf-preview" fzf-preview
  backup_target "${HOME}/.local/bin/terminal-doctor" terminal-doctor
}

append_block() {
  local target=$1 block=$2 marker=$3
  grep -Fq -- "${marker}" "${target}" 2>/dev/null && return 0
  mkdir -p "$(dirname -- "${target}")"
  printf '\n%s\n' "${block}" >>"${target}"
}

install_if_changed() {
  local source=$1 target=$2 mode=$3
  if [[ -e ${target} ]] && cmp -s "${source}" "${target}"; then
    return 0
  fi
  backup_once
  mkdir -p "$(dirname -- "${target}")"
  install -m "${mode}" "${source}" "${target}"
}

install_ble() {
  if [[ -r ${BLE_DIR}/ble.sh ]]; then
    printf 'terminal-omarchy: keeping existing ble.sh at %s\n' "${BLE_DIR}"
    return 0
  fi
  backup_once
  : >"${BACKUP_ROOT}/${BACKUP_ID}/blesh.absent"
  need curl
  need sha256sum
  need tar
  local temporary archive extracted
  temporary="$(mktemp -d)"
  archive="${temporary}/ble-nightly.tar.xz"
  curl --fail --location --proto '=https' --tlsv1.2 "${BLE_URL}" -o "${archive}"
  printf '%s  %s\n' "${BLE_SHA256}" "${archive}" | sha256sum -c -
  tar -xJf "${archive}" -C "${temporary}"
  extracted="$(find "${temporary}" -mindepth 2 -maxdepth 2 -type f -name ble.sh -printf '%h\n' | head -n 1)"
  [[ -n ${extracted} ]] || die 'ble.sh archive did not contain ble.sh'
  mkdir -p "${DATA_HOME}"
  bash "${extracted}/ble.sh" --install "${DATA_HOME}"
  rm -rf -- "${temporary}"
  [[ -r ${BLE_DIR}/ble.sh ]] || die 'ble.sh installation did not create ~/.local/share/blesh'
  printf 'terminal-omarchy: installed pinned ble.sh under %s\n' "${BLE_DIR}"
}

apply_bashrc() {
  local target=${HOME}/.bashrc
  local block='## >>> zenbook-omarchy terminal (managed) >>>
if [[ $- == *i* && -r "$HOME/.local/share/zenbook-omarchy/bashrc" ]]; then
  source -- "$HOME/.local/share/zenbook-omarchy/bashrc"
fi
## <<< zenbook-omarchy terminal (managed) <<<'
  if grep -q 'zenbook-omarchy terminal (managed)' "${target}" 2>/dev/null; then
    return 0
  fi
  backup_once
  if grep -q '^# Optional interactive enhancements\.' "${target}" 2>/dev/null; then
    local temporary
    temporary="$(mktemp "${target}.tmp.XXXXXX")"
    awk '
      /^# Optional interactive enhancements\./ { skip=1; next }
      /^# Add your own exports/ { skip=0 }
      !skip { print }
    ' "${target}" >"${temporary}"
    mv -f -- "${temporary}" "${target}"
  fi
  append_block "${target}" "${block}" 'zenbook-omarchy terminal (managed)'
}

apply_blerc() {
  local target=${HOME}/.blerc
  local block='## >>> zenbook-omarchy fzf (managed) >>>
_ble_contrib_fzf_base=/usr/share/fzf
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings
## <<< zenbook-omarchy fzf (managed) <<<'
  if grep -q 'zenbook-omarchy fzf (managed)' "${target}" 2>/dev/null; then
    return 0
  fi
  backup_once
  if grep -q '^# ble\.sh settings for the Omarchy Bash environment\.' "${target}" 2>/dev/null; then
    local temporary
    temporary="$(mktemp "${target}.tmp.XXXXXX")"
    awk '
      /^_ble_contrib_fzf_base=/ { next }
      /^ble-import -d integration\/fzf-/ { next }
      { print }
    ' "${target}" >"${temporary}"
    mv -f -- "${temporary}" "${target}"
  fi
  append_block "${target}" "${block}" 'zenbook-omarchy fzf (managed)'
}

apply_foot() {
  local target=${CONFIG_HOME}/foot/foot.ini
  mkdir -p "$(dirname -- "${target}")"
  if grep -Eq '^[[:space:]]*sixel[[:space:]]*=[[:space:]]*no[[:space:]]*$' "${target}" 2>/dev/null; then
    die "Foot explicitly disables Sixel: ${target}; refusing to override it"
  fi
  if ! grep -Eq '^[[:space:]]*sixel[[:space:]]*=[[:space:]]*yes[[:space:]]*$' "${target}" 2>/dev/null; then
    backup_once
    printf '\n[tweak]\nsixel=yes\n' >>"${target}"
  fi
}

apply_bindings() {
  local target=${CONFIG_HOME}/hypr/bindings.lua
  local block='-- >>> zenbook-omarchy ChatGPT shortcut (managed) >>>
hl.unbind("SUPER + SHIFT + ALT + A")
o.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
-- <<< zenbook-omarchy ChatGPT shortcut (managed) <<<'
  mkdir -p "$(dirname -- "${target}")"
  if grep -Fqx -- '  -- <<< zenbook-omarchy ChatGPT shortcut (managed) <<<' "${target}" 2>/dev/null; then
    backup_once
    local marker_temporary
    marker_temporary="$(mktemp "${target}.tmp.XXXXXX")"
    awk '{ if ($0 == "  -- <<< zenbook-omarchy ChatGPT shortcut (managed) <<<") print "-- <<< zenbook-omarchy ChatGPT shortcut (managed) <<<"; else print }' \
      "${target}" >"${marker_temporary}"
    install -m0644 "${marker_temporary}" "${target}"
    rm -f -- "${marker_temporary}"
    BINDINGS_CHANGED=1
  fi
  if grep -Fqx -- '-- Use ChatGPT instead of the preinstalled Grok web app shortcut.' "${target}" 2>/dev/null &&
     grep -Fqx -- 'hl.unbind("SUPER + SHIFT + ALT + A")' "${target}" &&
     grep -Fqx -- 'o.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https://chatgpt.com" })' "${target}"; then
    backup_once
    local legacy_temporary
    legacy_temporary="$(mktemp "${target}.tmp.XXXXXX")"
    sed '/^-- Use ChatGPT instead of the preinstalled Grok web app shortcut\.$/,/^o\.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https:\/\/chatgpt\.com" })$/d' \
      "${target}" >"${legacy_temporary}"
    install -m0644 "${legacy_temporary}" "${target}"
    rm -f -- "${legacy_temporary}"
    BINDINGS_CHANGED=1
  fi
  if ! grep -Fq -- 'zenbook-omarchy ChatGPT shortcut (managed)' "${target}" 2>/dev/null; then
    backup_once
    append_block "${target}" "${block}" 'zenbook-omarchy ChatGPT shortcut (managed)'
    BINDINGS_CHANGED=1
  fi
}

apply_profile() {
  need omarchy-pkg-add
  if ! command -v chafa >/dev/null 2>&1; then
    omarchy-pkg-add chafa
  fi
  install_ble
  mkdir -p "${DATA_HOME}/zenbook-omarchy" "${HOME}/.local/bin"
  install_if_changed "${SCRIPT_DIR}/bashrc" "${DATA_HOME}/zenbook-omarchy/bashrc" 0644
  install_if_changed "${SCRIPT_DIR}/blerc" "${DATA_HOME}/zenbook-omarchy/blerc" 0644
  install_if_changed "${SCRIPT_DIR}/omarchy-fzf-preview" "${HOME}/.local/bin/omarchy-fzf-preview" 0755
  install_if_changed "${SCRIPT_DIR}/terminal-doctor" "${HOME}/.local/bin/terminal-doctor" 0755
  apply_bashrc
  apply_blerc
  apply_foot
  apply_bindings
  if ((BINDINGS_CHANGED)) && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null
    local errors
    errors="$(hyprctl configerrors 2>/dev/null || true)"
    [[ -z ${errors} ]] || die "Hyprland configuration errors after terminal binding update: ${errors}"
  fi
  printf 'terminal-omarchy: applied user-scoped terminal profile\n'
}

select_latest_backup() {
  [[ -d ${BACKUP_ROOT} ]] || die "no terminal backups found under ${BACKUP_ROOT}"
  BACKUP_ID="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n 1)"
  [[ -n ${BACKUP_ID} ]] || die 'no terminal backups found'
}

restore_target() {
  local target=$1 name=$2
  if [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/${name} ]]; then
    mkdir -p "$(dirname -- "${target}")"
    cp -a -- "${BACKUP_ROOT}/${BACKUP_ID}/${name}" "${target}"
  elif [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent ]]; then
    rm -f -- "${target}"
  else
    die "incomplete terminal backup: ${name}"
  fi
}

rollback_profile() {
  select_latest_backup
  restore_target "${HOME}/.bashrc" bashrc
  restore_target "${HOME}/.blerc" blerc
  restore_target "${CONFIG_HOME}/foot/foot.ini" foot.ini
  # bindings.lua is shared with Bitwarden and other profile components.
  # Restore only this component's managed block instead of replacing the file.
  local target="${CONFIG_HOME}/hypr/bindings.lua" temporary
  if [[ -r ${target} ]]; then
    temporary="$(mktemp "${target}.tmp.XXXXXX")"
    sed '/^-- >>> zenbook-omarchy ChatGPT shortcut (managed) >>>$/,/^-- <<< zenbook-omarchy ChatGPT shortcut (managed) <<<$/{d;}' \
      "${target}" >"${temporary}"
    install -m0644 "${temporary}" "${target}"
    rm -f -- "${temporary}"
    if grep -Fqx -- '-- Use ChatGPT instead of the preinstalled Grok web app shortcut.' "${target}" 2>/dev/null &&
       grep -Fqx -- 'hl.unbind("SUPER + SHIFT + ALT + A")' "${target}" &&
       grep -Fqx -- 'o.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https://chatgpt.com" })' "${target}"; then
      temporary="$(mktemp "${target}.tmp.XXXXXX")"
      sed '/^-- Use ChatGPT instead of the preinstalled Grok web app shortcut\.$/,/^o\.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https:\/\/chatgpt\.com" })$/d' \
        "${target}" >"${temporary}"
      install -m0644 "${temporary}" "${target}"
      rm -f -- "${temporary}"
    fi
  fi
  restore_target "${HOME}/.local/bin/omarchy-fzf-preview" fzf-preview
  restore_target "${HOME}/.local/bin/terminal-doctor" terminal-doctor
  if [[ -e ${BACKUP_ROOT}/${BACKUP_ID}/blesh.absent ]]; then
    rm -rf -- "${BLE_DIR}"
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null
  fi
  printf 'terminal-omarchy: restored backup %s\n' "${BACKUP_ID}"
}

case ${ACTION} in
  check) check_repository ;;
  apply) check_repository; apply_profile ;;
  rollback) rollback_profile ;;
esac
