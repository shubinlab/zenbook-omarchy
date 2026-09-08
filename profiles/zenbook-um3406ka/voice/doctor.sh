#!/usr/bin/env bash
set -Eeuo pipefail

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

for command in voxtype pactl systemctl; do
  command -v "${command}" >/dev/null 2>&1 && pass "command ${command}" || fail "command ${command} missing"
done

if command -v voxtype >/dev/null 2>&1; then
  [[ "$(voxtype config get audio.device 2>/dev/null || true)" == default ]] && pass 'Voxtype uses PipeWire default host' || fail 'Voxtype host is not default'
  [[ "$(voxtype config get whisper.language 2>/dev/null || true)" == auto ]] && pass 'Whisper language auto' || fail 'Whisper language is not auto'
  [[ "$(voxtype config get output.mode 2>/dev/null || true)" == paste ]] && pass 'paste output' || fail 'paste output is not paste'
  [[ "$(voxtype config get vad.enabled 2>/dev/null || true)" == true ]] && pass 'Voxtype VAD enabled' || fail 'Voxtype VAD disabled'
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-active --quiet voxtype.service && pass 'voxtype.service active' || fail 'voxtype.service inactive'
fi

if command -v pactl >/dev/null 2>&1; then
  pactl info >/dev/null 2>&1 && pass 'PipeWire-Pulse reachable' || fail 'PipeWire-Pulse is unreachable'
  pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}' && pass 'filtered source present' || fail 'filtered source absent'
  pactl list short sinks | awk '$2 == "voxtype_echo_cancel_sink" {found=1} END {exit !found}' && pass 'echo-cancel sink present' || fail 'echo-cancel sink absent'
  default_source="$(pactl get-default-source)"
  default_sink="$(pactl get-default-sink)"
  [[ "${default_source}" == voxtype_noise_suppressed ]] && pass 'global default source is filtered' || fail "global default source is not filtered (${default_source})"
  [[ "${default_sink}" != voxtype_echo_cancel_sink ]] && pass "global default sink preserved (${default_sink})" || fail 'global default sink was changed to the virtual sink'
fi

binding="/usr/share/omarchy/default/hypr/bindings/voxtype.lua"
if [[ -r "${binding}" ]] && grep -F 'SUPER + CTRL + X' "${binding}" >/dev/null && grep -F 'F9' "${binding}" >/dev/null; then
  pass 'native Omarchy Voxtype bindings present'
else
  fail 'native Omarchy Voxtype bindings missing'
fi

printf 'result=%s\n' "$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)"
exit "${failures}"
