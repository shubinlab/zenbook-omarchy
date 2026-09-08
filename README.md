# zenbook-omarchy

Reproducible notes and local experiments for an ASUS Zenbook running Omarchy/Hyprland with an LG UltraGear display connected through the JSAUX RGB Docking Station.

## One command

Run this from a normal terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

It installs the official AdGuard VPN CLI when it is missing, clones or updates this repository, connects the AdGuard VPN CLI,
installs the recorded hardware and diagnostic packages, restores the monitor
profile with a backup, disables the Omarchy internal-monitor mirror and runs
the supported `omarchy update`. The first run may require the one-time
interactive AdGuard login. It never puts VPN credentials in Git.

To choose a VPN location for this run:

```bash
export ADGUARD_VPN_LOCATION=COUNTRY_OR_CITY; curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

To verify the current GitHub command without installing or changing anything:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

The current tested profile is 2560×1440 at 240 Hz, 10-bit, scale 1.6, `cm=srgb` and per-output VRR=1. The external scale is kept in the Omarchy-managed `omarchy_monitor_scale` variable so the normal scaling command remains usable.

## Run the protected experiment

Run from the graphical session with the display connected:

```bash
./tools/run_vrr_redteam_safe.sh --seconds 30
```

The wrapper blocks idle, suspend and the closed-lid action with `systemd-inhibit`. The runner also disables Omarchy idle, checks lock state and inhibitors in every sample, forces global and per-output `vrr=1`, runs the mode matrix and stress checks, then restores the recommended 1440p/240 Hz/10-bit/scale-1.6/VRR=1 profile and the prior idle state.

Results are written locally to `runs/` as JSON and Markdown; these raw artifacts are Git-ignored because they can contain machine-specific metadata. The local telemetry service writes its private JSONL log under `~/.local/state/omarchy/monitor-telemetry/` and is not copied into this repository automatically.

For flags, first-time AdGuard setup and the public/private boundary, see [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) and [SECURITY.md](SECURITY.md).

The full documentation map is [docs/README.md](docs/README.md). The latest full audit is [docs/AUDIT-2026-09-08.md](docs/AUDIT-2026-09-08.md), with protected display results in [docs/RESULTS-2026-09-08.md](docs/RESULTS-2026-09-08.md) and the aggregate system baseline in [docs/DIAGNOSTICS-2026-09-08.md](docs/DIAGNOSTICS-2026-09-08.md).

The follow-up runtime mode drift and recovery are recorded in [docs/INCIDENT-2026-09-08-display-mode-drift.md](docs/INCIDENT-2026-09-08-display-mode-drift.md). The exact cause was the enabled Omarchy internal-monitor mirror toggle, which requested the external display's preferred mode after reload. That toggle is now off, while the explicit 240 Hz rule remains active.

The expanded hardware and component review is [docs/COMPONENT-AUDIT-2026-09-08.md](docs/COMPONENT-AUDIT-2026-09-08.md); raw component runs stay local and ignored.

The cross-repository search map is [docs/REPOSITORY-MAP.md](docs/REPOSITORY-MAP.md). Current vendor and community findings, package decisions and open checks are in [docs/VENDOR-COMMUNITY-RESEARCH-2026-09-08.md](docs/VENDOR-COMMUNITY-RESEARCH-2026-09-08.md), with external sources consolidated in [docs/RESEARCH.md](docs/RESEARCH.md).

The installed diagnostics and staged validation are recorded in [docs/DIAGNOSTICS-2026-09-08.md](docs/DIAGNOSTICS-2026-09-08.md).

The HDR A/B investigation is [docs/HDR-2026-09-08.md](docs/HDR-2026-09-08.md); it records why the persistent desktop profile stays sRGB while auto-HDR remains available. Contribution and security rules are in [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
