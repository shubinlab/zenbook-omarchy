# Architecture

The repository is split into a stable engine, reusable documentation and
machine profiles.

```text
install.sh                 short GitHub entry point
scripts/bootstrap.sh       staged profile orchestrator and apply engine
scripts/install-*.sh       standalone aliases for one safe stage
profiles/<id>/              declarative packages, monitor rules and extensions
tools/                      read-only checks and protected experiments
wiki/                       all stable guides, inventories and evidence
runs/                       local ignored evidence only
```

`auto` selects a profile from a narrow DMI rule and falls back to `generic`.
An explicit `--profile` always wins. The generic profile installs only common
observability tools and does not enable a VPN or monitor override.
Hardware-specific behavior must be opt-in through a profile.

The design review rejected five failure modes:

1. A universal installer forcing a vendor VPN was changed to profile-controlled
   opt-in behavior.
2. Hardware facts in root documentation were moved into the producing profile.
3. Dated filenames were replaced with stable subject names; dates remain in
   evidence text where provenance matters.
4. Monitor changes without recovery were changed to timestamped user-state
   backups before installation.
5. Raw logs and host identifiers were kept out of Git through ignore rules and
   the public-repository check.

The default clean-install sequence is deliberately linear: connect the VPN,
apply the simple tested display override, install declared packages, invoke
Omarchy's native Voxtype path, apply the terminal extension and only then run
`omarchy update`. Each stage can be invoked independently through the main
installer's `--stage` option or its thin local wrapper.

Profiles are allowed to contain tested configuration and sanitized conclusions.
They must not contain credentials, serial numbers, EDID hashes, raw journals,
absolute home paths or live diagnostic data. New profiles should reuse the engine and
declare only capabilities they can justify with local evidence.

Within a hardware profile, `hardware.md` is the canonical inventory and
`configuration.md` is the user-facing restore map. Evidence files explain why
a value is trusted; they do not replace the inventory or source configuration.
