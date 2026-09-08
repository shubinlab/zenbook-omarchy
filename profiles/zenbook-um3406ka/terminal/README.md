# Native terminal extension

This extension restores the tested terminal workflow without replacing
Omarchy's packaged Foot or tmux configuration.

It provides:

- `chafa` for image previews in fzf with a text fallback;
- pinned official `ble.sh` installation on a clean machine, while preserving
  an existing user installation unless an explicit update is requested;
- Bash ghost text and the upstream ble.sh/fzf integration;
- explicit native Foot Sixel support;
- a ChatGPT web-app override for `Super+Shift+Alt+A`;
- a read-only `terminal-doctor` command.

The extension writes only user-owned files. It appends managed blocks to
`.bashrc`, `.blerc` and Hyprland bindings, and creates backups under
`~/.local/state/omarchy-profiles/backups/terminal/` before changes. It does not
copy `tmux.conf`: the current Omarchy tmux configuration already provides the
tested passthrough and clipboard settings.

Run from the repository root:

```bash
./profiles/zenbook-um3406ka/terminal/apply.sh --check
./profiles/zenbook-um3406ka/terminal/apply.sh --apply
terminal-doctor
```

Rollback restores the latest backed-up user files:

```bash
./profiles/zenbook-um3406ka/terminal/apply.sh --rollback
```

The pinned ble.sh archive is downloaded only over HTTPS from the official
upstream release and verified with SHA-256 before installation. Existing
`~/.local/share/blesh` is left untouched by a normal apply.
