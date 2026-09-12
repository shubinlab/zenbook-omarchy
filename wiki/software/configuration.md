# Configuration layers

Omarchy has a deliberate two-layer model:

```text
/usr/share/omarchy                 stock package-owned defaults (read-only)
        ↓ loaded first
~/.config/hypr, ~/.config/voxtype  user overrides and profile settings
        ↓ captured and restored by
profiles/zenbook-um3406ka          versioned source of truth in this repository
```

The [Omarchy dotfiles manual](https://github.com/omacom/omarchy/blob/quattro/manual/31-dotfiles.md)
lists the same user-owned files and warns that stock files are replaced by
updates.

| User file | Stock behavior | This host's difference |
|---|---|---|
| `~/.config/hypr/monitors.lua` | Stock monitor setup | External LG `DP-1` 1440p/240/10-bit/sRGB/VRR/scale 1.6 |
| `~/.config/hypr/bindings.lua` | Stock Omarchy bindings and web-app shortcuts | Layout-safe Super+C/V/X clipboard block, Google settings shortcut and Right Ctrl -> F13 Voxtype binding; language switching stays in XKB input policy; core bindings retained |
| `~/.config/hypr/input.lua` | Stock input defaults | `us,ru`, generated user XKB keymap and bidirectional Alt+Shift; click-to-focus is explicit; Fcitx5 is not the language-switch owner |
| `~/.config/foot/foot.ini` | Stock Foot settings | Keyboard selection/copy/paste, layout-safe Control keys, Sixel and search/URL/clipboard-output bindings on F6/F12/F8; other Foot settings retained |
| `~/.config/tmux/tmux.conf` and `~/.config/omarchy/hooks/theme-set.d/` | Omarchy tmux and theme hooks | Managed theme include and semantic-color tmux palette; complete stock tmux configuration remains intact |
| `~/.config/omarchy/shell.json` | Stock bar and clock defaults | Transparent shell; clock format `dddd HH:mm`; idle 150/300 seconds retained |
| `~/.config/omarchy/defaults/agent` | Omarchy default agent | `codex` |
| `~/.config/fcitx5/profile` | Fcitx5 default profile | Empty declared keyboard-layout list; any runtime `keyboard-us` fallback is not a language-switch owner |
| `~/.local/bin/toggle-fcitx-layout` | No stock profile helper | Intentionally absent; there is no second Fcitx/Hyprland toggle path |
| `~/.config/xkb/voxtype-keymap.xkb` | No profile-owned keymap | Generated two-group map with Right Ctrl translated to F13 |
| `~/.config/voxtype/config.toml` | Native Voxtype config | Remote mode to loopback Lemonade `whisper-v3-turbo-FLM`, auto language, native OSD, feedback and `wtype`-only output without clipboard fallback |
| `lemond.service` | Package-owned Lemonade system service | Enabled by the Zenbook voice profile; local FLM model must report `device=npu` |
| `~/.config/pipewire/pipewire-pulse.conf.d/90-omarchy-voice.conf` | No profile drop-in | Not created by clean install; legacy repair handles older installs explicitly |
| `~/.bashrc` / `~/.blerc` | Omarchy Bash and fzf setup | Managed profile blocks source ble.sh and fzf integration |
| `~/.local/bin/omarchy-bitwarden` | Not present in stock Omarchy | Native Wayland `rbw`/Fuzzel launcher with `wl-copy`, `wtype` and 30-second clipboard clearing |
| `~/.config/rbw/config.json` | Not present in stock Omarchy | User-scoped pinentry, 10-minute lock timeout and hourly sync; credentials stay outside the repository |

The profile source, apply command and rollback location for each row are in
[Zenbook configuration map](../zenbook/configuration.md).
