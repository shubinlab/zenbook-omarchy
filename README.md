# zenbook-omarchy

> Rebuild, diagnose and safely evolve an ASUS Zenbook 14 UM3406KA with its
> Omarchy desktop, LG DisplayPort monitor and JSAUX dock.

This repository has two jobs:

1. restore the tested configuration on this exact computer;
2. provide a clean profile model that other Omarchy users can extend without
   mixing their hardware with this one.

## Start here

### Verify without changing anything

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

For a checkout you already have:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
```

### Restore this Zenbook

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

This updates the repository, installs declared packages, applies the tested
terminal and monitor profile, and runs the supported Omarchy update. Use the
explicit command below when you want display and packages without VPN or
terminal changes:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-terminal
```

### Test the display safely

```bash
./profiles/zenbook-um3406ka/tools/run_vrr_redteam_safe.sh --seconds 30
```

The one-line installer detects `UM3406KA` through DMI. On this laptop it uses
the Zenbook profile; on another machine it falls back to `generic`. The
Zenbook restore creates backups under
`~/.local/state/omarchy-profiles/backups/` before changing user files.

For a guided recovery, read [Recovery](docs/recovery.md). For the exact
hardware and connected-device inventory, read [Hardware](profiles/zenbook-um3406ka/hardware.md).
The complete linked documentation is the [system wiki](wiki/README.md).

## This computer's known-good state

| Area | Current tested value |
|---|---|
| Laptop | ASUS Zenbook 14 OLED UM3406KA; BIOS `UM3406KA.306` |
| CPU | AMD Ryzen AI 7 350, 8 cores / 16 threads, `amd-pstate-epp` |
| Graphics | AMD Radeon 860M/Krackan; inventory tools also reported 840M/860M labels; kernel `amdgpu`, Mesa/RADV |
| External display | LG UltraGear on `DP-1` through JSAUX RGB Docking Station |
| Display mode | `2560×1440 @ 239.970 Hz`, `XRGB2101010` 10-bit, `cm=srgb`, VRR on |
| Desktop scale | `1.6` through `omarchy_monitor_scale` |
| Storage | WD_BLACK SN850X 2 TB, firmware `620361WD`, Btrfs |
| Wired network | Realtek RTL8153 over the dock, 1 Gb/s full duplex |
| Wireless | MediaTek MT7922 / `mt7921e`; Bluetooth / `btusb` |
| Memory | 30 GiB available RAM, 60 GiB zram observed |
| Dock topology | VIA USB2 at 480 Mb/s and USB3 at 10 Gb/s; Ethernet, LG controls, receivers and audio downstream |

The full inventory includes USB IDs, firmware, battery, audio, camera,
warnings, test limits and untested areas. It is kept in one stable file so a
future audit can update facts without scattering them across dated reports:
[hardware.md](profiles/zenbook-um3406ka/hardware.md).

## User features

The profile keeps each feature independently restorable:

- [Display and telemetry](profiles/zenbook-um3406ka/README.md) — monitor rule,
  VRR/HDR findings, protected tests and local telemetry;
- [Voice input](profiles/zenbook-um3406ka/voice/README.md) — PipeWire/WebRTC,
  Voxtype, doctor and rollback;
- [Terminal](profiles/zenbook-um3406ka/terminal/README.md) — Foot Sixel,
  ble.sh, fzf previews, chafa, ChatGPT shortcut and doctor;
- [Configuration map](profiles/zenbook-um3406ka/configuration.md) — what each
  file changes, how to verify it and where its backup lives.

The profile never edits `/usr/share/omarchy`. It applies user configuration in
`~/.config`, user data in `~/.local/share` and backups in
`~/.local/state/omarchy-profiles`.

## Repository map

```text
install.sh                         one-line GitHub entry point
scripts/bootstrap.sh               profile-aware restore engine
profiles/generic/                  safe fallback for other Omarchy machines
profiles/zenbook-um3406ka/         this laptop's facts and configuration
profiles/zenbook-um3406ka/docs/    audits, experiments and research
profiles/zenbook-um3406ka/tools/   dock/display-specific test runners
profiles/zenbook-um3406ka/voice/   voice extension
profiles/zenbook-um3406ka/terminal/ terminal extension
tools/                             repository and publication checks
docs/                              recovery, architecture and test guidance
runs/                              local ignored experiment output
```

Start with [Recovery](docs/recovery.md), [Hardware](profiles/zenbook-um3406ka/hardware.md),
or the [documentation map](docs/README.md). To add another computer, create a
new profile and keep its facts, settings, tests and limitations together.

Contribution and public-data rules are in [CONTRIBUTING.md](CONTRIBUTING.md)
and [SECURITY.md](SECURITY.md).
