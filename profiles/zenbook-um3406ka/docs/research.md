# External research

External sources provide context and hypotheses. The protected local runs are
the evidence for this hardware path. This page combines the general source
list and the dated hardware research record so the source index has one home.

## Display and compositor

Checked 2026-09-08.

- [JSAUX RGB Docking Station](https://jsaux.com/products/rgb-docking-station-for-steam-deck): the product page advertises up to 2K/240 and 4K/120 output and currently labels VRR as HDMI 2.1 only. This does not establish DisplayPort VRR support through the dock.
- [ASUS Zenbook UM3406 specifications](https://www.asus.com/de/laptops/for-home/zenbook/asus-zenbook-14-oled-um3406/techspec/): the laptop exposes display output over USB-C/USB4 and USB 3.2 Type-C.
- [ASUS UM3406 technical specifications](https://www.asus.com/us/laptops/for-home/zenbook/asus-zenbook-14-oled-um3406/techspec/): the UM3406 family exposes USB4 Type-C display/PD up to 40 Gb/s and a USB 3.2 Type-C display/PD port up to 10 Gb/s.
- [ASUS UM3406KA manual](https://dlcdnets.asus.com/pub/ASUS/nb/UM3406KA/0409_E24342_UM3406KA_A.pdf?model=UM3406KA): the USB4/PD port is intended for external displays and notes that the adapter can become warm under load.
- [Hyprland monitor modes](https://wiki.hypr.land/configuring/core/monitors/modes/): `vrr=1` enables VRR, `vrr=2` limits it to fullscreen and `vrr=3` limits it to fullscreen video/game content.
- [Hyprland current dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/): current Lua syntax uses `hl.dsp.dpms({ action = "disable" })`; legacy dispatcher syntax is rejected by this Lua configuration.
- [Omarchy dotfiles manual](https://omarchy.org/manual/dotfiles/): user overrides belong under `~/.config`; stock files under `/usr/share/omarchy` should not be edited, and selective dotfile backup is recommended.
- [Current Omarchy monitor manual](https://github.com/omacom/omarchy/blob/quattro/manual/33-monitors.md): monitor rules belong in `~/.config/hypr/monitors.lua` and the examples generally use 1× scaling for 1080p/1440p displays.
- [Current Omarchy troubleshooting manual](https://omarchy.org/manual/troubleshooting/): the desktop expects `GDK_SCALE=2` for the laptop's high-density panel.
- [Hyprland issue #7085](https://github.com/hyprwm/Hyprland/issues/7085), [#7007](https://github.com/hyprwm/Hyprland/issues/7007) and [#8492](https://github.com/hyprwm/Hyprland/issues/8492) describe related AMD/VRR flicker or reconnect reports. They are not exact reproductions of this Zenbook and dock.
- [Linux kernel HID endpoint discussion](https://www.spinics.net/lists/kernel/msg6128124.html): the exact `usbhid` message means the probed HID interface has no interrupt-in endpoint.

The local experiment activated DRM VRR at 1080p120 and 1440p120/144/240,
including 10-bit at 1440p144. It does not prove that every dock revision, cable
or monitor firmware behaves the same way.

## Firmware, power and storage

- [Linux AMD P-State documentation](https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html): AMD-Pstate EPP is a hardware performance hint whose values trade performance bias against power savings.
- [ASUS UM3406KA BIOS support](https://www.asus.com/supportonly/um3406ka/helpdesk_bios/): BIOS 306 was the current entry found during the audit; the local machine reports version 306.
- [WD Linux support](https://support-en.wd.com/app/answers/detailweb/a_id/5242/~/linux-and-unix-support-for-western-digital-retail-products): WD delegates Linux software behavior to the OS/vendor, so NVMe health is checked locally.
- [WD_BLACK SN850X data sheet](https://documents.westerndigital.com/content/dam/doc-library/th_th/assets/public/western-digital/product/internal-drives/wd-black-ssd/data-sheet-wd-black-sn850x-nvme-ssd.pdf) and [WD community](https://community.wd.com/c/wd-software-mobile-apps/10): product and support context for the installed NVMe.
- [Linux Wireless MediaTek documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html): MT7922 support is provided by the kernel driver and linux-firmware.
- [Arch linux-firmware-amdgpu](https://archlinux.org/packages/core/any/linux-firmware-amdgpu/) and [AMD Linux drivers](https://www.amd.com/en/support/download/linux-drivers.html): the distribution firmware and in-tree AMDGPU/Mesa stack are the appropriate Linux path for this hardware.

## Interpretation rules

1. Local measurements take precedence over generic product claims.
2. Mark a claim `confirmed`, `conditional`, `anecdotal` or `not reproduced`.
3. Record source date, scope and caveat for vendor/community material.
4. Use the two-month source window for current investigations unless an older
   primary document is required for context.
