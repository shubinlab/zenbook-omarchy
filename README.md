# zenbook-omarchy

Reusable Omarchy bootstrap scripts, optional machine profiles and sanitized
diagnostic evidence. The repository is designed to help any Omarchy user start
from a safe generic profile and add a tested hardware profile only when one
exists.

## One command

Validate the published repository without changing the system:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash -s -- --check
```

Install or update the selected profile:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/install.sh | bash
```

`auto` selects a known profile from DMI and uses `generic` otherwise. The
generic profile installs common observability tools and does not change the
monitor, VPN or telemetry policy. The Zenbook profile enables its tested
monitor and package settings; its VPN behavior can be disabled with
`--no-vpn`.

The bootstrap uses Omarchy's package and update helpers, backs up user files
before replacing them, and never edits `/usr/share/omarchy`. Credentials,
device serials, EDID hashes and raw telemetry stay out of Git.

## Repository layout

- [`scripts/`](scripts/) contains the reusable bootstrap and user-scoped
  extensions.
- [`profiles/`](profiles/) contains capability declarations and hardware
  specific evidence.
- [`tools/`](tools/) contains read-only checks and protected experiments.
- [`docs/`](docs/) contains the stable architecture, bootstrap and test
  guidance.

Start with the [documentation map](docs/README.md), [profile guide](profiles/README.md)
and [architecture](docs/architecture.md). The current Zenbook profile is
documented in [profiles/zenbook-um3406ka/README.md](profiles/zenbook-um3406ka/README.md).

## Native voice extension

The Zenbook profile also contains a user-scoped Omarchy voice extension. It
preserves Omarchy's packaged bindings and stock files, changes only the
user-session default microphone (with rollback backup), and keeps the
physical speaker routing unchanged while applying PipeWire and Voxtype
settings:

```bash
./profiles/zenbook-um3406ka/voice/apply.sh --check
./profiles/zenbook-um3406ka/voice/apply.sh --apply
./profiles/zenbook-um3406ka/voice/doctor.sh
```

See the [voice profile](profiles/zenbook-um3406ka/voice/README.md) for its
rollback contract. Contribution and security rules are in
[CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
