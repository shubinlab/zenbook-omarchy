<div align="center">

# System wiki

**The map of one tested Zenbook, its Omarchy layer and its recovery path.**

[Install](guides/bootstrap.md) · [Doctor](operations/README.md) · [Hardware](zenbook/hardware.md) · [Recovery](guides/recovery.md)

</div>

This wiki explains what the repository restores, what Omarchy owns, what was
actually tested and where to recover when something changes. Source files in
`profiles/` remain authoritative; these pages provide the readable map around
them.

## Start here

| If you want to… | Open |
|---|---|
| Install everything in the safest order | [Bootstrap guide](guides/bootstrap.md) |
| Check a live installation | [Operations and doctor](operations/README.md) |
| Understand the laptop and dock | [Zenbook hardware](zenbook/hardware.md) |
| See every maintained override | [Zenbook configuration](zenbook/configuration.md) |
| Understand display, audio or input | [Components](components/display.md) · [Media and input](components/media-input.md) |
| Tune native voice transcription | [Voice evidence](evidence/voice.md) |
| Roll back a change | [Recovery guide](guides/recovery.md) |
| Add another machine | [Profiles guide](profiles.md) |

## One-screen architecture

```mermaid
flowchart LR
  A[Fresh Omarchy 4] --> B[VPN]
  B --> C[Simple display override]
  C --> D[Profile packages]
  D --> E[Native Voxtype]
  E --> F[Terminal settings]
  F --> G[doctor]
  G --> H[Backups and rollback]
  G -.-> I[optional: diagnostics or update]
```

The important boundary is simple:

```text
Omarchy package defaults       /usr/share/omarchy       read-only source
This repository                profiles/                tested intent
User configuration             ~/.config/               applied override
Recovery state                 ~/.local/state/...       timestamped backup
```

## Current profile

The machine profile is [ASUS Zenbook 14 UM3406KA](zenbook/README.md): an ASUS
Zenbook with an LG DisplayPort monitor and JSAUX dock. DMI selects it
automatically; other machines fall back to a no-op `generic` profile.

The tested voice path is native Omarchy Voxtype capture and output with
`language=auto`, OSD and audio feedback. Its local inference request goes to
Lemonade's `whisper-v3-turbo-FLM` model through FastFlowLM on the AMD XDNA2
NPU, then native Voxtype types the result through Wayland. The profile does
not install a competing audio pipeline or modify package-owned Omarchy files.

## Evidence vocabulary

Every page labels the kind of statement it makes:

| Label | Meaning |
|---|---|
| **Observed** | Read from this host or reproduced in a protected test |
| **Profile** | Declared by this repository and intended to be restored |
| **Stock** | Supplied by the installed Omarchy release |
| **Open** | Not measured yet or dependent on hardware/firmware |

Start with the [system record](system.md), then use the [evidence index](evidence/README.md)
for detailed results and the [configuration comparison](software/configuration.md)
for a file-by-file view.

## Working rules

- Keep Omarchy defaults authoritative and use supported `omarchy` commands.
- Change only the smallest user-level file needed for a tested result.
- Back up before replacing user configuration.
- Keep credentials, raw journals, host identifiers and machine-local output out of Git.
- Treat a successful apply as incomplete until `doctor` or the relevant check passes.
