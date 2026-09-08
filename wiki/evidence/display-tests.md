# Display red-team results

Last verified: 2026-09-08

## Valid protected run

The protected run was written locally under the Git-ignored `runs/` directory. It ran with Omarchy idle disabled and a systemd inhibitor active.

All six matrix phases had 15 samples each and zero harness anomalies:

| Mode | Content | Format | Hyprland VRR | DRM active VRR | DPMS | Connector |
|---|---|---|---|---|---|---|
| 1920×1080@120 | windowed | 10-bit | true | 1 | true | connected |
| 2560×1440@120 | fullscreen | 10-bit | true | 1 | true | connected |
| 2560×1440@144 | windowed | 10-bit | true | 1 | true | connected |
| 2560×1440@144 | fullscreen | 10-bit | true | 1 | true | connected |
| 2560×1440@240 | fullscreen | 10-bit | true | 1 | true | connected |
| 2560×1440@144 | fullscreen | 8-bit | true | 1 | true | connected |

The mode-cycle stress test changed 144→120→240 Hz three times. Every sample reported an active inhibitor, an active unlocked session, DP-1 connected, DPMS on and DRM VRR active.

The intentional DPMS test produced the expected `DPMS=false` sample and recovered to `DPMS=true`. It did not suspend or lock the system under the inhibitor. The kernel journal recorded a USB HID reconnect for the LG monitor controls after the DPMS cycle; this is a real DPMS recovery side effect and should be treated separately from idle timeout.

The post-fix wrapper check repeated three 144→120→240 Hz cycles and a DPMS off/on cycle. All samples kept DP-1 connected, the session active and unlocked, the inhibitor active, 10-bit output, scale 1.6, sRGB and Hyprland VRR enabled. The final state returned to 239.970 Hz, scale 1.6, sRGB, VRR on, DPMS on and no mirror. The only kernel event was the expected USB disconnect/re-enumeration of `LG Monitor Controls` (`043e:9a8a`) during DPMS; no DP connector loss or AMDGPU reset occurred.

## Invalid earlier run

The earlier run around 13:58 is retained as contaminated evidence. At 13:58:02 the journal shows Omarchy `lock-requested`, systemd-logind `Suspending`, `PM: suspend entry`, then AMDGPU resume and USB HID reconnect. The stay-awake marker was insufficient because systemd-logind and the closed-lid policy were not blocked. Its DPMS/USB conclusions must not be used to judge VRR or DisplayPort stability.

## Recommended profile

The current selected operating point is 2560×1440 at 240 Hz, 10-bit, scale 1.6, `cm=srgb`, per-output `vrr=1`. A/B testing showed that both 240 and 144 Hz stayed technically identical, while `cm=auto` selected `wide`/BT2020 and was associated with the pale SDR image. The external rule references `omarchy_monitor_scale`, so the official Omarchy scaling command can change 1.6 and persist it across reloads. The earlier mode drift was caused by the mirror toggle, not by 240 Hz itself.

The package installation, staged hardware checks and color A/B are detailed in `wiki/evidence/diagnostics.md`.
