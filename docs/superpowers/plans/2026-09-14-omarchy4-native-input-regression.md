# Omarchy 4 Native Input Regression Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve and re-verify the vendor-native Omarchy 4 input architecture across future login and update boundaries without masking Fcitx5 or removing D-Bus activation.

**Architecture:** Hyprland XKB owns the ordinary `us,ru` physical layout; Omarchy's supervised Fcitx5 user service remains the XCompose/IME layer. The Zenbook profile changes only user-scoped Hyprland/input policy and diagnostics, while native services, environment, D-Bus activation, and Omarchy shell ownership remain authoritative.

**Tech Stack:** Omarchy `4.0.3-1`, Arch Linux, Hyprland Lua, Fcitx5, systemd user units, D-Bus, Wayland, Foot, GTK4/PyGObject, Qt6/QML, Chromium, `wtype`, Bash, Python, Markdown.

**Spec:** [`docs/omarchy-4-native-extension-contract.md`](../../omarchy-4-native-extension-contract.md)

## Global Constraints

- Never edit `/usr/share/omarchy`; read it only as vendor source.
- Keep `omarchy-fcitx5.service` `enabled/active` and preserve `INPUT_METHOD=fcitx`, `QT_IM_MODULE=fcitx`, `SDL_IM_MODULE=fcitx`, and `XMODIFIERS=@im=fcitx`.
- Do not remove D-Bus autoactivation or create a second Fcitx lifecycle owner.
- Treat physical hardware evidence and `wtype` virtual-keyboard evidence as separate acceptance classes.
- Change one hypothesis at a time; no input ownership change without a reproducible failing application test.
- Do not store typed user text; only store pass/fail and sanitized state.

## Knowledge and evidence map

- Native architecture and extension boundaries: [`docs/omarchy-4-native-extension-contract.md`](../../omarchy-4-native-extension-contract.md).
- Umbrella improvement and GitHub publication plan: [`2026-09-14-omarchy4-unified-improvement-and-github-sync.md`](2026-09-14-omarchy4-unified-improvement-and-github-sync.md).
- Investigation evidence and red-team history: [`docs/reports/2026-09-14-host-and-repository-audit.md`](../../reports/2026-09-14-host-and-repository-audit.md).
- Input component policy and upstream references: [`profiles/zenbook-um3406ka/input/README.md`](../../../profiles/zenbook-um3406ka/input/README.md).
- Regression policy test: [`test_input_policy.sh`](../../../profiles/zenbook-um3406ka/input/test_input_policy.sh).
- GTK fixture: [`gtk-input-acceptance.py`](../../../profiles/zenbook-um3406ka/input/gtk-input-acceptance.py).
- Qt fixture: [`qt-input-acceptance.qml`](../../../profiles/zenbook-um3406ka/input/qt-input-acceptance.qml).
- Chromium fixture: [`chromium-input-acceptance.html`](../../../profiles/zenbook-um3406ka/input/chromium-input-acceptance.html).
- Vendor documentation: [Omarchy dotfiles](https://github.com/omacom/omarchy/blob/quattro/manual/31-dotfiles.md), [keyboard manual](https://github.com/omacom/omarchy/blob/quattro/manual/34-keyboard-mouse-trackpad.md), [shell plugins](https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md), and [Hyprland load order](https://github.com/omacom/omarchy/blob/quattro/config/hypr/hyprland.lua).
- Known compatibility reports: [Omarchy #9552](https://github.com/omacom/omarchy/issues/9552) and [#483](https://github.com/basecamp/omarchy/issues/483).

## Current verified state

| Boundary | Verified result | Evidence |
|---|---|---|
| Physical hardware | Both Alt+Shift orders, Latin/Cyrillic input, and CapsLock/XCompose work in Foot | User physical acceptance on 2026-09-14 |
| GTK/Qt/Chromium delivery | Unique strings reached native Wayland targets through `wtype` | Toolkit fixtures and title/signal output |
| Fcitx owner | `enabled/active`, `NRestarts=0`, runtime `keyboard-us` | `systemctl --user`, `fcitx5-remote -n` |
| Language indicator | Native Omarchy indicator is the top bar; cursor popup is not expected from the current XKB-owned `us/ru` path | Vendor service, shell widget, current single-item Fcitx profile |
| D-Bus red-team | Stopping the unit and calling `fcitx5-remote -n` creates a stray owner; systemd then enters `auto-restart` | Report section 4.2 |
| Repository gate | Input regression test, doctor, bootstrap, CI and public scan pass | Fresh 2026-09-14 checks |

## Execution tasks

### Task 1: Re-baseline after a graphical login or Omarchy update

**Files:**
- Read: `profiles/zenbook-um3406ka/input/input.lua`
- Read: `profiles/zenbook-um3406ka/input/fcitx5-profile`
- Read: `docs/reports/2026-09-14-host-and-repository-audit.md`

- [x] **Step 1: Record vendor and live versions.**

```bash
omarchy version
systemctl --user show omarchy-fcitx5.service -p ActiveState -p SubState -p NRestarts -p UnitFileState
fcitx5-remote -n
hyprctl getoption input:kb_layout
hyprctl getoption input:kb_options
```

- [x] **Step 2: Confirm no user override masks the service.**

```bash
test ! -e "$HOME/.config/systemd/user/omarchy-fcitx5.service"
test ! -e "$HOME/.config/environment.d/90-zenbook-omarchy-no-fcitx.conf"
```

- [x] **Step 3: Run the read-only profile gates.**

```bash
./profiles/zenbook-um3406ka/input/test_input_policy.sh
./profiles/zenbook-um3406ka/input/doctor.sh
./profiles/zenbook-um3406ka/input/apply.sh --check
```

### Task 2: Re-run emulated toolkit delivery

**Files:**
- Read: `profiles/zenbook-um3406ka/input/gtk-input-acceptance.py`
- Read: `profiles/zenbook-um3406ka/input/qt-input-acceptance.qml`
- Read: `profiles/zenbook-um3406ka/input/chromium-input-acceptance.html`

- [x] **Step 1: Launch the GTK fixture under Wayland and focus it.**

```bash
GDK_BACKEND=wayland python3 profiles/zenbook-um3406ka/input/gtk-input-acceptance.py
```

Inject a unique non-sensitive marker with `wtype`; accept only if the GTK signal emits the same marker.

- [x] **Step 2: Launch the Qt fixture under Wayland and focus it.**

```bash
QT_QPA_PLATFORM=wayland qml6 profiles/zenbook-um3406ka/input/qt-input-acceptance.qml
```

Accept only if the window title includes the injected marker.

- [x] **Step 3: Launch the Chromium fixture as an isolated Wayland app.**

```bash
chromium --ozone-platform=wayland --user-data-dir="$(mktemp -d /tmp/omarchy-chromium-input.XXXXXX)" --no-first-run --no-default-browser-check --app="file://$PWD/profiles/zenbook-um3406ka/input/chromium-input-acceptance.html"
```

Accept only if the page title includes the injected marker. Do not retain the temporary profile or typed value.

### Task 3: Repeat physical acceptance when input ownership changes

**Files:**
- Update: `docs/reports/2026-09-14-host-and-repository-audit.md`
- Update: `docs/omarchy-4-native-extension-contract.md`

- [ ] **Step 1: Test both modifier orders on the physical keyboard in Foot.**
- [ ] **Step 2: Test Latin/Cyrillic text and CapsLock/XCompose without recording text.**
- [ ] **Step 3: Record only the result and active service/keymap state.**

### Task 4: Handle a future mismatch with a failing regression first

**Files:**
- Modify only the smallest affected user-scoped input file after the failure is reproduced.
- Test: `profiles/zenbook-um3406ka/input/test_input_policy.sh` or a new focused fixture.

- [ ] **Step 1: Capture the failing toolkit, active XKB group, Fcitx method, and environment.**
- [ ] **Step 2: Add a regression case that fails before the proposed change.**
- [ ] **Step 3: Test one synchronized Fcitx/XKB hypothesis without masking the service.**
- [ ] **Step 4: Re-run physical and toolkit acceptance plus the D-Bus single-owner red-team.**
- [ ] **Step 5: Update the evidence map and report; if no native-compatible fix exists, document the limitation instead of selecting XKB-only by default.**

### Task 5: Investigate the optional cursor language popup without changing ownership

The observed disappearance of `ru/en` beside the text cursor is explained by the current ownership contract: ordinary `us/ru` switching is Hyprland XKB, while the vendor service disables only Fcitx's tray `notificationitem` because Omarchy renders its own bar indicator. The current Fcitx profile has one `keyboard-us` fallback, so Fcitx does not receive a second input-method transition to display.

- [ ] **Step 1: Confirm the native top-bar label changes on both physical layout transitions and after shell restart.**
- [ ] **Step 2: If a cursor popup remains a hard requirement, create a reversible isolated Fcitx profile experiment; do not edit the permanent profile first.**
- [ ] **Step 3: Test popup visibility, actual GTK/Qt/Chromium text, CapsLock/XCompose, Fcitx service ownership, D-Bus activation and restart/relogin persistence.**
- [ ] **Step 4: Keep the experiment out of the permanent profile if it creates a second layout owner or causes any toolkit mismatch; record the limitation and retain the vendor-native top-bar indicator.**

## Completion gates

```bash
./tools/ci-check.sh
./tools/check-public-repo.sh
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./profiles/zenbook-um3406ka/input/test_input_policy.sh
./profiles/zenbook-um3406ka/input/doctor.sh
git diff --check
```

The plan is not complete merely because the configuration parses. It is complete only when the native service owner, D-Bus path, physical acceptance, toolkit delivery, update boundary, and sanitized evidence all remain consistent.
