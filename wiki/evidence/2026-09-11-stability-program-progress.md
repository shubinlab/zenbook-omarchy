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
| Hermes/Telegram | PARTIAL | units active; Telegram end-to-end connection not yet proven |
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
- OSINT basis: [ArchWiki dm-crypt discard guidance](https://wiki.archlinux.org/title/Dm-crypt/Specialties), [cryptsetup refresh warning](https://man.archlinux.org/man/cryptsetup-refresh.8.en), and [crypttab discard option](https://man.archlinux.org/man/crypttab.5).
- Task status: `PARTIAL`; the trim behavior is explained and safe, Hermes transport recovered, but end-to-end Telegram application confirmation and root-trim policy choice remain open.

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
- Pending next checkpoint: this SearXNG/Camofox checkpoint, after `git diff --check`, Markdown checks, bridge tests, healthcheck, and protected-service verification.
