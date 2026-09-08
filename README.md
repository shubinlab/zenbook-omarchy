# zenbook-omarchy

Rebuild, inspect and safely evolve an Omarchy system with a tested ASUS
Zenbook 14 UM3406KA, LG DisplayPort monitor and JSAUX dock profile.

The repository has one documentation home: the **[system wiki](wiki/README.md)**.
It connects hardware, drivers, Omarchy defaults, user overrides, package
manifests, experiments and recovery procedures. The executable profile under
`profiles/` contains only the files the bootstrap engine applies.

## Quick start

Check the published installer without changing the system:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

Restore the detected profile:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

With an existing checkout, check or apply explicitly:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-terminal
```

On the matching Zenbook, the normal bootstrap runs Omarchy's native Voxtype
installer automatically and then applies the repository's tested voice policy;
there is no separate voice-install step. Confirm the native prompt on a fresh
system. Use `--no-voice` only to opt out.

Run a protected display test from the graphical session:

```bash
./profiles/zenbook-um3406ka/tools/run_vrr_redteam_safe.sh --seconds 30
```

The installer selects `zenbook-um3406ka` from DMI and falls back to `generic`
on other Omarchy hardware. Applies create backups under
`~/.local/state/omarchy-profiles/` before changing user files.

## Wiki navigation

| Need | Page |
|---|---|
| Understand the whole system | [Wiki home](wiki/README.md) |
| Find every laptop and peripheral | [Hardware record](wiki/zenbook/hardware.md) |
| See what differs from stock Omarchy | [Configuration layers](wiki/software/configuration.md) |
| Check packages and clean-install requirements | [Package guide](wiki/software/packages.md) · [Live inventory](wiki/software/package-inventory.md) |
| Restore or roll back | [Recovery guide](wiki/guides/recovery.md) |
| Review evidence and research | [Evidence index](wiki/evidence/README.md) |
| Add another computer | [Profiles guide](wiki/profiles.md) |

## Repository layout

```text
install.sh                         one-line GitHub entry point
scripts/bootstrap.sh               profile-aware restore engine
profiles/                          executable profiles and apply assets
profiles/zenbook-um3406ka/tools/  display, telemetry and hardware tests
profiles/zenbook-um3406ka/voice/  voice extension
profiles/zenbook-um3406ka/terminal/ terminal extension
wiki/                              all narrative documentation and evidence
tools/                             repository, inventory and publication checks
runs/                              local ignored experiment output
```

The profile never edits `/usr/share/omarchy`; it applies user configuration in
`~/.config` and keeps rollback data in `~/.local/state/omarchy-profiles/`.
Contribution and public-data rules are in [CONTRIBUTING.md](CONTRIBUTING.md)
and [SECURITY.md](SECURITY.md).
