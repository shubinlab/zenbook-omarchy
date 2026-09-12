# System baseline

**Status:** observed on this host; package versions are a snapshot and must be
refreshed after an Omarchy update.

| Layer | Current value | Role |
|---|---|---|
| Distribution | Omarchy, Arch-compatible | Base operating system and Omarchy user experience |
| Omarchy | `4.0.3-1` | Stock commands, defaults, migrations and package policy |
| Kernel | `7.2.3-arch1-3`, x86_64, PREEMPT_DYNAMIC | Hardware drivers, DRM, USB, input, networking and storage |
| Firmware packages | `linux-firmware 20260810-2`, `amd-ucode 20260810-2` | GPU, Wi-Fi, Bluetooth and CPU firmware |
| Desktop | Hyprland `0.56.2-2` under UWSM | Wayland compositor and window management |
| Session audio | PipeWire `1.6.8`, WirePlumber `0.5.17` | ALSA devices, HDMI audio and native Voxtype capture |
| Local ASR | Lemonade Server + FastFlowLM | `whisper-v3-turbo-FLM` on AMD XDNA2 NPU; loopback-only service |
| Filesystem | EFI `/boot`, encrypted LUKS root on Btrfs | Boot, encryption, snapshots and user data |
| Memory | 30 GiB RAM, 60 GiB zram, no swap used during inventory | Memory pressure and compressed swap |
| Power policy | `power-profiles-daemon 0.30-1`, AMD P-State EPP | Performance/power selection |

## How the layers interact

1. UEFI loads the Omarchy boot configuration and Linux kernel.
2. Linux loads `amdgpu`, USB, NVMe, network, audio and sensor drivers.
3. UWSM starts Hyprland and Omarchy's default Lua/QML configuration.
4. Hyprland loads Omarchy defaults first, then `~/.config/hypr/*.lua`.
5. The Zenbook profile supplies monitor, keyboard/Fcitx5 and optional user services.
6. PipeWire and Voxtype use user-session configuration; optional package
   installation is handled by `omarchy-pkg-add` and updates by `omarchy update`.

## Stock versus this host

Stock Omarchy provides the default Hyprland, Foot, Fcitx5, Voxtype, PipeWire.
This host adds a tested external-display rule, a native Voxtype frontend policy
with a local FLM NPU backend, a terminal extension, optional diagnostic
packages and the tested keyboard/Fcitx5 policy. It retains Omarchy's stock
Hyprland loader, default bindings outside managed blocks, input framework,
theme system, tmux setup and package helper.

The exact file comparison is in [configuration layers](software/configuration.md).
