#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
BACKUP_ROOT="${STATE_HOME}/omarchy-profiles/backups/input"
BACKUP_ID=""
ACTION=check

usage() {
  cat <<'EOF'
Usage: profiles/<id>/input/apply.sh [--check|--apply|--rollback]

Installs the user-scoped Zenbook keyboard policy: global us <-> ru XKB
switching with bidirectional Alt + Shift and the separate Right Ctrl
-> F13 Voxtype workaround. The default is a read-only check.
EOF
}

while (($#)); do
  case "$1" in
    --check) ACTION=check ;;
    --apply) ACTION=apply ;;
    --rollback) ACTION=rollback ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'input: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

INPUT_TARGET="${CONFIG_HOME}/hypr/input.lua"
BINDINGS_TARGET="${CONFIG_HOME}/hypr/bindings.lua"
KEYMAP_TARGET="${CONFIG_HOME}/xkb/voxtype-keymap.xkb"
FCITX_TARGET="${CONFIG_HOME}/fcitx5/profile"
TOGGLE_TARGET="${HOME}/.local/bin/toggle-fcitx-layout"

fail() { printf 'FAIL input: %s\n' "$*"; exit 1; }
warn() { printf 'WARN input: %s\n' "$*"; }
backup_target() {
  local source="$1" name="$2"
  if [[ -e "$source" || -L "$source" ]]; then
    cp -a -- "$source" "${BACKUP_ROOT}/${BACKUP_ID}/${name}"
  else
    : >"${BACKUP_ROOT}/${BACKUP_ID}/${name}.absent"
  fi
}

check_files() {
  [[ -f "$INPUT_TARGET" ]] || fail "missing $INPUT_TARGET"
  [[ -x "$TOGGLE_TARGET" ]] && warn 'obsolete Fcitx toggle script remains; it is not used' || true
  grep -Fq 'kb_layout = "us,ru"' "$INPUT_TARGET" || fail 'input.lua does not declare us,ru'
  grep -Fq 'follow_mouse = 0' "$INPUT_TARGET" || fail 'click-to-focus is not configured'
  grep -Fq 'grp:alt_shift_toggle_bidir' "$INPUT_TARGET" || fail 'bidirectional XKB Alt+Shift option is missing'
  grep -Fq 'kb_file' "$INPUT_TARGET" || fail 'input.lua does not declare the Voxtype keymap'
  grep -Fq 'zenbook-omarchy universal clipboard layout fix (managed)' "$BINDINGS_TARGET" || fail 'managed universal clipboard bindings are missing'
  grep -Fq 'zenbook-omarchy Google settings shortcut (managed)' "$BINDINGS_TARGET" || fail 'managed Google settings shortcut is missing'
  grep -Fq 'zenbook-omarchy input (managed)' "$BINDINGS_TARGET" || fail 'managed input bindings are missing'
  if grep -vE '^[[:space:]]*--' "$INPUT_TARGET" | grep -Eq 'grp:(alts_toggle|alt_space_toggle)'; then
    fail 'Alt-based XKB switching remains enabled'
  fi
  if grep -Fq 'toggle-fcitx-layout' "$BINDINGS_TARGET"; then
    fail 'obsolete Fcitx language binding remains'
  fi
  if grep -Eq '^Name=keyboard-(us|ru)$' "$FCITX_TARGET"; then
    fail 'Fcitx profile still declares a keyboard layout'
  fi
  if command -v xkbcli >/dev/null 2>&1; then
    xkbcli compile-keymap --from-xkb "$KEYMAP_TARGET" >/dev/null || fail 'generated XKB keymap does not compile'
  else
    warn 'xkbcli is unavailable; generated keymap was not compiled'
  fi
  printf 'OK input: user files and managed policy are present\n'
}

rollback() {
  local latest
  latest="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n 1)"
  [[ -n "$latest" ]] || fail "no input backup exists under $BACKUP_ROOT"
  local dir="$BACKUP_ROOT/$latest"
  for pair in \
    "$INPUT_TARGET input.lua" \
    "$BINDINGS_TARGET bindings.lua" \
    "$KEYMAP_TARGET voxtype-keymap.xkb" \
    "$FCITX_TARGET fcitx5-profile" \
    "$TOGGLE_TARGET toggle-fcitx-layout"; do
    set -- $pair
    if [[ -f "$dir/$2.absent" ]]; then
      rm -f -- "$1"
    elif [[ -e "$dir/$2" ]]; then
      mkdir -p "$(dirname -- "$1")"
      cp -a -- "$dir/$2" "$1"
    fi
  done
  printf 'input: restored backup %s\n' "$latest"
  if command -v hyprctl >/dev/null 2>&1; then hyprctl reload >/dev/null || true; fi
}

if [[ "$ACTION" == rollback ]]; then
  rollback
  exit 0
fi

if [[ "$ACTION" == check ]]; then
  check_files
  exit 0
fi

command -v xkbcli >/dev/null 2>&1 || fail 'xkbcli is required to generate the user keymap'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
mkdir -p "$BACKUP_ROOT" "$(dirname -- "$INPUT_TARGET")" "$(dirname -- "$KEYMAP_TARGET")" "$(dirname -- "$FCITX_TARGET")" "$HOME/.local/bin"
BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)-$BASHPID"
mkdir -p -m 0700 "$BACKUP_ROOT/$BACKUP_ID"
backup_target "$INPUT_TARGET" input.lua
backup_target "$BINDINGS_TARGET" bindings.lua
backup_target "$KEYMAP_TARGET" voxtype-keymap.xkb
backup_target "$FCITX_TARGET" fcitx5-profile
backup_target "$TOGGLE_TARGET" toggle-fcitx-layout

install -m 0644 "$SCRIPT_DIR/input.lua" "$INPUT_TARGET"
install -m 0644 "$SCRIPT_DIR/fcitx5-profile" "$FCITX_TARGET"
rm -f -- "$TOGGLE_TARGET"
python3 "$SCRIPT_DIR/merge-bindings.py" "$BINDINGS_TARGET" "$SCRIPT_DIR/bindings-block.lua"

raw="$(mktemp "$KEYMAP_TARGET.raw.XXXXXX")"
final="$(mktemp "$KEYMAP_TARGET.tmp.XXXXXX")"
trap 'rm -f "$raw" "$final"' EXIT
xkbcli compile-keymap --layout us,ru --variant ',' \
  --options 'compose:caps,grp:alt_shift_toggle_bidir' >"$raw"
python3 "$SCRIPT_DIR/build-keymap.py" <"$raw" >"$final"
install -m 0644 "$final" "$KEYMAP_TARGET"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null
  # Refresh Fcitx's virtual keyboard so it adopts the compositor's current
  # two-group XKB map. Fcitx is not used as the language-switch owner.
  command -v fcitx5-remote >/dev/null 2>&1 && fcitx5-remote -r >/dev/null || true
  hyprctl switchxkblayout all 0 >/dev/null
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  [[ -z "$errors" ]] || { printf '%s\n' "$errors" >&2; fail 'Hyprland reload reported configuration errors'; }
fi
check_files
printf 'input: applied (backup: %s)\n' "$BACKUP_ROOT/$BACKUP_ID"
