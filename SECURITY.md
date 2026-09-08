# Security and public-data policy

## Reporting a vulnerability

Do not put credentials, VPN databases, private keys, raw logs or exploit
details in a public issue. Use GitHub's private vulnerability reporting for
this repository when it is enabled. If that channel is unavailable, contact
the maintainer through the GitHub profile before publishing technical details.

## Public repository boundary

The repository may contain declarative configuration, package names,
reproducible test programs and aggregate results. It must not contain:

- AdGuard VPN login state, account data, location history or configuration;
- SSH/GPG keys, GitHub credentials, API tokens, cookies or license data;
- raw `hyprctl`, `lsusb`, EDID, journal, network or firmware dumps;
- monitor and USB serial numbers, hostnames, usernames, absolute home paths or
  private telemetry.

Diagnostic runners may write raw results under the ignored `runs/` directory.
The bootstrap creates local backups and never commits them.

Before publishing, stage the change and run `./tools/check-public-repo.sh` and
`git diff --cached --check`.

A clean check is evidence for the current tree; it does not replace review of
new diagnostic data.
