<p align="center">
  <img src="../assets/solve-systems-logo.png" alt="SOLVE SYSTEMS" width="140">
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

# Focusrite Saffire 6 USB 1.1 on macOS Sonoma — Technical Report

Scripts and installation: see the [README](../README.md).

**Date:** September 23, 2026
**Machine:** iMac 27" Late 2013 (iMac14,2)
**System:** macOS Sonoma 14.8.9 via OpenCore Legacy Patcher 2.5.1
**Interface:** Focusrite Saffire 6 USB 1.1 (serial prefix `SU`)
**Original driver:** Focusrite USB Audio 3.0
**Final driver:** FocusriteUSBAudio 3.0.2 (binary-patched)

**Status: RESOLVED.** Playback, recording, 44.1 kHz and 48 kHz, both input channels and automatic loading at boot all work.

---

## 1. Summary

The Focusrite Saffire 6 USB 1.1 was officially abandoned by Focusrite; its last macOS driver (3.0) targets OS X 10.11.2 – 10.12.6, and Focusrite states it does not work from Catalina onward. The same interface worked on macOS Mojave on this iMac.

On Sonoma, the original 3.0 driver loads, matches the device and exposes it to CoreAudio, but audio never starts: every isochronous transfer is rejected by `IOUSBHostFamily` with

```text
AppleUSBIORequest::prepare: invalid buffer length or direction
0xe00002c2 (kIOReturnBadArgument)
```

Reverse engineering of the driver showed that it creates the memory descriptors for **both** the input (0x82) and output (0x01) isochronous endpoints with the option `kIOMemoryThreadSafe` (`0x00100000`) and **no transfer direction** (`kIODirectionNone`). Older USB stacks accepted this; Sonoma's stack requires the descriptor direction to match the endpoint direction. `kIODirectionInOut` is rejected as well (section 16).

A 24-byte binary patch makes the driver use `kIODirectionIn` for the input endpoint and `kIODirectionOut` for the output endpoint. With this patch (version 3.0.2), the Saffire works fully on Sonoma.

---

## 2. System

### iMac

- iMac 27" Late 2013, identifier `iMac14,2`
- Intel Core i5 3.2 GHz (Haswell)
- 32 GB DDR3
- NVIDIA GeForce GT 755M 1 GB
- Internal HDD APPLE ST1000DM003, 1 TB

### macOS / OpenCore

- macOS Sonoma 14.8.9 (build 23J631)
- OpenCore Legacy Patcher 2.5.1, OpenCore on the internal EFI
- Active root patches: Intel Haswell, NVIDIA Kepler, Modern Wireless

At no point were SIP settings changed, OCLP root patches modified, or the kernel collections rebuilt.

---

## 3. Device identification

The interface is the **Saffire 6 USB 1.1**, not the Saffire FireWire and not the Saffire 6 USB 2.0 (the USB 2.0 variant is class-compliant and needs no driver). The USB 1.1 variant is identified by a serial number starting with `SU`.

`system_profiler` reported:

```text
Saffire 6USB:

Product ID: 0x0010
Vendor ID: 0x1235
Version: 1.00
Speed: Up to 12 Mb/s
Manufacturer: Focusrite Audio Engineering
Location ID: 0x14400000 / 8
Current Available (mA): 500
Current Required (mA): 498
Extra Operating Current (mA): 0
```

This confirms a full-speed USB 1.1 device (12 Mb/s).

---

## 4. First problem: USB cable

Initially the Saffire powered on but did not appear in the macOS USB tree, on any port. Replacing the USB-A → USB-B cable made it appear immediately in `system_profiler`.

**Conclusion:** the old cable carried power but not data. A powered-on interface does not guarantee a working USB data connection.

---

## 5. Extracting the official Focusrite 3.0 driver

Source package: **Saffire 6 USB 1.1 Driver 3.0 Mac**, containing:

```text
Distribution
FocusriteusbDriver.pkg
NovationMIDIDriver.pkg
```

The payload of `FocusriteusbDriver.pkg` contains:

```text
System/Library/Extensions/FocusriteUSBAudio.kext
```

---

## 6. Original driver characteristics

Executable type:

```text
Mach-O 64-bit kext bundle x86_64
```

Original signature:

```text
Identifier=com.focusrite.driver.usb.audio
Authority=Developer ID Application: Focusrite Audio Engineering Ltd. (7VYBQV3T2Q)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
TeamIdentifier=7VYBQV3T2Q
```

`OSBundleLibraries` in `Info.plist`:

```text
com.apple.iokit.IOAudioFamily = 204.3
com.apple.iokit.IOUSBHostFamily = 1.0.1
com.apple.iokit.IOUSBFamily = 900.4.1
com.apple.kpi.iokit = 15.2
com.apple.kpi.libkern = 15.2
com.apple.kpi.mach = 15.2
```

IOKit personality: `IOClass = FocusriteUSBAudioDevice_Saffire6USB`, `IOProviderClass = IOUSBHostInterface`, `idVendor = 4661` (0x1235), `idProduct = 16` (0x0010).

Symbol analysis shows the driver imports **no** symbols from the legacy `IOUSBFamily`. All USB access goes through the modern `IOUSBHostFamily` (`IOUSBHostInterface`, `IOUSBHostPipe`, `IOUSBHostIsochronousFrame`, `StandardUSB` helpers). On this system the declared `IOUSBFamily` dependency still resolves, so the original `Info.plist` loads unchanged.

---

## 7. Loading the original driver on Sonoma

Permissions were set:

```bash
sudo chown -R root:wheel FocusriteUSBAudio.kext
sudo chmod -R 755 FocusriteUSBAudio.kext
```

The extension was approved in **System Settings → Privacy & Security**, the Mac was restarted, and the kext was installed at `/Library/Extensions/FocusriteUSBAudio.kext` and loaded manually:

```bash
sudo kmutil load -p /Library/Extensions/FocusriteUSBAudio.kext
```

Result:

```text
com.focusrite.driver.usb.audio (3.0)
E38B4A1E-6509-38EB-A19C-33799FA07B15
```

**Sonoma can load the old Focusrite 3.0 driver.** The problem is not that Sonoma refuses the kext.

---

## 8. The driver recognizes the Saffire

With the interface connected, `ioreg` showed `FocusriteUSBAudioDevice_Saffire6USB` and `FocusriteUSBAudioEngine`, both `registered, matched, active`:

```text
IOClass = FocusriteUSBAudioDevice_Saffire6USB
IOAudioDeviceName = Saffire 6USB
IOAudioDeviceShortName = Saffire 6USB
IOAudioDeviceModelID = FocusriteUSBAudioDevice_Saffire6USB:Saffire 6USB
idProduct = 16
idVendor = 4661
```

The driver loads, matches the USB interface, creates an `IOAudioDevice` and an `IOAudioEngine`, and exposes the device to CoreAudio. The failure happens **after** device detection.

---

## 9. The Saffire appears as an audio device

The interface appears in **System Settings → Sound** and in **Audio MIDI Setup** with coherent formats:

| Direction | Channels | Format | Sample rates |
|---|---|---|---|
| Input | 2 | 24-bit integer, mixable | 44.1 kHz, 48 kHz |
| Output | 4 | 24-bit integer, mixable | 44.1 kHz, 48 kHz |

---

## 10. Symptom with the original driver

When the Saffire is selected as output, no audio plays, and video or audio playback may stall. CoreAudio tries to start the device, but the engine immediately returns to the stopped state:

```text
IOAudioSampleRate = 44100
IOAudioEngineState = 0
IOAudioEngineNumActiveUserClients = 0
```

Changing between 44.1 kHz and 48 kHz made no difference.

---

## 11. CoreAudio attempts to start the driver

CoreAudio logs:

```text
HALS_IOContext_Legacy_Impl::IOWorkLoopInit
FocusriteUSBAudioEngine starting
HALS_IOA1Engine::_StartIO: the call to the driver failed  Error: 0xE00002C2
IOWorkLoop: failed to start the hardware
IO Stopped Context ... after 0 frames.
StartIOThread: IO thread failed to start  Error: -536870206
```

CoreAudio finds the driver and calls `StartIO`; the failure occurs when the USB audio streams are started.

---

## 12. IOAudioFamily layers accept the start

Kernel logs:

```text
IOAudioEngine::setState(0x1. oldState=0)
startAudioEngine() returns 0x0
incrementActiveUserClients() - 1 returns 0
startClient(...) returns 0x0
IOAudioStream::addClient(...) returns 0x0
IOAudioEngineUserClient::startClient() - 1 returns 0x0
externalMethod returns 0x0
```

The upper IOAudioFamily layers accept the start; the failure is further down, when the USB requests are prepared.

---

## 13. Key finding: AppleUSBIORequest

```bash
sudo log stream --style compact --level debug --predicate 'eventMessage CONTAINS[c] "AppleUSBIORequest"'
```

Each playback attempt produced:

```text
AppleUSBIORequest::prepare: invalid buffer length or direction for device 8 endpoint 0x82
AppleUSBIORequest::prepare: completed with 0xe00002c2
AppleUSBIORequest::prepare: invalid buffer length or direction for device 8 endpoint 0x01
AppleUSBIORequest::prepare: completed with 0xe00002c2
```

The sequence appears twice per endpoint. The driver double-buffers each stream with two transfer helpers, as described in section 15, so two requests per endpoint are submitted at start.

- `0x82`: IN endpoint (recording)
- `0x01`: OUT endpoint (playback)
- `0xE00002C2`: `kIOReturnBadArgument`

Sonoma rejects the isochronous requests **before any audio frame is transferred**. This explains why the device appears and the driver loads, yet no audio flows in either direction.

---

## 14. Input test with the original driver

A microphone connected to the Saffire could be heard in headphones connected to the interface (hardware direct monitoring), so the preamp, analog path and headphone output were working. Selecting the Saffire as input in macOS, however, stalled the system, and QuickTime could not start a recording. Both CoreAudio input and output were affected, consistent with the simultaneous errors on `0x82` and `0x01`.

---

## 15. Reverse engineering of the transfer path

### Call chain

```text
FocusriteUSBAudioEngine::StartReadTransfer / StartWriteTransfer
        ↓
USBAudioStreamingPipe::Read / Write      (0x37e0 / 0x3860)
        ↓
IOUSBHostPipe::io(...)                   (vtable slot +0x520)
        ↓
AppleUSBIORequest::prepare               ← rejection
```

`USBAudioStreamingPipe::Read` and `Write` tail-call `IOUSBHostPipe::io(IOMemoryDescriptor*, IOUSBHostIsochronousFrame*, uint32_t frameCount, uint64_t firstFrame, IOUSBHostIsochronousCompletion*)` with arguments taken from a `USBIsocTransferHelper` object:

| Helper offset | Content |
|---|---|
| `+0x00` | pointer to `IOUSBHostIsochronousFrame` array (24 bytes per frame) |
| `+0x10` | frame count |
| `+0x18` | first frame number |
| `+0x20` | `IOMemoryDescriptor*` for the transfer |
| `+0x28` | completion |

The request reaches `AppleUSBIORequest::prepare`, which confirms that the vtable call into `IOUSBHostPipe` is still ABI-compatible on Sonoma.

### Buffer construction: `FocusriteUSBSampleBufferManager::SetupBuffer` (0x3ff0)

Each stream has a buffer manager with two helpers (double buffering), at manager offsets `+0x30` and `+0x38`. `SetupBuffer(sampleRate, bytesPerFrame, IOUSBHostDevice*)`:

1. Fills 100 isochronous frames per helper. Each frame's `requestCount` is the number of samples in that millisecond (fractional accumulation of `sampleRate / 1000`) multiplied by bytes per sample frame.
2. Allocates one backing buffer with `IOUSBHostDevice::createIOBuffer(options = 0x13, capacity)`.
3. Splits it into two halves with `IOSubMemoryDescriptor::withSubRange`, one per helper:

```text
0x4113  shr rdx, 1
0x4116  xor esi, esi
0x4118  mov ecx, 0x100000     ; options = kIOMemoryThreadSafe, no direction
0x411d  mov rdi, rax
0x4120  call IOSubMemoryDescriptor::withSubRange    ; first half
...
0x4135  shr rsi, 1
0x4138  mov ecx, 0x100000     ; options = kIOMemoryThreadSafe, no direction
0x413d  mov rdx, rsi
0x4140  call IOSubMemoryDescriptor::withSubRange    ; second half
```

### Length check

The length of each sub-descriptor (half the buffer) equals the sum of the `requestCount` values of its 100 frames, so the buffer length is consistent. The remaining candidate in "invalid buffer length or direction" was the direction.

### Input vs. output

The same `SetupBuffer` code serves both streams:

- The **output** manager (engine offset `+0x150`) calls it with the real sample rate (44 100 or 48 000).
- The **input** manager (`USBInputSampleBufferManager`, engine offset `+0x130`) overrides `SetupBuffer` and always calls the base implementation with **49 000 Hz** (`mov esi, 0xbf68`), sizing its buffer for the maximum possible input rate.

Inside `SetupBuffer`, the requested rate stays in register `r13d`, which is callee-saved and not modified afterwards. This distinguishes the two streams at runtime.

### Root cause

Both sub-descriptors of both streams are created with options `0x00100000` (`kIOMemoryThreadSafe`) and direction bits `0` (`kIODirectionNone`). Sonoma's `AppleUSBIORequest::prepare` requires the memory descriptor direction to match the endpoint: `kIODirectionIn` (1) for IN endpoint `0x82`, `kIODirectionOut` (2) for OUT endpoint `0x01`.

---

## 16. First experimental patch (discarded)

An early experimental copy changed the `withSubRange` options at `0x4118` and `0x4138` from `0x00100000` (`kIOMemoryThreadSafe`, no direction) to `0x00000003` (`kIODirectionInOut`) and was re-signed ad-hoc. It loaded but produced exactly the same `0xe00002c2` errors.

This result is informative: it shows that Sonoma rejects `kIODirectionInOut` just as it rejects no direction. The buffer direction must match each endpoint exactly, which is what build 3.0.2 does (section 20).

**Note on the analysis sources:** the binary used for the reverse engineering in section 15 was this experimental copy, not the factory original, which is why the first version of this report showed `mov ecx, 3` at those sites. A later comparison with the binary extracted directly from Focusrite's installer (section 20) confirmed that the two copies differ **only** in those two constants (4 bytes) plus the code signature. All other code and data are identical.

---

## 17. Build 3.0.1 (discarded)

An intermediate build, `FocusriteUSBAudio-Sonoma.kext` (`CFBundleVersion = 3.0.1`), was prepared during the investigation. It contained **no code changes**: it only removed the `IOUSBFamily` dependency from `Info.plist` and stripped the Focusrite code signature from the binary.

Sonoma refused to load it:

```text
LINKEDIT overlap of local relocations and symbol table
```

The tool used to strip the signature left the `__LINKEDIT` segment in an inconsistent layout that Sonoma's `kmutil` correctly rejects. The build was discarded.

**Lesson:** do not rewrite the Mach-O structure. Patch bytes in place, keep the file size identical, and let `codesign` replace the stale signature.

---

## 18. Kernel collection rebuild (not performed)

```bash
sudo kmutil install --update-all
```

On this OCLP system, this requires a Kernel Debug Kit matching build `23J631`, and it refuses to proceed without one. Because OCLP manages the kernel collections, the rebuild was **not** forced, and no KDK was installed. Loading with `kmutil load -p` is sufficient, and the final setup does not require a rebuild (see section 22).

---

## 19. Clean baseline with the original driver

The original kext was kept as `FocusriteUSBAudio.original.kext`, restored to `/Library/Extensions`, and verified with `CFBundleVersion = 3.0` and a valid signature (`codesign --verify --deep --strict`).

After a restart with the Saffire disconnected, no Focusrite driver was loaded. The original driver was then loaded manually, the Saffire connected, and playback attempted. The result was the same `invalid buffer length or direction` errors on `0x82` and `0x01`. This is the reference baseline.

---

## 20. The fix: build 3.0.2

### Design

A 14-byte routine placed in unused alignment padding (`0x3072`–`0x307f`, originally a multi-byte NOP between functions) computes the correct direction from the sample rate held in `r13d`:

```text
0x3072  cmp r13d, 0xbf68     ; rate < 49000 → CF = 1 (output)
0x3079  sbb ecx, ecx         ; output: -1   input: 0
0x307b  neg ecx              ; output:  1   input: 0
0x307d  inc ecx              ; output:  2   input: 1
0x307f  ret
```

| Stream | Rate passed to SetupBuffer | Resulting `ecx` | Direction |
|---|---|---|---|
| Output (`0x01`) | 44 100 / 48 000 | 2 | `kIODirectionOut` |
| Input (`0x82`) | 49 000 | 1 | `kIODirectionIn` |

The routine clobbers only `ecx` and flags; `rax`, `rdx`, `rsi` and `rdi` are preserved as required at both call sites. The two `mov ecx, 0x100000` instructions (5 bytes each) are replaced by 5-byte `call` instructions to the routine, so no instruction boundaries or relocation sites move.

### Byte changes

| File offset | Original | Patched |
|---|---|---|
| `0x3072` (14 bytes) | `66 66 66 66 66 2e 0f 1f 84 00 00 00 00 00` | `41 81 fd 68 bf 00 00 19 c9 f7 d9 ff c1 c3` |
| `0x4118` (5 bytes) | `b9 00 00 10 00` (`mov ecx, 0x100000`) | `e8 55 ef ff ff` (`call 0x3072`) |
| `0x4138` (5 bytes) | `b9 00 00 10 00` (`mov ecx, 0x100000`) | `e8 35 ef ff ff` (`call 0x3072`) |

In total, 24 bytes changed. The file size is identical, and the Mach-O header, `__LINKEDIT`, symbol table and relocations are untouched. The original `Info.plist` is kept, with its original dependencies, except `CFBundleVersion`, which is set to `3.0.2`.

### Limitation

The direction logic assumes output rates below 49 000 Hz. This holds for this device, which exposes only 44.1 kHz and 48 kHz.

### Checksums (SHA-256 of the `FocusriteUSBAudio` binary)

| Binary | SHA-256 |
|---|---|
| Official Focusrite 3.0 (from `focusrite-usb-drivers-3.0.653.dmg`) | `10cfd51ff3b198729771b18c3f44b425adf45af291b0ae052011f5a075b1ed1c` |
| Patched 3.0.2 (before local ad-hoc signing) | `358562a0cf601750895e7d9fefdb40875cd5876fc068d7d8c9ef3f565a6a2af0` |

The patched binary produced from the official driver is byte-identical, in all code, data and linking information, to the 3.0.2 build tested on the iMac14,2. It differs only in the stale embedded code signature, which `codesign` replaces during installation.

The removal of `kIOMemoryThreadSafe` at these two call sites was part of the tested configuration, and no side effects were observed.

---

## 21. Installation and test of 3.0.2

### Procedure

1. Restart with the Saffire disconnected, and confirm that no Focusrite driver is loaded:
   ```bash
   kmutil showloaded | grep -i focusrite
   ```
2. Verify the patched kext:
   ```bash
   /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" FocusriteUSBAudio.kext/Contents/Info.plist
   # 3.0.2
   xxd -s 0x3072 -l 14 FocusriteUSBAudio.kext/Contents/MacOS/FocusriteUSBAudio
   # 00003072: 4181 fd68 bf00 0019 c9f7 d9ff c1c3
   ```
3. Install and re-sign ad-hoc:
   ```bash
   sudo rm -rf /Library/Extensions/FocusriteUSBAudio.kext
   sudo cp -R FocusriteUSBAudio.kext /Library/Extensions/
   sudo codesign --force --deep --sign - /Library/Extensions/FocusriteUSBAudio.kext
   sudo chown -R root:wheel /Library/Extensions/FocusriteUSBAudio.kext
   sudo chmod -R 755 /Library/Extensions/FocusriteUSBAudio.kext
   codesign --verify --verbose=2 /Library/Extensions/FocusriteUSBAudio.kext
   # valid on disk / satisfies its Designated Requirement
   ```
4. The first load attempt fails with `KMErrorDomain Code=27 ... not approved to load`, because re-signing changed the extension's identity. Approve it in **System Settings → Privacy & Security** ("New system extensions require a restart before they can be used"), then restart.
5. Load:
   ```bash
   sudo kmutil load -p /Library/Extensions/FocusriteUSBAudio.kext
   kmutil showloaded | grep -i focusrite
   # com.focusrite.driver.usb.audio (3.0.2) E38B4A1E-6509-38EB-A19C-33799FA07B15
   ```

### Results

| Test | Result |
|---|---|
| Playback through Saffire output | ✅ Works |
| Recording from Saffire input (QuickTime) | ✅ Works |
| 44.1 kHz playback and recording | ✅ Works, clean |
| 48 kHz playback and recording | ✅ Works, clean |
| Input channels | ✅ Each input records to its own channel (input 1 → L, input 2 → R) |
| `AppleUSBIORequest` errors | ✅ No longer occur |

This confirms that the descriptor direction was the cause of `invalid buffer length or direction` / `0xe00002c2`.

---

## 22. Automatic loading at boot

Because the kernel collections are not rebuilt (section 18), the kext is not part of the auxiliary kernel collection and does not load by itself. A LaunchDaemon loads it at every boot without touching OCLP or the collections.

`/Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.github.solve-systems.saffire6usb-loader</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/kmutil</string>
        <string>load</string>
        <string>-p</string>
        <string>/Library/Extensions/FocusriteUSBAudio.kext</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/saffire6usb-loader.log</string>
</dict>
</plist>
```

Installed with:

```bash
sudo chown root:wheel /Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist
sudo chmod 644 /Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist
plutil -lint /Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist
```

After a restart, without any manual command:

```text
com.focusrite.driver.usb.audio (3.0.2) E38B4A1E-6509-38EB-A19C-33799FA07B15
```

✅ The driver loads automatically at boot.

---

## 23. Final state

| Component | State |
|---|---|
| Installed kext | `/Library/Extensions/FocusriteUSBAudio.kext`, version 3.0.2, ad-hoc signed, approved |
| Backup of original | `FocusriteUSBAudio.original.kext` (Focusrite 3.0, original signature) |
| Autoload | `/Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist` |
| Load errors | `/var/log/saffire6usb-loader.log` |
| OCLP / SIP / kernel collections | Unchanged |
| Audio | Input and output working at 44.1 and 48 kHz |

---

## 24. Maintenance and troubleshooting

- **After a macOS or OCLP update:** check `kmutil showloaded | grep -i focusrite`. If the driver is missing, check `/var/log/saffire6usb-loader.log`. The extension may need to be approved again in Privacy & Security, followed by a restart.
- **If the kext no longer loads:** repeat steps 3–5 of section 21 with the saved 3.0.2 copy.
- **If the Saffire does not appear after boot:** unplug and reconnect it. The device may enumerate before the LaunchDaemon has loaded the driver.
- **Disable autoload:**
  ```bash
  sudo rm /Library/LaunchDaemons/io.github.solve-systems.saffire6usb-loader.plist
  ```
- **Roll back to the original driver:** restart, then copy `FocusriteUSBAudio.original.kext` to `/Library/Extensions/FocusriteUSBAudio.kext`, set permissions and approve it if prompted. The original driver loads, but it produces no audio on Sonoma.
- **Keep safe copies** of the 3.0.2 kext (and its zip) and of the original kext.

---

## 25. Alternatives considered

- **Separate Mojave system:** confirmed working on this iMac with this interface. It is no longer needed, but remains a fallback.
- **USB 2.0 hub:** considered, but the rejection happened in `AppleUSBIORequest::prepare` before any transfer, so there was no evidence a hub would help. It was not pursued, and it is unnecessary now.
- **Class-compliant replacement interface:** unnecessary now.

---

## 26. Key commands

```bash
# Loaded driver and version
kmutil showloaded | grep -i focusrite

# Manual load
sudo kmutil load -p /Library/Extensions/FocusriteUSBAudio.kext

# Installed version
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" /Library/Extensions/FocusriteUSBAudio.kext/Contents/Info.plist

# Verify patch bytes
xxd -s 0x3072 -l 14 /Library/Extensions/FocusriteUSBAudio.kext/Contents/MacOS/FocusriteUSBAudio

# Signature
codesign --verify --verbose=2 /Library/Extensions/FocusriteUSBAudio.kext

# Architecture
file /Library/Extensions/FocusriteUSBAudio.kext/Contents/MacOS/FocusriteUSBAudio

# Audio engine state
ioreg -r -c FocusriteUSBAudioEngine -l | grep -E "IOAudioEngineState|IOAudioSampleRate"

# USB request errors
sudo log stream --style compact --level debug --predicate 'eventMessage CONTAINS[c] "AppleUSBIORequest" OR sender == "FocusriteUSBAudio"'

# Autoload log
cat /var/log/saffire6usb-loader.log
```

---

## 27. Conclusion

The Focusrite Saffire 6 USB 1.1 works on macOS Sonoma 14.8.9 (OCLP 2.5.1) on the iMac14,2.

The original Focusrite 3.0 driver was already largely compatible: it uses the modern `IOUSBHostFamily` API, loads on Sonoma, and its vtable calls into `IOUSBHostPipe` remain valid. The single incompatibility was that it created the isochronous transfer buffers without a transfer direction for both endpoints, which Sonoma's USB stack rejects with `invalid buffer length or direction` / `0xe00002c2`.

A 24-byte in-place patch assigns `kIODirectionIn` to the input endpoint and `kIODirectionOut` to the output endpoint, distinguishing the streams by the sample rate each buffer manager requests. Combined with ad-hoc signing, user approval and a LaunchDaemon for boot-time loading, this restores full functionality without modifying OCLP, SIP or the kernel collections.
