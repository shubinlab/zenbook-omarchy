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
| `~/.config/hypr/bindings.lua` | Stock Omarchy bindings and web-app shortcut | ChatGPT web app and native Bitwarden launcher overrides; core bindings retained |
| `~/.config/hypr/input.lua` | Stock input defaults | No active override; Fcitx5 remains `keyboard-us` |
| `~/.config/foot/foot.ini` | Stock Foot settings | `sixel=yes` appended; other Foot settings retained |
| `~/.config/omarchy/shell.json` | Stock bar and clock defaults | Clock format is `ddd d MMM HH:mm`; idle 150/300 seconds retained |
| `~/.config/omarchy/defaults/agent` | Omarchy default agent | `codex` |
| `~/.config/voxtype/config.toml` | Native Voxtype config | Remote mode to loopback Lemonade `whisper-v3-turbo-FLM`, auto language, native OSD, feedback and `wtype`-only output without clipboard fallback |
| `lemond.service` | Package-owned Lemonade system service | Enabled by the Zenbook voice profile; local FLM model must report `device=npu` |
| `~/.config/pipewire/pipewire-pulse.conf.d/90-omarchy-voice.conf` | No profile drop-in | Not created by clean install; legacy repair handles older installs explicitly |
| `~/.bashrc` / `~/.blerc` | Omarchy Bash and fzf setup | Managed profile blocks source ble.sh and fzf integration |
| `~/.local/bin/omarchy-bitwarden` | Not present in stock Omarchy | Native Wayland `rbw`/Fuzzel launcher with `wl-copy`, `wtype` and 30-second clipboard clearing |
| `~/.config/rbw/config.json` | Not present in stock Omarchy | User-scoped pinentry, 10-minute lock timeout and hourly sync; credentials stay outside the repository |

The profile source, apply command and rollback location for each row are in
[Zenbook configuration map](../zenbook/configuration.md).
