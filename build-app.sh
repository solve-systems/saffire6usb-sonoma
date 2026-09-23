#!/bin/bash
#
# build-app.sh — Build "Saffire 6 USB Installer.app" and a release zip.
# SOLVE SYSTEMS · Victor Urtubia
#
# Run on a Mac from the repository folder:  bash build-app.sh
# Output: build/Saffire 6 USB Installer.app and build/Saffire6USB-Installer.zip
#
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Saffire 6 USB Installer.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/scripts/launchd"

cp app/Info.plist                 "$APP/Contents/Info.plist"
cp app/launcher.sh                "$APP/Contents/MacOS/Saffire6USBInstaller"
cp app/AppIcon.icns               "$APP/Contents/Resources/AppIcon.icns"
cp patch.sh install.sh uninstall.sh "$APP/Contents/Resources/scripts/"
cp launchd/*.plist                "$APP/Contents/Resources/scripts/launchd/"
cp LICENSE                        "$APP/Contents/Resources/"

chmod 755 "$APP/Contents/MacOS/Saffire6USBInstaller" "$APP/Contents/Resources/scripts/"*.sh

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP"
  echo "==> Signed ad-hoc"
fi

if command -v ditto >/dev/null 2>&1; then
  ditto -c -k --keepParent "$APP" build/Saffire6USB-Installer.zip
else
  (cd build && zip -qry Saffire6USB-Installer.zip "Saffire 6 USB Installer.app")
fi
( cd build && shasum -a 256 Saffire6USB-Installer.zip 2>/dev/null || sha256sum Saffire6USB-Installer.zip ) | tee build/Saffire6USB-Installer.zip.sha256
echo "==> Built: $APP"
echo "==> Release zip: build/Saffire6USB-Installer.zip"
