<div align="center">

# ASUS Zenbook 14 UM3406KA

**The tested host profile for Omarchy 4.**

[Hardware](hardware.md) · [Configuration](configuration.md) · [Voice](../evidence/voice.md) · [Terminal](../evidence/terminal.md)

</div>

This profile describes one ASUS Zenbook, one LG DisplayPort monitor and one
JSAUX RGB dock. It is a tested example, not a requirement for other Omarchy
hosts.

## Apply

The profile is selected automatically by DMI. To select it explicitly:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka
```

The same clean-install flow applies VPN, display, native Voxtype, terminal
settings and doctor. Diagnostics and the supported Omarchy update remain
explicit optional stages. Check it first with:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./scripts/doctor.sh --profile zenbook-um3406ka
```

## Tested result

| Area | Known-good behavior |
|---|---|
| **External display** | LG DisplayPort at 2560×1440, 239.97/240 Hz, 10-bit, sRGB, VRR on, scale 1.6 |
| **Internal display** | Managed by the profile and Omarchy display layer; no global Hyprland replacement |
| **Voice** | Native Voxtype capture/service/bindings and `wtype` output; local Lemonade FLM Whisper inference on AMD XDNA2 NPU; automatic language detection, OSD and feedback |
| **Terminal** | Foot Sixel, ble.sh/fzf integration, image preview and no profile ChatGPT override |
| **Network** | Official AdGuard VPN CLI before network-dependent install stages |
| **Recovery** | Timestamped user backups before profile-owned replacements |

## Source map

| Question | Page |
|---|---|
| What hardware is connected? | [Hardware inventory](hardware.md) |
| Which files change? | [Configuration map](configuration.md) |
| Why these display values? | [Display tests](../evidence/display-tests.md) |
| Why this voice path? | [Native voice evidence](../evidence/voice.md) |
| How does the terminal extension work? | [Terminal evidence](../evidence/terminal.md) |
| How do I recover? | [Recovery guide](../guides/recovery.md) |

## Boundary

Omarchy remains the authority for `/usr/share/omarchy`, default bindings,
package helpers and native Voxtype installation. This profile only adds
tested user-level policy. It does not install a background collector, replace
the audio stack or copy a vendor-specific Ubuntu/GNOME installer onto Omarchy.
