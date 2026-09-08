# Native Omarchy voice profile

Last verified: 2026-09-08

## Decision

The Ubuntu/GNOME/Lemonade/NPU installer from `zenbook-voice` is not used on
this Arch/Omarchy/Hyprland host. Omarchy's own `omarchy-voxtype-install`
remains authoritative for package installation, model download, the user
service and Hyprland bindings. This profile adds only the host's useful
multilingual policy:

```text
physical PipeWire default microphone
  -> native Voxtype audio capture
  -> Whisper large-v3-turbo, language=auto
  -> native wtype keyboard typing into the focused field
```

Native Voxtype OSD remains enabled, and start/stop audio feedback is enabled.
The profile does not switch to clipboard paste, install a second typing tool,
change the default sink, or add a global echo-cancel filter. Optional VAD and
the former virtual microphone are intentionally not part of the baseline;
their model file may remain as harmless local rollback/storage data.

The packaged Omarchy bindings remain the source of truth: `Super+Ctrl+X`
toggles dictation and `F9` is push-to-talk. No file under `/usr/share/omarchy`
is modified.

## Quality and safety gates

- `language = "auto"` is the supported single-recording setting for a phrase
  containing Russian and English; Whisper may still choose one language for an
  ambiguous mixed recording.
- `large-v3-turbo` is multilingual and uses the installed Vulkan backend on
  this host.
- Native `type` output uses `wtype` under Hyprland and leaves the normal
  clipboard path untouched.
- `output.pre_type_delay_ms = 300` gives the focused Wayland field time to
  attach before the first keystroke; `type_delay_ms` remains at Omarchy's
  native value.
- The profile is user-scoped and creates a timestamped backup before changing
  Voxtype or audio defaults. No raw audio, credentials or model weights are
  stored in Git.

## Apply and verify

On a fresh Omarchy installation, first use the stock menu/notification action
or run `omarchy-voxtype-install`. Then from this repository run:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --apply
./profiles/zenbook-um3406ka/voice/doctor.sh
```

The apply script is deliberately not called by the generic bootstrap: the
stock installer is interactive and owns first-run setup. The profile package
manifest only declares `voxtype-bin` and `wtype`.

Restore the latest saved voice state with:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --rollback
```

The earlier WebRTC design remains available in Git history and local backups
for investigation, but it is not silently installed in the native baseline.
The mixed-language and focused-field tests must be rerun after any Voxtype or
Omarchy package update; a successful ASR transcript alone does not prove GUI
insertion succeeded.
