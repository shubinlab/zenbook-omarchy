# Audio, camera and input

## Audio

The machine exposes AMD ACP/SOF audio, a Realtek analog codec and Radeon HDMI
audio. PipeWire and WirePlumber remain the Omarchy-managed session. The native
voice profile follows the user-session physical default microphone and does
not install a global echo-cancel virtual source or change the default sink.

Voxtype uses multilingual Whisper `large-v3-turbo`, `language = "auto"` and
`translate = false`. Native OSD and start/stop audio feedback are enabled.
Standalone Russian and English fixture recognition passed in the earlier
audit; mixed-language recognition remains subject to Whisper's single-pass
language detection and must not be treated as guaranteed.

## Camera

The camera is exposed through `uvcvideo`/V4L2. The profile does not store
recordings.

## Keyboard and input

The keyboard, touchpad and dock receivers use the stock Hyprland/libinput and
HID path. Fcitx5 remains the input framework. Voxtype uses native `type`
output through `wtype`, avoiding a clipboard-manager/image-paste path and
leaving Omarchy's universal copy/paste bindings unchanged.
