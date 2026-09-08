## What changed

<!-- Describe the user-visible or maintenance result. -->

## Evidence

- [ ] `./tools/ci-check.sh`
- [ ] `./tools/check-public-repo.sh` after staging
- [ ] `git diff --cached --check`
- [ ] Hardware-specific tests were run only when the affected hardware was available.

## Public-data review

- [ ] No credentials, private keys, VPN state, serials, EDID hashes, hostnames,
      absolute paths, raw journals or private diagnostic data are included.
- [ ] Any new claims identify their source, date and hardware-specific limits.
