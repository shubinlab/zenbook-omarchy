# Changelog

## Unreleased

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
