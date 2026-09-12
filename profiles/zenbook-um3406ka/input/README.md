# Zenbook input policy

This component is user-scoped and keeps one compositor-owned XKB state:

```text
us <-> ru
```

The stock `grp:alt_shift_toggle_bidir` option handles both:

```text
Alt -> Shift
Shift -> Alt
```

Fcitx5 remains available for Omarchy's XCompose service, but its profile is
intentionally empty of declared keyboard layouts. Fcitx5 may create a runtime
`keyboard-us` fallback; that is not a language-switch owner and must not be
paired with a `keyboard-ru` item or a second toggle script. The generated
keymap only adds the separate Right Ctrl -> F13 Voxtype workaround.

The active config must not contain `us,ru,us`, `grp:ctrl_shift_toggle_bidir`,
`grp:alts_toggle`, `grp:alt_space_toggle`, or a language binding for
modifier-only keys.

A human must still verify actual text in a Wayland app, the launcher/search,
and after returning to the desktop. The doctor cannot safely synthesize physical
modifier events.

## Upstream basis (reviewed 2026-09-12)

- [Hyprland keyboard layouts](https://wiki.hypr.land/configuring/core/binds/keyboard-layouts/): use XKB layouts/options for normal layout switching; `switchxkblayout` is an alternative mechanism.
- [Hyprland binds](https://wiki.hypr.land/Configuring/Binds/): modifier-only bindings are not a reliable replacement for an XKB group option.
- [Fcitx 5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland): compositor XKB state and Fcitx XKB state must not be allowed to diverge.
- [Hyprland issue #15952](https://github.com/hyprwm/Hyprland/issues/15952): the F13 translation remains separate for the affected Right Ctrl release path.
