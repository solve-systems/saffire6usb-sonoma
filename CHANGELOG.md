# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-09-23

First public release.

### Added

- Binary patch for the official Focusrite USB Audio driver 3.0 (Saffire 6 USB 1.1), producing driver version **3.0.2**. The isochronous transfer buffers now use `kIODirectionIn` for the input endpoint (`0x82`) and `kIODirectionOut` for the output endpoint (`0x01`), instead of no direction (`kIOMemoryThreadSafe` only) for both, which macOS 11+ rejects with `0xe00002c2`.
- `patch.sh`: patches the driver from the official `.dmg`, `.pkg` or `.kext`, with SHA-256 verification of the input and the output.
- `install.sh` / `uninstall.sh`: install and remove the driver and the startup service.
- Startup service `io.github.solve-systems.saffire6usb-loader`, which loads the driver at every boot without rebuilding the kernel collections.
- **Saffire 6 USB Installer.app**: a double-click installer with native macOS dialogs.
- Technical report of the investigation (`docs/TECHNICAL_REPORT.md`).

### Tested

- iMac 27" Late 2013 (iMac14,2), macOS Sonoma 14.8.9 (23J631), OpenCore Legacy Patcher 2.5.1: playback and recording at 44.1 kHz and 48 kHz.

[1.0.0]: https://github.com/solve-systems/saffire6usb-sonoma/releases/tag/v1.0.0
