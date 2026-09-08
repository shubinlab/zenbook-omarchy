#!/usr/bin/env bash
set -u

pass=0
warn=0
fail=0

ok() { printf 'PASS  %s\n' "$1"; ((pass += 1)); }
warning() { printf 'WARN  %s\n' "$1"; ((warn += 1)); }
bad() { printf 'FAIL  %s\n' "$1"; ((fail += 1)); }

check_cmd() {
  local name=$1
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name: $(command -v "$name")"
  else
    bad "$name is not installed or not on PATH"
  fi
}

CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
LAUNCHER="${HOME}/.local/bin/omarchy-bitwarden"
BINDINGS="${CONFIG_HOME}/hypr/bindings.lua"
RBW_CONFIG="${CONFIG_HOME}/rbw/config.json"
ONBOARDING_STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/omarchy-profiles/bitwarden/onboarding-complete"

printf '%s\n' 'Bitwarden Omarchy doctor (read-only)'
printf '%s\n' '=================================='

for command_name in rbw rofi-rbw fuzzel wl-copy wtype pinentry-gnome3; do
  check_cmd "$command_name"
done

if [[ -x ${LAUNCHER} ]] &&
   grep -Fq -- '--selector fuzzel' "${LAUNCHER}" &&
   grep -Fq -- '--clipboarder wl-copy' "${LAUNCHER}" &&
   grep -Fq -- '--typer wtype' "${LAUNCHER}" &&
   grep -Fq -- '--clear-after 30' "${LAUNCHER}"; then
  ok 'launcher uses Fuzzel, wl-copy, wtype and 30-second clipboard clearing'
else
  bad 'native Bitwarden launcher is missing or incomplete'
fi

if [[ -r ${RBW_CONFIG} ]] && command -v jq >/dev/null 2>&1 &&
   jq -e '.pinentry == "/usr/bin/pinentry-gnome3" and .lock_timeout == 600 and .sync_interval == 3600' \
      "${RBW_CONFIG}" >/dev/null 2>&1; then
  ok 'rbw uses native pinentry, 10-minute lock timeout and hourly sync'
else
  bad 'rbw user configuration is missing or does not use the safe defaults'
fi

if [[ -r ${RBW_CONFIG} ]] && [[ $(stat -c '%a' "${RBW_CONFIG}" 2>/dev/null || true) == 600 ]]; then
  ok 'rbw configuration permissions are 0600'
else
  warning 'rbw configuration permissions are not 0600'
fi

managed_binding_count="$(grep -Fc -- 'o.bind("SUPER + SHIFT + SLASH", "Passwords", "omarchy-bitwarden")' "${BINDINGS}" 2>/dev/null || true)"
legacy_binding_count="$(grep -Fc -- 'o.bind("SUPER + SHIFT + SLASH", "Passwords", "rofi-rbw --selector fuzzel --clipboarder wl-copy --typer wtype")' "${BINDINGS}" 2>/dev/null || true)"
if [[ ${managed_binding_count} -eq 1 && ${legacy_binding_count} -eq 0 ]] &&
   grep -Fq -- 'zenbook-omarchy Bitwarden (managed)' "${BINDINGS}" 2>/dev/null; then
  ok 'Hyprland password hotkey is managed by the native launcher'
elif [[ ${legacy_binding_count} -gt 0 ]]; then
  bad 'older unmanaged Bitwarden binding is still present; run the Bitwarden stage again'
else
  bad 'Hyprland password hotkey is not configured'
fi

if [[ -r ${ONBOARDING_STATE} ]]; then
  ok 'guided Bitwarden onboarding was completed'
else
  warning 'guided onboarding is not marked complete; browser extension setup may remain'
fi

if [[ ${XDG_SESSION_TYPE:-} == wayland || -n ${WAYLAND_DISPLAY:-} ]]; then
  ok 'Wayland session detected'
else
  warning 'Wayland session not detected; run this check inside Omarchy'
fi

printf '\n%s\n' "Summary: $pass passed, $warn warnings, $fail failures"
(( fail == 0 ))
