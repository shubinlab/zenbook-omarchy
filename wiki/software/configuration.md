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
| `~/.config/hypr/bindings.lua` | Stock Omarchy bindings and web-app shortcut | ChatGPT web app replaces the stock Grok shortcut; core bindings retained |
| `~/.config/hypr/input.lua` | Stock input defaults | No active override; Fcitx5 remains `keyboard-us` |
| `~/.config/foot/foot.ini` | Stock Foot settings | `sixel=yes` appended; other Foot settings retained |
| `~/.config/omarchy/shell.json` | Stock bar and clock defaults | Clock format is `ddd d MMM HH:mm`; idle 150/300 seconds retained |
| `~/.config/omarchy/defaults/agent` | Omarchy default agent | `codex` |
| `~/.config/voxtype/config.toml` | Native default model/language and audio path | `large-v3-turbo`, auto language, native OSD and audio feedback |
| `~/.config/pipewire/pipewire-pulse.conf.d/90-omarchy-voice.conf` | No profile drop-in | Not created by clean install; legacy repair handles older installs explicitly |
| `~/.bashrc` / `~/.blerc` | Omarchy Bash and fzf setup | Managed profile blocks source ble.sh and fzf integration |

The profile source, apply command and rollback location for each row are in
[Zenbook configuration map](../zenbook/configuration.md).
