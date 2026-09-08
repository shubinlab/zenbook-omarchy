# CPU, GPU and NPU

## CPU

The processor is an AMD Ryzen AI 7 350 with 8 cores and 16 threads. Linux uses
AMD P-State EPP in active mode, currently reporting the `balance_performance`
energy-performance preference. Boost is enabled, with a current maximum near
5.09 GHz in the inventory.

**Stock relationship:** Omarchy/Arch supplies the kernel, AMD microcode and
power profile service. The profile does not add a custom governor or kernel
command line. That preserves Omarchy's power behavior and avoids importing a
power-manager conflict from another distribution.

## GPU

The integrated GPU is AMD Krackan, PCI ID `1002:1114`, labelled by PCI tools
as Radeon 840M/860M and by the CPU inventory as Radeon 860M. It uses the
in-kernel `amdgpu` driver, Mesa `1:26.2.2-1` and RADV through
`vulkan-radeon 1:26.2.2-1`.

The GPU drives the internal `eDP-1` panel and the external DisplayPort path.
VRR, 10-bit output and the tested 240 Hz mode are therefore properties of the
amdgpu/DRM/Hyprland chain, not a separate vendor display driver.

## NPU

The AMD XDNA device is enumerated at PCI `64:00.1` with the `amdxdna` driver.
The profile installs Lemonade Server and FastFlowLM, downloads
`whisper-v3-turbo-FLM`, and requires Lemonade to report `recipe=flm`,
`device=npu` and `backend_health=ready`. A live fixture run reached the NPU
route; CPU/GPU are not the selected Whisper inference device. NPU readiness
does not improve DisplayPort sharpness, HDR or VRR, and a separate LLM NPU
workload was not evaluated.

## Evidence and open work

- [Component audit](../evidence/components.md)
- [Vendor and driver research](../evidence/vendor-research.md)
- Open: GPU benchmark, sustained thermal test and an LLM NPU workload.
