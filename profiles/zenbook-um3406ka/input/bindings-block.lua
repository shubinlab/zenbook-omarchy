-- >>> zenbook-omarchy universal clipboard layout fix (managed) >>>
-- Hyprland resolves send_key_state() key names in the active XKB group.
-- A Russian group has no Latin V/C/X keysyms, so the stock SUPER+C/V/X
-- bindings fail with `send_key_state: key not found`. Use physical keycodes
-- for the injected non-terminal shortcuts; terminal shortcuts stay native.
local function send_clipboard_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function clipboard_active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

local function universal_clipboard_shortcut_fixed(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if clipboard_active_window_is_terminal() then
      send_clipboard_shortcut_once(terminal_mods, terminal_key)()
    else
      send_clipboard_shortcut_once(default_mods, default_key)()
    end
  end
end

hl.unbind("SUPER + C")
hl.unbind("SUPER + V")
hl.unbind("SUPER + X")
o.bind("SUPER + C", "Universal copy", universal_clipboard_shortcut_fixed("CTRL", "code:54", "CTRL", "Insert"))
o.bind("SUPER + V", "Universal paste", universal_clipboard_shortcut_fixed("CTRL", "code:55", "SHIFT", "Insert"))
o.bind("SUPER + X", "Universal cut", send_clipboard_shortcut_once("CTRL", "code:53"))
-- <<< zenbook-omarchy universal clipboard layout fix (managed) <<<

-- >>> zenbook-omarchy Google settings shortcut (managed) >>>
o.bind("SUPER + SHIFT + F10", "System settings", "env XDG_CURRENT_DESKTOP=GNOME DESKTOP_SESSION=gnome gnome-control-center")
-- <<< zenbook-omarchy Google settings shortcut (managed) <<<

-- >>> zenbook-omarchy input (managed) >>>
-- Language switching is global XKB state (see input.lua), not an
-- application/Fcitx binding. This also keeps the launcher and empty desktop
-- on the same us <-> ru state.

-- Right Ctrl is translated to F13 in the generated keymap.
hl.unbind("F9")
hl.unbind("F13")
o.bind("F13", "Start dictation (push-to-talk)", "voxtype record start")
o.bind("F13", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })
-- <<< zenbook-omarchy input (managed) <<<
