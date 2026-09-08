# Repository index and search map — 2026-09-08

This file is the durable search map for the Zenbook system. It records where to look first for each component and which evidence belongs in this repository. It is an index, not a claim that private repository contents are public or that an assistant retains knowledge outside the checked-in files.

## Repository inventory

The authenticated GitHub inventory was checked on 2026-09-08 with `gh repo list shubinlab --limit 100`. The repositories were grouped by purpose before this project was expanded:

| Area | Best place to search first | What is reused here |
|---|---|---|
| Omarchy, Hyprland, monitor rules and display incidents | `zenbook-omarchy` and official Omarchy/Hyprland issue trackers | User configuration, reproducible runs, incident records and rollback notes |
| Zenbook firmware, ACPI, lid and power | private Zenbook audit repository | Baseline-first method, evidence gates and firmware caution |
| AMD thermal, NVMe and power experiments | public Zenbook verification pack | Verify gates, rollback, thermal measurements and APST as a hypothesis |
| Audio, microphone and input health | private voice-input repository | Health gates and separation of raw user data from reports |
| OSINT source tracking | private OSINT inventory repository | Source date, acquisition method, scope, caveat and claim status |
| Backups, CI and publication checks | private backup/CICD repository | Fail-closed verification and separation of evidence from payload |
| Dotfiles and workstation defaults | private dotfiles repository | User-level configuration conventions |

Private repository names and contents are intentionally not copied into this public project. The authenticated inventory and this mapping are the record of where to search; the public project remains the single reviewable result for this machine.

## Component search order

| Component | Local evidence first | Then check vendor/community sources | Useful search terms |
|---|---|---|---|
| External display | `config/monitors.lua`, `docs/INCIDENT-*`, protected telemetry | Omarchy monitor manual, Omarchy issues, Hyprland issues, LG manual | `DP-1`, `scale`, `bitdepth`, `vrr`, `DPMS`, `preferred` |
| AMD display/GPU | kernel journal, `lspci -k`, Mesa/AMDGPU package versions | AMD kernel docs, Arch packages, AMDGPU/Hyprland issue trackers | `amdgpu`, `DC`, `VRR`, `10-bit`, `Ryzen AI 7 350` |
| ASUS firmware/ACPI | BIOS version, ACPI journal, battery and lid state | ASUS UM3406KA support, ASUS Linux community, kernel ACPI reports | `UM3406KA`, `BIOS 306`, `lid`, `asus_wmi`, `asus_armoury` |
| USB-C dock and DisplayPort path | `lsusb -t`, DRM connectors, link speed and mode matrix | JSAUX product/FAQ, Steam Deck and Linux dock reports | `JSAUX RGB`, `USB-C DP Alt Mode`, `VRR`, `RTL8153` |
| Ethernet | interface driver, link, errors, gateway loss | ArchWiki Ethernet, kernel `r8152`, Realtek firmware package | `r8152`, `RTL8153`, `Tx timeout`, `USB autosuspend` |
| Wi-Fi/Bluetooth | PCI/USB IDs, kernel driver and association test | kernel wireless docs, linux-firmware, MediaTek community | `MT7922`, `mt7921e`, `btusb`, `firmware` |
| NVMe/Btrfs | `nvme list`, SMART, Btrfs device stats and I/O test | Western Digital support, fwupd/LVFS, WD community | `SN850X`, `620361WD`, `APST`, `Btrfs` |
| Camera/audio | V4L2 and ALSA/PipeWire health gates | kernel UVC/ALSA docs, PipeWire and WirePlumber issues | `uvcvideo`, `snd`, `PipeWire`, `RTKit` |
| Input devices | USB descriptors, HID journal and per-device isolation | kernel HID reports and vendor support | `usbhid`, `interrupt endpoint`, `306f:1234` |

## Evidence rules for future entries

1. Record the exact local command, timestamp and session condition in a run file.
2. Mark every conclusion as `confirmed`, `conditional`, `anecdotal` or `not reproduced`.
3. For vendor/community material, record publication date and use a two-month window ending on the audit date unless an older primary document is required for context.
4. Keep raw host identifiers, network addresses, serials, raw journals and user media outside the public repository.
5. Update the component report and this index together when a new device or failure mode is found.
6. Use the Omarchy user configuration under `~/.config`; do not modify `/usr/share/omarchy`.
