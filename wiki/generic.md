# Generic profile

This is the portable fallback for an Omarchy host without a matching tested
hardware profile. It makes no automatic changes; run the optional diagnostics
stage explicitly when an audit is intended.

Check it without changing the system:

```bash
./scripts/bootstrap.sh --profile generic --check
```

Use this profile as the starting point for a new machine. Add a new profile
directory when a monitor rule, package set or service has been tested on that
machine; do not broaden this fallback with assumptions about one vendor's
hardware.
