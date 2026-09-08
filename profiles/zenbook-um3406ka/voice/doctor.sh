#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only health check for Omarchy's native Voxtype path.
failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

for command in voxtype pactl systemctl wtype; do
  command -v "${command}" >/dev/null 2>&1 && pass "command ${command}" || fail "command ${command} missing"
done

if command -v voxtype >/dev/null 2>&1; then
  type_delay="$(awk '
    BEGIN { in_output = 0 }
    /^\[output\][[:space:]]*$/ { in_output = 1; next }
    /^\[/ { in_output = 0 }
    in_output && /^[[:space:]]*type_delay_ms[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/[[:space:]]+#.*$/, "")
      print
      exit
    }
  ' "${XDG_CONFIG_HOME:-${HOME}/.config}/voxtype/config.toml")"
  [[ "$(voxtype config get audio.device 2>/dev/null || true)" == default ]] && pass 'Voxtype follows PipeWire default source' || fail 'Voxtype audio.device is not default'
  [[ "$(voxtype config get whisper.model 2>/dev/null || true)" == large-v3-turbo ]] && pass 'multilingual Whisper model' || fail 'large-v3-turbo is not selected'
  [[ "$(voxtype config get whisper.language 2>/dev/null || true)" == auto ]] && pass 'Whisper language auto' || fail 'Whisper language is not auto'
  [[ "$(voxtype config get whisper.translate 2>/dev/null || true)" == false ]] && pass 'translation disabled' || fail 'translation is enabled'
  [[ "$(voxtype config get output.mode 2>/dev/null || true)" == type ]] && pass 'native type output' || fail 'native type output is not enabled'
  [[ "${type_delay}" == 10 ]] && pass 'native typing delay tuned for this Zenbook' || fail "typing delay is ${type_delay:-unset}, expected 10 ms"
  [[ "$(voxtype config get output.pre_type_delay_ms 2>/dev/null || true)" == 300 ]] && pass 'native typing focus delay' || fail 'typing focus delay is not 300 ms'
  [[ "$(voxtype config get audio.feedback.enabled 2>/dev/null || true)" == true ]] && pass 'native start/stop audio feedback' || fail 'audio feedback is disabled'
  [[ "$(voxtype config get osd.enabled 2>/dev/null || true)" == true ]] && pass 'native OSD enabled' || fail 'OSD is disabled'
  [[ "$(voxtype config get vad.enabled 2>/dev/null || true)" != true ]] && pass 'optional VAD disabled/unset' || fail 'optional VAD is enabled'
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-active --quiet voxtype.service && pass 'voxtype.service active' || fail 'voxtype.service inactive'
fi

if command -v pactl >/dev/null 2>&1; then
  pactl info >/dev/null 2>&1 && pass 'PipeWire-Pulse reachable' || fail 'PipeWire-Pulse is unreachable'
  default_source="$(pactl get-default-source 2>/dev/null || true)"
  default_sink="$(pactl get-default-sink 2>/dev/null || true)"
  [[ "${default_source}" =~ ^alsa_input\..* && "${default_source}" != *.monitor ]] && pass "physical default source (${default_source})" || fail "default source is not physical (${default_source})"
  [[ "${default_sink}" != voxtype_echo_cancel_sink ]] && pass "default sink preserved (${default_sink})" || fail 'default sink is obsolete virtual sink'
  pactl list short sources | awk '$2 == "voxtype_noise_suppressed" {found=1} END {exit !found}' && fail 'obsolete filtered source present' || pass 'obsolete filtered source absent'
  pactl list short sinks | awk '$2 == "voxtype_echo_cancel_sink" {found=1} END {exit !found}' && fail 'obsolete echo-cancel sink present' || pass 'obsolete echo-cancel sink absent'
fi

for dropin in \
  "${XDG_CONFIG_HOME:-${HOME}/.config}/pipewire/pipewire-pulse.conf.d/90-omarchy-voice.conf" \
  "${XDG_CONFIG_HOME:-${HOME}/.config}/pipewire/pipewire-pulse.conf.d/90-zenbook-omarchy-voice.conf"; do
  if [[ ! -e "${dropin}" && ! -L "${dropin}" ]]; then
    pass "obsolete drop-in absent (${dropin##*/})"
  else
    fail "obsolete drop-in remains (${dropin##*/})"
  fi
done

binding="/usr/share/omarchy/default/hypr/bindings/voxtype.lua"
if [[ -r "${binding}" ]] && grep -F 'SUPER + CTRL + X' "${binding}" >/dev/null && grep -F 'F9' "${binding}" >/dev/null; then
  pass 'native Omarchy Voxtype bindings present'
else
  fail 'native Omarchy Voxtype bindings missing'
fi

printf 'result=%s\n' "$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)"
exit "${failures}"
