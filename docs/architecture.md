# Architecture

The repository is split into a stable engine, reusable documentation and
machine profiles.

```text
install.sh                 short GitHub entry point
scripts/bootstrap.sh       profile loader and idempotent apply engine
profiles/<id>/              declarative packages, monitor rules and extensions
tools/                      read-only checks and protected experiments
docs/                       stable design and operating guidance
runs/                       local ignored evidence only
```

`auto` selects a profile from a narrow DMI rule and falls back to `generic`.
An explicit `--profile` always wins. The generic profile installs only common
observability tools and does not enable a VPN, monitor override or telemetry.
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

Profiles are allowed to contain tested configuration and sanitized conclusions.
They must not contain credentials, serial numbers, EDID hashes, raw journals,
absolute home paths or live telemetry. New profiles should reuse the engine and
declare only capabilities they can justify with local evidence.
