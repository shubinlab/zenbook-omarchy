# Full component audit — 2026-09-08

## Scope and method

The audit used Omarchy's user configuration model and the installed `omarchy-debug --no-sudo --print` diagnostic path. It combined read-only inventory, a protected short load test, camera and microphone capture discarded to `/dev/null`, a temporary 512 MiB Btrfs write/read/delete test, Ethernet gateway pings, and a reversible display-scale A/B check.

The protected phases used `systemd-inhibit` for idle, sleep and lid-switch actions. Omarchy Stay Awake was already enabled. No kernel parameters, firmware, packages, system services or stock files under `/usr/share/omarchy` were changed.

## Results

| Component | Evidence | Result |
|---|---|---|
| CPU | Ryzen AI 7 350, 8 cores/16 threads, AMD P-State EPP, boost enabled | Healthy; no CPU or thermal error |
| CPU thermal behavior | 8-way SHA-256 workload; peak Tctl about 85.4 °C, fan about 2600 RPM; returned to about 60.5 °C | Passed short load; no throttling or crash evidence |
| Memory/zram | 1 GiB allocate, page-touch and SHA-256; 30 GiB RAM available, zram and swap unused | Passed |
| GPU | Radeon 840M/860M, `amdgpu`, power state D0; GPU peak about 64 °C during CPU/memory run | Healthy in tested workload |
| NPU | AMD XDNA device and driver enumerated | Enumerated; no workload test installed |
| Display path | DP-1 connected through JSAUX; current profile is 1440p/240 Hz/10-bit/VRR/DPMS with `cm=srgb`, plus an 8-sample 144 Hz post-fix control run | Passed |
| Display scale | DP-1 uses the Omarchy-managed `omarchy_monitor_scale` variable; scale 1.6 survives the official scaling command and reload | Current user profile |
| NVMe/Btrfs | WD_BLACK SN850X; temporary 512 MiB write with `fdatasync`, read and delete; Btrfs device stats all zero | Passed; diagnostic tools are installed, but direct SMART access was not completed in the restricted test shell |
| Camera | 30-frame V4L2 stream, about 24.32 fps, output discarded | Passed |
| Microphone | 2-second ALSA capture to `/dev/null` | Passed |
| Audio | PipeWire, WirePlumber, analog sink/source and HDMI sink active | Routing healthy; audible speaker test was not run |
| Ethernet | USB Realtek link at 5 Gb/s, interface 1 Gb/s full duplex; gateway ping 10/10, 0% loss, average 0.573 ms | Passed; cumulative RX drops should be watched, errors are zero |
| Wi-Fi | MediaTek MT7922 with `mt7921e`; interface present but no carrier while wired Ethernet is active | Hardware enumerated; over-air test not performed |
| Bluetooth | MediaTek controller powered and pairable | Controller healthy; no new pairing test performed |
| USB dock/peripherals | USB2 hub 480 Mb/s, USB3 hub 10 Gb/s; keyboard/mouse receivers, LG controls, microphone and Ethernet enumerated | Link topology is plausible and stable |
| Battery/charging | 67.4 Wh full charge against 75 Wh design, approximately 89.9% reported condition; AC online, threshold 100% | Usable; optional 80% cap for docked use |
| Services | No system or user failed units; PipeWire, WirePlumber, Hyprland and telemetry active | Passed |

## Findings requiring follow-up

The kernel reported `usbhid ... couldn't find an input interrupt endpoint` once at boot for USB device `306f:1234`, product `Wushi0.01S60`, on the USB2 branch of the dock. The device has no usable input interface in sysfs. It is a malformed or vendor-specific HID-like interface candidate, but it is not on the DisplayPort path and did not recur during the display or component tests. If keyboard/mouse glitches appear, isolate it by unplugging nonessential USB2 devices one at a time; do not add a kernel quirk yet.

The boot journal also contains one ACPI warning about an unexpected lid state, plus routine platform warnings from `asus_armoury`, the AMD audio machine-driver probe, missing RTKit real-time priority, `boltd` not recognizing the USB4 NHI PCI ID, and the sensor hub reporting a short event. Audio, Bluetooth, USB4/DisplayPort Alt Mode and thermal behavior still worked in the observed session. These are candidates for package/firmware investigation, not confirmed failures.

One unprotected suspend/resume occurred earlier in the boot after an idle/lock sequence. The protected tests did not suspend, lock or lose DP-1. This confirms that the test wrapper must keep both Omarchy Stay Awake and the systemd inhibitor active when the lid is closed.

The earlier mode drift investigation is now resolved to a concrete configuration cause. Omarchy's active `internal-monitor-mirror.lua` toggle contained a DP-1 rule with `mode = "preferred"`, `scale = 1` and `mirror = "eDP-1"`. Disabling that toggle with `omarchy hyprland monitor internal mirror off`, reloading Hyprland and applying the explicit DP-1 rule restored 144 Hz. The subsequent 32-second control run kept 143.991 Hz, scale 1.0, VRR on, DPMS on and `mirrorOf = none` in all eight samples.

## Improvements ranked by evidence

1. Install observability tools through Omarchy when convenient: `usbutils`, `ethtool`, `nvme-cli`, `smartmontools`, `fwupd`, `fio` and `stress-ng`. They improve future evidence quality; they are not required to fix the current display.
2. Keep scale 1.6 for the current UI profile. The external rule must reference `omarchy_monitor_scale`; a literal scale value breaks the normal Omarchy scaling command after reload.
3. Consider an 80% battery charge limit if the laptop remains docked most of the time. It was not enabled automatically.
4. Keep the current AMD P-State EPP policy and avoid importing the APST workaround or manual EPP/governor settings from another distribution until a matching failure is reproduced.
5. If audio dropouts occur under load, revisit the missing RTKit service. Current PipeWire routing and microphone capture pass without it.
6. Do not change BIOS, kernel command line, lid handling or USB quirks based only on the warnings above. First reproduce the affected function and collect a matched before/after run.

## Limitations

No SMART self-test, Wi-Fi association test, Bluetooth pairing test, speaker playback test, GPU benchmark or suspend test was run. Each would either require a missing tool, a user-visible side effect, a network change, or a deliberate power-state transition that could invalidate the closed-lid display session.

The CPU phase produced valid thermal samples and SHA-256 results, then the runner stopped the multi-process OpenSSL group after the measurement window. Its `-15` return code describes the controlled test stop, not a laptop failure.

## Evidence files

- Raw component and steady-state runs remain local under the Git-ignored `runs/` directory.
- `docs/AUDIT-2026-09-08.md`
- `docs/INCIDENT-2026-09-08-display-mode-drift.md`
- `docs/REPOSITORY-MAP.md`
- `docs/VENDOR-COMMUNITY-RESEARCH-2026-09-08.md`
