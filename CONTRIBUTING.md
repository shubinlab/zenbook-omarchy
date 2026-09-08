# Contributing

This repository contains an Omarchy user configuration, reproducible hardware
checks and sanitized conclusions for one Zenbook and its docked LG display.
Hardware-specific observations must stay clearly separate from general Linux
advice.

Before opening a pull request:

1. Run `./tools/ci-check.sh`.
2. Run `./tools/check-public-repo.sh` after staging changes.
3. Run `git diff --cached --check`.
4. Update `docs/README.md` when adding or moving documentation.

The protected display runner requires the real graphical session and hardware.
Its raw output belongs in the ignored local `runs/` directory. Publish only an
aggregate report after removing hostnames, paths, serials, EDID hashes,
network data, credentials and private telemetry.

Use `install/bootstrap.sh --check` for a no-change profile check. Use the
one-command installer only on an Omarchy system where an update and package
installation are intended.

Keep Omarchy changes under `~/.config`. Do not edit `/usr/share/omarchy`.
Explain the observed trigger, the experiment, the result and the rollback path
for any hardware or display change.
