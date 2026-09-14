# Omarchy 4 Unified Improvement and GitHub Sync Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Continue improving the Zenbook Omarchy 4 profile one evidence-backed change at a time, preserve the vendor architecture across updates, and publish only sanitized, focused, verified improvements to the repository on GitHub.

**Architecture:** `/usr/share/omarchy` and the vendor `quattro` source are read-only authority. User behavior belongs in `~/.config`, user plugins, hooks, or narrowly owned services. Every component has one lifecycle owner; a local workaround must not mask or replace a native Omarchy owner. The current canonical input contract is Hyprland XKB for ordinary `us/ru`, supervised Fcitx5 for XCompose/IME, and Omarchy Quickshell for the bar indicator.

**Tech Stack:** Omarchy 4.0.3, Arch Linux, Hyprland Lua, Quickshell, Fcitx5, systemd user services, D-Bus, Wayland, Docker Compose/SearXNG, Hermes/Camofox, Voxtype, Chromium, Bash, Python, Markdown, Git and GitHub pull requests.

**Spec:** [`docs/superpowers/specs/2026-09-11-zenbook-stability-program.md`](../specs/2026-09-11-zenbook-stability-program.md)

## Canonical document map

- Architecture and extension boundary: [`docs/omarchy-4-native-extension-contract.md`](../../omarchy-4-native-extension-contract.md).
- Host/repository investigation and evidence: [`docs/reports/2026-09-14-host-and-repository-audit.md`](../../reports/2026-09-14-host-and-repository-audit.md).
- Input-specific regression plan: [`2026-09-14-omarchy4-native-input-regression.md`](2026-09-14-omarchy4-native-input-regression.md).
- Earlier broad stability plan: [`2026-09-11-zenbook-stability-program.md`](2026-09-11-zenbook-stability-program.md); this document is its current umbrella for execution and publication.
- SearXNG/Hermes subplan: [`2026-09-11-searxng-agent-and-omarchy-hardening.md`](2026-09-11-searxng-agent-and-omarchy-hardening.md).
- Sanitized progress ledger: [`wiki/evidence/2026-09-11-stability-program-progress.md`](../../../wiki/evidence/2026-09-11-stability-program-progress.md).

## Verified baseline — 2026-09-14

| Area | State | Next gate |
| --- | --- | --- |
| Input ownership | PASS: physical Foot test, GTK/Qt/Chromium delivery, Fcitx service and D-Bus single-owner red-team | Fresh login/update recheck; decide separately whether a cursor popup is required |
| `ru/en` indicator | Explained: Omarchy's native indicator is the top bar; Fcitx `notificationitem` is intentionally disabled, and the current Fcitx profile has one `keyboard-us` fallback | Do not add a second owner. If cursor popup is required, run an isolated opt-in experiment and prove no layout/input regression |
| Quickshell | CONTAINED, not permanently fixed: upstream QML/Qt lifetime race remains possible | Track upstream/package fix; rerun controlled restart and coredump matrix after each relevant update |
| SearXNG/Hermes | Prepared in repository; host apply still requires visible privileged authentication and post-apply health checks | Apply once, then test container readiness, HTML/JSON, normalized search and Hermes health |
| Voice | Service/model path previously healthy, live profile drift still requires end-to-end capture acceptance | Apply versioned policy only if drift is reproduced; verify real microphone capture and paste/output |
| Repository contract | CI, public-repo scan, bootstrap check and input policy tests pass in the current dirty worktree | Separate focused commits; never stage unrelated existing changes or raw runs |
| GitHub publication | `origin` is `https://github.com/shubinlab/zenbook-omarchy.git`; current branch is `main` and worktree is intentionally dirty | Use clean publication worktree/branch, fetch, rebase or merge consciously, verify, then push a focused branch and open a PR |

## Non-negotiable method

1. Read the installed vendor source and current official documentation for the exact Omarchy branch.
2. Assign one owner before changing anything: Hyprland, Fcitx5, Quickshell/plugin, systemd, Docker, profile script, or package.
3. Capture a sanitized baseline and state the hypothesis in one sentence.
4. Add or reuse a failing regression check before implementation when behavior is changing.
5. Change one bounded variable in a user-scoped location.
6. Run positive acceptance, adversarial/red-team checks, persistence checks after restart/login/update, and OSINT cross-checks.
7. Record fact, interpretation, unknown, rollback and remaining risk in the linked report/ledger.
8. Publish only after `ci-check`, public scan and `git diff --check` pass.

## Execution backlog

### Task 1: Rebaseline the native Omarchy boundary

- [x] Record `omarchy version`, package versions, vendor source revision, active user units, shell/plugin state and repository status.
- [x] Confirm no user mask, no `no-fcitx` environment override, no duplicate lifecycle owner and no edits under `/usr/share/omarchy`.
- [x] Run the native contract checks and update only the sanitized evidence ledger.

### Task 2: Finish input and indicator acceptance

- [ ] Repeat physical Alt+Shift, Latin/Cyrillic and CapsLock/XCompose acceptance after a fresh graphical login.
- [ ] Repeat the GTK, Qt/QML and Chromium fixtures with explicit focus and unique non-sensitive markers.
- [ ] Verify the native top-bar indicator after `us/ru` switching and shell restart.
- [ ] If the user specifically requires a popup beside the cursor, test the smallest reversible option in an isolated profile. Do not add `keyboard-ru` to the permanent Fcitx profile until text delivery, XCompose, D-Bus ownership and restart behavior all pass.
- [ ] Update [`2026-09-14-omarchy4-native-input-regression.md`](2026-09-14-omarchy4-native-input-regression.md) with the result; a missing popup alone is not evidence that Fcitx or D-Bus is broken.

### Task 3: Quickshell and desktop-shell stability

- [x] Keep the current containment explicit and reversible; do not call it a root-cause fix.
- [ ] After each Omarchy/Qt/Quickshell update, run the controlled shell restart, plugin reload and coredump matrix.
- [ ] Compare new cores with upstream reports before changing packages, themes or plugins.
- [ ] Only promote an update to permanent remediation when the failing signature disappears across the controlled matrix and the shell recovers after restart/login.

### Task 4: SearXNG/Hermes lifecycle completion

- [ ] Apply the prepared native user/system service only with visible authentication and record the exact ownership boundary.
- [ ] Verify Docker readiness, container health, loopback binding, HTML and JSON search, normalized `searxng-search`, engine quality and Hermes healthcheck separately.
- [ ] Red-team boot/restart, Docker restart, stale container, unavailable network and missing credentials; preserve a clean rollback.

### Task 5: Voice, display, terminal and peripheral acceptance

- [x] Treat voice, display, terminal input, printer/scanner, Bluetooth and cloud tools as separate contracts with real target tests.
- [x] Do not infer microphone, display or peripheral success from configuration syntax; capture the actual device/app operation.
- [x] Keep optional hardware/cloud installers standalone and outside the default Omarchy bootstrap unless their ownership and rollback are explicit.

### Task 6: Repository quality and publication gate

- [x] Keep raw journals, serials, hostnames, EDID hashes, credentials and typed text outside published Markdown.
- [x] Make test discovery explicit; reject a zero-test result as success for supported profile checks.
- [x] Add/update documentation and cross-links in the same focused change as behavior.
- [x] Run the repository gate:

```bash
./tools/ci-check.sh
./tools/check-public-repo.sh
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./profiles/zenbook-um3406ka/input/test_input_policy.sh
./profiles/zenbook-um3406ka/input/doctor.sh
git diff --check
```

## GitHub synchronization workflow

The current working tree contains user-owned changes and must not be mass-staged. Publication is a separate, focused operation:

```bash
git status --short --branch
git fetch --prune origin
git log --oneline --decorate -8
git diff --check
```

For a publishable change, create a clean worktree from the intended base (`origin/main`), bring over only the reviewed files, run the complete gate there, then use an imperative scoped commit such as `fix(zenbook): preserve native input ownership`. Push a topic branch, open a PR, and include:

- user-visible result;
- exact evidence and tests;
- OSINT/vendor links;
- rollback and remaining limitations;
- public-data checklist confirmation.

Do not push `main`, force-push, or publish raw `runs/` output. A PR is not complete until its branch is reproducible from a clean checkout and the live host acceptance result is recorded in sanitized form.

## Completion definition

The program is complete only when the relevant component has a verified owner, a real acceptance test, red-team coverage, persistence evidence across the next update boundary, linked documentation, and a focused GitHub publication. A passing static check alone is never a permanent fix.
