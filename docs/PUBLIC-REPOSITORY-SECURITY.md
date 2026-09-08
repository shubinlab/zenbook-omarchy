# Public repository boundary

This repository is intended to be public. It stores declarative user
configuration, package names, reproducible test programs and aggregate results.

Keep these items local:

- AdGuard VPN login state, account data, location history and configuration;
- SSH/GPG keys, GitHub credentials, API tokens, cookies and license data;
- raw `hyprctl`, `lsusb`, EDID, journal, network and firmware dumps;
- monitor and USB serial numbers, hostnames, usernames, absolute home paths and
  private telemetry.

The bootstrap creates local backups and never commits them. Diagnostic runners
may write raw results under `runs/` for local analysis, but those artifacts are
Git-ignored. Publish conclusions in `docs/` after removing machine identifiers.

Before publishing, run a secret scan and inspect the staged diff. A successful
Git push does not prove that a new diagnostic artifact is safe to disclose.
