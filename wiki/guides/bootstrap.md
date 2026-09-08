<div align="center">

# Bootstrap

**One command for a clean Omarchy restore. One stage when you need control.**

[Quick install](../../README.md#quick-install) · [Doctor](../operations/README.md) · [Recovery](recovery.md)

</div>

## Recommended

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash
```

The installer clones or updates the repository, selects the profile from DMI
and runs the supported stages in this order:

```text
VPN → display → NPU packages → native Voxtype → Lemonade model → terminal → optional Bitwarden onboarding → doctor
```

On the first run, expect the official AdGuard login, Omarchy's native Voxtype
confirmation and (at the very end) one optional Bitwarden question. The
installer reconnects safely on reruns, refuses to update a locally modified
checkout and does not run a system update implicitly.

## Verify without changing anything

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --check
```

The check clones the published repository into a temporary directory, validates
the profile and exits without installing packages or changing user files. The
normal installation command needs no arguments. It reports the exact source
branch and commit; a reviewed branch or tag can be selected with
`OMARCHY_REF=NAME`, while a modified or differently checked-out local
repository is refused for safety.

## Check the live system

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage doctor
```

`doctor` is read-only. It checks Omarchy, native Voxtype capture/output,
Lemonade's loaded NPU model, terminal settings, Hyprland configuration and VPN
status when those components belong to the selected profile.

## Run one stage

Use the same raw entry point when you want one action only:

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage vpn
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage display
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage packages
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage bitwarden
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage diagnostics
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage voice
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage terminal
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage update
```

From an existing checkout, the equivalent short commands are:

```bash
./scripts/install-vpn.sh
./scripts/install-display.sh
./scripts/install-packages.sh
./scripts/install-bitwarden.sh
./scripts/install-diagnostics.sh
./scripts/install-voice.sh
./scripts/install-terminal.sh
./scripts/install-update.sh
./scripts/doctor.sh
```

Network-dependent standalone stages automatically ensure the profile VPN unless
you pass `--no-vpn`. The display stage has no network dependency. Diagnostics
are optional and are not part of the clean flow.

The standalone voice stage is self-contained: it installs the voice-scoped
Lemonade/FLM packages first, then runs native Voxtype, installs the native
Silero VAD model and applies the NPU policy. It also installs the opt-in local
`technical` post-process profile. `--no-packages` cannot be combined with voice
because that would create an incomplete installation.

## Safe switches

| Switch | Effect |
|---|---|
| `--check` | Validate repository assets without changing the system |
| `--manifest` | Print the stage manifest as JSON |
| `--non-interactive` | Stop before interactive VPN/Voxtype/Bitwarden onboarding |
| `--no-vpn` | Do not connect AdGuard VPN for this run |
| `--no-voice` | Skip native Voxtype and its Zenbook policy |
| `--no-bitwarden` | Skip native Wayland Bitwarden setup |
| `--no-terminal` | Skip terminal settings |
| `--no-monitor` | Skip the tested display override |
| `--profile ID` | Select a profile instead of DMI detection |

## Profile behavior

`zenbook-um3406ka` is selected when DMI reports `UM3406KA`. It enables the
official AdGuard VPN CLI, tested display configuration, native Wayland Bitwarden
launcher, the two-package local Lemonade/FLM NPU voice backend, native Voxtype
policy and terminal extension.
The NPU package set is voice-scoped: `--no-voice` skips both native Voxtype and
Lemonade/FLM installation.
Other hosts use `generic`, which makes no automatic changes. Run the diagnostic
stage explicitly only when that is intended.

The installer never edits `/usr/share/omarchy`. It uses native Omarchy commands,
keeps user changes under `~/.config`, and stores recoverable backups under
`~/.local/state/omarchy-profiles/`.

## Native Bitwarden

The Zenbook profile installs only the Wayland path: `rbw`, `rofi-rbw`, `fuzzel`,
`wl-clipboard` and `pinentry`. Native Omarchy Voxtype owns `wtype`. It does not install the Electron
Bitwarden desktop client or X11 typing/clipboard tools. The profile creates
`~/.local/bin/omarchy-bitwarden` and replaces the default password-manager
binding `Super + Shift + /` with that launcher.

The default path keeps Chromium user-managed: onboarding opens the official Web
Store and asks you to confirm the extension is installed. A machine-wide
Chromium force-install policy is deliberately opt-in via
`OMARCHY_BITWARDEN_FORCE_CHROMIUM_EXTENSION=1`; it requires `sudo` and remains
managed until `bitwarden/apply.sh --rollback` removes the repository's policy.
An existing Bitwarden installation is detected and left user-managed.

The full restore asks before entering this stage. If accepted, the guided
onboarding asks for the Bitwarden email, runs the first-time `rbw register`,
login and sync, opens the official browser-extension store, waits for the user
to install and log in to the extension, and finishes with a hotkey test. The
onboarding refuses to mark completion until the extension installation is
confirmed. The first-time `rbw register` still requires the user to enter
their API key; no credential is accepted by the installer or stored in this
repository. Browser autofill and Android autofill remain the responsibility of
the official Bitwarden clients. Edit vault items in the Bitwarden web vault. The
user configuration is backed up before the profile changes pinentry, a
10-minute lock timeout and hourly sync.

Normal installs use a compact progress view. If a stage fails, reopen
`zenbook-omarchy` and select that component to retry; no long command is needed.

After the first GitHub installation, use the short local launcher instead of
retyping the raw URL:

```bash
zenbook-omarchy
```

Choose **Bitwarden** from the numbered menu, or run `zenbook-omarchy bitwarden`.
The latter opens onboarding in a visible Foot window so prompts are not hidden
inside an automation terminal.

The menu is a multi-select orchestrator: choose any combination of display,
voice/NPU, Bitwarden, terminal and diagnostics, then confirm once. Required
runtime package and VPN dependencies are added automatically, the components
run in the safe order, and doctor verifies the result at the end. The Omarchy
system update is intentionally selectable only by itself; re-apply the profile
after that update.

There is no separate Packages choice in the menu. Packages are implementation
dependencies: Voice adds native Voxtype plus the Lemonade/FLM NPU runtime,
Bitwarden adds its native Wayland tools, and Diagnostics adds its optional
hardware tools. This keeps the user menu focused on capabilities rather than
package names.

Run the read-only live check with:

```bash
./scripts/doctor.sh --profile zenbook-um3406ka
```

## Full update policy

The clean restore does not update the operating system automatically. Use
`--stage update` only when you explicitly want Omarchy to own the snapshot,
migrations and package update. Run the profile again after the update so
user-owned overrides are checked against the new Omarchy defaults.

```bash
curl -fsSL https://raw.githubusercontent.com/shubinlab/zenbook-omarchy/main/sh.sh | bash -s -- --stage update
```

Older Zenbook installs can use the opt-in legacy repair command. It is never
called by a clean install:

```bash
./scripts/repair-voice-legacy.sh --check
./scripts/repair-voice-legacy.sh --apply
```
