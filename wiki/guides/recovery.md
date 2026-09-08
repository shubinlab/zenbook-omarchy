# Recovery

Use the smallest action that repairs the problem. The commands below assume
the repository is at `~/zenbook-omarchy`.

## Verify before changing anything

```bash
cd ~/zenbook-omarchy
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
```

This validates the profile, package manifests, monitor rule and optional
terminal assets without installing packages or changing user configuration.

## Restore the external-display profile

For the monitor and packages, while keeping VPN and terminal changes out of
the operation:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-terminal
```

The monitor file is backed up before replacement. The restore target is
`~/.config/hypr/monitors.lua`; the profile keeps the tested 1440p/240 Hz,
10-bit, sRGB, VRR-on rule and the Omarchy scale variable.

## Restore individual extensions

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --rollback
./profiles/zenbook-um3406ka/terminal/apply.sh --rollback
```

Each extension selects its newest backup under
`~/.local/state/omarchy-profiles/backups/`. Check the result before applying
again:

```bash
./profiles/zenbook-um3406ka/voice/doctor.sh
terminal-doctor
```

## If the display goes dark during an experiment

Use the protected wrapper so idle, lock, suspend and lid handling are accounted
for:

```bash
./profiles/zenbook-um3406ka/tools/run_vrr_redteam_safe.sh --seconds 30
```

If the graphical session is already unusable, switch to a TTY, stop only the
user telemetry service if it is running, and restore the latest monitor backup
manually after checking its contents:

```bash
systemctl --user disable --now omarchy-monitor-telemetry.service
ls -dt ~/.local/state/omarchy-profiles/zenbook-um3406ka/backups/*
```

Do not delete `/usr/share/omarchy` or replace the whole Hyprland configuration
to recover one monitor rule. The profile is intentionally limited to user
files and has a rollback path.
