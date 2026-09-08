# Configuration and restore map

This map answers three questions for every maintained feature: which file is
the source of truth, how it is applied, and where recovery starts.

| Area | Source of truth | Apply | Verify | Recovery |
|---|---|---|---|---|
| Monitor | [monitors.lua](../../profiles/zenbook-um3406ka/monitors.lua) | `scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-terminal` | [display tests](../evidence/display-tests.md) and `hyprctl monitors all` | Latest `~/.local/state/omarchy-profiles/zenbook-um3406ka/backups/*/monitors.lua` |
| Packages | [platform.txt](../../profiles/zenbook-um3406ka/packages/platform.txt), [diagnostics.txt](../../profiles/zenbook-um3406ka/packages/diagnostics.txt), [voice.txt](../../profiles/zenbook-um3406ka/packages/voice.txt), [terminal.txt](../../profiles/zenbook-um3406ka/packages/terminal.txt) | Bootstrap or `omarchy-pkg-add` | [diagnostics](../evidence/diagnostics.md), `pacman -Q` | Packages are additive; remove only after a dependency review |
| Telemetry | `services/monitor-telemetry.service` plus `tools/omarchy-monitor-telemetry.py` | `--enable-telemetry` | `systemctl --user status omarchy-monitor-telemetry` | `systemctl --user disable --now omarchy-monitor-telemetry` |
| Voice | `voice/apply.sh` and `voice/*` | `voice/apply.sh --apply` | `voice/apply.sh --check`, `voice/doctor.sh` | `voice/apply.sh --rollback` |
| Terminal | `terminal/apply.sh` and `terminal/*` | `terminal/apply.sh --apply` or bootstrap | `terminal-doctor` | `terminal/apply.sh --rollback` |
| Display experiments | `tools/run_vrr_redteam_safe.sh` and Python runners | Run from the graphical session | Local JSON/Markdown under ignored `runs/` | The safe wrapper restores the selected final mode |

The profile currently keeps the Zenbook's display, terminal and voice work
together, while the generic engine remains reusable. Do not copy a file into
`/usr/share/omarchy`; Omarchy stock files are inputs to the profile, not its
write target.

When a setting changes, update the source file, the verification command and
the relevant evidence record in the same change. Keep measured values in
[hardware.md](hardware.md), policies in source files, and raw observations in
ignored local run output.
