# Omarchy 4 runtime

## Installed release

The host currently reports Omarchy `4.0.3-1` with the `quattro` settings
package. Omarchy supplies stock files under `/usr/share/omarchy`, commands
under `/usr/bin`, package manifests under `/usr/share/omarchy/install`, and
user configuration under `~/.config`.

## Default behavior retained

- Hyprland loads Omarchy defaults before user override files.
- Foot is the default terminal and tmux remains managed by Omarchy.
- Fcitx5 is the keyboard input framework.
- The Zenbook input extension owns the user-level `us,ru` XKB policy and uses
  the native bidirectional Alt+Shift group option. Fcitx5 keeps an empty
  declared keyboard-layout list and is not a second language-switch owner.
- Omarchy's Voxtype installer owns packages, model download, user service and
  native Hyprland bindings.
- Voxtype's native OSD and output path remain in use.
- This host's separate package-owned Lemonade service supplies the local FLM
  Whisper inference on the AMD XDNA2 NPU; it does not replace Voxtype capture,
  feedback, typing or bindings. Its optional LAN broadcast discovery is
  disabled because this profile uses only the loopback client.
- PipeWire and WirePlumber remain the stock audio session.
- `omarchy-pkg-add` is the package transaction helper.
- `omarchy update` owns full system updates and migrations.

## This host's changes

- external `DP-1` mode, 10-bit color, sRGB, VRR and scale 1.6;
- mirror toggle disabled after a reproducible mode-drift interaction;
- clock format and bar layout stored in `~/.config/omarchy/shell.json`;
- default agent set to `codex`;
- `us,ru` keyboard policy with bidirectional Alt+Shift, a generated Right Ctrl
  -> F13 keymap and a read-only input doctor;
- the stock Omarchy web-app shortcuts remain unchanged;
- Foot Sixel, ble.sh/fzf and image preview helpers;
- native Voxtype frontend with `language=auto`, using local Lemonade FLM NPU
  inference (`whisper-v3-turbo-FLM`);
- optional diagnostic packages listed in the profile.

The [configuration comparison](configuration.md) shows each changed user file.
