# Native voice integration audit

Last verified: 2026-09-08

## Decision

The Ubuntu/GNOME/Lemonade installer from `zenbook-voice` is not installed on
Omarchy. This laptop runs Arch/Omarchy/Hyprland, has no `dpkg` or Lemonade
runtime, and the repository's AMD-XDNA2 path is tied to a different Ubuntu
stack. Its tested PipeWire/WebRTC preprocessing is suitable for a user-scoped
adaptation.

The native profile is implemented by `profiles/zenbook-um3406ka/voice/apply.sh`:

```text
physical ALSA microphone + physical speaker sink
  -> PipeWire module-echo-cancel / WebRTC
    noise suppression + high-pass + voice/transient detection
  -> voxtype_noise_suppressed (user-session default microphone)
  -> Voxtype multilingual Whisper
  -> native keyboard typing into the focused field
```

The user-session default microphone is changed to the filtered source because
Voxtype 1.0.1 accepts the PipeWire host `default`, not the virtual source
name. The previous source is stored in backup metadata. The physical sink and
other routing remain unchanged. The Omarchy packaged Hyprland binding remains authoritative: `Super+Ctrl+X` toggles and
`F9` is push-to-talk. No file under `/usr/share/omarchy` is modified.

## Quality and safety gates

- `language = "auto"` is required for one recording containing Russian and
  English. A language list such as `en,ru` is not accepted by the installed
  Voxtype 1.0.1 runtime.
- Paste output avoids text corruption caused by keyboard-layout switching.
- The microphone hardware baseline is kept conservative: analog mic boost is
  disabled and the capture gain is not raised automatically by this profile.
- The profile does not claim perfect noise isolation. WebRTC suppression and
  VAD reduce common noise but do not guarantee rejection of speech-like noise.
- Every apply creates a user-state backup. A failed apply attempts an automatic
  restore; the latest backup can be restored explicitly with `--rollback`.
- No raw audio, model weights, credentials, host dumps or telemetry are stored
  in Git.

## Verification record

The target host must pass:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --check
./profiles/zenbook-um3406ka/voice/doctor.sh
```

Completed on this Zenbook on 2026-09-08:

- `apply.sh --apply`, `apply.sh --check` and `doctor.sh` pass;
- exactly one echo-cancel module and one filtered source are loaded;
- physical-mic silence is about `-35.6 dB` mean / `-14.5 dB` peak, while the
  filtered source is about `-57.7 dB` mean / `-43.3 dB` peak;
- the physical speaker test completed successfully at a deliberately low
  test volume, without changing the stored default sink;
- the native Voxtype daemon recorded through `default`, used Vulkan on the
  Radeon 860M, typed text through the native output path, then returned to
  `idle`;
- standalone Russian and English fixture tests pass acceptably with
  `large-v3-turbo`.

The mixed fixture still auto-detects Russian for the whole recording and loses
the English half. This is a verified limitation of the current single-pass
Voxtype/Whisper path, not a claim that mixed-language dictation is solved.
A real user-spoken mixed phrase should still be tested interactively after
this profile is installed. Recordings used for testing remain in `/tmp` or
another local ignored path only.

The original `zenbook-voice` reports remain evidence for the WebRTC design, but
not proof of this Arch/Omarchy target. Model quality and mixed-language WER
must be measured on this host's microphone, not inferred from NPU readiness or
one successful file replay.
