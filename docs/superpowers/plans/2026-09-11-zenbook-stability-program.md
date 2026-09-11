# Zenbook Omarchy Stability Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the approved Zenbook stability program, reducing unexplained failures and unnecessary resource use while preserving the requested Omarchy agent and desktop workloads.

**Architecture:** Use a read-first, evidence-gated sequence. Hardware/power diagnosis comes before kernel or boot-parameter changes; crash diagnosis comes before desktop fixes; service and package cleanup comes after end-to-end functionality is proven. Existing SearXNG design and red-team documents are subplans, not replaced by this document.

**Tech Stack:** Omarchy/Arch Linux, systemd, Btrfs, fwupd, smartmontools, nvme-cli, Linux NVMe driver, coredumpctl, Docker Compose, SearXNG, Camofox/Node, Hermes, Voxtype, Chromium, Bash, Python standard library, Markdown, Git.

**Spec:** `docs/superpowers/specs/2026-09-11-zenbook-stability-program.md`

## Global Constraints

- Preserve Telegram autostart, Hermes, Camofox/Node, Voxtype, SearXNG, Chromium, Codex extension, `asusctl/asusd`, and VPN.
- Never edit `/usr/share/omarchy/`.
- Never publish serials, hostnames, EDID hashes, credentials, raw journals, or unsanitized diagnostics.
- Never make APST/PCIe/suspend changes without a reproduced symptom and reversible A/B evidence.
- Use `omarchy` package commands for package state and user-scoped configuration for Omarchy customization.
- Each task ends with positive verification, adversarial/red-team verification, OSINT/reference verification, sanitized Markdown evidence, and a narrow Git checkpoint.
- Existing dirty files in the repository are user work and must not be staged by this program.

## File and Artifact Map

- Create: `docs/superpowers/specs/2026-09-11-zenbook-stability-program.md` — scope and acceptance contract.
- Create: `docs/superpowers/plans/2026-09-11-zenbook-stability-program.md` — this executable plan.
- Create: `wiki/evidence/2026-09-11-stability-program-progress.md` — append-only sanitized progress ledger.
- Reuse: `docs/superpowers/plans/2026-09-11-searxng-agent-and-omarchy-hardening.md` — SearXNG implementation subplan.
- Reuse: `docs/superpowers/specs/2026-09-11-searxng-agent-integration-design.md` — SearXNG contract.
- Reuse: `docs/reports/2026-09-11-codex-searxng-camofox-block-red-team.md` — prior ten-domain evidence and limitations.
- Create outside Git: external raw evidence directory — raw local output; publish only sanitized summaries. The repository's current `.gitignore` covers only selected `runs/` file types, so raw evidence must not be placed under the repository root.

## Execution Rules

At the start of an execution session, create one user-private raw-evidence root outside the repository and keep its path in the task-local variable `zenbook_raw_root`:

```bash
zenbook_raw_root="$(mktemp -d -p "${XDG_RUNTIME_DIR:-/tmp}" zenbook-stability.XXXXXX)"
chmod 700 "$zenbook_raw_root"
```

Each task follows this loop:

1. Read current state and relevant official documentation.
2. Capture a sanitized before-state.
3. Change one bounded variable, or explicitly record that no change is justified.
4. Run positive checks.
5. Run adversarial/red-team checks.
6. Compare with primary documentation or current upstream issue data.
7. Record result, risk, and rollback in the progress ledger.
8. Run repository checks and commit only the task’s Markdown/config files.

### Task 1: Create the evidence ledger and protect the dirty worktree

**Files:**
- Create: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Modify: none of the existing dirty files

**Interfaces:**
- Consumes: current repository status and the approved spec.
- Produces: a sanitized ledger with baseline, task status, evidence, and rollback fields.

- [ ] **Step 1: Record the initial repository boundary**

  ```bash
  git status --short --branch
  git diff --check
  git diff --name-only
  git ls-files --others --exclude-standard
  ```

  Treat every pre-existing modified/untracked path as user-owned. Do not stage it.

- [ ] **Step 2: Create the raw evidence directory outside published documentation**

  ```bash
  mkdir -p "$zenbook_raw_root/2026-09-11-stability-program"
  chmod 700 "$zenbook_raw_root/2026-09-11-stability-program"
  ```

- [ ] **Step 3: Write the first progress entry**

  Record the execution start, repository boundary, current acceptance status, and the explicit fact that no runtime configuration has changed in this task.

- [ ] **Step 4: Verify and commit only the three program documents**

  ```bash
  git diff --check
  git add docs/superpowers/specs/2026-09-11-zenbook-stability-program.md \
          docs/superpowers/plans/2026-09-11-zenbook-stability-program.md \
          wiki/evidence/2026-09-11-stability-program-progress.md
  git commit -m "docs(zenbook): add stability program and evidence ledger"
  ```

### Task 2: Freeze storage, firmware, and power baseline

**Files:**
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Create outside Git: `$zenbook_raw_root/2026-09-11-stability-program/storage/`

**Interfaces:**
- Consumes: the live laptop and the storage section of the spec.
- Produces: sanitized SMART/NVMe/fwupd/BIOS/kernel/APST/power evidence.

- [ ] **Step 1: Capture versions and firmware without serials**

  ```bash
  mkdir -p "$zenbook_raw_root/2026-09-11-stability-program/storage"
  uname -srvm
  pacman -Q linux linux-firmware amd-ucode fwupd smartmontools nvme-cli
  cat /sys/class/dmi/id/bios_version
  fwupdmgr get-devices
  ```

  Redact serial numbers before copying any summary into Markdown.

- [ ] **Step 2: Capture read-only NVMe health**

  ```bash
  sudo smartctl -x /dev/nvme0
  sudo nvme smart-log /dev/nvme0
  sudo nvme error-log /dev/nvme0 -e 32
  sudo nvme list
  ```

  Record health, temperature, media errors, unsafe shutdowns, error-log count, firmware, and whether current error entries contain non-zero errors.

- [ ] **Step 3: Refresh firmware metadata and verify update status**

  ```bash
  fwupdmgr refresh
  fwupdmgr get-updates
  fwupdmgr get-history
  ```

  Do not apply firmware updates in this step. If an update appears, record it as a separately gated action requiring AC power and backup confirmation.

- [ ] **Step 4: Capture kernel NVMe/APST and power state**

  ```bash
  cat /proc/cmdline
  cat /sys/module/nvme_core/parameters/default_ps_max_latency_us
  cat /sys/module/nvme_core/parameters/force_apst
  sudo nvme get-feature /dev/nvme0 -f 0x0c -H
  cat /sys/power/mem_sleep
  cat /sys/class/nvme/nvme0/device/power/control
  journalctl -k -b 0 --no-pager | rg -i 'nvme|aer|timeout|reset controller|I/O error|suspend|resume'
  ```

- [ ] **Step 5: Run positive and red-team checks**

  Positive: SMART passes, `nvme list` identifies the device, fwupd inventory works, and no critical kernel error is present.

  Red-team: distinguish a non-zero lifetime counter from a non-zero current error entry; verify that a clean command does not silently pass after permission failure; reject any plan that changes APST solely because the counters look large.

- [ ] **Step 6: Verify against current OSINT**

  Compare with Western Digital SMART definitions, ASUS BIOS support, Linux NVMe driver policy, and Arch NVMe power-management guidance. Record source URLs and the decision to keep current APST unless a real timeout/reset is reproduced.

- [ ] **Step 7: Record and commit the evidence checkpoint**

  ```bash
  git diff --check
  git add wiki/evidence/2026-09-11-stability-program-progress.md
  git commit -m "docs(zenbook): record storage and firmware baseline"
  ```

### Task 3: Diagnose desktop coredumps before fixing them

**Files:**
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Create outside Git: `$zenbook_raw_root/2026-09-11-stability-program/crashes/`

**Interfaces:**
- Consumes: coredumpctl, package versions, recent boot journals, and the diagnose-crash workflow.
- Produces: root-cause classification for Quickshell, Nautilus, and Crashpad; no speculative fix.

- [ ] **Step 1: Inspect the latest relevant coredumps using the crash-diagnosis workflow**

  Record signal, executable, package version, backtrace quality, and whether the core is current or historical. Keep raw backtraces outside published docs.

- [ ] **Step 2: Separate crash classes**

  Classify `/usr/bin/quickshell`, Voxtype’s `qs`, Nautilus, kDrive's AppImage `crashpad_handler`, and any browser Crashpad process separately. Do not treat all SIGBUS/SIGABRT events as NVMe failures. kDrive is not a protected workload; do not remove or disable it in this task unless a separate user-approved decision is recorded.

- [ ] **Step 3: Compare with recent changes and working paths**

  Compare current package versions, Omarchy shell config, theme changes, Chromium restarts, Voxtype activity, kDrive AppImage launches, and suspend/resume boundaries. Use one hypothesis at a time. Record whether Quickshell's stack matches an existing upstream issue before changing packages.

- [ ] **Step 4: Reproduce safely**

  Test shell restart, theme change, lock/unlock, Chromium launch, Voxtype OSD, and suspend/resume one at a time. Do not force-reset the machine to end a test; stop and preserve evidence if the desktop becomes unresponsive.

- [ ] **Step 5: Apply only a root-cause fix**

  Use Omarchy update/package paths or user-scoped configuration. Do not edit packaged Omarchy files. If the cause is an upstream package bug without a safe local fix, document containment and upstream status instead of guessing.

- [ ] **Step 6: Verify, red-team, and commit**

  Require no new relevant coredump during the stress sequence, recovery after a component restart, clean systemd state, and a recorded rollback. Compare the Quickshell stack with current upstream reports such as [Qt 6.11.2 QML binding crash](https://github.com/quickshell-mirror/quickshell/issues/983) and [IpcHandler dynamic-cast crash](https://github.com/quickshell-mirror/quickshell/issues/956); compare kDrive findings with its [current upstream issue list](https://github.com/Infomaniak/desktop-kDrive/issues). Commit only the sanitized ledger and any deliberately changed user config.

### Task 4: Validate shutdown, suspend/resume, and APST with controlled experiments

**Files:**
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Create outside Git: `$zenbook_raw_root/2026-09-11-stability-program/power/`

**Interfaces:**
- Consumes: Task 2 baseline and Task 3 crash classification.
- Produces: a decision to keep or change APST/suspend settings based on observed behavior.

- [ ] **Step 1: Record the exact baseline counters before the experiment**

  Read SMART and NVMe error log immediately before the first cycle.

- [ ] **Step 2: Run clean reboot cycles**

  Perform five normal reboots through systemd/Omarchy, allowing each boot to reach the graphical session. Do not use hard reset.

- [ ] **Step 3: Run suspend/resume cycles**

  Perform five AC and five battery suspend/resume cycles. After each cycle check NVMe health, kernel journal, filesystem state, and coredump list.

- [ ] **Step 4: Decide the APST branch**

  If no NVMe timeout/reset/AER appears and counters remain stable, retain current APST and record no-change evidence. If a reproducible controller/power failure appears, perform one temporary boot with APST disabled and repeat the smallest failing test.

- [ ] **Step 5: Roll back immediately when the A/B test does not improve the symptom**

  Do not persist `nvme_core.default_ps_max_latency_us=0`, `pcie_aspm=off`, or `pcie_port_pm=off` without a positive before/after result.

- [ ] **Step 6: Commit the experimental result**

  Commit only the ledger and sanitized conclusion; system counters and raw journals stay outside Git.

### Task 5: Finish SearXNG, Hermes, Camofox, Telegram, Voxtype, and Chromium acceptance

**Files:**
- Modify: the existing SearXNG plan/spec artifacts only when their status changes.
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Reuse: `docs/superpowers/plans/2026-09-11-searxng-agent-and-omarchy-hardening.md`
- Reuse: `docs/reports/2026-09-11-codex-searxng-camofox-block-red-team.md`

**Interfaces:**
- Consumes: local services and existing SearXNG contract.
- Produces: end-to-end acceptance evidence for the protected agent stack.

- [ ] **Step 1: Verify SearXNG local HTML, JSON, and bounded CLI paths**

  Confirm loopback-only bind, JSON result array, normalized output limits, raw-mode behavior, malformed input handling, and no Docker socket access.

- [ ] **Step 2: Make Hermes health meaningful**

  Keep bounded local checks for SearXNG, Camofox, and Hermes. Add a real local SearXNG query and Camofox session readiness check where the existing design permits it. Do not report Telegram as connected merely because its unit is active.

- [ ] **Step 3: Verify Camofox on demand**

  Create a real session, open a public page, capture a snapshot, close the tab/session, and confirm idle browser shutdown is treated as expected rather than as failure.

- [ ] **Step 4: Verify Hermes/Telegram without unapproved external messaging**

  Check DNS/VPN/API connectivity and reconnect behavior. A real send/receive message remains a separate user-confirmed test.

- [ ] **Step 5: Verify Voxtype and Chromium**

  Confirm a real transcription and paste, Chromium Codex control, SearXNG page, Camofox comparison, AdGuard Store installation, and absence of unintended extension duplication. Do not remove AdGuard Extra until its redundancy is demonstrated.

- [ ] **Step 6: Red-team all local boundaries**

  Test SearXNG down, Camofox idle, Chromium closed, VPN unavailable, invalid domains, `file://`, unknown tabs, malformed queries, and oversized output. Record graceful failure and fallback.

- [ ] **Step 7: Commit the acceptance evidence**

  Commit only sanitized reports and deliberately changed repository-owned bridge/config files.

### Task 6: Re-run the ten-site OSINT/red-team matrix

**Files:**
- Create: `docs/reports/2026-09-11-zenbook-agent-route-matrix.md`
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Create outside Git: `$zenbook_raw_root/2026-09-11-stability-program/red-team/`

**Interfaces:**
- Consumes: SearXNG/Camofox/Chromium acceptance from Task 5 and the prior red-team report.
- Produces: current, reproducible route comparison for ten sites.

- [ ] **Step 1: Reuse the existing ten-domain set and label the evidence type**

  Preserve the distinction between OONI-confirmed network observations, current VPN egress, HTTP reachability, login walls, CAPTCHA, legal takedown, and useful page content.

- [ ] **Step 2: Test each domain through four channels**

  SearXNG discovery, Camofox page/snapshot, Codex Chromium control, and ordinary Chromium. Do not bypass authentication, paywalls, CAPTCHA, or access controls.

- [ ] **Step 3: Run failure injections**

  Disable one local dependency at a time and record expected fallback/error behavior. Do not modify external sites or send forms.

- [ ] **Step 4: Compare every result with current OSINT**

  Use OONI/current authoritative sources for Russia measurements and distinguish US legal seizure, sanctions, geo restrictions, login walls, and ordinary service errors.

- [ ] **Step 5: Commit the sanitized matrix**

  Do not include cookies, credentials, raw browser logs, IP addresses, or machine-identifying data.

### Task 7: Audit memory, packages, services, containers, and extensions

**Files:**
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Create outside Git: `$zenbook_raw_root/2026-09-11-stability-program/hygiene/`

**Interfaces:**
- Consumes: all protected-workload acceptance evidence.
- Produces: a ranked keep/tune/remove list with measured impact and rollback.

- [ ] **Step 1: Measure idle and representative RSS**

  Take five samples for Hermes, Camofox, SearXNG/Docker, Voxtype, Quickshell, Telegram, Chromium, and Lemonade. Record peak and steady-state values, not just one snapshot.

- [ ] **Step 2: Audit package ownership**

  Separate explicitly installed packages, dependency packages, AUR packages, Rust crates, build caches, pacman cache, Docker images, Docker volumes, user caches, and coredumps.

- [ ] **Step 3: Audit services and ports**

  Map every active system/user unit and listener to an intentional workload. Treat Docker as a hidden dependency of SearXNG and decide whether its current always-on behavior is justified.

- [ ] **Step 4: Identify candidates**

  Candidates require all of: unused, not a dependency, not protected, reversible, and measurable. AdGuard Extra, stale Docker artifacts, old traces, redundant caches, and obsolete package remnants are reviewed separately.

- [ ] **Step 5: Remove or tune one candidate at a time**

  Use Omarchy package commands for package state, `gio trash` for recoverable user artifacts, and timestamped backups for configuration. After every removal, run the protected-workload smoke test.

- [ ] **Step 6: Commit only repository artifacts**

  System package/service state is recorded in the ledger; only scripts/config/docs owned by the repository are committed.

### Task 8: Final verification and release record

**Files:**
- Modify: `wiki/evidence/2026-09-11-stability-program-progress.md`
- Create: `docs/reports/2026-09-11-zenbook-stability-final.md`

**Interfaces:**
- Consumes: all previous task evidence.
- Produces: final acceptance matrix, unresolved risks, rollback map, and exact Git commit list.

- [ ] **Step 1: Re-read the spec and mark every acceptance gate**

  A gate is `PASS` only with fresh command output; otherwise mark it `PARTIAL`, `BLOCKED`, or `NOT APPLICABLE` with evidence.

- [ ] **Step 2: Run repository verification**

  ```bash
  ./tools/ci-check.sh
  ./tools/check-public-repo.sh
  git diff --check
  git status --short --branch
  ```

- [ ] **Step 3: Run final live-machine verification**

  Check failed units, protected services, SearXNG/Camofox health, Voxtype, storage health, fstrim timer, coredumps, and ports. Sanitize the output before publication.

- [ ] **Step 4: Record unresolved risks honestly**

  A historical counter, idle Camofox browser, active-but-not-connected Telegram unit, or running-but-crashed-before Quickshell must not be marked fully healthy.

- [ ] **Step 5: Commit the final report**

  The final commit must contain only the final Markdown report, ledger update, and any reviewed repository-owned configuration changes. It must not include raw `runs/` output or pre-existing user edits.
