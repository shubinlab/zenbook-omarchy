# Packages: stock, profile and current state

**Snapshot:** 2026-09-08. Versions below are observed on this host and will
change with Omarchy/Arch updates.

## How “default” is defined

The installed Omarchy tree exposes the stock package catalogs at:

- `/usr/share/omarchy/install/omarchy-base.packages` — 147 names;
- `/usr/share/omarchy/install/omarchy-other.packages` — 59 names used for
  hardware/ISO availability and optional paths.

These catalogs are the comparison baseline, not a claim that every conditional
hardware package is installed on every machine. Omarchy's package helper uses
`pacman -S --needed`, so profile additions are idempotent.

## Profile-declared platform stack

| Group | Packages | Current state |
|---|---|---|
| Kernel/firmware | `linux`, `amd-ucode`, `linux-firmware`, `linux-firmware-amdgpu`, `linux-firmware-mediatek`, `linux-firmware-realtek` | Installed; firmware subpackages are dependency-installed |
| Graphics | `mesa`, `vulkan-radeon` | Installed; Mesa is dependency-installed, RADV explicit |
| Audio | `pipewire`, `wireplumber`, `sof-firmware` | Installed |
| Connectivity | `networkmanager`, `bluez`, `bluez-utils`, `power-profiles-daemon` | Installed |

## Profile-declared diagnostics

| Package | Current version | Install reason | Purpose |
|---|---:|---|---|
| `usbutils` | `019-1` | explicit | USB IDs and topology |
| `ethtool` | `1:7.1-1` | explicit | Ethernet link/counters |
| `nvme-cli` | `2.16-2` | explicit | NVMe inventory and health |
| `smartmontools` | `7.5-1` | explicit | SMART access |
| `fwupd` | `2.1.7-1` | explicit | Firmware inventory |
| `fio` | `3.42-1` | explicit | Controlled storage I/O |
| `stress-ng` | `0.22.00-1` | explicit | Short protected load tests |
| `drm-info` | `2.10.0-1` | explicit | DRM connector/mode data |
| `vulkan-tools` | `1.4.357.0-1` | explicit | Vulkan/GPU inventory |
| `mesa-utils` | `9.0.0-7` | explicit | OpenGL/Mesa checks |
| `inxi` | `3.3.41.1-1` | explicit | Sanitized system inventory |
| `ddcutil` | `2.2.7-1` | explicit | DDC/CI display queries |
| `i2c-tools` | `4.4-4` | dependency | I2C/DDC support |
| `libinput` | `1.31.3-1` | dependency | Input diagnostics |
| `lm_sensors` | `3.6.2-1` | dependency | Sensor readings |
| `mpv` | `0.41.0-6` | explicit | Controlled media/display checks |
| `wayland-utils` | — | declared, missing | Wayland compositor queries; available in repository but not installed |

## User-facing additions

| Package or component | State | Why it exists |
|---|---|---|
| `voxtype-bin` `1.0.1-1` | explicit, installed | Native voice transcription |
| `wtype` `0.4-2` | explicit, installed | Voxtype keyboard output |
| `chafa` `1.18.2-2` | explicit, installed | Terminal image previews |
| ble.sh | profile download, not pacman | Bash ghost text and fzf integration |

## Explicit local additions outside the stock catalogs

The current explicit package database also contains `omarchy`,
`omarchy-settings`, `omarchy-keyring`, `efibootmgr`, `mkinitcpio`, `sudo`,
`amd-ucode`, the diagnostic packages above, `voxtype-bin`, `wtype` and
`chafa`. Some are Omarchy provisioning/runtime packages and some are this
profile's additions; the package manifests, Omarchy's native Voxtype
installer and `pacman -Qi` install reason are the authority. Do not remove a
package solely because it is absent from the two stock catalog files.

The source manifests are [platform.txt](../../profiles/zenbook-um3406ka/packages/platform.txt),
[diagnostics.txt](../../profiles/zenbook-um3406ka/packages/diagnostics.txt) and
[terminal.txt](../../profiles/zenbook-um3406ka/packages/terminal.txt).
`voxtype-bin` and `wtype` are intentionally not duplicated in a repository
manifest: the clean-install flow lets Omarchy's native Voxtype installer own
their package transaction.

The complete explicit package table is regenerated from the live package
database in [package-inventory.md](package-inventory.md).
