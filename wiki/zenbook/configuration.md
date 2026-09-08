# Configuration and restore map

This map answers three questions for every maintained feature: which file is
the source of truth, how it is applied, and where recovery starts.

| Area | Source of truth | Apply | Verify | Recovery |
|---|---|---|---|---|
| Monitor | [monitors.lua](../../profiles/zenbook-um3406ka/monitors.lua) | `scripts/bootstrap.sh --profile zenbook-um3406ka --no-vpn --no-terminal` | [display tests](../evidence/display-tests.md) and `hyprctl monitors all` | Latest `~/.local/state/omarchy-profiles/zenbook-um3406ka/backups/*/monitors.lua` |
| Packages | Native Omarchy package set plus required [voice-npu.txt](../../profiles/zenbook-um3406ka/packages/voice-npu.txt); optional [diagnostics.txt](../../profiles/zenbook-um3406ka/packages/diagnostics.txt) | Bootstrap installs the required NPU runtime; diagnostics remain explicit | [diagnostics](../evidence/diagnostics.md), `pacman -Q` | Packages are additive; remove only after a dependency review |
| Voice | Native Omarchy installer plus `voice/apply.sh`; Lemonade FLM NPU model | Bootstrap, or `voice/apply.sh --apply` for an existing native install | `voice/apply.sh --check`, `voice/doctor.sh` | `voice/apply.sh --rollback`; model cleanup and legacy migration are separate |
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
