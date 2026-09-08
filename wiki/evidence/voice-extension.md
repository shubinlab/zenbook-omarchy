# Native Omarchy voice profile

This profile is a small post-install policy layer on top of Omarchy's native
Voxtype installation. It does not port the Ubuntu/GNOME/Lemonade/AMD-XDNA2
installer from `zenbook-voice` and does not create a competing audio pipeline.

The stock Omarchy command `omarchy-voxtype-install` installs `voxtype-bin`,
`wtype`, the Whisper model, the user service and the compositor bindings. The
profile then keeps only these Zenbook-specific choices:

- multilingual `large-v3-turbo` model;
- `language = "auto"` and `translate = false`;
- native `type` output through `wtype`;
- a 300 ms native pre-type focus delay to avoid first-character loss;
- native Voxtype OSD and start/stop audio feedback enabled.

Apply from the repository root after the stock installer has completed:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --check
./profiles/zenbook-um3406ka/voice/apply.sh --apply
./profiles/zenbook-um3406ka/voice/doctor.sh
```

The operation creates a timestamped user-state backup. Restore it with:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --rollback
```

There is no profile PipeWire drop-in and no changed global sink. The default
source is restored to a physical ALSA source if an older profile left a
virtual source selected. The native Omarchy files under `/usr/share/omarchy`
remain read-only inputs.
