#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
INPUT_TARGET="${CONFIG_HOME}/hypr/input.lua"
BINDINGS_TARGET="${CONFIG_HOME}/hypr/bindings.lua"
KEYMAP_TARGET="${CONFIG_HOME}/xkb/voxtype-keymap.xkb"
FCITX_TARGET="${CONFIG_HOME}/fcitx5/profile"
FAILURES=0

ok() { printf 'OK input: %s\n' "$*"; }
fail() { printf 'FAIL input: %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
warn() { printf 'WARN input: %s\n' "$*"; }

[[ -f "$INPUT_TARGET" ]] && ok 'input.lua exists' || fail "missing $INPUT_TARGET"
[[ -f "$KEYMAP_TARGET" ]] && ok 'generated keymap exists' || fail "missing $KEYMAP_TARGET"
[[ -f "$FCITX_TARGET" ]] && ok 'Fcitx profile exists' || fail "missing $FCITX_TARGET"
[[ -f "$BINDINGS_TARGET" ]] && ok 'bindings file exists' || fail "missing $BINDINGS_TARGET"

if [[ -f "$INPUT_TARGET" ]]; then
  grep -Fq 'kb_layout = "us,ru"' "$INPUT_TARGET" && ok 'Hyprland layout is us,ru' || fail 'Hyprland layout is not us,ru'
  grep -Fq 'follow_mouse = 0' "$INPUT_TARGET" && ok 'click-to-focus is configured' || fail 'focus still follows mouse'
  grep -Fq 'grp:alt_shift_toggle_bidir' "$INPUT_TARGET" && ok 'bidirectional XKB Alt+Shift is configured' || fail 'bidirectional XKB Alt+Shift is missing'
  grep -Fq 'kb_file' "$INPUT_TARGET" && ok 'custom Voxtype keymap is configured' || fail 'custom Voxtype keymap is not configured'
  if grep -vE '^[[:space:]]*--' "$INPUT_TARGET" | grep -Eq 'grp:(alts_toggle|alt_space_toggle)'; then fail 'legacy Alt group-switching option is enabled'; else ok 'legacy Alt group-switching options are disabled'; fi
fi
if [[ -f "$FCITX_TARGET" ]]; then
  if grep -Eq '^Name=keyboard-(us|ru)$' "$FCITX_TARGET"; then
    fail 'Fcitx profile still declares a keyboard layout'
  else
    ok 'Fcitx profile has no declared keyboard layouts'
  fi
fi
if [[ -f "$BINDINGS_TARGET" ]]; then
  if grep -Fq 'toggle-fcitx-layout' "$BINDINGS_TARGET"; then fail 'obsolete Fcitx language binding remains'; else ok 'Fcitx is not used as language-switch owner'; fi
  grep -Fq 'zenbook-omarchy universal clipboard layout fix (managed)' "$BINDINGS_TARGET" && ok 'universal Super+C/V/X clipboard bindings exist' || fail 'universal clipboard bindings are missing'
  grep -Fq 'zenbook-omarchy Google settings shortcut (managed)' "$BINDINGS_TARGET" && ok 'Google settings shortcut exists' || fail 'Google settings shortcut is missing'
  grep -Fq 'o.bind("F13"' "$BINDINGS_TARGET" && ok 'Right Ctrl/F13 Voxtype binding exists' || fail 'F13 Voxtype binding is missing'
fi
if command -v xkbcli >/dev/null 2>&1 && [[ -f "$KEYMAP_TARGET" ]]; then
  xkbcli compile-keymap --from-xkb "$KEYMAP_TARGET" >/dev/null && ok 'generated keymap compiles' || fail 'generated keymap does not compile'
else
  warn 'xkbcli unavailable; keymap compilation skipped'
fi
if command -v fcitx5-remote >/dev/null 2>&1; then
  method="$(fcitx5-remote -n 2>/dev/null || true)"
  [[ -z "$method" || "$method" == keyboard-us ]] && ok "Fcitx runtime fallback: ${method:-none}" || warn "Fcitx runtime method: ${method:-none}"
else
  warn 'fcitx5-remote unavailable; live Fcitx check skipped'
fi
if command -v hyprctl >/dev/null 2>&1; then
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  [[ -z "$errors" ]] && ok 'Hyprland has no config errors' || { fail 'Hyprland config errors present'; printf '%s\n' "$errors"; }
else
  warn 'hyprctl unavailable; live compositor check skipped'
fi
printf 'input: manual verification still required: type in a Wayland app after both key orders\n'
((FAILURES == 0))
