# Contributing

Thank you for helping keep the Saffire 6 USB 1.1 alive.

## The most valuable contribution: compatibility reports

Every Mac and macOS version this is tested on makes the project more reliable. If you tried it, whether it worked or not, please submit a **[compatibility report](../../issues/new?template=compatibility-report.yml)**.

Useful commands for the report:

```bash
sw_vers                                   # macOS version
sysctl -n hw.model                        # Mac model
kmutil showloaded | grep -i focusrite     # driver loaded?
cat ~/Library/Logs/Saffire6USB-Installer.log   # installer app log
cat /var/log/saffire6usb-loader.log            # startup service log
```

## Bug reports

Use the **[bug report](../../issues/new?template=bug-report.yml)** template, and include the logs above. For audio problems, a log captured while reproducing the issue helps a lot:

```bash
sudo log stream --style compact --level debug --predicate 'eventMessage CONTAINS[c] "AppleUSBIORequest" OR sender == "FocusriteUSBAudio"'
```

Security problems: see [SECURITY.md](SECURITY.md). Do not report them publicly.

## Pull requests

- Keep changes small and focused, one topic per pull request.
- Shell scripts must stay compatible with the default macOS `/bin/bash` (3.2).
- Never add Focusrite files or any part of the Focusrite driver to the repository.
- Changes to the binary patch must be documented in `docs/TECHNICAL_REPORT.md` and the `CHANGELOG.md`, with the new checksums.
- Describe how you tested the change: Mac model and macOS version.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
