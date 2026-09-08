# Laptop and external-device audit

Last verified: 2026-09-08

## Current verdict

The current Omarchy session is healthy for the tested external-display workflow. The recommended profile is active:

- LG UltraGear on `DP-1` through the JSAUX dock;
- 2560×1440 at 239.970 Hz;
- `XRGB2101010` (10-bit), scale 1.6, color preset `srgb`;
- Hyprland VRR=true and DRM VRR active;
- DPMS=true, connector=connected, monitor not disabled;
- no Hyprland config errors or failed user services.

The independent 60-second steady-state run used 30 samples and passed every stability gate. It did not change display modes or DPMS.

The later 32-second post-fix control run held 143.991 Hz, scale 1.0, VRR on, DPMS on and no mirror in all eight samples. The current profile was then restored to 239.970 Hz and scale 1.6 through the Omarchy scaling helper; a reload retained both values. The earlier mode drift was caused by the Omarchy internal-monitor mirror toggle requesting the dock's preferred mode after reload.

## Device checks

| Area | Observation | Decision |
|---|---|---|
| AMD GPU | Radeon 840M/860M, `amdgpu`, power state D0, about 43 °C at idle | Keep current driver and power policy |
| CPU | AMD Ryzen AI 7 350, `amd-pstate-epp`, active mode, EPP `balance_performance` | Keep; do not import another governor blindly |
| USB-C dock | VIA USB2 hub at 480 Mb/s and USB3 hub at 10 Gb/s | Link is negotiated as expected |
| Dock downstream | Realtek USB Ethernet at 5 Gb/s; Logitech receivers at 12 Mb/s; LG controls at 12 Mb/s | No speed anomaly found |
| Display link | DP-1 connected, DRM link status Good, `vrr_capable=1` | Keep current DP Alt Mode path |
| DDC/CI | LG monitor responds; input is DisplayPort-1; brightness/contrast read successfully | DDC diagnostics are available; no OSD writes performed |
| Ethernet | Interface is up, zero RX/TX errors and zero TX drops in the current counters | Keep current wired path |
| NVMe/Btrfs | WD_BLACK SN850X live; Btrfs device errors all zero; NVMe around 38.9 °C | No storage tuning justified |
| Memory/swap | 30 GiB RAM, 60 GiB zram, no swap currently used | Keep current setup |
| Audio/video | PipeWire and WirePlumber active; webcam and HDMI audio enumerated | No change needed |
| Battery | 100%, charge end threshold 100%, AC power | Optional longevity improvement: consider 80% cap if desired |

## Findings that need attention

1. The kernel has an ACPI warning: `Unexpected lid state reported by firmware`. BIOS is `UM3406KA.306`, and the related Zenbook audit records BIOS/PD firmware as already checked. Do not add lid or suspend workarounds without a repeatable failure; the test runner must continue using a systemd inhibitor because the closed-lid path can suspend independently of Omarchy's stay-awake marker.
2. The diagnostic set `usbutils`, `ethtool`, `nvme-cli`, `smartmontools`, `fwupd`, `fio`, `stress-ng`, `drm-info`, `vulkan-tools`, `mesa-utils` and `inxi` is now installed through `omarchy-pkg-add`. The package database check is clean; these packages improve observability and do not replace the kernel drivers.
3. The battery is allowed to charge to 100%. An 80% threshold may reduce long-term wear while docked, but it changes battery behavior and should be enabled only when the owner wants that tradeoff.
4. The CachyOS pack's APST workaround was not copied. The current NVMe is healthy, Btrfs counters are clean and no resume/storage failure was reproduced, so a kernel command-line change would be unjustified.
5. The related CachyOS notes warn about conflicts between dynamic EPP and power-profiles-daemon. This host is already on AMD P-State EPP with `balance_performance`; no manual EPP or governor override is justified.

## Files

- Full hardware and component review: `profiles/zenbook-um3406ka/docs/components.md`
- Raw steady-state data remains local under the Git-ignored `runs/` directory.
- Display red-team methodology: `../../../docs/METHODOLOGY.md`
- Sanitized telemetry collector: `profiles/zenbook-um3406ka/tools/omarchy-monitor-telemetry.py`
