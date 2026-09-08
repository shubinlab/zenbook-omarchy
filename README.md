# zenbook-omarchy

Reproducible notes and local experiments for an ASUS Zenbook running Omarchy/Hyprland with an LG UltraGear display connected through the JSAUX RGB Docking Station.

The current tested profile is 2560×1440 at 144 Hz, 10-bit, scale 1.6 and per-output VRR=1. The repository records test conditions and observed results without publishing private telemetry or machine serial numbers.

## Run the protected experiment

Run from the graphical session with the display connected:

```bash
./tools/run_vrr_redteam_safe.sh --seconds 30
```

The wrapper blocks idle, suspend and the closed-lid action with `systemd-inhibit`. The runner also disables Omarchy idle, checks lock state and inhibitors in every sample, forces global and per-output `vrr=1`, runs the mode matrix and stress checks, then restores the recommended 1440p/144 Hz/10-bit/VRR=1 profile and the prior idle state.

Results are written to `runs/` as JSON and Markdown. The local telemetry service writes its private JSONL log under `~/.local/state/omarchy/monitor-telemetry/` and is not copied into this repository automatically.

The latest full audit is [docs/AUDIT-2026-09-08.md](docs/AUDIT-2026-09-08.md), with the protected display results in [docs/RESULTS-2026-09-08.md](docs/RESULTS-2026-09-08.md) and the system baseline in `runs/2026-09-08-steady-health.md`.
