# Native kDrive for Arch/Omarchy

This repository carries a separate installer for the locally verified native
Arch build of Infomaniak kDrive `3.8.7.1`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/scripts/kdrive.sh | bash
```

The installer downloads the pinned GitHub Release asset, verifies its SHA-256
checksum, checks both ELF binaries with `ldd`, and installs only under the
current user's home directory:

- `~/.local/share/kdrive/3.8.7.1/` — application files;
- `~/.local/bin/kDrive` and `kDrive_client` — launchers;
- `~/.local/share/applications/kDrive.desktop` — desktop entry.

It does not edit `/usr`, `/usr/share/omarchy`, system services or the general
Omarchy bootstrap. The native build uses the host's Arch Qt/OpenSSL/cURL,
libsecret and libzip libraries; missing runtime libraries are reported before
installation completes.

## Check and remove

```bash
bash scripts/kdrive.sh --check
bash scripts/kdrive.sh --uninstall
```

For an offline install, point the installer at the verified archive:

```bash
KDRIVE_ARCHIVE=/path/to/kdrive-3.8.7.1-native-arch.tar.zst \
  bash scripts/kdrive.sh --install
```

The archive is the native x86_64 build from upstream tag `3.8.7`, with Linux
Crashpad/Sentry initialization disabled and without bundled `libldap`,
`liblber`, `libsasl2` or Crashpad artifacts. This is an Arch/Omarchy
compatibility build, not an upstream-supported Arch package.
