# Profiles

The repository is a reusable Omarchy bootstrap engine with optional host
profiles. The `generic` profile is the safe fallback: it installs only common
observability tools and leaves display, VPN and telemetry policy unchanged.

The `zenbook-um3406ka` profile contains the tested ASUS/LG/dock configuration,
package manifests, optional telemetry service and voice extension. It is
selected automatically when DMI reports `UM3406KA`, or explicitly with
`--profile zenbook-um3406ka`.

To add another machine, create a directory with:

- `profile.env` describing package manifests and optional capabilities;
- `packages/*.txt` for package names, split by purpose;
- a monitor file only when the profile owns a tested monitor layout;
- service and extension files under the profile directory;
- stable documentation under `docs/`.

Profiles must not contain credentials, serials, EDID hashes, raw journals,
absolute home paths or live telemetry. The bootstrap backs up user files before
applying a profile.
