#!/bin/bash
#
# install.sh — Install the patched FocusriteUSBAudio.kext and the boot loader daemon.
# SOLVE SYSTEMS · Victor Urtubia
#
# Usage:  sudo ./install.sh [path/to/patched/FocusriteUSBAudio.kext]
#
set -euo pipefail

PATCHED_SHA256="358562a0cf601750895e7d9fefdb40875cd5876fc068d7d8c9ef3f565a6a2af0"
BUNDLE_ID="com.focusrite.driver.usb.audio"
LABEL="io.github.solve-systems.saffire6usb-loader"
DEST="/Library/Extensions/FocusriteUSBAudio.kext"
DAEMON="/Library/LaunchDaemons/$LABEL.plist"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-./output/FocusriteUSBAudio.kext}"

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

[ "$(uname -s)" = "Darwin" ] || die "this script must run on macOS"
[ "$(uname -m)" = "x86_64" ] || die "Intel Macs only. The Focusrite driver is x86_64 and cannot run on Apple Silicon."
[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo $0 $*"
[ -d "$SRC" ] || die "patched kext not found: $SRC (run ./patch.sh first)"

SHA="$(shasum -a 256 "$SRC/Contents/MacOS/FocusriteUSBAudio" | awk '{print $1}')"
[ "$SHA" = "$PATCHED_SHA256" ] || die "$SRC is not the patched 3.0.2 binary (run ./patch.sh first)"

# Unload any loaded copy
if kmutil showloaded 2>/dev/null | grep -q "$BUNDLE_ID"; then
  info "Unloading currently loaded Focusrite driver"
  kmutil unload -b "$BUNDLE_ID" || die "could not unload the current driver. Disconnect the Saffire, restart, and run this again."
fi

# Back up an existing, different kext
if [ -d "$DEST" ]; then
  OLD="$(shasum -a 256 "$DEST/Contents/MacOS/FocusriteUSBAudio" | awk '{print $1}')"
  if [ "$OLD" != "$PATCHED_SHA256" ]; then
    BK="/Users/Shared/FocusriteUSBAudio.backup-$(date +%Y%m%d-%H%M%S).kext"
    info "Backing up existing kext to $BK"
    cp -R "$DEST" "$BK"
  fi
  rm -rf "$DEST"
fi

info "Installing kext to $DEST"
cp -R "$SRC" "$DEST"
codesign --force --deep --sign - "$DEST"
chown -R root:wheel "$DEST"
chmod -R 755 "$DEST"
codesign --verify "$DEST" || die "signature verification failed"

info "Installing boot loader daemon ($DAEMON)"
cp "$HERE/launchd/$LABEL.plist" "$DAEMON"
chown root:wheel "$DAEMON"
chmod 644 "$DAEMON"
plutil -lint "$DAEMON" >/dev/null || die "invalid daemon plist"

info "Trying to load the driver"
if OUT="$(kmutil load -p "$DEST" 2>&1)"; then
  kmutil showloaded 2>/dev/null | grep "$BUNDLE_ID" || true
  echo
  info "Installed and loaded. Connect the Saffire and select it in System Settings > Sound."
else
  echo "$OUT"
  echo
  if echo "$OUT" | grep -qi "not approved"; then
    cat <<MSG
==> The extension needs your approval (this is expected the first time):
    1. Open System Settings > Privacy & Security.
    2. In the Security section, click "Allow" for the blocked system software.
    3. Restart when macOS asks. The driver will load automatically at boot.
MSG
  else
    die "kmutil could not load the driver (see message above)"
  fi
fi
