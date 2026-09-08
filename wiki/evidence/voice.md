# Native Omarchy voice profile

Last verified: 2026-09-08

## Decision

The Ubuntu/GNOME installer from `zenbook-voice` is not used on this
Arch/Omarchy/Hyprland host. Omarchy's own `omarchy voxtype install` remains
authoritative for Voxtype package installation, its stock model download, the
user service and Hyprland bindings. This profile adds only a local Lemonade
NPU backend and the host's useful multilingual/output policy:

```text
physical PipeWire default microphone
  -> native Voxtype audio capture
  -> localhost Lemonade API
  -> whisper-v3-turbo-FLM through FastFlowLM
  -> AMD XDNA2 NPU
  -> native wtype keyboard typing into the focused field
```

Native Voxtype OSD remains enabled, and start/stop audio feedback is enabled.
The profile does not switch to clipboard paste, install a second typing tool,
change the default sink, or add a global echo-cancel filter. Optional VAD and
the former virtual microphone are intentionally not part of the clean baseline.
Legacy cleanup is available only through the explicit voice-repair command.

The packaged Omarchy bindings remain the source of truth: `Super+Ctrl+X`
toggles dictation and `F9` is push-to-talk. No file under `/usr/share/omarchy`
is modified.

## Quality and safety gates

- `language = "auto"` is the supported single-recording setting for a phrase
  containing Russian and English; Whisper may still choose one language for an
  ambiguous mixed recording.
- The active inference model is `whisper-v3-turbo-FLM`; the Lemonade health
  endpoint must report `recipe=flm`, `device=npu` and `backend_health=ready`.
  The stock native Voxtype model setting and artifact are left under Omarchy's
  ownership; they are not selected for active inference here.
- The endpoint is loopback-only (`127.0.0.1`); no cloud transcription path is
  configured, Lemonade LAN broadcast discovery is disabled, and the profile
  refuses to proceed if Lemonade telemetry is on.
- Native `type` output uses `wtype` under Hyprland and leaves the normal
  clipboard path untouched.
- `output.pre_type_delay_ms = 300` gives the focused Wayland field time to
  attach before the first keystroke. `type_delay_ms = 10` is the smallest
  stable value measured on this Zenbook's GTK/wtype path; it only slows native
  keystroke delivery and does not introduce a second output mechanism.
- The profile is user-scoped and creates a timestamped backup before changing
  Voxtype or audio defaults. No raw audio, credentials or model weights are
  stored in Git.

## Apply and verify

On a fresh Omarchy installation, the Zenbook bootstrap invokes the stock
`omarchy voxtype install` automatically after the VPN and package stages. Confirm its
native prompt; the repository then applies the tested policy in the same run:

```bash
./install.sh --no-vpn
```

There is no separate native Voxtype step. The generic profile does not enable
voice. `--no-voice` is an explicit opt-out for the Zenbook profile; it skips
both the native installer and the Zenbook voice policy. To verify an already
configured system directly:

```bash
./profiles/zenbook-um3406ka/voice/doctor.sh
```

After verifying the remote/NPU route, the optional cleanup can reclaim old
native model files. It is deliberately not part of clean install because the
native Omarchy installer owns its stock model artifact:

```bash
./profiles/zenbook-um3406ka/voice/cleanup-unused-models.sh --check
./profiles/zenbook-um3406ka/voice/cleanup-unused-models.sh --apply
```

The script requires remote Whisper mode, no secondary model and disabled VAD;
it moves only `ggml-base.bin`, `ggml-base.en.bin` and
`ggml-silero-vad.bin` into a timestamped user-state backup. It never touches
the active `large-v3-turbo` artifact or Lemonade's NPU model.

Restore the latest saved voice state with:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --rollback
```

The earlier WebRTC design remains available in Git history and local backups
for investigation, but it is not silently installed in the native baseline.
The mixed-language and focused-field tests must be rerun after any Voxtype or
Omarchy package update; a successful ASR transcript alone does not prove GUI
insertion succeeded.
