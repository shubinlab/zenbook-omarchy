# Changelog

## Unreleased

- Hardened shared Hyprland binding migration and rollback so Bitwarden and
  terminal changes cannot erase each other's managed blocks; legacy duplicate
  bindings are removed safely.
- Made Chromium extension force-install opt-in, made Bitwarden onboarding fail
  closed when the official extension is not confirmed, and removed duplicate
  `wtype` package ownership from the Bitwarden stage.
- Decoupled already-ready local Lemonade/NPU voice and terminal stages from the
  VPN, while keeping network-dependent package and update stages ordered behind
  the explicit AdGuard VPN step.
- Added an HDMI feedback-sink warning and rejected combining a system update
  with the all-in-one stage; re-apply the profile after Omarchy updates.
- Calibrated the Zenbook voice capture baseline to 30% after measuring clipping
  at 60% and a too-quiet VAD input at 15%.
- Added the short `zenbook-omarchy` launcher with a numbered menu and a visible
  Foot window for interactive Bitwarden onboarding.
- Changed the launcher menu to multi-select components and execute the selected
  combination through one dependency-aware orchestrator run; system update
  remains an explicit standalone action.
- Removed the confusing user-facing Packages choice: runtime packages are now
  internal dependencies of the selected components, and the package-only stage
  no longer installs voice packages accidentally.
- Added a compact installer progress view with a single final verification
  summary, warning/error context and an explicit `OMARCHY_VERBOSE=1` trace mode.
- Added a no-change `--plan` preview, exact source commit reporting, safe
  branch selection via `OMARCHY_REF`, and a direct `--verbose` shortcut.
- Added CI coverage for the plan's native boundary and standalone-stage scope.
- Made the no-argument path the only prominent user flow; advanced plan and
  trace switches remain available internally but are no longer advertised as
  normal steps.
- Kept a single public `install.sh` entry point for the clean-install flow.
- Simplified clean installation into ordered VPN, display, package, native
  Voxtype, terminal and doctor stages; diagnostics and update are explicit
  optional stages.
- Moved legacy PipeWire/VAD cleanup into an opt-in voice repair command.
- Removed duplicate package ownership and consolidated the native voice check.
- Added the Arch-native Lemonade/FastFlowLM voice backend and routed active
  Whisper inference to the AMD XDNA2 NPU while retaining Omarchy Voxtype as
  the capture, feedback, typing, service and binding authority.
- Removed the obsolete local monitor collector, service, files and docs.
- Added a canonical Zenbook hardware and peripheral inventory.
- Added a per-file restore map and guided recovery commands.
- Reworked the main README around restoration, diagnostics and current known-good values.
- Preserved the terminal extension with its package, doctor and rollback paths.
- Kept hardware-specific runners and evidence inside the Zenbook profile.

## 2026-09-08

- Added the one-command GitHub installer and no-change verification mode.
- Added the 240 Hz, 10-bit, sRGB, VRR and scale 1.6 monitor profile.
- Added platform and diagnostic package manifests.
- Recorded the dock, display, HDR, component and protected VRR investigations.
- Removed raw run artifacts from the public tree; local runs remain ignored.
