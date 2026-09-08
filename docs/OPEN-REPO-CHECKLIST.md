# Public repository checklist

Before publishing:

- Keep the sanitized Markdown reports and the reproducible runner.
- Do not commit private JSONL telemetry from `~/.local/state/omarchy/monitor-telemetry/`.
- Remove monitor serials, USB HID serials, EDID hashes, usernames, machine hostnames and local absolute paths from any new artifacts.
- Add a license and contribution guide.
- State the exact hardware/software versions and mark results as hardware-specific.
- Explain that the runner changes display modes and intentionally performs a DPMS cycle.
