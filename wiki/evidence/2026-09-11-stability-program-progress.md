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
| fstrim | PASS/PARTIAL | timer and latest service run succeeded; root-filesystem coverage remains to be confirmed |
| Quickshell | UNRESOLVED | recent SIGSEGV/SIGABRT coredumps remain |
| Hermes/Telegram | PARTIAL | units active; Telegram end-to-end connection not yet proven |
| SearXNG | PARTIAL | local HTML/JSON and Chromium route work; direct multi-agent acceptance remains |
| Camofox | PARTIAL | historical live sessions worked; idle `browserConnected=false` is expected but needs fresh session proof |
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

## Decision log

| Decision | Reason | Rollback |
| --- | --- | --- |
| Keep current APST initially | No NVMe timeout/reset/AER/I/O evidence; only historical counters | No change to roll back |
| Do not install a WD Linux driver | NVMe support is provided by the kernel driver; `nvme-cli` is management tooling | No extra driver installed |
| Preserve `asusctl/asusd` | Hardware backend is distinct from removed ROG GUI | Reinstall only through approved Omarchy package path if later needed |
| Treat Camofox idle browser as expected state | Service supports on-demand browser lifecycle | Create/close a real session to verify readiness |
| Keep protected workloads | Explicit user requirement | Any tuning must be measured and reversible |

## Checkpoint commits

The first documentation checkpoint is `a6811e9`, created after repository-boundary checks, Markdown file checks, placeholder scan, and `git diff --check`. Subsequent commits will be listed here with task name, verification command, and pass/partial result.
