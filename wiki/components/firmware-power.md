# Firmware, sensors and power

| Area | Observed value | Difference from stock |
|---|---|---|
| BIOS | `UM3406KA.306` | Current vendor firmware recorded; no separate ASUS Linux driver |
| CPU microcode | `amd-ucode 20260810-2` | Explicit platform package |
| Firmware | `linux-firmware 20260810-2` | AMDGPU, MediaTek and Realtek firmware are tracked in the profile manifest |
| Sensor hub | AMD `pcie_mp2_amd`, `amd_sfh`, HID ALS | Stock kernel path retained |
| ASUS controls | `asus_wmi`, `asus_nb_wmi`, `asus_armoury` loaded | No extra ASUS control daemon added |
| Battery | Full, 100%, charge threshold 100% | 80% cap remains an owner choice; not enabled automatically |
| Power | AMD P-State EPP, `balance_performance` | No governor/APST override added |
| Lid | One ACPI unexpected-lid warning in prior journal | Tests use a systemd inhibitor; no unproven lid workaround |

The profile adds `fwupd` for inventory/update visibility but does not perform a
firmware flash. Firmware changes require a matching vendor/LVFS package,
backup and a reproduced need.
