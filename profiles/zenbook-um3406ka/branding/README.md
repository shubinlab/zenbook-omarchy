# Shubin branding

The branding extension installs the SHUBIN text logo for the Omarchy
screensaver and About/Fastfetch view, plus the matching Plymouth and SDDM
logos. It also installs a `post-update` hook so `omarchy update` restores the
assets after package upgrades.

Apply it with:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --stage all
```

Original user and system files are backed up under
`~/.local/state/omarchy-profiles/backups/branding/original/` before a changed
file is replaced.
