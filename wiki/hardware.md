# Hardware overview

The canonical detailed inventory is [Zenbook hardware](zenbook/hardware.md). This page connects each device to its Linux driver, its user-visible function and its detailed component page.

| Component | Observed hardware | Linux path | Page |
|---|---|---|---|
| Platform | ASUS Zenbook 14 OLED UM3406KA, BIOS `UM3406KA.306` | DMI, ACPI, ASUS WMI | [firmware and power](components/firmware-power.md) |
| CPU | AMD Ryzen AI 7 350, 8C/16T | `amd-pstate-epp`, `k10temp` | [compute](components/compute.md) |
| GPU | AMD Krackan Radeon 840M/860M, observed as Radeon 860M | `amdgpu`, Mesa, RADV | [compute](components/compute.md) |
| NPU | AMD XDNA / `amdxdna` | XDNA kernel driver | [compute](components/compute.md) |
| Internal panel | `eDP-1` | DRM/KMS | [display](components/display.md) |
| External panel | LG UltraGear on `DP-1` | USB-C/USB4 DP Alt Mode, DRM/KMS, EDID | [display](components/display.md) |
| Dock | JSAUX RGB Docking Station | xHCI, USB hubs, DP Alt Mode | [dock and USB](components/dock-usb.md) |
| Storage | WD_BLACK SN850X 2000GB, firmware `620361WD` | `nvme`, dm-crypt, Btrfs | [storage](components/storage.md) |
| Wi-Fi | MediaTek MT7922 | `mt7921e`, linux-firmware | [network](components/network.md) |
| Bluetooth | MediaTek Bluetooth controller | `btusb`, `btmtk` | [network](components/network.md) |
| Ethernet | Realtek RTL8153 downstream of dock | `r8152` | [network](components/network.md) |
| Audio | AMD ACP, Realtek codec, Radeon HDMI audio | ALSA, SOF, PipeWire, WirePlumber | [media and input](components/media-input.md) |
| Camera | USB UVC camera | `uvcvideo`, V4L2 | [media and input](components/media-input.md) |
| Sensors | AMD Sensor Fusion Hub and ambient-light sensor | `amd_sfh`, HID sensor stack | [firmware and power](components/firmware-power.md) |
| Input | Logitech receivers, dock HID, keyboard/touchpad | `usbhid`, Logitech HID, libinput | [dock and USB](components/dock-usb.md) |

Hardware-specific facts must be updated in the canonical profile file first;
the wiki pages are the explanatory index.
