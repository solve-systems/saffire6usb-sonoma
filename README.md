<p align="center">
  <img src="assets/solve-systems-logo.png" alt="SOLVE SYSTEMS" width="140">
</p>

<p align="center">
  <strong>SOLVE SYSTEMS™</strong><br>
  <sub>by Victor Urtubia</sub>
</p>

<p align="center">
  <a href="https://solvesystems.systems">solvesystems.systems</a> ·
  <a href="https://instagram.com/solve.systems">@solve.systems</a> ·
  <a href="mailto:contact@solvesystems.systems">contact@solvesystems.systems</a>
</p>

<p align="center">
  <a href="../../releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/solve-systems/saffire6usb-sonoma?color=2a2ae8"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2011%2B%20·%20Intel-2a2ae8">
  <img alt="Tested" src="https://img.shields.io/badge/tested-Sonoma%2014.8.9-2a2ae8">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-2a2ae8"></a>
</p>

# Saffire 6 USB 1.1 on macOS Sonoma

Make the discontinued **Focusrite Saffire 6 USB 1.1** work on modern macOS (tested on macOS Sonoma 14.8.9) by patching Focusrite's own last driver (version 3.0).

Focusrite's official position is that the Saffire 6 USB 1.1 does not work on macOS Catalina or later. It turns out the old driver is almost compatible. A single problem stops audio from starting, and a 24-byte patch fixes it.

| | Status |
|---|---|
| Playback | ✅ |
| Recording | ✅ |
| 44.1 kHz / 48 kHz | ✅ |
| Both inputs (1 → L, 2 → R) | ✅ |
| Loads automatically at boot | ✅ |

> [!IMPORTANT]
> This repository does **not** contain any Focusrite software. The script patches **your own copy** of the official driver, which you download from Focusrite's website.

---

## Is this for you?

- ✅ **Focusrite Saffire 6 USB 1.1**: serial number starts with **`SU`**, or the back says "USB" / "USB 1.1" under the USB port.
- ❌ **Saffire 6 USB 2.0** (serial starts with `S2`): you don't need this. It is class-compliant and works without a driver.
- ✅ **Intel Macs only.** The Focusrite driver is x86_64 code and cannot run on Apple Silicon (M1/M2/M3/M4).
- ✅ macOS 11 or later with third-party kernel extensions allowed. Tested on **macOS Sonoma 14.8.9** installed with **OpenCore Legacy Patcher 2.5.1** on an iMac 27" Late 2013 (iMac14,2). Other versions will probably work but are **untested**. Please report your results (see [Help others](#help-others)).

## Disclaimer

This modifies and loads a kernel extension. It worked perfectly on the tested machine, but a kernel driver can in the worst case cause a kernel panic (a crash and restart). Keep a backup and know how to boot in Safe Mode. **Use at your own risk.** This project is not affiliated with, endorsed by, or supported by Focusrite. Please don't contact Focusrite support about it.

---

## Easy install (recommended)

No Terminal needed.

1. **Download the official Focusrite driver.** From Focusrite's [Saffire 6 USB download page](https://downloads.focusrite.com/focusrite/saffire/saffire-6-usb), get **"Saffire 6 USB 1.1 Driver 3.0 - Mac"** (`focusrite-usb-drivers-3.0.653.dmg`). Leave it in your **Downloads** folder and **do not run its installer**.
2. **Download the installer app.** Get **`Saffire6USB-Installer.zip`** from the [latest release](../../releases/latest) and double-click it to unzip.
3. **Disconnect the Saffire** and open **Saffire 6 USB Installer**.

   The first time, macOS says the app is from an unidentified developer. This is normal for free, independent apps. Click **OK** or **Cancel** (never **Move to Trash**), open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to "Saffire 6 USB Installer", then confirm.
4. **Follow the windows.** The app finds the Focusrite file, patches it, asks for your Mac password and installs everything.
5. **Allow the driver.** At the end the app opens **Privacy & Security**. Click **Allow** in the Security section and **restart** when macOS asks.
6. After restarting, connect the Saffire and choose **Saffire 6USB** in **System Settings → Sound**.

To uninstall, open the app again and choose **Uninstall**.

If something goes wrong, the app saves a log at `~/Library/Logs/Saffire6USB-Installer.log`. Please attach it when you open an issue.

---

## Terminal install (advanced)

The app runs exactly these scripts. You can also use them directly.

### 1. Download the official driver

From Focusrite's download page for the [Saffire 6 USB](https://downloads.focusrite.com/focusrite/saffire/saffire-6-usb), download **"Saffire 6 USB 1.1 Driver 3.0 - Mac"** (`focusrite-usb-drivers-3.0.653.dmg`).

**Do not run the installer.** You only need the file.

### 2. Download this repository

Click **Code → Download ZIP** at the top of this page and unzip it. Then open **Terminal** and go to the folder, for example:

```bash
cd ~/Downloads/saffire6usb-sonoma-main
```

### 3. Patch the driver

```bash
bash patch.sh ~/Downloads/focusrite-usb-drivers-3.0.653.dmg
```

The script mounts the `.dmg`, extracts the driver, checks that it is **exactly** the official 3.0 driver (it refuses anything else), applies the patch, and verifies the result. The patched driver is saved to `./output/FocusriteUSBAudio.kext`.

You can also pass the `.pkg` or an already extracted `FocusriteUSBAudio.kext`.

### 4. Install

Disconnect the Saffire first, then:

```bash
sudo bash install.sh
```

It installs the driver to `/Library/Extensions`, signs it locally (ad-hoc), and installs a small startup service that loads the driver at every boot.

### 5. Approve and restart

The first time, macOS blocks the driver. This is expected.

1. Open **System Settings → Privacy & Security**.
2. In the **Security** section, click **Allow** for the blocked system software.
3. Restart when macOS asks ("New system extensions require a restart…").

### 6. Test

After restarting, check that the driver is loaded:

```bash
kmutil showloaded | grep -i focusrite
```

You should see `com.focusrite.driver.usb.audio (3.0.2)`. Connect the Saffire, select **Saffire 6USB** in **System Settings → Sound**, and play something.

---

## Troubleshooting

**macOS says the app "can't be opened" or is from an unidentified developer.**
Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. You only need to do this once. The app is not notarized by Apple because that requires a paid developer account. Its full source is in this repository (`app/launcher.sh` and the scripts).

**The Saffire does not appear at all in System Information → USB.**
Try another USB cable. A cable that powers the unit does not necessarily carry data.

**The driver is not loaded after a restart.**
Check the startup service log:
```bash
cat /var/log/saffire6usb-loader.log
```
If it says the extension is *not approved*, repeat step 5.

**The Saffire does not show up in Sound settings after boot.**
Unplug it and plug it back in. It can enumerate before the driver has loaded.

**It stopped working after a macOS or OpenCore update.**
Check `kmutil showloaded | grep -i focusrite`. You may need to approve the extension again (step 5). If needed, run `sudo bash install.sh` again.

**A microphone records only on one side.**
That's normal. Input 1 is the left channel and input 2 is the right channel. Record on a mono track in your DAW.

**You get a kernel panic.**
Boot in Safe Mode (hold **Shift** at startup on Intel Macs), then run `sudo bash uninstall.sh`, or delete `/Library/Extensions/FocusriteUSBAudio.kext` and `/Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist`. Please open an issue with your Mac model and macOS version.

---

## Uninstall

Open the installer app and choose **Uninstall**, or run:

```bash
sudo bash uninstall.sh
```

Then restart.

---

## How it works

On modern macOS, the original driver loads and the Saffire appears in CoreAudio, but no audio ever flows. Every USB transfer is rejected with:

```text
AppleUSBIORequest::prepare: invalid buffer length or direction for device … endpoint 0x82
AppleUSBIORequest::prepare: completed with 0xe00002c2
```

The driver creates the memory buffers for **both** the input endpoint (`0x82`) and the output endpoint (`0x01`) with the option `kIOMemoryThreadSafe` (`0x00100000`) and **no transfer direction**. Older USB stacks accepted this. The current one requires `kIODirectionIn` for input and `kIODirectionOut` for output (`kIODirectionInOut` is rejected too).

The patch replaces that fixed value with a 14-byte routine that picks the right direction for each stream. It places the routine in unused padding inside the driver, so nothing else moves: the file size, symbols and relocations stay identical. In total, 24 bytes change.

| Offset | Original | Patched |
|---|---|---|
| `0x3072` | `66 66 66 66 66 2e 0f 1f 84 00 00 00 00 00` (padding) | `41 81 fd 68 bf 00 00 19 c9 f7 d9 ff c1 c3` |
| `0x4118` | `b9 00 00 10 00` (`mov ecx, 0x100000`) | `e8 55 ef ff ff` (`call 0x3072`) |
| `0x4138` | `b9 00 00 10 00` (`mov ecx, 0x100000`) | `e8 35 ef ff ff` (`call 0x3072`) |

The installer app is built from the same scripts with `bash build-app.sh` (on a Mac). Its source is in the `app/` folder.

The full investigation is in **[docs/TECHNICAL_REPORT.md](docs/TECHNICAL_REPORT.md)**.

**Checksums of the `FocusriteUSBAudio` binary (SHA-256):**

- Original 3.0: `10cfd51ff3b198729771b18c3f44b425adf45af291b0ae052011f5a075b1ed1c`
- Patched 3.0.2: `358562a0cf601750895e7d9fefdb40875cd5876fc068d7d8c9ef3f565a6a2af0`

---

## Tested configurations

| Mac | macOS | OpenCore Legacy Patcher | Result |
|---|---|---|---|
| iMac 27" Late 2013 (iMac14,2) | Sonoma 14.8.9 (23J631) | 2.5.1 | ✅ Full audio I/O, 44.1/48 kHz |

Tried it on another Mac? Please submit a **[compatibility report](../../issues/new?template=compatibility-report.yml)**, whether it worked or not. Confirmed reports are added to this table.

---

## Support

- **Questions and problems:** open an **[issue](../../issues/new/choose)**. Public answers help the next person with the same problem. Please use the issue tracker instead of email for technical support.
- **Security issues:** see **[SECURITY.md](SECURITY.md)**.
- **Everything else:** contact@solvesystems.systems

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for how to report results or propose changes, and **[CHANGELOG.md](CHANGELOG.md)** for the version history.

## Credits

**SOLVE SYSTEMS™**: investigation, testing and patch by Victor Urtubia. The reverse engineering of the driver was done with the help of Claude (Anthropic).

[solvesystems.systems](https://solvesystems.systems) · [Instagram @solve.systems](https://instagram.com/solve.systems) · contact@solvesystems.systems

Focusrite and Saffire are trademarks of Focusrite Audio Engineering Ltd. This project is independent and not affiliated with Focusrite.

## License

The scripts and documentation are released under the [MIT License](LICENSE). The Focusrite driver is not included and is not covered by this license.
