# NVMe watchdog restore

`scripts/watchdog.sh` restores the tested Zenbook storage-monitoring setup as a
separate, opt-in installer. It uses the in-tree NVMe driver and Omarchy's
package helper for `fwupd`, `smartmontools`, and `nvme-cli`.

The installed policy is deliberately narrow:

- `/dev/nvme0` is monitored by `smartd` every 30 minutes;
- `Critical Warning`, error-log changes, temperature thresholds, and related
  kernel NVMe/Btrfs/AER signatures are written to the journal;
- Hermes runs a no-agent script every 15 minutes and delivers only non-empty
  alerts through its existing Telegram configuration;
- no firmware update, controller reset, APST change, reboot, or automatic
  remediation is performed;
- the normal healthy run is silent.

## Commands

```bash
./scripts/watchdog.sh --plan
./scripts/watchdog.sh --install
./scripts/watchdog.sh --check
./scripts/watchdog.sh --uninstall
```

Installation requires a graphical `pkexec` authentication prompt for the
system files. A rollback backup is kept outside Git under
`~/.local/state/omarchy-profiles/watchdog/`. Uninstall restores those files and
removes only the Hermes job owned by the fixed name
`zenbook-nvme-telegram-alerts`; packages are left installed because they are
useful read-only diagnostics beyond the watchdog.

The installer never stores Telegram tokens, chat IDs, serials, journals, or
host-specific raw evidence in the repository. To test only the script's output
without sending a message, run:

```bash
ZENBOOK_WATCHDOG_SELFTEST=1 ~/.hermes/scripts/zenbook-smartd-alert.sh
```
