# Package and validation results

Last verified: 2026-09-08

## Installation

Packages were installed through the native Omarchy command `omarchy-pkg-add`. The Omarchy wrapper delegates the actual transaction to `sudo pacman -S --needed`; no direct manual pacman command was used.

Installed diagnostic set:

```text
usbutils 019-1
ethtool 1:7.1-1
nvme-cli 2.16-2
smartmontools 7.5-1
fwupd 2.1.7-1
fio 3.42-1
stress-ng 0.22.00-1
drm-info 2.10.0-1
vulkan-tools 1.4.357.0-1
mesa-utils 9.0.0-7
inxi 3.3.41.1-1
```

Previously installed and reused: `ddcutil`, `i2c-tools`, `libinput` and `lm_sensors`.

`pacman -Dk` reported no database errors and no system or user failed units were found. All installed packages provide useful repeatable diagnostics, so none was removed.

## Staged tests

Stage 1 covered package integrity, USB topology, drivers, Ethernet link, fwupd inventory, GPU/DRM discovery, NVMe enumeration, a temporary fio workload and a protected 20-second CPU/RAM stress test.

- CPU/RAM stress-ng: 9 stressors passed, 0 failed; no suspend or lock occurred.
- fio temporary workload: read/write completed with zero I/O errors; the result is not treated as physical SSD throughput because the test used a temporary filesystem path and synchronous I/O.
- Ethernet: RTL8153 with in-tree `r8152`, firmware `rtl8153b-2`, 1 Gb/s full duplex, link detected.
- Wi-Fi: MT7922 with `mt7921e`, firmware timestamp `20260724143402`, currently no carrier because wired networking is active.
- NVMe: WD_BLACK SN850X 2000GB, firmware 620361WD; fwupd reports no available update. Direct SMART ioctl access is restricted in the agent sandbox, so the earlier Btrfs/error-counter checks remain the storage health evidence.
- GPU: AMDGPU/Mesa/RADV stack enumerated by `inxi`; the GPU is Radeon 860M/Krackan and the display is DP-1.

Stage 2 ran the full protected display matrix: 1080p/120, 1440p/120, 1440p/144 windowed and fullscreen, 1440p/240 fullscreen and 1440p/144 8-bit. Every phase reported the requested mode, 10-bit where requested, VRR true, DPMS on, connector connected and no harness anomalies. Three 144→120→240 cycles and DPMS off/on recovery also passed.

The runner now restores `FINAL_MODE = 2560x1440@239.97` in its cleanup path. A follow-up restore-check confirmed 240 Hz, scale 1.6, 10-bit, sRGB, VRR on, DPMS on and no mirror after the test.

## Color A/B result

The test held resolution, scale, bit depth and VRR constant while changing only the color management preset:

| Mode | Hyprland preset | DRM Colorspace | Link | VRR | Format |
|---|---|---|---|---|---|
| 240 Hz | `srgb` | `Default` | Good | on | XRGB2101010 |
| 240 Hz | `auto` | `BT2020_RGB` | Good | on | XRGB2101010 |
| 144 Hz | `auto` | `BT2020_RGB` | Good | on | XRGB2101010 |
| 144 Hz | `srgb` | `Default` | Good | on | XRGB2101010 |
| 240 Hz final | `srgb` | `Default` | Good | on | XRGB2101010 |

This isolates the pale SDR image to `cm=auto` selecting the `wide`/BT2020 path at 10-bit. Refresh rate did not change the color path. The persistent external rule now uses `cm = "srgb"`; DDC brightness 80, contrast 70 and hardware color preset `User 1` were unchanged.

The choice follows current Hyprland color-management documentation: `auto` selects sRGB for 8 bpc and wide gamut for 10 bpc, while `srgb` forces sRGB primaries. [Hyprland colors and colorspaces](https://wiki.hypr.land/configuring/core/monitors/colors/)

The separate HDR experiment confirmed that `cm=hdr` can engage PQ/BT2020 metadata on this path, with 603 cd/m² peak metadata, but it was restored immediately. The persistent decision and tradeoffs are recorded in [wiki/evidence/hdr.md](hdr.md).

## Current profile

```text
DP-1: 2560x1440@239.970 Hz
scale: 1.6 through omarchy_monitor_scale
format: XRGB2101010
cm: srgb
VRR: on
DPMS: on
mirror: none
```
