<div align="center">

# Zenbook Omarchy

**A reliable, native-first restore for ASUS Zenbook 14 UM3406KA on Omarchy.**

Display · VPN · native Bitwarden · packages · native Voxtype · terminal · safe recovery

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
| 3 | **Packages** | Install the small local Lemonade/FLM NPU runtime through Omarchy's package helper |
| 4 | **Voice** | Run native `omarchy voxtype install`, then route its inference to Lemonade on the AMD NPU |
| 5 | **Terminal** | Apply user-scoped Foot, Sixel, ble.sh, fzf and shortcut settings |
| 6 | **Bitwarden** | Ask before installing the native Wayland launcher and guide the complete first setup |
| 7 | **Doctor** | Verify the resulting native/user configuration |

On a first run, answer the native VPN and Voxtype prompts when they appear. At
the end, the installer asks whether to start the optional Bitwarden onboarding.
The clean flow does not run a system update automatically. Verify everything
with:

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
| **Bitwarden** | Optional final stage with guided onboarding; native Wayland `rbw` + `rofi-rbw` + Fuzzel launcher; `wl-copy` clipboard with 30-second clearing; `wtype` autotyping; one `Super + Shift + /` hotkey; no Electron/X11/XWayland client |
| **Voice** | Native Voxtype capture/service/bindings and `wtype` output; active Whisper inference through local Lemonade FLM on the AMD XDNA2 NPU; OSD, start/stop sounds and `language=auto` |
| **Terminal** | Foot Sixel, pinned ble.sh/fzf integration, preview helper and tested ChatGPT shortcut |
| **Network** | Official AdGuard VPN CLI is installed and connected before network-dependent stages |
| **Diagnostics** | Optional hardware tools, installed only with `--stage diagnostics` |
| **Recovery** | User changes are backed up under `~/.local/state/omarchy-profiles/` |
| **Privacy** | No background collector or data-logging path is installed |

## One command, or one stage

The main raw entry point accepts the same small set of stages as the local
wrappers:

```bash
# Full restore
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash

# One stage from the same URL; voice also installs its two NPU packages
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage voice

# Native Wayland Bitwarden (also included in the full restore)
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage bitwarden

# Machine-readable stage list
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --manifest

# Optional diagnostics
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage diagnostics

# Explicit Omarchy update (kept separate from the clean restore)
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage update
```

From an existing checkout:

```bash
./scripts/install-vpn.sh --profile zenbook-um3406ka
./scripts/install-display.sh --profile zenbook-um3406ka
./scripts/install-packages.sh --profile zenbook-um3406ka
./scripts/install-bitwarden.sh --profile zenbook-um3406ka
./scripts/install-voice.sh --profile zenbook-um3406ka
./profiles/zenbook-um3406ka/voice/cleanup-unused-models.sh --check
./scripts/install-terminal.sh --profile zenbook-um3406ka
./scripts/install-update.sh --profile zenbook-um3406ka
./scripts/install-diagnostics.sh --profile zenbook-um3406ka
./scripts/repair-voice-legacy.sh --check
./scripts/doctor.sh --profile zenbook-um3406ka
```

Useful safety switches:

```text
--check              validate without changing the system
--non-interactive    stop before interactive VPN/Voxtype/Bitwarden onboarding
--no-vpn             do not connect VPN for this run
--no-voice           skip native Voxtype, Lemonade and the NPU voice policy
--no-bitwarden       skip native Wayland Bitwarden setup
--no-terminal        skip terminal settings
--no-monitor         skip the display override
--stage diagnostics  install optional diagnostic packages
```

## Why this stays native

The profile never edits `/usr/share/omarchy`. The stock Omarchy command
`omarchy voxtype install` owns Voxtype packages, its stock model download, the
user service and compositor bindings. The profile adds only the two direct
Lemonade packages and a localhost Voxtype remote policy: FastFlowLM serves
`whisper-v3-turbo-FLM` on the AMD XDNA2 NPU, while Voxtype remains the native
capture, feedback and typing frontend. The stock model artifact may therefore
remain installed for native Omarchy compatibility, but it is not selected as
the active inference route on this profile.
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
profiles/zenbook-um3406ka/bitwarden/ native Wayland policy, launcher and onboarding
profiles/zenbook-um3406ka/terminal/ terminal policy and rollback
scripts/repair-voice-legacy.sh     opt-in migration for older voice setups
wiki/                              guides, inventories and evidence
tools/                             CI and publication checks
runs/                              local ignored experiment output
```

## Scope and recovery

The automatic profile is selected by DMI: `zenbook-um3406ka` for this ASUS
Zenbook, otherwise the no-op `generic` profile. Diagnostics are explicit and
are never part of the clean restore by accident. Neither profile adds a
background collector or data-logging service.

All supported changes are user-scoped. Monitor, voice and terminal operations
create recoverable state under `~/.local/state/omarchy-profiles/`; the native
Omarchy package files remain untouched and can be updated normally.

## License

MIT — see [LICENSE](LICENSE).
