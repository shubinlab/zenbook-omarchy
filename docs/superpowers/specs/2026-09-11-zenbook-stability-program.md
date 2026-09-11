# Zenbook Omarchy Stability Program

**Date:** 2026-09-11

**Status:** Approved for staged execution

## Goal

Make the Omarchy 4 Zenbook stable, measurable, low-bloat, and safe for the requested local agent stack while preserving Telegram autostart, Hermes gateway, Camofox/Node, Voxtype, SearXNG, Chromium, and ASUS hardware controls.

## Scope

- Diagnose and reduce unsafe NVMe shutdowns without assuming that the SSD is defective.
- Verify firmware, BIOS, kernel, NVMe driver, APST, suspend/resume, and Btrfs behavior.
- Find the root causes of Quickshell, Nautilus, and related desktop coredumps.
- Verify Hermes, Telegram, SearXNG, Camofox, Voxtype, Chromium, and AdGuard end to end.
- Complete the ten-site Russia/United States comparison through SearXNG, Camofox, Codex Chromium, and ordinary Chromium over the active VPN.
- Remove only redundant packages, services, extensions, caches, and containers after evidence.
- Record every stage, red-team result, OSINT reference, rollback path, and unresolved risk in Markdown and Git.

## Protected workloads

Telegram autostart, Hermes gateway, Camofox/Node, Voxtype, SearXNG, Chromium, the Codex extension, `asusctl/asusd`, and the local VPN path are not removal candidates. They may be tuned only after an idle/use-case measurement and a recovery test.

## Safety constraints

- Never edit `/usr/share/omarchy/`; use Omarchy commands or user-scoped configuration.
- Never publish serial numbers, hostnames, EDID hashes, credentials, raw journals, or unsanitized diagnostic output.
- Do not disable APST, PCIe ASPM, or suspend globally without a reproduced NVMe symptom and a reversible A/B test.
- Do not flash firmware without AC power, backup confirmation, and a separate verification checkpoint.
- Do not send real Telegram messages, submit forms, place orders, or alter external accounts during tests without an explicit per-test confirmation.
- Do not give any agent access to the Docker socket or arbitrary local files.
- Every production change must have a timestamped backup, a positive verification, a red-team check, an OSINT/reference check, and a rollback command.

## Current evidence baseline

- BIOS is `UM3406KA.306`; the ASUS support page lists BIOS 306 for this model.
- Kernel is `7.2.3`; the in-tree `nvme` driver, `linux-firmware`, and `amd-ucode` are installed.
- WD_BLACK SN850X health is `PASSED`, temperature is 44°C, media/data-integrity errors are zero, and the current NVMe error-log entries are zero.
- `unsafe_shutdowns=125` and `error_log_entries=14` are lifetime counters, not proof of current media failure.
- Kernel journals inspected so far contain no NVMe timeout, controller reset, AER, or I/O error; suspend uses `s2idle`.
- APST is enabled with the kernel default latency budget; no APST change is justified by current evidence.
- `rog-control-center` is removed; `asusctl/asusd` remains intentionally active.
- Quickshell still has recent coredumps and is unresolved.
- SearXNG/Camofox/Chromium paths have partial or historical positive tests, but direct multi-agent readiness and a durable ten-site matrix remain acceptance gates.

## Acceptance gates

1. No unexplained new critical coredump or NVMe error during the observation window.
2. SMART remains healthy and NVMe counters do not increase after clean operations.
3. BIOS, firmware, kernel, and trim state are verified from the live machine.
4. Quickshell root cause is either fixed and verified or documented as an upstream/package blocker with a safe containment decision.
5. Hermes and Telegram are tested beyond `systemd active`.
6. SearXNG is usable by Hermes and Codex through the same bounded local interface.
7. Camofox creates and closes real sessions; idle state is distinguished from failure.
8. Ten-site red-team results are reproducible and separate network, geo, login, CAPTCHA, and agent/browser failures.
9. Protected workloads remain functional with before/after memory evidence.
10. Every retained change is documented, committed, and reversible.
