# Xerox WorkCentre 3025

`scripts/xerox-workcentre.sh` is a separate, repeatable installer for the
Xerox WorkCentre 3025 print and scan path on Omarchy. It installs the current
Arch packages for driverless IPP printing and WSD scanning, creates the
user-scoped SANE configuration, and makes the CUPS queue the default printer.

The repository does not contain the printer's IP address, hostname, serial,
VPN details, or diagnostic output. Supply the current network name or address
when running the installer:

```bash
./scripts/xerox-workcentre.sh --check --host xerox.local
./scripts/xerox-workcentre.sh --host xerox.local
```

The default targets are:

```text
IPP:  ipp://HOST/ipp/print
WSD:  http://HOST:8018/wsd/scan
Queue: xerox-workcentre-3025
```

Use explicit endpoints when the printer uses a non-default path:

```bash
./scripts/xerox-workcentre.sh \
  --printer-uri ipp://HOST/ipp/print \
  --scanner-url http://HOST:8018/wsd/scan
```

The installer never submits a print job. It verifies the CUPS queue and
default destination, and attempts a time-limited SANE device enumeration. A
SANE enumeration timeout is reported as a warning because the printer can be
reachable for printing while its WSD scan service is disabled or slow.

## What it installs

The package set is deliberately small:

| Package | Purpose |
|---|---|
| `cups` | IPP print service and queue management |
| `cups-filters` | Driverless CUPS filter support |
| `sane` | SANE scanner frontend and utilities |
| `sane-airscan` | Driverless eSCL/WSD backend |
| `simple-scan` | Omarchy launcher entry “Document Scanner” |

`ipp-usb`, vendor Windows drivers, and legacy XSane are not required for this
network-connected model. The upstream `sane-airscan` compatibility list marks
the WorkCentre 3025 as WSD-supported. Xerox documents the WSD scan workflow in
the [WorkCentre 3025 user guide](https://download.support.xerox.com/pub/docs/WC3025/userdocs/any-os/en_GB/WorkCentre_3025_UG_EN.pdf).

The installer writes only these user files:

```text
~/.config/sane/airscan.conf
~/.config/environment.d/90-sane-airscan.conf
```

Changed files are backed up under
`~/.local/state/omarchy-profiles/xerox-workcentre-3025/backups/`. No file under
`/usr/share/omarchy` is modified.

If the scanner is not listed after installation, enable WSD scanning in the
MFP's network scan settings, then log in again or start a new graphical
session so `SANE_CONFIG_DIR` from `environment.d` is inherited. The installer
does not claim that a WSD capability query or an actual scan succeeded merely
because the device was discovered.
