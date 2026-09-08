# VRR red-team run — 2026-09-08

Этот отчёт создан локальным `tools/run_vrr_redteam.py`. На время прогона Omarchy stay-awake был включён, а после завершения восстановлен.

- Host profile: ASUS Zenbook 14 UM3406, AMDGPU, Omarchy/Hyprland.
- Output under test: DP-1 через JSAUX USB-C dock, LG UltraGear, 2560×1440.
- Forced policy: per-output and global `vrr=1` (always-on).
- Telemetry: local service sampled every 5 seconds; this runner sampled every 2 seconds.

## Results

| Phase | Requested | Samples | VRR (Hyprland) | DRM VRR_ENABLED | DPMS | Connector | Format | Anomalies |
|---|---|---:|---|---|---|---|---|---:|

## Red-team checks

- Mode matrix covers 1080p/120 Hz, 1440p/120 Hz, 1440p/144 Hz and 1440p/240 Hz.
- Both fullscreen and windowed rendering are tested.
- 8-bit versus 10-bit is tested at 144 Hz.
- Every sample checks DPMS, connector state, monitor disable state, output format and DRM VRR property.
- A DPMS cycle and rapid mode-cycle stress test are recorded separately below.

## Stress checks

```json
{
  "mode_cycles": [
    {
      "cycle": 1,
      "label": "144",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:43.370459+03:00",
        "phase": "cycle-1-144",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 143.991,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 1,
      "label": "120",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:45.395616+03:00",
        "phase": "cycle-1-120",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 119.998,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 1,
      "label": "240",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:47.425260+03:00",
        "phase": "cycle-1-240",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 239.97,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 2,
      "label": "144",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:49.451778+03:00",
        "phase": "cycle-2-144",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 143.991,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 2,
      "label": "120",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:51.480216+03:00",
        "phase": "cycle-2-120",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 119.998,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 2,
      "label": "240",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:53.508801+03:00",
        "phase": "cycle-2-240",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 239.97,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 3,
      "label": "144",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:55.534594+03:00",
        "phase": "cycle-3-144",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 143.991,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 3,
      "label": "120",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:57.561625+03:00",
        "phase": "cycle-3-120",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 119.998,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    },
    {
      "cycle": 3,
      "label": "240",
      "setup": {
        "global": "ok",
        "monitor": "ok"
      },
      "sample": {
        "time": "2026-09-08T13:57:59.587172+03:00",
        "phase": "cycle-3-240",
        "monitor": {
          "width": 2560,
          "height": 1440,
          "refresh_hz": 239.97,
          "scale": 1.6,
          "format": "XRGB2101010",
          "color_preset": "wide",
          "vrr": true,
          "dpms": true,
          "disabled": false,
          "fullscreen_test_windows": []
        },
        "connector": {
          "/sys/class/drm/card1-DP-1/status": "connected"
        },
        "drm_vrr_enabled": [
          0,
          1,
          0,
          0
        ]
      }
    }
  ],
  "dpms_cycle": {
    "off_command": "ok",
    "off_sample": {
      "time": "2026-09-08T13:58:06.945407+03:00",
      "phase": "intentional-dpms-off",
      "monitor": {
        "width": 2560,
        "height": 1440,
        "refresh_hz": 239.97,
        "scale": 1.6,
        "format": "XRGB2101010",
        "color_preset": "wide",
        "vrr": true,
        "dpms": true,
        "disabled": false,
        "fullscreen_test_windows": []
      },
      "connector": {
        "/sys/class/drm/card1-DP-1/status": "connected"
      },
      "drm_vrr_enabled": [
        0,
        1,
        0,
        0
      ]
    },
    "on_command": "ok",
    "on_sample": {
      "time": "2026-09-08T13:58:11.967680+03:00",
      "phase": "dpms-on-recovery",
      "monitor": {
        "width": 2560,
        "height": 1440,
        "refresh_hz": 239.97,
        "scale": 1.6,
        "format": "XRGB2101010",
        "color_preset": "wide",
        "vrr": true,
        "dpms": true,
        "disabled": false,
        "fullscreen_test_windows": []
      },
      "connector": {
        "/sys/class/drm/card1-DP-1/status": "connected"
      },
      "drm_vrr_enabled": [
        0,
        1,
        0,
        0
      ]
    }
  },
  "kernel_events": [
    "2026-09-08T13:58:02+03:00 zen kernel: usb 5-1.3.3: USB disconnect, device number 23",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: [drm] PCIE GART of 512M enabled (table at 0x000000801FB00000).",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: SMU is resuming...",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: SMU is resumed successfully!",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring gfx_0.0.0 uses VM inv eng 0 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.0.0 uses VM inv eng 1 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.1.0 uses VM inv eng 4 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.2.0 uses VM inv eng 6 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.3.0 uses VM inv eng 7 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.0.1 uses VM inv eng 8 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.1.1 uses VM inv eng 9 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.2.1 uses VM inv eng 10 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring comp_1.3.1 uses VM inv eng 11 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring sdma0 uses VM inv eng 12 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring vcn_unified_0 uses VM inv eng 0 on hub 8",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring jpeg_dec_0 uses VM inv eng 1 on hub 8",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring mes_kiq_3.1.0 uses VM inv eng 13 on hub 0",
    "2026-09-08T13:58:06+03:00 zen kernel: amdgpu 0000:63:00.0: ring vpe uses VM inv eng 4 on hub 8",
    "2026-09-08T13:58:08+03:00 zen kernel: usb 5-1.3.3: new full-speed USB device number 24 using xhci_hcd",
    "2026-09-08T13:58:08+03:00 zen kernel: usb 5-1.3.3: New USB device found, idVendor=043e, idProduct=9a8a, bcdDevice= 2.02",
    "2026-09-08T13:58:08+03:00 zen kernel: usb 5-1.3.3: New USB device strings: Mfr=1, Product=3, SerialNumber=4",
    "2026-09-08T13:58:08+03:00 zen kernel: usb 5-1.3.3: Product: LG Monitor Controls",
    "2026-09-08T13:58:08+03:00 zen kernel: usb 5-1.3.3: Manufacturer: LG Electronics Inc.",
    "2026-09-08T13:58:08+03:00 zen kernel: usb 5-1.3.3: SerialNumber: REDACTED",
    "2026-09-08T13:58:08+03:00 zen kernel: hid-generic 0003:043E:9A8A.0029: hiddev100,hidraw8: USB HID v1.11 Device [LG Electronics Inc. LG Monitor Controls] on usb-0000:65:00.3-1.3.3/input0",
    "2026-09-08T13:58:08+03:00 zen kernel: hid-generic 0003:043E:9A8A.002A: hiddev101,hidraw9: USB HID v1.11 Device [LG Electronics Inc. LG Monitor Controls] on usb-0000:65:00.3-1.3.3/input1",
    "2026-09-08T13:58:08+03:00 zen kernel: cdc_acm 5-1.3.3:1.2: ttyACM0: USB ACM device"
  ]
}
```

## Interpretation

VRR was forced at the Hyprland policy level. The report must be read together with observed drm_vrr_enabled and monitor vrr values: a requested vrr=1 is not proof that the DRM variable-refresh property became active.
