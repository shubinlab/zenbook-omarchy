# Native Omarchy voice profile

This profile is a small post-install policy layer on top of Omarchy's native
Voxtype installation. It does not port the Ubuntu/GNOME installer from
`zenbook-voice` and does not create a competing audio pipeline. It adds the
small Arch-native Lemonade/FastFlowLM backend needed to use this Zenbook's
AMD XDNA2 NPU for inference.

The stock Omarchy command `omarchy voxtype install` installs `voxtype-bin`,
`wtype`, its stock Whisper model, the user service and the compositor
bindings. The profile manifest adds `lemonade-server` and `fastflowlm`; the
profile then keeps only these Zenbook-specific choices:

- local `whisper-v3-turbo-FLM` inference through Lemonade on `device=npu`;
- `language = "auto"` and `translate = false`;
- native `type` output through `wtype`;
- a 300 ms native pre-type focus delay to avoid first-character loss;
- native Voxtype OSD and start/stop audio feedback enabled.
- native Silero VAD installed with `voxtype setup vad` and enabled through the
  `whisper` backend at threshold `0.5`;
- native spoken punctuation and filler-word filtering enabled;
- an opt-in local `technical` post-process profile for conservative glossary
  cleanup, invoked with `voxtype record start --profile technical`.

The native model setting and artifact may remain in the config because the
Omarchy installer owns them, but remote mode selects the Lemonade FLM model
for actual transcription. The endpoint is loopback-only and telemetry must be
disabled; LAN broadcast discovery is disabled as well because no remote client
is needed.

The normal Zenbook bootstrap invokes the stock installer automatically and
then applies this extension in the same clean-install run. There is no
separate native Voxtype step. To apply only the policy on an already native
Voxtype installation:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --check
./profiles/zenbook-um3406ka/voice/apply.sh --apply
./profiles/zenbook-um3406ka/voice/doctor.sh
```

Use `--no-voice` on the Zenbook bootstrap only as an explicit opt-out. The
generic profile leaves voice untouched.

The operation creates a timestamped user-state backup. Restore it with:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --rollback
```

There is no profile PipeWire drop-in and no changed global sink. The clean
profile does not inspect or remove legacy PipeWire/VAD drop-ins. Older installs
can use the explicit migration command:

```bash
./scripts/repair-voice-legacy.sh --check
./scripts/repair-voice-legacy.sh --apply
```

The native Omarchy files under `/usr/share/omarchy` remain read-only inputs.
