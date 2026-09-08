# Bootstrap

The repository has one small engine and optional profiles. `generic` is the
portable fallback: it installs common diagnostic tools and leaves monitor, VPN
and unrelated user policy unchanged. A known machine can supply a profile with
tested monitor, package, service and extension files.

The shortest command clones or updates the repository, selects a profile from
DMI when possible, and runs the stages in safe order:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

The default order is VPN, simple display settings, profile packages, native
Voxtype, terminal settings and finally the supported `omarchy update`. Native
Voxtype's first-run confirmation remains the only expected interactive prompt.
The same raw entry point can run one stage with `--stage vpn|display|packages|voice|terminal|update`.

Use this first to validate the published repository without changing the
system:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

Useful explicit choices after the repository has been cloned are:

```bash
~/zenbook-omarchy/scripts/bootstrap.sh --profile generic --check
~/zenbook-omarchy/scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-monitor
~/zenbook-omarchy/scripts/bootstrap.sh --profile zenbook-um3406ka --update-vpn-cli
```

Equivalent standalone stage wrappers are in `scripts/install-*.sh`. They are
thin aliases over the same engine, so there is one implementation and one
rollback/checking policy.

VPN is profile-controlled and opt-in for generic machines. The Zenbook profile
can install the official AdGuard CLI and connect it before an update, but it
never stores account data in Git. Set `ADGUARD_VPN_LOCATION` for one run when
needed. `--no-vpn` always wins over a profile default.

The bootstrap applies user configuration under `~/.config`, creates a backup
under `~/.local/state/omarchy-profiles/` before replacing a monitor file, and
does not edit `/usr/share/omarchy`.

On the matching Zenbook profile, the bootstrap also runs Omarchy's native
Voxtype installer when first-run user setup is absent, then applies the
user-scoped Zenbook voice policy and terminal extension. This is one
clean-install flow; no separate native voice command is required. Skip voice
with `--no-voice` or the terminal extension with `--no-terminal`; apply or
rollback either policy directly with the commands in its profile README.

The full operating-system update is intentionally `omarchy update`, not a raw
`pacman -Syu`: Omarchy owns snapshots and migrations around that operation.
