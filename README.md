<div align="center">

# Zenbook Omarchy

**A reliable, native-first restore for ASUS Zenbook 14 UM3406KA on Omarchy.**

Display · VPN · packages · native Voxtype · terminal · safe recovery

[![Quality checks](https://github.com/shubinlab/zenbook-omarchy/actions/workflows/quality.yml/badge.svg)](https://github.com/shubinlab/zenbook-omarchy/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

This repository turns a fresh Omarchy 4 installation into the tested Zenbook
setup with one command. It keeps Omarchy's defaults authoritative, writes only
user-level overrides, and makes every applied change inspectable and reversible.

## Quick install

Recommended — one command, full restore:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

The installer runs these stages in order:

| | Stage | What happens |
|---:|---|---|
| 1 | **Network** | Install/login/connect AdGuard VPN when the Zenbook profile requires it |
| 2 | **Display** | Apply the tested monitor layout with a backup |
| 3 | **Packages** | Install the declared platform, diagnostic and terminal packages |
| 4 | **Voice** | Run native `omarchy voxtype install`, then apply the multilingual policy |
| 5 | **Terminal** | Apply user-scoped Foot, Sixel, ble.sh, fzf and shortcut settings |
| 6 | **Update** | Run the supported `omarchy update` command |

On a first run, answer the native VPN and Voxtype prompts when they appear.
After installation, verify everything with:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage doctor
```

## Check first

The check mode downloads the published repository into a temporary directory,
validates the scripts and changes nothing on the system:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

The raw URL must include the branch name (`main`).

## What you get

| Area | Result |
|---|---|
| **Omarchy** | Native commands and defaults remain the source of truth |
| **Zenbook display** | Tested external LG DisplayPort mode: 2560×1440, 240 Hz, 10-bit, sRGB, VRR and scale 1.6 |
| **Voice** | Native Voxtype, Whisper `large-v3-turbo`, `language=auto`, OSD, start/stop sounds and native Wayland typing |
| **Terminal** | Foot Sixel, pinned ble.sh/fzf integration, preview helper and tested ChatGPT shortcut |
| **Network** | Official AdGuard VPN CLI is installed and connected before network-dependent stages |
| **Recovery** | User changes are backed up under `~/.local/state/omarchy-profiles/` |
| **Privacy** | No background collector or data-logging path is installed |

## One command, or one stage

The main raw entry point accepts the same small set of stages as the local
wrappers:

```bash
# Full restore
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash

# One stage from the same URL
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage voice

# Machine-readable stage list
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --manifest
```

From an existing checkout:

```bash
./scripts/install-vpn.sh --profile zenbook-um3406ka
./scripts/install-display.sh --profile zenbook-um3406ka
./scripts/install-packages.sh --profile zenbook-um3406ka
./scripts/install-voice.sh --profile zenbook-um3406ka
./scripts/install-terminal.sh --profile zenbook-um3406ka
./scripts/install-update.sh --profile zenbook-um3406ka
./scripts/doctor.sh --profile zenbook-um3406ka
```

Useful safety switches:

```text
--check              validate without changing the system
--non-interactive    stop before VPN login or first-run Voxtype confirmation
--no-vpn             do not connect VPN for this run
--no-voice           skip native Voxtype and its profile policy
--no-terminal        skip terminal settings
--no-monitor         skip the display override
```

## Why this stays native

The profile never edits `/usr/share/omarchy`. The stock Omarchy command
`omarchy voxtype install` owns Voxtype packages, model setup, the user service
and compositor bindings; this repository only adds the tested Zenbook policy.
The same rule applies to the shell, Hyprland defaults and package helpers:
use Omarchy's supported command first, then add the smallest user override.

## Documentation

The [system wiki](wiki/README.md) is the documentation home. Start with the
page that matches the question:

| Need | Read |
|---|---|
| Install, update or verify | [Bootstrap guide](wiki/guides/bootstrap.md) |
| Check the current machine | [Doctor and operations](wiki/operations/README.md) |
| Understand the whole system | [Wiki home](wiki/README.md) |
| See the tested hardware | [Zenbook hardware](wiki/zenbook/hardware.md) |
| See every user override | [Configuration map](wiki/software/configuration.md) |
| Tune or diagnose voice | [Native voice evidence](wiki/evidence/voice.md) |
| Restore a previous state | [Recovery guide](wiki/guides/recovery.md) |
| Add another host | [Profiles guide](wiki/profiles.md) |

## Repository map

```text
install.sh                         one-line GitHub entry point
scripts/bootstrap.sh               staged profile orchestrator
scripts/install-*.sh               standalone stage wrappers
scripts/doctor.sh                  read-only health check
profiles/                          executable host profiles
profiles/zenbook-um3406ka/voice/   native Voxtype policy and doctor
profiles/zenbook-um3406ka/terminal/ terminal policy and rollback
wiki/                              guides, inventories and evidence
tools/                             CI and publication checks
runs/                              local ignored experiment output
```

## Scope and recovery

The automatic profile is selected by DMI: `zenbook-um3406ka` for this ASUS
Zenbook, otherwise the conservative `generic` profile. Neither profile adds a
background collector or data-logging service.

All supported changes are user-scoped. Monitor, voice and terminal operations
create recoverable state under `~/.local/state/omarchy-profiles/`; the native
Omarchy package files remain untouched and can be updated normally.

## License

MIT — see [LICENSE](LICENSE).
