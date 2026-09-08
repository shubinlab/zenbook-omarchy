# Test methodology

Power management is part of the experiment. A stay-awake setting alone does
not necessarily block systemd-logind sleep, screen locking or a closed-lid
action, so a display run must guard the whole test window.

The protected harness uses:

1. the desktop environment's idle disable mechanism and its stay-awake state;
2. `systemd-inhibit --what=idle:sleep:handle-lid-switch --mode=block` around
   the entire runner;
3. a sample gate that invalidates results when the session locks, the inhibitor
   disappears, the connector disconnects or the display changes state outside
   the requested phase.

Each sample should record the compositor mode, refresh, format, VRR, DPMS and
disabled state; the DRM VRR flag; the active connector; session idle/lock
state; and relevant kernel events. A profile supplies the connector and mode
matrix for its hardware.

An intentional DPMS phase must be labelled separately from an unexpected DPMS
transition. Software telemetry can detect link loss, modesets, DRM VRR state
and kernel events, but cannot prove that a human-visible flicker never
occurred. Optical confirmation requires a camera or photodiode.
