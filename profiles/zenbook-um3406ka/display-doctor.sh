#!/usr/bin/env bash
set -euo pipefail

# Read-only check for the tested Zenbook display profile. A missing graphical
# session is a warning, not a failure, so the general doctor remains usable
# from a TTY or during recovery.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_file="${script_dir}/monitors.lua"
target_file="${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/monitors.lua"

fail() {
  printf 'FAIL display: %s\n' "$*"
  exit 1
}

if [[ ! -f "${target_file}" ]]; then
  fail "user monitor file is missing: ${target_file}"
fi
cmp -s "${source_file}" "${target_file}" ||
  fail 'user monitor file differs from the profile; re-apply the display stage'

if ! command -v hyprctl >/dev/null 2>&1; then
  printf 'WARN display: hyprctl is unavailable; live output was not checked\n'
  exit 0
fi

monitor_json="$(hyprctl monitors -j 2>/dev/null || true)"
if [[ -z "${monitor_json}" ]]; then
  printf 'WARN display: graphical Hyprland session is unavailable; live output was not checked\n'
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'WARN display: jq is unavailable; live output was not checked\n'
  exit 0
fi

if ! jq -e '
  any(.[];
    .name == "DP-1" and
    .width == 2560 and
    .height == 1440 and
    ((.refreshRate - 239.97) | fabs) < 0.05 and
    .scale == 1.6 and
    .currentFormat == "XRGB2101010" and
    .vrr == true and
    .colorManagementPreset == "srgb" and
    .dpmsStatus == true and
    .disabled == false and
    .mirrorOf == "none"
  )
' <<<"${monitor_json}" >/dev/null; then
  state="$(jq -r '[.[] | select(.name == "DP-1") | "mode=\(.width)x\(.height)@\(.refreshRate) scale=\(.scale) format=\(.currentFormat) vrr=\(.vrr) cm=\(.colorManagementPreset) dpms=\(.dpmsStatus) mirror=\(.mirrorOf)"] | .[0] // "DP-1 missing"' <<<"${monitor_json}")"
  fail "live DP-1 state is not the tested profile (${state})"
fi

connector_file="$(compgen -G '/sys/class/drm/*-DP-1/status' | head -n 1 || true)"
if [[ -n "${connector_file}" ]] && [[ "$(<"${connector_file}")" != connected ]]; then
  fail "DRM connector is $(<"${connector_file}")"
fi

printf 'OK display: profile file and live DP-1 state match\n'
