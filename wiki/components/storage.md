# Storage and encryption

The internal drive is a WD_BLACK SN850X 2000GB NVMe device:

| Layer | Current path |
|---|---|
| Device | `nvme0n1`, PCI `61:00.0`, kernel `nvme` |
| Firmware | `620361WD` |
| Boot | `nvme0n1p1`, 2 GiB VFAT mounted at `/boot` |
| Root/data | `nvme0n1p2`, LUKS encrypted, Btrfs inside |
| Swap | `zram0`, about 30.5 GiB, compressed; no disk swap observed |

The profile adds `nvme-cli`, `smartmontools`, `fwupd`, `fio` and Btrfs-aware
checks for observability. It does not flash firmware, enable an APST workaround
or alter the kernel command line. A temporary 512 MiB write/read/delete test
passed and Btrfs device error counters were zero in the audit.

SMART self-test and a long performance benchmark remain open because they have
different thermal, wear and power implications. See the [component audit](../evidence/components.md).
