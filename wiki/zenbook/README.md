# ASUS Zenbook 14 UM3406KA profile

This profile records the tested configuration for an ASUS Zenbook 14
UM3406KA, an LG DisplayPort monitor and a JSAUX RGB docking station. It is an
example of a hardware profile, not a requirement for other Omarchy hosts.

The two files to open first are [hardware.md](hardware.md), the canonical
inventory of this laptop and its peripherals, and [configuration.md](configuration.md),
the restore and development map.

The display rule keeps the tested external mode at 2560×1440, 240 Hz, 10-bit,
sRGB, VRR enabled and the Omarchy-managed scale variable. The package lists
cover the platform and diagnostics. The optional service records local
monitor telemetry. The profile can use the official AdGuard VPN CLI before an
update, but `--no-vpn` disables that behavior for a run.

The profile's `tools/` directory contains the connector-specific telemetry and
protected display/component runners. They are intentionally outside the common
repository tools because their defaults describe this dock and monitor.

Apply it explicitly only on matching hardware:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn
```

Profile evidence:

- [hardware](hardware.md) — canonical laptop, display, dock and peripheral inventory;
- [configuration](configuration.md) — source files, apply commands and rollback paths;
- [audit](../evidence/audit.md) — system and connected-device baseline;
- [components](../evidence/components.md) — component checks and limitations;
- [diagnostics](../evidence/diagnostics.md) — package and staged validation;
- [display tests](../evidence/display-tests.md) — protected red-team runs;
- [display incident](../evidence/display-incident.md) — mode drift and recovery;
- [HDR](../evidence/hdr.md) — color and HDR decision;
- [telemetry](../evidence/telemetry.md) — local collector and privacy boundary;
- [vendor research](../evidence/vendor-research.md) and [sources](../evidence/research.md);
- [repository map](../evidence/repository-map.md) — where related evidence lives;
- [voice audit](../evidence/voice.md) and [voice extension](../evidence/voice-extension.md);
- [terminal extension](../evidence/terminal.md) — Sixel, ble.sh, fzf and doctor.

Dates in these documents describe when evidence was collected. They are kept
inside the records rather than in filenames so links remain stable when the
profile is updated.
