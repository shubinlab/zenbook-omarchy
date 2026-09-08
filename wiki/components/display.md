# Display and color path

```text
amdgpu / DRM
  -> USB-C/USB4 DisplayPort Alt Mode
     -> JSAUX dock
        -> DP-1
           -> LG UltraGear
```

## Current profile

| Setting | Tested value | Stock/unique explanation |
|---|---|---|
| Internal panel | `eDP-1`, preferred mode, scale 2 | Omarchy high-density default retained |
| External mode | `2560x1440@239.97` | Unique to the connected LG path |
| Position | `0x0` | Unique layout override for the closed-lid workflow |
| Scale | `1.6` via `omarchy_monitor_scale` | User choice; keeps Omarchy scaling command functional |
| Bit depth | 10-bit `XRGB2101010` | Explicit profile override |
| Color management | `cm = "srgb"` | Explicit fix for pale SDR output seen with `cm=auto` |
| VRR | `vrr = 1` | Explicit per-output override; DRM confirmed active |
| Mirror | none | Omarchy internal-monitor mirror toggle disabled after mode drift |
| DPMS | on during normal work | Power-management state, not a mode setting |

The profile's `local omarchy_gdk_scale = 2` remains separate from the external
Hyprland scale. GDK scale controls toolkit sizing; monitor scale controls the
Wayland output. Changing one does not safely replace the other.

## Why the image looked pale

The A/B test held resolution, refresh, bit depth and VRR constant. `cm=auto`
selected a wide/BT2020 path at 10-bit; `cm=srgb` kept the SDR desktop in the
expected sRGB primaries. Refresh rate was not the cause. HDR was tested
separately and is not forced globally.

## Why the mode drifted

The Omarchy internal-monitor mirror toggle contained a `preferred` DP-1 rule.
After reload it could win over the explicit profile and select the dock's
preferred mode. The recovery was performed through the supported Omarchy
command and is recorded in [display-incident.md](../../profiles/zenbook-um3406ka/docs/display-incident.md).

## Verification

Use the protected runner from the [operations page](../operations/README.md).
It blocks idle, lock, suspend and lid handling, and samples compositor mode,
DRM VRR, connector state, DPMS and session state. The full results are in
[display-tests.md](../../profiles/zenbook-um3406ka/docs/display-tests.md).
