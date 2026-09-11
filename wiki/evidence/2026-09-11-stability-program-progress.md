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
- Next gate: commit the three program documents, then run the fresh storage/firmware baseline.

## Decision log

| Decision | Reason | Rollback |
| --- | --- | --- |
| Keep current APST initially | No NVMe timeout/reset/AER/I/O evidence; only historical counters | No change to roll back |
| Do not install a WD Linux driver | NVMe support is provided by the kernel driver; `nvme-cli` is management tooling | No extra driver installed |
| Preserve `asusctl/asusd` | Hardware backend is distinct from removed ROG GUI | Reinstall only through approved Omarchy package path if later needed |
| Treat Camofox idle browser as expected state | Service supports on-demand browser lifecycle | Create/close a real session to verify readiness |
| Keep protected workloads | Explicit user requirement | Any tuning must be measured and reversible |

## Checkpoint commits

The first documentation checkpoint is created after the repository boundary and Markdown syntax are verified. Subsequent commits will be listed here with task name, verification command, and pass/partial result.
