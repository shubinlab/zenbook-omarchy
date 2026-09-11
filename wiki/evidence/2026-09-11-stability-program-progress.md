# Zenbook Omarchy Stability Program — Progress

**Date started:** 2026-09-11

**Scope:** storage/power reliability, Omarchy crash diagnosis, protected agent stack, OSINT/red-team validation, and measured hygiene.

**Source of truth:** `docs/superpowers/specs/2026-09-11-zenbook-stability-program.md` and `docs/superpowers/plans/2026-09-11-zenbook-stability-program.md`.

## Operating rules

- This file contains sanitized conclusions only. Raw journals, coredumps, serials, hostnames, IP addresses, credentials, and browser/session data remain outside Git.
- Existing dirty repository files are user-owned and are not part of this program.
- A running systemd unit is not treated as proof of end-to-end health.
- A lifetime NVMe counter is not treated as proof of current media failure.
- Every stage requires positive verification, red-team verification, reference/OSINT comparison, rollback, and a narrow Git checkpoint.

## Initial status before this program

| Area | Status | Evidence summary |
| --- | --- | --- |
| ROG GUI | PASS | `rog-control-center` absent; `asusctl/asusd` intentionally retained |
| NVMe health | PARTIAL | SMART passed; no media errors; lifetime unsafe/error counters need observation |
| NVMe current error log | PASS | inspected slots contain zero error counts/status |
| BIOS/driver | PASS | BIOS 306; current Arch kernel and in-tree NVMe driver present |
| APST | OBSERVE | enabled by default; no timeout/reset evidence justifying a change |
| fstrim | PASS/PARTIAL | weekly timer is healthy; `/boot` trims, but encrypted root deliberately rejects discard |
| Quickshell | UNRESOLVED | recent SIGSEGV/SIGABRT coredumps remain |
| Hermes/Telegram | PARTIAL/PASS | units active; Hermes gateway delivered a synthetic alert, client receipt remains unverified |
| SearXNG | PARTIAL/PASS | loopback health and Google-only domain-safe route pass; engine redundancy is intentionally not enabled after Bing/Brave/Qwant failures |
| Camofox | PASS | fresh Codex-style session opened CBR, snapshot contained page content, and session cleanup left zero active tabs/sessions |
| Voxtype | PASS | real recording, remote transcription, and paste observed |
| Ten-site red team | PARTIAL | prior report exists; current rerun and full route matrix remain |
| Memory/bloat | UNMEASURED | protected services have not yet been compared with a final budget |

## Execution ledger

### 2026-09-11 — program initialization

- User approved execution and requested Markdown/Git checkpoints.
- Repository was already on `main` with pre-existing user modifications; those paths are explicitly excluded from this program’s staging.
- Created the program spec, execution plan, and this progress ledger.
- No runtime configuration, package state, firmware, boot parameter, or service state was changed while creating the documentation.
- Checkpoint commit: `a6811e9` (`docs(zenbook): add stability program and evidence ledger`).
- Markdown validation and `git diff --check` passed before the commit; pre-existing user changes remain unstaged.
- Next gate: run the fresh storage/firmware baseline.

### 2026-09-11 — storage, firmware, and power baseline

- Fresh baseline captured under an external, user-private raw-evidence directory; raw output was moved out of the repository after discovering that the current `.gitignore` does not ignore arbitrary nested `runs/` files.
- Live versions confirmed: Arch kernel `7.2.3`, `linux-firmware` and `amd-ucode` from the current installed set, `fwupd`, `smartmontools`, and `nvme-cli` installed.
- BIOS confirmed as `UM3406KA.306`; no BIOS change was made.
- `fwupdmgr refresh` completed successfully. After refresh, `WD BLACK SN850X 2000GB` and `System Firmware` report no available update. No firmware was flashed.
- Current kernel journal again contains NVMe discovery and successful suspend/resume messages, but no NVMe timeout, controller reset, AER, or I/O-error signature.
- APST remains enabled with the existing kernel default; `s2idle` remains the only exposed system sleep mode. No boot parameter or power-management setting was changed.
- `fstrim.timer` is enabled/active and its last run succeeded; the observed run reports `/boot` trimming. Root-filesystem trim coverage remains a separate verification item.
- A fresh privileged SMART/NVMe read was attempted through Polkit but did not produce output in the agent terminal; the earlier privileged read remains the evidence for `PASSED`, 44°C, zero media errors, and zero current error entries. This sub-check is `PARTIAL`, not silently marked passed.
- Red-team conclusion: historical counters alone do not justify disabling APST or PCIe power management.
- OSINT basis: [WD SMART field definitions](https://support-en.wd.com/app/answers/detailweb/a_id/12163/~/s.m.a.r.t.-self-monitoring-analysis-and-reporting-technology), [ASUS UM3406KA BIOS support](https://www.asus.com/uk/laptops/for-home/zenbook/asus-zenbook-14-oled-um3406/helpdesk_bios?model2Name=UM3406KA), [Linux NVMe driver policy](https://github.com/torvalds/linux/blob/master/Documentation/nvme/feature-and-quirk-policy.rst), and [Arch NVMe power guidance](https://wiki.archlinux.org/title/Solid_state_drive/NVMe).
- Task status: `PARTIAL`; remaining gate is an interactive privileged storage read plus root-filesystem trim coverage.

### 2026-09-11 — crash root-cause checkpoint

- Memory pressure is not supported as the cause: the live system reports about 20 GiB available RAM and 60 GiB free swap, with no OOM-kill record in the inspected period.
- The latest Omarchy Quickshell core is `/usr/bin/quickshell -n -p /usr/share/omarchy/shell`, signal `SIGSEGV`, with the stack entering `__dynamic_cast` and then Qt QML object finalization. The installed versions are `quickshell 0.3.1-1`, `qt6-base 6.11.2-3`, and `qt6-declarative 6.11.2-1`.
- A prior Quickshell `SIGABRT` is a different signature: GLib allocation/assertion code while a GVFS/GIO D-Bus directory-monitor request is being built. These are not yet proven to share one root cause.
- OSINT comparison found current upstream Quickshell reports with the same family of Qt 6.11/QML incubation and `__dynamic_cast`/IpcHandler failures, including [issue 983](https://github.com/quickshell-mirror/quickshell/issues/983) and [issue 956](https://github.com/quickshell-mirror/quickshell/issues/956). This raises the likelihood of an upstream Quickshell/Qt defect, but does not prove that the Omarchy shell graph triggers the same path until a controlled reproduction is run.
- The repeated `SIGBUS` cores around 21:38–21:57 belong to a kDrive AppImage `crashpad_handler` under `/tmp/.mount_kDrive...`; the command line included kDrive's Sentry crash database and the stack entered the AppImage-bundled LDAP library. No kDrive process is currently running. These crashes are separate from NVMe and Quickshell and are now a distinct containment decision.
- The live memory sample also showed a high Quickshell RSS and a substantial Voxtype Quickshell RSS; this is an observation only, not yet a memory regression result.
- Red-team conclusion: removing or tuning NVMe/APST would not address these desktop/AppImage crashes. First isolate Quickshell/Qt and kDrive Crashpad separately.
- Controlled positive test: `omarchy restart shell` exited the old shell through its IPC path, launched a new Omarchy shell, loaded configuration, and left `systemctl --failed` empty. The Quickshell coredump count remained unchanged at two. This proves recovery from a normal restart, not that the underlying crash is fixed.
- The same restart journal included a Telegram `QDBusTrayIcon` `ServiceUnknown` warning. It did not stop Telegram autostart, but it is a separate tray-integration risk for the protected workload.
- Task status: `PARTIAL`; root-cause classification is substantially improved and normal shell restart recovers, but controlled trigger reproduction and a safe upstream/package containment decision remain.

### 2026-09-12 — Camofox, SearXNG, and browser-route checkpoint

- Camofox positive test passed through its local OpenAPI: a fresh isolated session opened the Bank of Russia key-rate page, returned the expected title and accessibility snapshot, and the session was deleted. The post-cleanup API reported zero active tabs and sessions; the browser process then shut down on its normal idle timer. No credentials, cookies, clicks, or external state changes were used.
- SearXNG local health remained `200 OK`, and Hermes' bounded healthcheck continued to report `camofox=ok`, `searxng=ok`, and `hermes_gateway=ok` after two controlled SearXNG container recreations.
- Red-team query testing disproved the previous assumption that a healthy JSON endpoint implies useful search quality. Bing returned unrelated results for `site:` queries and varied with locale/User-Agent; Google was initially CAPTCHA-suspended, then recovered after a container restart; Brave hit a request-rate suspension; Qwant returned CAPTCHA. The bridge's post-filter correctly returned zero instead of leaking unrelated domains.
- Production decision: keep only the verified Google engine in the SearXNG `keep_only` pool. Bing, Brave, and Qwant were tested but are not enabled by default. The runtime settings were backed up outside the repository before each change; no firmware, package, agent policy, or protected service was changed by this experiment.
- Security hygiene: the local SearXNG `secret_key` was rotated after an accidental diagnostic print, with a private pre-rotation backup, mode `0600` retained, container recreation, healthcheck, and Google/domain query verification. The new value was not recorded in Git or evidence.
- Positive domain checks passed for `cbr.ru`, `cisa.gov`, `omarchy.org`, and `telegram.org` through `searxng-search --engine google --domain ...`; the bridge also rejected URL-shaped domains, raw mode combined with `--domain`, and empty queries.
- Browser comparison: the connected CUA surface exposed no Chromium/Codex Browser tab in this session, so the comparison used installed Chromium 152 with a temporary isolated profile. Chromium saw the same Google-only SearXNG response and the same `www.cbr.ru` host set. This is independent HTML/network validation, not a claim that the unavailable CUA UI was tested.
- OSINT basis: current [SearXNG settings documentation](https://docs.searxng.org/admin/settings/settings.html), [search syntax documentation](https://docs.searxng.org/user/search-syntax.html), [configured engine matrix](https://docs.searxng.org/user/configured_engines.html), and the current engine-specific CAPTCHA/rate-limit behavior observed locally.
- Hermes/Telegram remains `PARTIAL`: the OS can resolve and reach `api.telegram.org` over the VPN, but the long-running Hermes process still has historical reconnect warnings and no fresh end-to-end message test was authorized. No Telegram message was sent.
- Task status: `PARTIAL/PASS`; Camofox path is accepted, SearXNG is fail-closed and usable through the verified engine, and engine redundancy remains an explicit open risk rather than hidden failure.

### 2026-09-12 — trim and Hermes reconnect checkpoint

- `fstrim.timer` is enabled and active with the stock weekly `fstrim.service`; the last run exited successfully and trimmed `/boot`.
- The root filesystem is Btrfs on `/dev/mapper/root`, backed by LUKS2. The mapper exposes `DISC-GRAN=0B`, and a privileged direct `fstrim /` reports `discard operation is not supported`; this explains why the stock timer logs only `/boot`.
- Current boot uses Limine and the `encrypt` initramfs hook with `cryptdevice=...:root`. Enabling root trim would require a boot/initramfs change such as `:allow-discards` and carries the dm-crypt metadata-leak tradeoff documented by ArchWiki and cryptsetup. No such security-sensitive change was made. Current decision: keep the secure default and mark root trim intentionally unavailable until the user explicitly chooses the tradeoff.
- Hermes gateway was restarted once under systemd. The old process exited with status 1 during normal shutdown, systemd started the new process, and it remained active with `NRestarts=0`. After reconnect, the process held established HTTPS sockets to Telegram's IPv6 API address; this is a fresh transport-level positive check, not proof of application-level message delivery. No Telegram message was sent.
- Post-restart healthcheck still reports `camofox=ok`, `searxng=ok`, and `hermes_gateway=ok`; no system or user failed units are present.
- Package hygiene audit found zero pacman orphan packages and zero foreign packages. A memory sample is not a tuning baseline because several Codex/CUA sessions were active; notable resident consumers included Telegram, Omarchy/Voxtype Quickshell, LocalSearch, Camofox, Hermes, and three rclone mounts. No service was disabled based on this single sample.
- The next measured-hygiene gate is to classify enabled user services and cache growth, then test only reversible candidates such as unused indexing/online-account integrations. Protected Telegram, Hermes, Camofox, Voxtype, cloud mounts, and local speech services remain preserved.
- Cache review found approximately 6.1 GiB under `~/.cache`, led by Codex runtimes, Camoufox, Zen's residual cache, Chromium, and the package/build caches; approximately 1.0 GiB is in `~/.local/share/Trash`. These are storage findings, not proof of a RAM leak, and no cache or Trash content was deleted.
- `localsearch` is not an orphan: it is required by installed Nautilus and currently uses about 290 MiB when active. GNOME Online Accounts/GVFS are explicitly installed and have cloud-related optional backends; they remain candidates for a user-confirmed “no GNOME accounts/file browsing” profile, not blind removals.
- Reversible `localsearch-3` A/B test: stopping the active indexer changed its user-unit memory from about 278 MiB to inactive and increased reported available memory by about 70 MiB; starting it again succeeded with a small initial footprint (~7 MiB). No persistent disable or package removal was applied. This supports a future idle/on-demand policy only if Nautilus search is not part of the user's workflow.
- Quickshell follow-up: the current Omarchy launcher already sets `QS_DISABLE_FILE_WATCHER=1`, disables reload popups, waits for clean shell exit during restart, and supervises abnormal exits. No new Quickshell coredump appeared after the prior restart; the two known Quickshell cores remain the Qt/QML SIGSEGV and older GLib/GVFS SIGABRT. Current installed package versions remain `quickshell 0.3.1-1`, `qt6-base 6.11.2-3`, and `qt6-declarative 6.11.2-1`.
- Current upstream OSINT materially strengthens the Qt hypothesis: Quickshell issue 983 documents the same Arch package family and says the minimal repro is good on Qt 6.11.1 but crashes on Qt 6.11.2; issue 956 separately documents the same `__dynamic_cast` plus `QQmlObjectCreator::finalize` teardown family. The local stack and timing are consistent, but no system-wide Qt downgrade was applied because the package cache has no safe rollback set and Qt is a shared desktop dependency.
- Residual-app cleanup: `zen-browser-bin`/`zen-browser` are absent, no Zen process or autostart reference exists, and the orphaned `~/.cache/zen` (~1.1 GiB) plus `~/.config/zen` (~172 MiB) were moved to a private runtime backup outside Git. Chromium, Codex, and Telegram processes remained present; user cache/config footprint fell by about 1.3 GiB. The backup is recoverable until the next reboot, after which the runtime directory is normally cleared.
- Hermes end-to-end search test passed: a one-shot Hermes run using only the `web` toolset and the configured OpenAI Codex provider returned the official Bank of Russia key-rate URL/title and explicitly identified the `cbr.ru` host. The test made no Telegram call, browser side effect, file change, or non-official navigation.
- This closes the current Hermes→SearXNG acceptance gate for a read-only search. The separate Hermes→Camofox browser gate is represented by the direct Camofox session test above; the CUA Codex Browser surface itself remained unavailable.
- Repository verification passed: `./tools/ci-check.sh` completed with `ci-check: PASS`, including shell syntax, package-token safety, public-repository scan, no direct `/usr/share/omarchy` writes, and red-team installer checks.
- OSINT basis: [ArchWiki dm-crypt discard guidance](https://wiki.archlinux.org/title/Dm-crypt/Specialties), [cryptsetup refresh warning](https://man.archlinux.org/man/cryptsetup-refresh.8.en), and [crypttab discard option](https://man.archlinux.org/man/crypttab.5).
- Task status: `PARTIAL`; the trim behavior is explained and safe, Hermes transport recovered, but end-to-end Telegram application confirmation and root-trim policy choice remain open.

### 2026-09-12 — ten-domain Camofox/Chromium repeat

- Repeated the existing ten-domain read-only matrix: `instagram.com`, `facebook.com`, `twitter.com`, `linkedin.com`, `bbc.com`, `bsky.app`, `censor.net`, `carnegie.ru`, `amnezia.org`, and `paperpaper.io`.
- Camofox opened all ten URLs and returned an accessibility snapshot for each. Every isolated session was deleted successfully; the API ended with zero active tabs/sessions and zero consecutive failures. Challenge/login/privacy indicators were recorded as page outcomes, not transport blocks.
- Installed Chromium 152 rendered all ten URLs with isolated temporary profiles. All ten browser processes exited successfully; challenge/login/privacy indicators varied by site, but no browser-level transport failure occurred.
- Red-team conclusion: the current VPN egress reaches these domains from this host, but this must not be generalized to every Russian ISP, ASN, or U.S. network. A page rendering is not proof of useful access, and a challenge/login wall remains a functional block for an unauthenticated agent.
- Task status: `PASS` for this host's Camofox/Chromium transport control; `PARTIAL` for the broader geo-blocking question and authenticated-content usability.

### 2026-09-12 — fresh OSINT options checkpoint

- Current upstream evidence strengthens, but does not prove, the Quickshell/Qt hypothesis: issue 983 documents a Qt 6.11.2 QML binding crash with a minimal reproduction that works on Qt 6.11.1; issue 956 independently documents the local-looking `__dynamic_cast`/`QQmlObjectCreator::finalize` teardown family. Arch currently ships `quickshell 0.3.1-1` against the installed Qt 6.11.2 set.
- Current Infomaniak issue activity shows several Linux/AppImage compatibility reports, while the project support matrix names Ubuntu rather than Arch. The local kDrive Crashpad SIGBUS class is therefore treated as a separate unsupported-AppImage risk, not as NVMe evidence.
- OSINT confirms that weekly `fstrim.timer` is the normal policy and that dm-crypt discards are disabled by default with an explicit information-leak tradeoff for `allow_discards`. Root trim remains intentionally unavailable; no boot or mapper change was made.
- GNOME LocalSearch documentation confirms it is an optional background desktop indexer. The local reversible A/B supports offering a profile choice, but not removing it blindly because Nautilus requires the package.
- Decision options, risks, rollback paths, source links, and blind spots are recorded in [the fresh OSINT options report](../../docs/reports/2026-09-12-fresh-osint-stability-options.md). No runtime state changed in this checkpoint.
- Task status remains `PARTIAL`: the research decision gates are clearer, but NVMe privileged re-read, controlled suspend coverage, Quickshell causal A/B, and the LocalSearch/kDrive user choices remain open.

### 2026-09-12 — interactive decision: Quickshell containment

- User selected option `A1`: keep the current packaged Quickshell/Qt set and existing Omarchy launcher containment; do not downgrade Qt, add a patched build, or alter shell plugins now.
- Rationale: the upstream match is strong enough to guide the next experiment, but no fresh local core appeared after controlled restart and a shared-Qt downgrade has unnecessary blast radius.
- Trigger for reopening this decision: a new Quickshell core or a reproducible reload/hotplug/resume crash. Then preserve the exact backtrace and reassess a controlled Qt 6.11.1 A/B.
- Rollback: not applicable; no runtime or package state changed.

### 2026-09-12 — fresh privileged storage re-check

- Read-only `pkexec` checks completed successfully: SMART `PASSED`; temperature `44 C`; available spare `100%`; percentage used `0%`; media/data integrity errors `0`; all inspected NVMe error-log entries have `error_count=0` and successful status.
- Lifetime counters remain `unsafe shutdowns=125` and `error log entries=14`. They are recorded for observation, not classified as current media/controller failure.
- `fwupdmgr get-updates` reports no available firmware updates for System Firmware or WD BLACK SN850X. No firmware was flashed.
- Current power policy remains unchanged: `s2idle` only, NVMe APST default latency `100000`, `force_apst=N`, and NVMe runtime power control `on`. This boot has no NVMe timeout, controller reset, AER, block I/O, or Btrfs error signature.
- Red-team conclusion: the unsafe-shutdown/error-log counters alone do not justify replacing the SSD, disabling APST, or adding a vendor driver. The remaining useful reliability experiment is controlled suspend/resume observation, not a speculative parameter change.
- Task status: storage/firmware baseline `PASS`; suspend/resume coverage remains `OBSERVE`.

### 2026-09-12 — controlled suspend/resume smoke test

- One real `s2idle` cycle completed: suspend entry at `00:51:23`, resume at `00:51:51`, with systemd reporting a successful return from the sleep operation.
- After resume, NVMe queues were recreated normally. A fresh privileged SMART read remained `PASSED`, `44 C`, `100%` spare, `0%` used, media/data errors `0`; lifetime counters were unchanged at `125/14`.
- No NVMe timeout, controller reset, AER, block-I/O, Btrfs error, or new Quickshell coredump appeared in the cycle window. System and user failed-unit lists remained empty.
- Protected units recovered as active: Telegram autostart, Hermes gateway, Camofox, Voxtype, and Hermes healthcheck timer.
- Expected side effects: Telegram transport reconnect during network sleep and two transient NetworkManager P2P warnings after wake. These did not persist as failed units or block the protected stack.
- Red-team conclusion: this first suspend/resume cycle does not justify changing APST, sleep mode, NVMe driver policy, or Telegram/Hermes configuration. More cycles are useful for confidence, but the immediate failure hypothesis is not reproduced.
- Task status: suspend/APST `OBSERVE`; first controlled cycle `PASS`.

### 2026-09-12 — five-cycle AC suspend/resume series

- Because AC was online, four additional cycles were run automatically after the smoke test; the boot journal now contains six matching `suspend entry`/`suspend exit` pairs in total.
- All five tested AC/s2idle cycles returned successfully. After the series, SMART remained `PASSED`, temperature `42 C`, spare `100%`, used `0%`, media/data errors `0`, and lifetime counters unchanged at `125/14`.
- Red-team checks found no NVMe timeout/reset/AER/I/O/Btrfs error, no new coredump, no system or user failed unit, and all protected services remained active. The repeated queue-recreation messages are expected for this platform's suspend path, not controller failure.
- This materially weakens the hypothesis that routine AC suspend/resume or APST is causing the unsafe-shutdown history. Battery suspend coverage remains untested; no APST or sleep-policy change is justified.
- Task status: suspend/APST `PASS` for five AC cycles; `OBSERVE` for battery cycles.

### 2026-09-12 — NVMe error-counter clearing investigation

- The request to clear the NVMe errors was checked against current `nvme-cli 2.16` behavior and the NVMe specification. The standard `error-log` command is read-only; local help exposes no standard clear operation.
- The SMART field `Number of Error Information Log Entries=14` is a controller-lifetime counter, not a count of current failures. The current log entries inspected locally all report `error_count=0` and successful completion status.
- The WDC plugin's `clear-pcie-correctable-errors` command targets a different vendor-specific PCIe counter; it does not clear the standard NVMe lifetime error-entry counter and is not justified when the current PCIe/error evidence is clean.
- No controller reset, namespace format, sanitize, vendor command, or firmware operation was used. Those would either not clear the requested lifetime field or would create unnecessary data-loss/diagnostic risk.
- OSINT basis: [nvme-cli error-log documentation](https://github.com/linux-nvme/nvme-cli/blob/master/Documentation/nvme-error-log.txt) and [NVMe Base Specification field definition](https://nvmexpress.org/wp-content/uploads/NVM-Express_1_4c-2021.06.28-Ratified.pdf).
- Decision: retain the counter as historical evidence and monitor for a future increase together with non-zero entries or kernel errors.

### 2026-09-12 — clarification of earlier cleanup claim

- A review of the available Git history, saved raw-evidence references, memory index, and shell history found no recorded execution of a standard NVMe error-log clearing command on this host.
- The earlier cleanup work did include unrelated user caches/build artifacts and diagnostic evidence handling; those operations must not be conflated with clearing controller-lifetime NVMe fields.
- A prior vendor-specific `clear-pcie-correctable-errors` action would, if it had been used, affect only that separate PCIe counter and would not reset `error_log_entries=14`. No evidence of that command was found either.
- Current correction: the evidence supports “the NVMe lifetime counter was read and monitored,” not “the standard NVMe counter was erased.”

### 2026-09-12 — WD vendor-counter clear attempt

- Because the user explicitly asked whether the separate vendor-specific counter could be cleared, the supported local command was tested: `pkexec nvme wdc clear-pcie-correctable-errors /dev/nvme0`.
- The WD firmware returned `unsupported device for this command` with exit code `1`; no vendor counter was cleared and no data, namespace, SMART field, or NVMe lifetime counter was modified.
- Immediate red-team verification: SMART remained `PASSED`, `unsafe_shutdowns=125`, `error_log_entries=14`, media/data errors `0`, and no new PCIe/NVMe kernel error appeared.
- Final result: this particular SN850X firmware does not expose the WDC clear operation through the installed plugin. There is no safe supported clear path for the requested standard counter.

### 2026-09-12 — fresh NVMe prevention OSINT

- Current OSINT distinguishes the clearable Error Information log page from the SMART lifetime counter: controller reset/power-cycle may clear old log-page entries, but `Number of Error Information Log Entries=14` remains historical by design. Local current entries are already zero/invalid and do not need clearing.
- Official WD/SanDisk support points to the Windows-only Dashboard path for supported firmware management; Linux has no separate WD kernel driver for this NVMe. `fwupd` currently reports no update, and no third-party firmware image was used.
- Read-only local feature check: APST is enabled with states 3/4 selected, NOPPM is enabled, runtime power control is `on`, and the device firmware is `620361WD`. Five AC suspend/resume cycles produced no storage error, so disabling APST/PCIe power saving would be speculative.
- `smartd` is installed but disabled. It remains an optional monitor, not an automatic addition: enabling another persistent service without an alert path conflicts with the low-bloat goal and current clean evidence.
- Prevention decision: keep the in-tree NVMe driver, `nvme-cli`, `smartmontools`, `fwupd`, weekly fstrim, and current APST/NOPPM; monitor after real failures; change power policy only after a reproduced timeout/reset/I/O/Btrfs event.
- Full source comparison and action matrix are in [the updated NVMe OSINT report](../../docs/reports/2026-09-12-fresh-osint-stability-options.md). No runtime change was made in this research stage.

### 2026-09-12 — minimal NVMe monitor enabled

- The existing `smartmontools` package was used; no new package or vendor driver was installed. A host-specific `/etc/smartd-zenbook.conf` now monitors only `/dev/nvme0` with `-H -l error -W 5,70,80`.
- `smartd.service` is enabled and active with a 30-minute interval. It writes to the system journal only; no mail transport, firmware action, controller reset, APST change, or automatic remediation is configured.
- One-shot validation completed with exit `0`; the daemon identified one NVMe device and the forced immediate check produced no critical/error/warning event. The service uses about `1.5 MiB` resident memory.
- Reaction contract: informational journal entry for a counter increase that is no longer present or is command-related; preserve evidence and stop automatic changes for a device-related persistent error, Critical Warning, media error, critical temperature, or kernel timeout/reset/I/O/Btrfs signature.
- Rollback is bounded: restore the previous `/etc/conf.d/smartd`, remove `/etc/smartd-zenbook.conf`, and disable the unit. No SSD data or controller counters are affected by the monitor.
- OSINT basis: [smartd.conf NVMe monitoring semantics](https://man.archlinux.org/man/smartd.conf.5) and [smartd persistent state behavior](https://man.archlinux.org/man/extra/smartmontools/smartd.8.en).
- Task status: monitoring `PASS`; prevention remains `OBSERVE` because the historical lifetime counter cannot be reset and no current storage failure is present.

### 2026-09-12 — Hermes Telegram alert bridge

- Added `~/.hermes/scripts/zenbook-smartd-alert.sh`, a minimal no-agent filter. It reads only new `smartd` and kernel journal lines, redacts serial-shaped text, and remains silent when healthy.
- Created Hermes cron job `zenbook-nvme-telegram-alerts` on `every 15m`, `no-agent`, delivery `telegram`. It uses Hermes' existing configured home target; no bot token or chat ID was copied into the script.
- Manual healthy run completed successfully with empty output, so no Telegram message was sent. The script self-test and shell syntax checks passed.
- Alert policy: notify only on Critical Warning, media/data error, retained device-related NVMe error, high temperature, NVMe timeout/reset/I/O, Btrfs error, or AER error. Do not notify for the historical baseline `14` or normal suspend queue recreation.
- Failure boundary: `smartd` remains the independent storage monitor; if Hermes is down, journal evidence accumulates and delivery resumes on the next healthy Hermes tick. No automatic reset, reboot, firmware flash, or APST change is wired to Telegram alerts.
- Task status: local storage monitoring `PASS`; healthy Hermes-to-Telegram path `PASS`, synthetic alert delivery pending the separate test below.

### 2026-09-12 — synthetic Hermes-to-Telegram alert test

- The production filter was rechecked in the healthy state and remained silent (`0` output bytes), so the normal 15-minute job does not generate false alerts.
- A temporary one-shot `no-agent` Hermes cron job printed a clearly marked `TEST ONLY` alert and the Hermes scheduler log recorded delivery to the configured Telegram target. No NVMe error, SMART value, kernel journal entry, controller reset, or firmware action was injected.
- The CLI initially reported the manually triggered run as `failed`, but the execution database marked it `completed` and the scheduler recorded `delivered to telegram`; this is a CLI race/status-reporting discrepancy, not a production alert failure.
- The temporary cron job self-removed after `repeat=1`, and its test script was deleted. The permanent `zenbook-nvme-telegram-alerts` job remains the only active job on `every 15m`.
- This proves Hermes-side delivery to Telegram; actual rendering/receipt on the user's Telegram client remains unverified until the user confirms seeing the marked test message.
- Task status: alert pipeline `PASS` at the Hermes gateway boundary; client receipt `UNVERIFIED`.

### 2026-09-12 — standalone watchdog installer

- Added `scripts/watchdog.sh` as a separate opt-in installer with `--plan`,
  `--check`, `--install`, and `--uninstall` modes. It restores the tested
  `fwupd`/`smartmontools`/`nvme-cli` package set through Omarchy, the
  journal-only `smartd` configuration, and the existing Hermes Telegram job.
- Added the sanitized source alert script at
  `scripts/zenbook-smartd-alert.sh`; the installer copies it with mode `0700`
  and never stores tokens, chat IDs, serials, or raw journals in Git.
- The real host run of `./scripts/watchdog.sh --install` completed: smartd
  one-shot validation exited `0`, Hermes job matching remained idempotent, the
  self-test passed, and the final installer check returned `RESULT PASS`.
- The installer created its runtime rollback backup outside Git under the
  user's state directory. It did not send a Telegram message or change NVMe,
  firmware, APST, or fstrim policy.
- Red-team checks and repository CI passed after the installer addition.

## Decision log

| Decision | Reason | Rollback |
| --- | --- | --- |
| Keep current APST initially | No NVMe timeout/reset/AER/I/O evidence; only historical counters | No change to roll back |
| Do not install a WD Linux driver | NVMe support is provided by the kernel driver; `nvme-cli` is management tooling | No extra driver installed |
| Preserve `asusctl/asusd` | Hardware backend is distinct from removed ROG GUI | Reinstall only through approved Omarchy package path if later needed |
| Treat Camofox idle browser as expected state | Service supports on-demand browser lifecycle | Create/close a real session to verify readiness |
| Keep SearXNG on Google-only until another engine passes quality tests | Bing, Brave, and Qwant produced incorrect or blocked results in this VPN/session | Restore the timestamped settings backup and recreate the stack |
| Keep protected workloads | Explicit user requirement | Any tuning must be measured and reversible |

## Checkpoint commits

The first documentation checkpoint is `a6811e9`, created after repository-boundary checks, Markdown file checks, placeholder scan, and `git diff --check`. Subsequent commits will be listed here with task name, verification command, and pass/partial result.

- `c71a499` — storage/firmware refresh evidence; checks: `fwupdmgr refresh`, device update inventory, kernel/NVMe journal review; result `PARTIAL` for privileged SMART re-read and root trim coverage.
- `a13944f` — raw evidence moved outside Git after repository ignore-boundary review.
- `acd2118` — Quickshell/kDrive crash classification with coredump and OSINT evidence; result `PARTIAL`.
- `bf47069` — controlled Omarchy shell restart and recovery check; result `PASS` for recovery, not root-cause resolution.
- `PENDING` — synthetic Hermes-to-Telegram test checkpoint; checks: production healthy silence, gateway delivery log, temporary-job cleanup, `git diff --check`, and repository CI.
- `PENDING` — fresh OSINT options report and ledger entry; checks: Markdown validation, `git diff --check`, and repository CI.
