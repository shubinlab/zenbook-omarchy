# Audio, camera and input

## Audio

The machine exposes AMD ACP/SOF audio, a Realtek analog codec and Radeon HDMI
audio. PipeWire and WirePlumber remain the Omarchy-managed session. The native
voice profile follows the user-session physical default microphone and does
not install a global echo-cancel virtual source or change the default sink.
Legacy cleanup is deliberately outside the clean profile and is available only
through `scripts/repair-voice-legacy.sh`.

Voxtype uses native capture and output with `language = "auto"` and
`translate = false`; the active Whisper request is served locally by
Lemonade/FastFlowLM as `whisper-v3-turbo-FLM` on the AMD XDNA2 NPU. Native OSD
and start/stop audio feedback are enabled. Standalone Russian and English
fixture recognition passed; mixed-language recognition remains subject to the
model's single-pass language behavior and must not be treated as guaranteed.

## Camera

The camera is exposed through `uvcvideo`/V4L2. The profile does not store
recordings.

## Keyboard and input

The keyboard, touchpad and dock receivers use the stock Hyprland/libinput and
HID path. Fcitx5 remains the input framework. Voxtype uses native `type`
output through `wtype`, avoiding a clipboard-manager/image-paste path and
leaving Omarchy's universal copy/paste bindings unchanged.
