# Dock and USB topology

## Observed topology

```text
Zenbook USB-C / USB4 controller
├─ USB2 hub: VIA Labs `2109:2822`, 480 Mb/s
│  ├─ LG controls, Logitech receivers, microphone and HID devices
│  └─ one malformed HID-like interface observed as `306f:1234`
└─ USB3 hub: VIA Labs `2109:0822`, 10 Gb/s
   └─ Realtek RTL8153 Ethernet, negotiated at USB 5 Gb/s
```

DisplayPort travels through the dock's USB-C DisplayPort Alt Mode path and is
seen by Linux as `DP-1`. There is no separate Linux dock driver: xHCI, hub,
DRM/KMS, `r8152`, UVC and HID are the relevant kernel paths.

## What differs from stock

Stock Omarchy provides the kernel drivers and general USB support. This profile
adds observability packages (`usbutils`, `ethtool`, `drm-info`, `ddcutil` and
related tools), records the observed IDs and tests the full display mode
matrix. It does not install a Windows dock driver, `r8152-dkms` or an old JSAUX
firmware updater.

The dock's exact commercial revision is not exposed by the descriptors. The
profile therefore records the family and observed IDs without pretending to
know a model revision.

## Warnings

The `306f:1234` HID-like device once reported a missing interrupt endpoint at
boot. It was not on the DisplayPort path and did not recur during protected
tests. If input failures return, remove nonessential USB2 devices one at a time
before changing kernel parameters.

See the [canonical hardware record](../../profiles/zenbook-um3406ka/hardware.md)
and [component audit](../../profiles/zenbook-um3406ka/docs/components.md).
