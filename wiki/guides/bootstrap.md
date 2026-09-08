<div align="center">

# Bootstrap

**One command for a clean Omarchy restore. One stage when you need control.**

[Quick install](../../README.md#quick-install) · [Doctor](../operations/README.md) · [Recovery](recovery.md)

</div>

## Recommended

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

The installer clones or updates the repository, selects the profile from DMI
and runs the supported stages in this order:

```text
VPN → display → NPU packages → native Voxtype → Lemonade model → terminal → doctor
```

On the first run, the only expected questions are the official AdGuard login
and Omarchy's native Voxtype confirmation. The installer reconnects safely on
reruns, refuses to update a locally modified checkout and does not run a
system update implicitly.

## Verify without changing anything

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

The check clones the published repository into a temporary directory, validates
the profile and exits without installing packages or changing user files.

## Check the live system

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage doctor
```

`doctor` is read-only. It checks Omarchy, native Voxtype capture/output,
Lemonade's loaded NPU model, terminal settings, Hyprland configuration and VPN
status when those components belong to the selected profile.

## Run one stage

Use the same raw entry point when you want one action only:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage vpn
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage display
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage packages
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage diagnostics
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage voice
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage terminal
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage update
```

From an existing checkout, the equivalent short commands are:

```bash
./scripts/install-vpn.sh
./scripts/install-display.sh
./scripts/install-packages.sh
./scripts/install-diagnostics.sh
./scripts/install-voice.sh
./scripts/install-terminal.sh
./scripts/install-update.sh
./scripts/doctor.sh
```

Network-dependent standalone stages automatically ensure the profile VPN unless
you pass `--no-vpn`. The display stage has no network dependency. Diagnostics
are optional and are not part of the clean flow.

## Safe switches

| Switch | Effect |
|---|---|
| `--check` | Validate repository assets without changing the system |
| `--manifest` | Print the stage manifest as JSON |
| `--non-interactive` | Stop before VPN login or first-run Voxtype confirmation |
| `--no-vpn` | Do not connect AdGuard VPN for this run |
| `--no-voice` | Skip native Voxtype and its Zenbook policy |
| `--no-terminal` | Skip terminal settings |
| `--no-monitor` | Skip the tested display override |
| `--profile ID` | Select a profile instead of DMI detection |

## Profile behavior

`zenbook-um3406ka` is selected when DMI reports `UM3406KA`. It enables the
official AdGuard VPN CLI, tested display configuration, the two-package local
Lemonade/FLM NPU voice backend, native Voxtype policy and terminal extension.
Other hosts use `generic`, which makes no automatic changes. Run the diagnostic
stage explicitly only when that is intended.

The installer never edits `/usr/share/omarchy`. It uses native Omarchy commands,
keeps user changes under `~/.config`, and stores recoverable backups under
`~/.local/state/omarchy-profiles/`.

## Full update policy

The clean restore does not update the operating system automatically. Use
`--stage update` only when you explicitly want Omarchy to own the snapshot,
migrations and package update. Apply the profile again after an update if a
stock migration changes a user-facing default.

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --stage update
```

Older Zenbook installs can use the opt-in legacy repair command. It is never
called by a clean install:

```bash
./scripts/repair-voice-legacy.sh --check
./scripts/repair-voice-legacy.sh --apply
```
