# Repository map

This file records where to search first for each system component and which
evidence belongs in this public project. It combines the earlier repository
cross-check and search index. Private repositories are not copied here.

## Component search order

| Component | Local evidence first | Then check vendor/community sources | Useful terms |
|---|---|---|---|
| External display | `profiles/zenbook-um3406ka/monitors.lua`, `profiles/zenbook-um3406ka/docs/display-incident.md`, protected telemetry | Omarchy monitor manual, Omarchy issues, Hyprland issues, LG manual | `DP-1`, `scale`, `bitdepth`, `vrr`, `DPMS`, `preferred` |
| AMD display/GPU | kernel journal, `lspci -k`, Mesa/AMDGPU versions | AMD kernel docs, Arch packages, AMDGPU/Hyprland issues | `amdgpu`, `DC`, `VRR`, `10-bit` |
| ASUS firmware/ACPI | BIOS version, ACPI journal, battery and lid state | ASUS UM3406KA support, kernel ACPI reports | `UM3406KA`, `BIOS 306`, `lid`, `asus_wmi` |
| USB-C dock and DisplayPort | `lsusb -t`, DRM connectors, link speed and mode matrix | JSAUX product/FAQ and Linux dock reports | `JSAUX RGB`, `DP Alt Mode`, `VRR`, `RTL8153` |
| Ethernet | interface driver, link, errors, gateway loss | ArchWiki Ethernet, kernel `r8152`, Realtek firmware | `r8152`, `RTL8153`, `Tx timeout` |
| Wi-Fi/Bluetooth | PCI/USB IDs, kernel driver and association test | kernel wireless docs, linux-firmware, MediaTek sources | `MT7922`, `mt7921e`, `btusb` |
| NVMe/Btrfs | `nvme list`, SMART, Btrfs stats and I/O test | Western Digital support, fwupd/LVFS, WD community | `SN850X`, `APST`, `Btrfs` |
| Camera/audio | V4L2 and ALSA/PipeWire health gates | kernel UVC/ALSA docs, PipeWire and WirePlumber issues | `uvcvideo`, `snd`, `PipeWire`, `RTKit` |
| Input devices | USB descriptors, HID journal and per-device isolation | kernel HID reports and vendor support | `usbhid`, `interrupt endpoint` |

## Reused practices

The earlier private Zenbook, CachyOS, voice-input, backup/CI, OSINT and
dotfiles projects contributed methods rather than copied private data:

- baseline first, with evidence before firmware, kernel or power changes;
- explicit verify gates, rollback paths and thermal/power experiments;
- raw user media and telemetry outside Git;
- source date, acquisition method, scope, caveat and claim status;
- fail-closed publication checks and user-level configuration conventions.

Every display experiment blocks Omarchy idle and systemd idle/sleep/lid actions.
A sample is invalid when the session is idle or locked, the inhibitor
disappears, DP-1 disconnects, DPMS changes unexpectedly or the monitor is
disabled.

## Future entries

1. Record the exact local command, timestamp and session condition in a local
   run file.
2. Mark the conclusion and publish only an aggregate, sanitized result.
3. Update the component report and this map together when a device or failure
   mode is added.
4. Keep raw host identifiers, network addresses, serials, journals and user
   media outside the public repository.
5. Keep Omarchy user configuration under `~/.config`; do not modify
   `/usr/share/omarchy`.
