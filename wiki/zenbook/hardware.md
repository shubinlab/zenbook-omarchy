# Hardware and connected devices

This is the canonical hardware record for the tested Zenbook profile. Values
come from local inventory and protected experiments. A future audit should
update this page first, then link detailed evidence from `wiki/evidence/`.

## Laptop

| Property | Observed value |
|---|---|
| System | ASUS Zenbook 14 OLED UM3406KA |
| BIOS | `UM3406KA.306`, dated 2026-07-23 in the vendor record |
| CPU | AMD Ryzen AI 7 350, 8 cores / 16 threads |
| CPU policy | `amd-pstate-epp`, active mode, EPP `balance_performance` |
| GPU | Radeon 860M / Krackan; inventory tools also reported 840M/860M labels; kernel `amdgpu`, power state D0 |
| NPU | AMD XDNA2 device with `amdxdna`; Lemonade FLM Whisper route installed and verified on `device=npu` |
| Memory | About 30 GiB available; 60 GiB zram observed; swap unused during audit |
| Internal display | `eDP-1`; closed during the external-display workflow |
| Storage | WD_BLACK SN850X 2000 GB, firmware `620361WD`, Btrfs |
| Battery | 67.4 Wh full charge against 75 Wh design; approximately 89.9% reported condition; AC online |

## Display path

```text
Zenbook USB-C/USB4
  -> JSAUX RGB Docking Station
     -> DisplayPort
        -> LG UltraGear on DP-1
```

| Property | Observed value |
|---|---|
| Connector | `DP-1`, connected, DRM link status `Good` |
| Mode | `2560x1440@239.970 Hz` |
| Pixel format | `XRGB2101010`, 10-bit |
| Color | Hyprland `cm=srgb`; DRM colorspace `Default` |
| Scale | `1.6` through `omarchy_monitor_scale` |
| VRR | Hyprland per-output `vrr=1`; DRM VRR active in protected runs |
| Power state | DPMS on; monitor enabled; no mirror |
| DDC/CI | LG input and brightness/contrast respond; no OSD writes were automated |
| Alternate control run | `2560x1440@143.991 Hz`, scale 1.0, 10-bit, VRR on, DPMS on |

The persistent rule is [monitors.lua](../../profiles/zenbook-um3406ka/monitors.lua). The `cm=srgb` choice is
deliberate: the local A/B showed `cm=auto` selecting a wide/BT2020 path at
10-bit, which caused the pale SDR image. HDR remains an application-dependent
option; the decision and evidence are in [HDR evidence](../evidence/hdr.md).

## Dock and downstream devices

| Device or path | Observed detail |
|---|---|
| Dock family | JSAUX RGB Docking Station; exact commercial revision unconfirmed |
| USB2 hub | VIA Labs, 480 Mb/s, observed ID `2109:2822` |
| USB3 hub | VIA Labs, 10 Gb/s, observed ID `2109:0822` |
| Ethernet | Realtek RTL8153, USB 5 Gb/s, in-tree `r8152`, 1 Gb/s full duplex |
| Monitor controls | LG USB HID/control device, observed ID `043e:9a8a` during DPMS recovery |
| USB HID warning | `306f:1234`, product `Wushi0.01S60`, one malformed interrupt-endpoint report at boot |
| Input | Logitech keyboard/mouse receivers observed downstream |
| Audio/video | LG microphone, HDMI audio and webcam enumerated; UVC/ALSA/PipeWire path |

The USB HID warning was not reproduced during protected display or component
runs. If input glitches return, isolate nonessential USB2 devices one at a
time before considering a kernel quirk.

## Network, audio and firmware

| Area | Observed value and current decision |
|---|---|
| Wi-Fi | MediaTek MT7922 with `mt7921e`; firmware path is kernel + linux-firmware |
| Bluetooth | MediaTek controller through `btusb`; controller powered and pairable |
| Audio | PipeWire and WirePlumber active; analog and HDMI routes enumerated |
| Firmware | Keep Arch/Omarchy firmware and in-tree drivers; no AMDGPU-PRO, DKMS Ethernet driver or separate ASUS Linux driver justified |
| Power | Keep current AMD P-State policy; do not add APST or governor overrides without a reproduced failure |

## Evidence and limits

- [Audit](../evidence/audit.md) contains the system-level verdict and device checks.
- [Component audit](../evidence/components.md) contains test methods and warnings.
- [Diagnostics](../evidence/diagnostics.md) records package versions and staged tests.
- [Vendor research](../evidence/vendor-research.md) records source scope and claim status.
- Raw runs stay in the ignored `runs/` directory. No EDID hash, serial number,
  hostname, credential or raw journal belongs in this file.
- Wi-Fi throughput, Bluetooth pairing, speaker playback, NVMe SMART self-test,
  GPU benchmark and deliberate suspend testing remain open.
