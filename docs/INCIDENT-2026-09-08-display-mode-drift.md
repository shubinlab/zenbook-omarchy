# Display mode drift — 2026-09-08

## Observation

At approximately 14:51:30 MSK the live Hyprland state changed to:

- 2560×1440 at 239.97 Hz;
- scale 1.0;
- 10-bit format;
- VRR enabled.

The checked-in monitor configuration still requested 2560×1440 at 143.99 Hz, scale 1.6, 10-bit and VRR. This means the live compositor state had drifted from the persistent user configuration.

## Evidence

- DP-1 remained `connected`.
- DRM DPMS remained `On`.
- The Wayland session remained active, unlocked and not idle.
- No recent AMDGPU, DRM, USB, suspend/resume or EDID error was present in the kernel journal.
- The Hyprland log showed modesets between the available 120/144/240 Hz modes, without a link-loss or GPU-reset message.
- The last five telemetry samples after recovery remained at 144 Hz, scale 1.6, 10-bit, VRR enabled and DPMS on.

## Recovery

The tested profile was reapplied through the Hyprland Lua API:

```text
2560×1440 @ 143.99 Hz, scale 1.6, 10-bit, color management auto, VRR=1
```

The display returned immediately and remained stable during the follow-up observation.

## Assessment

This episode confirms runtime configuration drift, not a confirmed JSAUX, DisplayPort, AMDGPU or monitor hardware failure. The exact initiating client was not recorded. The persistent configuration remains correct; future experiments must restore the profile in a `finally` block and record the live state before and after every mode change.
