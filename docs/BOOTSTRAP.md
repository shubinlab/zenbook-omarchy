# Clean-install bootstrap

The public repository contains the reproducible parts of this Zenbook profile:

- `config/monitors.lua` keeps the LG display at 2560×1440, 240 Hz, 10-bit,
  sRGB, VRR enabled and the user-selected scale `1.6` while preserving the
  Omarchy scaling variable;
- `config/packages-platform.txt` records the kernel, firmware, graphics,
  network, Bluetooth and audio stack expected by this hardware;
- `config/packages-diagnostics.txt` lists the diagnostic and display tools used
  during the audit;
- `install/bootstrap.sh` installs those packages through `omarchy-pkg-add`,
  applies the monitor rule with a timestamped backup, optionally enables local
  telemetry, connects an existing AdGuard VPN session, and optionally runs
  `omarchy update`.

The script does not contain or copy AdGuard credentials, VPN databases, tokens,
private keys, serial numbers or raw machine telemetry. It also does not edit
`/usr/share/omarchy`; user configuration belongs under `~/.config`.

For a machine where AdGuard VPN CLI is already installed and logged in, update
the repository and apply the profile in one line:

```bash
repo="$HOME/zenbook-omarchy"; if [ -d "$repo/.git" ]; then git -C "$repo" pull --ff-only; else git clone https://github.com/shubinlab/zenbook-omarchy.git "$repo"; fi && "$repo/install/bootstrap.sh" --vpn --update-system
```

To select a particular AdGuard location without saving it in Git, prefix the
same command with `ADGUARD_VPN_LOCATION=COUNTRY_OR_CITY`.

On a clean system without the CLI, install the official release first in the
same shell, complete the one-time login interactively, then run the bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/HEAD/scripts/release/install.sh | sh -s -- -v && adguardvpn-cli login && repo="$HOME/zenbook-omarchy"; git clone https://github.com/shubinlab/zenbook-omarchy.git "$repo" && "$repo/install/bootstrap.sh" --vpn --update-system
```

That installer command is the one published by AdGuard. It installs the
official CLI; this repository only detects it and invokes its documented
`status`, `connect` and optional `update` commands. The login step is never
automated and no account data belongs in this repository.

Use `--update-vpn-cli` when you explicitly want the installed AdGuard CLI to
update itself. Use `--enable-telemetry` only when local five-second monitor
telemetry is wanted; its JSONL data remains under
`~/.local/state/omarchy/monitor-telemetry/` and is ignored by Git.

The full operating-system update is intentionally `omarchy update`, not a raw
`pacman -Syu`: Omarchy owns snapshots and migrations around that operation.
