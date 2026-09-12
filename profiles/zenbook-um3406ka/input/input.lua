-- Zenbook keyboard policy. This file is installed as a user-scoped override.
-- Omarchy's package-owned defaults remain loaded before this file.
-- One compositor-owned XKB state is used globally: exactly us <-> ru.
-- The stock bidirectional Alt+Shift XKB option handles either press order.
-- The custom keymap only preserves Right Ctrl -> F13 for Voxtype.
hl.config({
  input = {
    kb_layout = "us,ru",
    kb_variant = ",",
    kb_options = "compose:caps,grp:alt_shift_toggle_bidir",
    kb_file = os.getenv("HOME") .. "/.config/xkb/voxtype-keymap.xkb",
    -- Prefer click-to-focus over Omarchy's stock focus-follows-mouse behavior.
    follow_mouse = 0,
    numlock_by_default = true,
  },
})
