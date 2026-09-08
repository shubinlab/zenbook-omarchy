# Local telemetry

The collector in `tools/omarchy-monitor-telemetry.py` is installed locally as a user systemd service. It samples every five seconds and records:

- lid state;
- DP-1 connector and EDID hash;
- Hyprland mode, refresh, scale, pixel format, color preset, VRR, disabled and DPMS state;
- JSAUX/VIA USB hub presence;
- Hyprland config errors;
- new kernel events mentioning AMDGPU, DRM, DP-1, Type-C or USB;
- Omarchy stay-awake marker state.

The installed service writes to `~/.local/state/omarchy/monitor-telemetry/` with restrictive file permissions. The repository intentionally does not include those raw logs because they can contain hostnames, timestamps, device serials and machine-specific hashes.
