# Native Google desktop apps

The separate `scripts/gmail.sh` installer adds the lightweight native GNOME
clients used for Google services:

- `gnome-control-center` — Online Accounts settings;
- `geary` — lightweight Gmail client;
- `gnome-calendar` — calendar client;
- `gnome-contacts` — contacts client.

Install or verify them with:

```bash
bash scripts/gmail.sh
bash scripts/gmail.sh --check
```

The installer uses Omarchy's native package helper and does not change Google
accounts, passwords or tokens. Existing Google Online Accounts remain the
source for mail, calendar and contacts authorization. KDrive is separate: its
native Arch archive and checksum are published in the GitHub Release
`kdrive-3.8.7.1-native-arch` and are handled by `scripts/kdrive.sh` on the
`feature/kdrive-installer` branch.
