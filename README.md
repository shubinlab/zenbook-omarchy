# zenbook-omarchy

Reproducible notes and local experiments for an ASUS Zenbook running Omarchy/Hyprland with an LG UltraGear display connected through the JSAUX RGB Docking Station.

The repository is designed for review before any public release. It records the test conditions and observed results without uploading telemetry or exposing machine-specific serial numbers.

## Local experiment

Run from the graphical session with the display connected:

```bash
sudo -v  # only if the local DRM tools require it
python3 tools/run_vrr_redteam.py --seconds 30
```

The harness temporarily creates Omarchy's stay-awake marker, forces global and per-output `vrr=1`, samples Hyprland and DRM state, runs the mode matrix and stress checks, then restores the stable 1440p/144 Hz/10-bit/VRR-off profile and the prior idle marker.

Results are written to `runs/` as JSON and Markdown. The local telemetry service writes its private JSONL log under `~/.local/state/omarchy/monitor-telemetry/` and is not copied into this repository automatically.
