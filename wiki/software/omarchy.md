# Omarchy 4 runtime

## Installed release

The host reports:

```text
Omarchy: 4.0.3rc1-2
Build ID: 4.0.3rc1
Kernel: 7.2.3-arch1-3
Branch family: quattro
```

Omarchy supplies a stock configuration tree at `/usr/share/omarchy`, default
files under `/usr/share/omarchy/default`, commands under `/usr/bin`, package
manifests under `/usr/share/omarchy/install`, and user configuration under
`~/.config`.

## Default behavior retained

- Hyprland loads Omarchy defaults before user override files.
- `eDP-1` uses the preferred mode with high-density GDK scale 2.
- Foot is the default terminal; tmux is managed by Omarchy.
- Fcitx5 is the keyboard input framework.
- Voxtype is present with default `base.en`/English settings.
- PipeWire and WirePlumber are the stock audio session.
- `omarchy-pkg-add` is the package transaction helper.
- `omarchy update` owns full system updates and migrations.

## This host's changes

- external `DP-1` mode, 10-bit color, sRGB, VRR and scale 1.6;
- mirror toggle disabled after a reproducible mode-drift interaction;
- clock format and bar layout stored in `~/.config/omarchy/shell.json`;
- default agent set to `codex`;
- ChatGPT replaces the stock web-app shortcut at `Super+Shift+Alt+A`;
- Foot Sixel, ble.sh/fzf and image preview helpers;
- voice echo cancellation and multilingual Voxtype model;
- local monitor telemetry service;
- diagnostic packages listed in the profile.

The [configuration comparison](configuration.md) shows each changed user file.
