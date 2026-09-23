# Security Policy

This project installs and loads a **kernel extension**, which runs with the highest privileges on your Mac. Security reports are taken seriously.

## Scope

In scope:

- `patch.sh`, `install.sh`, `uninstall.sh`, `build-app.sh`
- the installer app (`app/`)
- the startup service (`launchd/`)
- the binary patch itself (the 24 changed bytes documented in the [README](README.md#how-it-works))

Out of scope: the original Focusrite driver code. It is Focusrite's software; this project only changes the documented bytes.

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ |

## Reporting a vulnerability

**Do not open a public issue for security problems.**

Email **security@solvesystems.systems** with:

- a description of the issue and its impact;
- steps to reproduce;
- your macOS version and Mac model.

You will receive an acknowledgement within **7 days**. Confirmed issues are fixed and released as soon as possible, and credited in the [CHANGELOG](CHANGELOG.md) unless you prefer to remain anonymous.

## Verifying what you run

- `patch.sh` refuses to run unless the input is the official Focusrite 3.0 binary (SHA-256 `10cfd51ff3b198729771b18c3f44b425adf45af291b0ae052011f5a075b1ed1c`), and it verifies that the result is exactly `358562a0cf601750895e7d9fefdb40875cd5876fc068d7d8c9ef3f565a6a2af0`.
- Every release lists the SHA-256 checksum of the installer zip. Compare it before opening the app:
  ```bash
  shasum -a 256 Saffire6USB-Installer.zip
  ```
- Download releases only from this repository: <https://github.com/solve-systems/saffire6usb-sonoma/releases>. Copies hosted elsewhere are not official.
