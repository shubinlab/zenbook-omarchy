# Audio, camera and input

## Audio

The machine exposes AMD ACP/SOF audio, a Realtek analog codec and Radeon HDMI
audio. PipeWire `1:1.6.8-1` and WirePlumber `0.5.17-1` manage the session.
The profile's voice extension loads a user PipeWire echo-cancel module with
WebRTC noise suppression, high-pass filtering, transient suppression and voice
detection. Voxtype selects the user-session default source; the physical sink
and Omarchy stock files remain outside the profile write set.

The tested Voxtype policy is multilingual Whisper `large-v3-turbo`,
`language = "auto"`, VAD enabled and `translate = false`. Standalone Russian
and English fixtures passed; a mixed-language recording still auto-selected
Russian for the whole phrase. That is a documented limitation.

## Camera

The camera is exposed through `uvcvideo`/V4L2. A 30-frame capture at about
24.32 fps passed in the component audit. The profile does not store recordings.

## Keyboard and input

The keyboard, touchpad and dock receivers use the stock Hyprland/libinput and
HID path. Fcitx5 currently has `keyboard-us` as its active profile. The voice
tests use paste/type output rather than changing the keyboard layout, which
avoids Cyrillic/Latin layout corruption in mixed text.

The terminal extension adds ble.sh/fzf integration, Foot Sixel and a ChatGPT
web-app binding while retaining Omarchy's default bindings and tmux setup.
