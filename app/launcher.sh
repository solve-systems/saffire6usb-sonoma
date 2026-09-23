#!/bin/bash
#
# Saffire 6 USB Installer — double-click installer for the Saffire 6 USB 1.1 patch.
# SOLVE SYSTEMS · Victor Urtubia · https://solvesystems.systems
# https://github.com/solve-systems/saffire6usb-sonoma
#
# This is the app's main executable. It shows native macOS dialogs and runs
# the same patch.sh / install.sh / uninstall.sh as the Terminal method.
#

TITLE="Saffire 6 USB Installer"
RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
SCRIPTS="$RES/scripts"
ICON="$RES/AppIcon.icns"
BUNDLE_ID="com.focusrite.driver.usb.audio"
FOCUSRITE_URL="https://downloads.focusrite.com/focusrite/saffire/saffire-6-usb"
REPO_URL="https://github.com/solve-systems/saffire6usb-sonoma"
SITE_URL="https://solvesystems.systems"
LOG="$HOME/Library/Logs/Saffire6USB-Installer.log"

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "===== $(date) ====="

# ---------- dialogs ----------

# ask "message" "Button1,Button2,Button3" "DefaultButton"  -> prints the button pressed
ask() {
  osascript - "$1" "$2" "$3" "$ICON" "$TITLE" <<'OSA'
on run argv
  set msg to item 1 of argv
  set AppleScript's text item delimiters to ","
  set btns to text items of (item 2 of argv)
  set AppleScript's text item delimiters to ""
  try
    set r to display dialog msg buttons btns default button (item 3 of argv) with title (item 5 of argv) with icon (POSIX file (item 4 of argv) as alias)
  on error
    set r to display dialog msg buttons btns default button (item 3 of argv) with title (item 5 of argv)
  end try
  return button returned of r
end run
OSA
}

say_ok()  { ask "$1" "OK" "OK" >/dev/null; }

fail() {
  echo "FAIL: $1"
  ask "$1

A log was saved to:
~/Library/Logs/Saffire6USB-Installer.log

If you need help, open an issue on GitHub and attach that log." "Open GitHub,Close" "Close" | grep -q "Open GitHub" && open "$REPO_URL/issues"
  exit 1
}

choose_file() {
  osascript <<'OSA'
try
  return POSIX path of (choose file with prompt "Select the Focusrite driver you downloaded (.dmg or .pkg):")
on error
  return ""
end try
OSA
}

# run a script as administrator (macOS password prompt); prints its output
run_admin() {
  osascript - "$@" <<'OSA' 2>&1
on run argv
  set cmd to "/bin/bash"
  repeat with a in argv
    set cmd to cmd & " " & quoted form of (a as text)
  end repeat
  return do shell script (cmd & " 2>&1") with prompt "Saffire 6 USB Installer needs your password to install a system driver." with administrator privileges without altering line endings
end run
OSA
}

open_security() {
  open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" 2>/dev/null \
    || open "x-apple.systempreferences:com.apple.preference.security?General"
}

is_loaded() { kmutil showloaded 2>/dev/null | grep -q "$BUNDLE_ID"; }

# ---------- checks ----------

if [ "$(uname -m)" != "x86_64" ]; then
  fail "This Mac has an Apple Silicon processor.

The Focusrite driver only works on Intel Macs, so it cannot be installed here."
fi
command -v kmutil >/dev/null 2>&1 || fail "This installer needs macOS 11 (Big Sur) or later."

# ---------- uninstall ----------

do_uninstall() {
  OUT="$(run_admin "$SCRIPTS/uninstall.sh")" || { echo "$OUT"; exit 0; }
  echo "$OUT"
  say_ok "The driver and the startup service were removed.

Restart your Mac to finish."
  exit 0
}

# ---------- welcome ----------

if is_loaded || [ -d /Library/Extensions/FocusriteUSBAudio.kext ]; then
  CHOICE="$(ask "A Focusrite Saffire driver is already installed on this Mac.

What would you like to do?" "Cancel,Uninstall,Reinstall" "Reinstall")"
else
  CHOICE="$(ask "This installer makes the Focusrite Saffire 6 USB 1.1 work on modern macOS.

It patches your own copy of Focusrite's official driver (version 3.0) and installs it. You will need:

• the driver file from Focusrite's website
• your Mac password
• one restart

Disconnect the Saffire before continuing." "Cancel,Install" "Install")"
fi

case "$CHOICE" in
  Uninstall) do_uninstall ;;
  Install|Reinstall) ;;
  *) exit 0 ;;
esac

# ---------- find the Focusrite driver ----------

find_driver() {
  find "$HOME/Downloads" "$HOME/Desktop" -maxdepth 2 \
    \( -iname "focusrite*usb*driver*.dmg" -o -iname "focusrite*usb*driver*.pkg" -o -iname "FocusriteusbDriver.pkg" \) \
    2>/dev/null | head -n 1
}

SRC="$(find_driver)"
while true; do
  if [ -n "$SRC" ]; then
    A="$(ask "Found the Focusrite driver:

$(basename "$SRC")

Use this file?" "Choose another…,Use this file" "Use this file")"
    [ "$A" = "Use this file" ] && break
    SRC=""
  fi
  A="$(ask "Please select the official Focusrite driver:

\"Saffire 6 USB 1.1 Driver 3.0 - Mac\"
(focusrite-usb-drivers-3.0.653.dmg)

If you don't have it yet, open Focusrite's website, download it (do not run its installer), then come back and click \"Choose file…\"." "Cancel,Open Focusrite website,Choose file…" "Choose file…")"
  case "$A" in
    "Open Focusrite website") open "$FOCUSRITE_URL" ;;
    "Choose file…")
      SRC="$(choose_file)"
      SRC="${SRC%/}"
      if [ -n "$SRC" ]; then
        case "$SRC" in
          *.dmg|*.pkg|*.kext) break ;;
          *) say_ok "Please select the .dmg or .pkg file from Focusrite."; SRC="" ;;
        esac
      fi ;;
    *) exit 0 ;;
  esac
done
echo "Driver source: $SRC"

# ---------- patch ----------

WORK="$(mktemp -d "${TMPDIR:-/tmp}/saffire6usb-app.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if ! POUT="$(/bin/bash "$SCRIPTS/patch.sh" "$SRC" "$WORK/out" 2>&1)"; then
  echo "$POUT"
  MSG="$(echo "$POUT" | grep '^ERROR' | tail -n 1 | sed 's/^ERROR: //')"
  [ -z "$MSG" ] && MSG="$(echo "$POUT" | grep -v '^\s*$' | tail -n 1)"
  fail "The driver could not be patched.

${MSG:-Unknown error.}

Make sure you selected \"Saffire 6 USB 1.1 Driver 3.0 - Mac\" from Focusrite."
fi
echo "$POUT"

# ---------- install ----------

KEXT="$WORK/out/FocusriteUSBAudio.kext"
if ! IOUT="$(run_admin "$SCRIPTS/install.sh" "$KEXT")"; then
  echo "$IOUT"
  echo "$IOUT" | grep -q -- "-128" && exit 0   # user cancelled the password prompt
  MSG="$(echo "$IOUT" | grep 'ERROR' | tail -n 1 | sed 's/.*ERROR: //')"
  [ -z "$MSG" ] && MSG="$(echo "$IOUT" | grep -v '^\s*$' | tail -n 1)"
  fail "The installation failed.

${MSG:-Unknown error.}"
fi
echo "$IOUT"

# ---------- finish ----------

if is_loaded; then
  A="$(ask "Done! The driver is installed and running.

Connect the Saffire, then choose \"Saffire 6USB\" in System Settings → Sound.

It will load automatically every time your Mac starts.

SOLVE SYSTEMS™ · solvesystems.systems" "Visit SOLVE SYSTEMS,Done" "Done")"
  [ "$A" = "Visit SOLVE SYSTEMS" ] && open "$SITE_URL"
else
  A="$(ask "Almost done. macOS needs your permission:

1. Click \"Open Privacy & Security\".
2. Scroll down to the Security section.
3. Click \"Allow\" next to the blocked system software.
4. Restart your Mac when asked.

After restarting, connect the Saffire and choose \"Saffire 6USB\" in System Settings → Sound.

SOLVE SYSTEMS™ · solvesystems.systems" "Later,Open Privacy & Security" "Open Privacy & Security")"
  [ "$A" = "Open Privacy & Security" ] && open_security
fi
exit 0
