# Bootstrap

The repository has one small engine and optional profiles. `generic` is the
portable fallback: it installs common diagnostic tools and leaves monitor, VPN
and telemetry policy unchanged. A known machine can supply a profile with
tested monitor, package, service and extension files.

The shortest command clones or updates the repository, selects a profile from
DMI when possible, and runs the supported Omarchy update:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

Use this first to validate the published repository without changing the
system:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

Useful explicit choices after the repository has been cloned are:

```bash
~/zenbook-omarchy/scripts/bootstrap.sh --profile generic --check
~/zenbook-omarchy/scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-monitor
~/zenbook-omarchy/scripts/bootstrap.sh --profile zenbook-um3406ka --enable-telemetry
~/zenbook-omarchy/scripts/bootstrap.sh --profile zenbook-um3406ka --update-vpn-cli
```

VPN is profile-controlled and opt-in for generic machines. The Zenbook profile
can install the official AdGuard CLI and connect it before an update, but it
never stores account data in Git. Set `ADGUARD_VPN_LOCATION` for one run when
needed. `--no-vpn` always wins over a profile default.

The bootstrap applies user configuration under `~/.config`, creates a backup
under `~/.local/state/omarchy-profiles/` before replacing a monitor file, and
does not edit `/usr/share/omarchy`. Telemetry is opt-in; its local JSONL data
stays under `~/.local/state/omarchy/monitor-telemetry/` and is ignored by Git.

On the matching Zenbook profile, the bootstrap also applies the optional
user-scoped terminal extension. Skip it with `--no-terminal`; apply or
rollback it directly with the commands in the profile's terminal README.

The full operating-system update is intentionally `omarchy update`, not a raw
`pacman -Syu`: Omarchy owns snapshots and migrations around that operation.
