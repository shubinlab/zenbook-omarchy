# Display mode incident and recovery

Last verified: 2026-09-08

## Observation

At approximately 14:51:30 MSK the live Hyprland state changed to:

- 2560×1440 at 239.97 Hz;
- scale 1.0;
- 10-bit format;
- VRR enabled.

The checked-in monitor configuration requested 2560×1440 at 143.99 Hz, scale 1.0, 10-bit and VRR. The live compositor state had drifted from the persistent user configuration.

## Evidence

- DP-1 remained `connected`.
- DRM DPMS remained `On`.
- The Wayland session remained active, unlocked and not idle.
- No recent AMDGPU, DRM, USB, suspend/resume or EDID error was present in the kernel journal.
- The Hyprland log showed modesets between the available 120/144/240 Hz modes, without a link-loss or GPU-reset message.
- The first recovery samples remained at 144 Hz, scale 1.0, 10-bit, VRR enabled and DPMS on.

## Recovery

The tested profile was reapplied through the Hyprland Lua API:

```text
2560×1440 @ 143.99 Hz, scale 1.0, 10-bit, color management auto, VRR=1
```

The display returned immediately and remained stable during the follow-up observation.

## Assessment

The initiating change was the Omarchy internal-monitor mirror toggle. Its state file requested `mode = "preferred"` for DP-1 and mirroring to eDP-1, so a reload selected the dock path's preferred 240 Hz mode and temporarily bypassed the explicit 144 Hz rule. Disabling the toggle through the official Omarchy command removed the drift. This confirms a configuration interaction, not a JSAUX, DisplayPort, AMDGPU or monitor hardware failure. A follow-up 32-second control run held 143.991 Hz, scale 1.0, VRR on, DPMS on and no mirror in all eight samples.
