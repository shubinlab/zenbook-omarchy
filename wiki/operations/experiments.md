# Experiments and verification

The display harness exists because the first tests were contaminated by the
screensaver, lock timeout and suspend/resume. A valid run combines Omarchy's
stay-awake state with:

```text
systemd-inhibit --what=idle:sleep:handle-lid-switch --mode=block
```

Each sample checks compositor mode/refresh/format/VRR/DPMS, DRM VRR state,
connector status, session idle/lock state and relevant kernel events. A sample
is invalid when the session locks, the inhibitor disappears, the connector
disconnects or the display changes outside the planned phase.

Run the profile-specific wrapper from the graphical session:

```bash
./profiles/zenbook-um3406ka/tools/run_vrr_redteam_safe.sh --seconds 30
```

The wrapper restores the selected final display mode. Results are written to
the ignored `runs/` directory. The full matrix and known limitations are in
[display-tests.md](../evidence/display-tests.md),
while the component run is in [components.md](../evidence/components.md).
