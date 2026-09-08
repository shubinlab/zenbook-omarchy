# Network

## Wired path

The dock exposes a Realtek RTL8153 USB Ethernet adapter. Linux binds it to the
in-tree `r8152` driver. The observed link was 1 Gb/s full duplex, with USB
negotiated at 5 Gb/s. The protected gateway test passed 10/10 with zero loss;
current counters showed no errors or TX drops.

## Wi-Fi and Bluetooth

The internal MediaTek MT7922 is PCI `14c3:0616`, bound to `mt7921e` and the
kernel's `linux-firmware` package. Bluetooth uses the MediaTek USB path through
`btusb`/`btmtk`. The hardware is enumerated and the controller was pairable;
Wi-Fi throughput and a fresh Bluetooth pairing were not run while the wired
path was active.

## Difference from stock

Omarchy supplies NetworkManager, the kernel drivers, BlueZ and wireless
regulatory data. The Zenbook profile makes the firmware/runtime set explicit
and adds `ethtool` for evidence. It does not add a vendor Wi-Fi package or
DKMS Ethernet driver.
