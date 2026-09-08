<div align="center">

# Operations

**Check first. Change one thing. Keep a way back.**

[Bootstrap](../guides/bootstrap.md) · [Doctor](../../scripts/doctor.sh) · [Recovery](../guides/recovery.md)

</div>

## The three commands to remember

```bash
# Is the repository/install definition valid?
./scripts/bootstrap.sh --profile zenbook-um3406ka --check

# Is the live system healthy?
./scripts/doctor.sh --profile zenbook-um3406ka

# Restore the tested profile
./scripts/bootstrap.sh --profile zenbook-um3406ka
```

## Choose the smallest action

| I need to… | Run |
|---|---|
| Rebuild everything | `./scripts/bootstrap.sh --profile zenbook-um3406ka` |
| Connect VPN only | `./scripts/install-vpn.sh --profile zenbook-um3406ka` |
| Restore display only | `./scripts/install-display.sh --profile zenbook-um3406ka` |
| Verify required package set | `./scripts/install-packages.sh --profile zenbook-um3406ka` |
| Install native Wayland Bitwarden | `./scripts/install-bitwarden.sh --profile zenbook-um3406ka` |
| Install optional diagnostics | `./scripts/install-diagnostics.sh --profile zenbook-um3406ka` |
| Repair/check native voice | `./scripts/install-voice.sh --profile zenbook-um3406ka` or `voice/doctor.sh` |
| Repair an older voice setup | `./scripts/repair-voice-legacy.sh --check` then `--apply` |
| Restore terminal settings | `./scripts/install-terminal.sh --profile zenbook-um3406ka` |
| Run Omarchy update | `./scripts/install-update.sh --profile zenbook-um3406ka` |
| Test monitor/VRR safely | [Protected experiment](experiments.md) |

## What doctor checks

`doctor` is read-only and reports a final `RESULT PASS` or `RESULT FAIL`:

- Omarchy version and command availability;
- native Voxtype mode, language, output, OSD, feedback and service;
- Lemonade FLM model readiness on `device=npu` and telemetry state;
- physical PipeWire microphone and available output sink;
- terminal, Foot Sixel, ble.sh/fzf and managed shortcut;
- native Bitwarden packages, launcher, rbw policy and managed password hotkey;
- Bitwarden onboarding completion when the optional final stage was accepted;
- Hyprland configuration errors;
- AdGuard VPN status when the selected profile enables it.

## Recovery rule

Do not reset all of Omarchy to fix one profile setting. The repository changes
only user-level files and creates backups under:

```text
~/.local/state/omarchy-profiles/
```

Use the [recovery guide](../guides/recovery.md) to restore the latest voice,
terminal or monitor backup. Never edit `/usr/share/omarchy`; it is the stock
package-owned layer.
