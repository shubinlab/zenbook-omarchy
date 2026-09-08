# Vendor and community research — 2026-09-08

Research window: 2026-07-08 through 2026-09-08, with older primary documentation retained where it defines the driver model. Local tests were run on the ASUS Zenbook 14 UM3406KA with an AMD Ryzen AI 7 350, Radeon 840M/860M, MediaTek MT7922, WD_BLACK SN850X and a JSAUX RGB docking station feeding an LG display through DisplayPort.

## Decisions

| Area | Decision | Confidence |
|---|---|---|
| External 1440p profile | Keep DP-1 at scale 1.6, 2560×1440, 240 Hz, 10-bit, `cm=srgb` and VRR=1; keep scale tied to `omarchy_monitor_scale` | Confirmed by local A/B and reload |
| Display driver | Keep the in-kernel `amdgpu` plus Mesa and Arch firmware stack | Confirmed fit for this system |
| AMDGPU-PRO | Do not install for desktop display; AMD's Linux download page targets supported Radeon Pro/professional packages and does not replace the Arch display stack here | Strong recommendation |
| ASUS driver package | No separate ASUS Linux driver is justified. BIOS 306 dated 2026-07-23 is already installed | Confirmed against local BIOS and ASUS support |
| Dock firmware | Do not run an old Windows updater. JSAUX says recent units ship with stable firmware and removed the old download link | Vendor guidance |
| Dock USB drivers | Use kernel xHCI, hub, UVC, HID and `r8152` drivers | Confirmed by local bindings |
| Wi-Fi/Bluetooth | Keep kernel `mt7921e` and `btusb` with linux-firmware | Confirmed by local bindings and kernel documentation |
| NVMe firmware | Do not flash from Linux without a matching official package and backup. Keep the observed 620361WD firmware for now | Conservative, evidence-based |
| ASUS control tools | Do not add `asusctl` or competing power managers solely because of boot warnings; evaluate only for a specific fan or charge-limit need | Conditional |

## Display and Omarchy

Omarchy's monitor manual recommends 1x scaling for 1080p and 1440p displays, but the user's chosen UI profile is scale 1.6. The local rule pins DP-1 to 2560×1440 at 239.97 Hz, 10-bit, `cm=srgb` and VRR=1 while referencing `omarchy_monitor_scale`, so the official scaling helper remains functional. [Omarchy monitor manual](https://github.com/omacom/omarchy/blob/quattro/manual/33-monitors.md)

The local failure was traced to Omarchy's internal-monitor mirror toggle. Its state file requested `mode = "preferred"` for DP-1 and mirroring to eDP-1; a reload then selected the dock's preferred 240 Hz mode. Omarchy's recent mirror recovery report documents the same toggle-file mechanism and recovery interaction. [Omarchy issue #6706](https://github.com/basecamp/omarchy/issues/6706)

There is also a recent Omarchy report that the shared monitor-scaling helper can persist one scale across displays. That supports keeping the external rule explicit instead of using a shared scale variable for this laptop-plus-monitor layout. [Omarchy issue #7978](https://github.com/omacom/omarchy/issues/7978)

The corrective setting was first verified through eight samples over 32 seconds at 143.991 Hz, scale 1.0, VRR on, DPMS on, DP-1 enabled and no mirror. It was then restored to 239.970 Hz and scale 1.6 using the official scaling helper; reload retained both values. The later color A/B showed that `cm=auto` selected `wide`/BT2020 at both 240 and 144 Hz, while `cm=srgb` kept the DRM colorspace at Default. This does not prove that every future Hyprland/monitor update is bug-free, so the telemetry service remains useful.

Community reports still describe VRR flicker on some AMD DisplayPort and FreeSync combinations. They are relevant watchlist evidence, not proof for this LG path because panel, cable, dock revision and compositor workload differ. [Recent community report](https://www.reddit.com/r/linux_gaming/comments/1u51dp9/)

## Laptop firmware, AMD and ASUS

ASUS lists BIOS 306 for UM3406KA with a 2026-07-23 date. The local machine reports BIOS 306, so there is no newer vendor BIOS found in this review. [ASUS UM3406KA BIOS support](https://www.asus.com/us/laptops/for-home/zenbook/asus-zenbook-14-oled-um3406/helpdesk_bios?model2Name=UM3406KA)

Arch's current `linux-firmware-amdgpu` package is the appropriate firmware source for the integrated Radeon. The current kernel and firmware packages should be updated through the normal Arch/Omarchy update path. Installing a separate AMD display package or a DKMS GPU driver would add risk without addressing the observed mode drift. [Arch linux-firmware-amdgpu](https://archlinux.org/packages/core/any/linux-firmware-amdgpu/), [AMD Linux drivers](https://www.amd.com/en/support/download/linux-drivers.html)

The AMD XDNA NPU is enumerated. An XDNA runtime is relevant only for a tested AI workload; it cannot improve DisplayPort sharpness, 10-bit output or VRR, so it is not a display recommendation.

## Dock and connected devices

The JSAUX product page advertises high-refresh output and VRR-related features, but the USB descriptors do not expose a unique commercial model or revision. The exact unit should therefore be recorded as “JSAUX RGB docking station, model revision unconfirmed” until its label or purchase record is available. Local DRM evidence is stronger for this machine: DP-1 negotiates 2560×1440 at 144/240 Hz and Hyprland exposes VRR on the active DisplayPort path. [JSAUX product page](https://jsaux.com/products/rgb-docking-station-for-steam-deck)

JSAUX's current FAQ says recently shipped docks already contain the stable firmware and that the original firmware download link was taken offline after update-detection problems. That makes installing an old Windows updater an unjustified experiment. [JSAUX firmware FAQ](https://jsaux.com/pages/faqs)

The dock's USB topology is a normal kernel-managed path: VIA USB2 hub at 480 Mb/s, VIA USB3 hub at 10 Gb/s, Realtek RTL8153 Ethernet at USB 5 Gb/s, LG monitor controls, an LG microphone and input receivers. No vendor Linux dock driver is indicated.

The RTL8153 is bound to the in-tree `r8152` driver. Arch ships matching Realtek firmware, including RTL8153 blobs, and the local link test passed at 1 Gb/s full duplex with zero current errors. Do not install the AUR `r8152-dkms` package unless a reproducible in-tree driver failure appears. [Arch Realtek firmware file list](https://archlinux.org/packages/core/any/linux-firmware-realtek/files/), [ArchWiki Ethernet](https://wiki.archlinux.org/title/Network_configuration/Ethernet)

The MediaTek MT7922 is bound to `mt7921e` and the Bluetooth controller to `btusb`. The kernel wireless documentation lists MT7922 support and directs users to linux-firmware. No vendor binary package is needed. A Wi-Fi association/throughput test is still open because wired Ethernet was active during the audit. [Linux Wireless MediaTek documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html)

The webcam uses `uvcvideo`; the microphone and HDMI audio use the kernel ALSA/PipeWire stack. The LG display needs no Linux vendor driver: DRM/KMS, EDID and DDC/CI are sufficient for the tested functions.

The WD_BLACK SN850X is directly attached as NVMe and reports firmware 620361WD. The local Btrfs and temporary I/O checks passed, while `nvme-cli`, `smartmontools` and `fwupd` are absent. Install those only as observability tools when convenient; they do not change the driver. WD's product material still describes the dashboard as Windows software, and no matching LVFS update was found in this review. [WD_BLACK SN850X data sheet](https://documents.westerndigital.com/content/dam/doc-library/th_th/assets/public/western-digital/product/internal-drives/wd-black-ssd/data-sheet-wd-black-sn850x-nvme-ssd.pdf), [WD community](https://community.wd.com/c/wd-software-mobile-apps/10)

## Package plan

Safe observability additions, when a maintenance window is available:

```text
usbutils ethtool nvme-cli smartmontools fwupd fio stress-ng
```

These packages improve evidence for USB descriptors, Ethernet counters, NVMe SMART/firmware inventory, firmware metadata, storage I/O and controlled stress. They are now installed through `omarchy-pkg-add`; the package database check is clean. They are not display drivers. Do not install vendor Windows packages, AMDGPU-PRO, `r8152-dkms`, random DKMS display modules or duplicate power managers without a reproduced failure.

The boot warnings for `asus_armoury`, `asus_wmi`, the audio machine driver and `boltd` remain candidates for separate investigations. None was connected to the display-mode drift by the local evidence.

## Source and claim status

- `confirmed`: local device binding, mode state or repeatable test result.
- `conditional`: a package or setting that may help only after a matching symptom is reproduced.
- `anecdotal`: community report with different hardware or incomplete reproduction.
- `not reproduced`: issue found in searches but absent from this machine's tests.

The next useful tests are a protected Wi-Fi association/throughput run, a Bluetooth pairing check, speaker playback, NVMe SMART inventory and a longer display telemetry period. They should be run with the same idle/suspend/lock guards used by the display tests.
