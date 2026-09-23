#!/bin/bash
#
# uninstall.sh — Remove the patched driver and the boot loader daemon.
# SOLVE SYSTEMS · Victor Urtubia
#
# Usage:  sudo ./uninstall.sh
#
set -euo pipefail

BUNDLE_ID="com.focusrite.driver.usb.audio"
LABEL="io.github.solve-systems.saffire6usb-loader"
DEST="/Library/Extensions/FocusriteUSBAudio.kext"
DAEMON="/Library/LaunchDaemons/$LABEL.plist"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo: sudo $0" >&2; exit 1; }

if kmutil showloaded 2>/dev/null | grep -q "$BUNDLE_ID"; then
  echo "==> Unloading driver"
  kmutil unload -b "$BUNDLE_ID" || echo "    Could not unload now; it will be gone after a restart."
fi

[ -f "$DAEMON" ] && { echo "==> Removing $DAEMON"; rm -f "$DAEMON"; }
[ -d "$DEST" ]   && { echo "==> Removing $DEST";   rm -rf "$DEST"; }
rm -f /var/log/saffire6usb-loader.log

echo "==> Done. Restart your Mac to finish."
