# VRR red-team run — 2026-09-08

Этот отчёт создан локальным `tools/run_vrr_redteam.py`. На время прогона Omarchy stay-awake был включён, а после завершения восстановлен.

- Host profile: ASUS Zenbook 14 UM3406, AMDGPU, Omarchy/Hyprland.
- Output under test: DP-1 через JSAUX USB-C dock, LG UltraGear, 2560×1440.
- Forced policy: per-output and global `vrr=1` (always-on).
- Telemetry: local service sampled every 5 seconds; this runner sampled every 2 seconds.

## Results

| Phase | Requested | Samples | VRR (Hyprland) | DRM VRR_ENABLED | DPMS | Connector | Format | Anomalies |
|---|---|---:|---|---|---|---|---|---:|
| `1080p120-10b-windowed` | 1920x1080@120.00, 10 bit, windowed | 15 | [False] | [0] | [True] | ['connected'] | ['XRGB2101010'] | 0 |
| `1440p120-10b-fullscreen` | 2560x1440@120.00, 10 bit, fullscreen | 15 | [True] | [0, 1] | [True] | ['connected'] | ['XRGB2101010'] | 0 |
| `1440p144-10b-windowed` | 2560x1440@143.99, 10 bit, windowed | 15 | [True] | [0, 1] | [True] | ['connected'] | ['XRGB2101010'] | 0 |
| `1440p144-10b-fullscreen` | 2560x1440@143.99, 10 bit, fullscreen | 15 | [True] | [0, 1] | [True] | ['connected'] | ['XRGB2101010'] | 0 |
| `1440p240-10b-fullscreen` | 2560x1440@239.97, 10 bit, fullscreen | 15 | [True] | [0, 1] | [True] | ['connected'] | ['XRGB2101010'] | 0 |
| `1440p144-8b-fullscreen` | 2560x1440@143.99, 8 bit, fullscreen | 15 | [True] | [0, 1] | [True] | ['connected'] | ['XRGB8888'] | 0 |

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
        "time": "2026-09-08T13:56:03.733595+03:00",
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
        "time": "2026-09-08T13:56:05.763156+03:00",
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
        "time": "2026-09-08T13:56:07.788257+03:00",
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
        "time": "2026-09-08T13:56:09.816022+03:00",
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
        "time": "2026-09-08T13:56:11.843072+03:00",
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
        "time": "2026-09-08T13:56:13.871956+03:00",
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
        "time": "2026-09-08T13:56:15.899823+03:00",
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
        "time": "2026-09-08T13:56:17.926226+03:00",
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
        "time": "2026-09-08T13:56:19.953206+03:00",
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
    "off_command": "error: [string \"return hl.dispatch(dpms off DP-1)\"]:1: ')' expected near 'off'\n\n → Note: dispatch in lua is a shorthand for hl.dispatch(...), your syntax might need to be updated.",
    "off_sample": {
      "time": "2026-09-08T13:56:24.975526+03:00",
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
    "on_command": "error: [string \"return hl.dispatch(dpms on DP-1)\"]:1: ')' expected near 'on'\n\n → Note: dispatch in lua is a shorthand for hl.dispatch(...), your syntax might need to be updated.",
    "on_sample": {
      "time": "2026-09-08T13:56:29.998517+03:00",
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
  "kernel_events": []
}
```

## Interpretation

VRR was forced at the Hyprland policy level. The report must be read together with observed drm_vrr_enabled and monitor vrr values: a requested vrr=1 is not proof that the DRM variable-refresh property became active.
