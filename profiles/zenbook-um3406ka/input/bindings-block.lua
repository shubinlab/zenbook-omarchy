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
