# Profiles

The repository is a reusable Omarchy bootstrap engine with optional host
profiles. The `generic` profile is the safe fallback: it installs only common
observability tools and leaves display, VPN and other user policy unchanged.

The `zenbook-um3406ka` profile contains the tested ASUS/LG/dock configuration,
package manifests and the voice extension. It is
selected automatically when DMI reports `UM3406KA`, or explicitly with
`--profile zenbook-um3406ka`.

Keep all narrative pages, inventories, experiments and source links in the
repository `wiki/`. Keep a machine profile executable: manifests, source
configuration, tests and user-facing extensions such as `voice/` or `terminal/`.

To add another machine, create a directory with:

- `profile.env` describing package manifests and optional capabilities;
- `packages/*.txt` for package names, split by purpose;
- a monitor file only when the profile owns a tested monitor layout;
- service and extension files under the profile directory;
- a matching section under `wiki/` for its inventory, configuration and evidence.

Profiles must not contain credentials, serials, EDID hashes, raw journals,
absolute home paths or live diagnostic data. The bootstrap backs up user files before
applying a profile.
