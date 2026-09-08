# Native Omarchy voice profile

This profile adapts the tested audio part of `zenbook-voice` to Omarchy's
user-configuration model. It is deliberately separate from the Ubuntu,
GNOME, Lemonade and AMD-XDNA2 installer in that repository.

The generated PipeWire-Pulse drop-in loads WebRTC echo cancellation,
noise suppression, voice detection, transient suppression and a high-pass
filter. The physical source and sink are discovered when the profile is
applied. Voxtype 1.0.1 uses the supported PipeWire host `default`; the
user-session default source is pointed at the filtered virtual microphone and
the previous source is backed up. The physical sink and other Omarchy routing
stay unchanged.

The profile uses `language = "auto"`, a multilingual Whisper model, Voxtype
Whisper VAD and paste output. Paste avoids keyboard-layout corruption when a
single phrase contains both Cyrillic and Latin text. The native Omarchy
bindings remain the source of truth for starting/stopping dictation.

Apply from the repository root:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --check
./profiles/zenbook-um3406ka/voice/apply.sh --apply
./profiles/zenbook-um3406ka/voice/doctor.sh
```

The apply path creates a timestamped backup under
`~/.local/state/zenbook-omarchy/backups/voice/`. Restore the latest voice
configuration with:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --rollback
```

Run apply again after changing between the built-in speakers, HDMI, USB audio
or a headset: PipeWire's echo-cancel module keeps the physical master names
resolved at load time.

The profile never changes `/usr/share/omarchy`, `~/.config/hypr/bindings.lua`,
or the Omarchy monitor profile. Its only global audio change is the
user-session default microphone, which is rollbackable; the physical sink is
left unchanged.
