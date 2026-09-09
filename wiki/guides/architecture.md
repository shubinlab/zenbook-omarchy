# Architecture

The repository is split into a stable engine, reusable documentation and
machine profiles.

```text
install.sh                 short GitHub entry point and bootstrap
scripts/bootstrap.sh       staged profile orchestrator and apply engine
scripts/install-*.sh       standalone aliases for one safe stage
scripts/doctor.sh           read-only installed-profile health check
scripts/install-diagnostics.sh optional audit package stage
scripts/repair-voice-legacy.sh  explicit migration for older voice setups
profiles/<id>/              declarative packages, monitor rules and extensions
tools/                      read-only checks and protected experiments
wiki/                       all stable guides, inventories and evidence
runs/                       local ignored evidence only
```

`auto` selects a profile from a narrow DMI rule and falls back to a no-op
`generic` profile. An explicit `--profile` always wins. Diagnostics are
installed only through the explicit optional stage.
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
apply the simple tested display override, verify required packages, invoke
Omarchy's native Voxtype path, apply the terminal extension and run doctor.
Diagnostics and `omarchy update` are explicit optional menu actions. Individual
components are selected through the thin local launcher; the underlying stage
engine remains an internal implementation detail.

Profiles are allowed to contain tested configuration and sanitized conclusions.
They must not contain credentials, serial numbers, EDID hashes, raw journals,
absolute home paths or live diagnostic data. New profiles should reuse the engine and
declare only capabilities they can justify with local evidence.

Within a hardware profile, `hardware.md` is the canonical inventory and
`configuration.md` is the user-facing restore map. Evidence files explain why
a value is trusted; they do not replace the inventory or source configuration.
