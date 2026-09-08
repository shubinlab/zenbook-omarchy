# Test methodology

The first test series was contaminated by power management. Omarchy was configured with a 150-second screensaver and a 300-second lock timeout. The stay-awake marker cancels Omarchy's idle cycle, but it does not by itself block systemd-logind sleep or the closed-lid action.

The corrected harness uses both controls:

1. `omarchy-shell idle disable` and the Omarchy stay-awake state file.
2. `systemd-inhibit --what=idle:sleep:handle-lid-switch --mode=block` around the entire runner.

Every 2-second sample records and validates:

- Hyprland mode, refresh, format, VRR, DPMS and disabled state;
- DRM `VRR_ENABLED` values;
- DP-1 connector status;
- `loginctl` `IdleHint`, `LockedHint` and session state;
- Omarchy lock state;
- presence of the test systemd inhibitor.

A phase is invalid when the session is idle, locked, the inhibitor disappears, the connector is disconnected, or DPMS changes unexpectedly. The DPMS phase intentionally turns DPMS off and therefore records the off interval separately.

Software telemetry cannot prove that a human-visible flicker never occurred. The runner detects link loss, DPMS, mode changes, DRM VRR state and kernel events; optical confirmation would require a camera or photodiode.
