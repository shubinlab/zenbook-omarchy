# OSINT and external references

Checked 2026-09-08. External reports provide context and hypotheses; the local protected run is the evidence for this hardware path.

- [JSAUX RGB Docking Station](https://jsaux.com/products/rgb-docking-station-for-steam-deck): the product page advertises up to 2K/240 and 4K/120 output and currently labels VRR as HDMI 2.1 only. This does not establish DisplayPort VRR support through the dock.
- [ASUS Zenbook UM3406 specifications](https://www.asus.com/de/laptops/for-home/zenbook/asus-zenbook-14-oled-um3406/techspec/): the laptop exposes display output over USB-C/USB4 and USB 3.2 Type-C.
- [Hyprland monitor modes](https://wiki.hypr.land/configuring/core/monitors/modes/): `vrr=1` enables VRR, `vrr=2` limits it to fullscreen and `vrr=3` limits it to fullscreen video/game content.
- [Hyprland current dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/): current Lua syntax uses `hl.dsp.dpms({ action = "disable" })`; legacy `hyprctl keyword` and dispatcher syntax is rejected by this Lua configuration.
- [Hyprland issue #7085](https://github.com/hyprwm/Hyprland/issues/7085), [#7007](https://github.com/hyprwm/Hyprland/issues/7007) and [#8492](https://github.com/hyprwm/Hyprland/issues/8492) describe related AMD/VRR flicker or reconnect reports. They are not exact reproductions of this Zenbook and dock.
- Community reports about the JSAUX HB1201 family are mixed for DisplayPort and HDMI VRR, so the local DRM result is more reliable than a generic dock claim.

The protected experiment establishes that this local DP-1 path can activate DRM VRR at 1080p120 and 1440p120/144/240, including 10-bit at 1440p144. It does not prove that every dock revision, cable or monitor firmware behaves the same way.
