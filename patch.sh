#!/bin/bash
#
# patch.sh — Patch the official Focusrite Saffire 6 USB 1.1 driver (3.0)
# so it works on macOS 11+ (tested on macOS Sonoma 14.8.9).
#
# SOLVE SYSTEMS · Victor Urtubia
# https://github.com/solve-systems/saffire6usb-sonoma
#
# This script does NOT contain any Focusrite code. It modifies YOUR copy
# of the official driver, downloaded from Focusrite's website.
#
# Usage:
#   ./patch.sh <input> [output_dir]
#
#   <input> can be:
#     - the official driver .dmg  (focusrite-usb-drivers-3.0.653.dmg)
#     - the installer .pkg        (or FocusriteusbDriver.pkg inside it)
#     - an extracted FocusriteUSBAudio.kext
#
#   output_dir defaults to ./output
#
set -euo pipefail

ORIG_SHA256="10cfd51ff3b198729771b18c3f44b425adf45af291b0ae052011f5a075b1ed1c"
PATCHED_SHA256="358562a0cf601750895e7d9fefdb40875cd5876fc068d7d8c9ef3f565a6a2af0"
PATCHED_VERSION="3.0.2"

# offset | original bytes | patched bytes
PATCHES=(
  "0x3072|66666666662e0f1f840000000000|4181fd68bf000019c9f7d9ffc1c3"
  "0x4118|b900001000|e855efffff"
  "0x4138|b900001000|e835efffff"
)

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*" >&2; }

[ $# -ge 1 ] || die "usage: $0 <driver .dmg | .pkg | FocusriteUSBAudio.kext> [output_dir]"
INPUT="$1"
OUTDIR="${2:-./output}"
[ -e "$INPUT" ] || die "not found: $INPUT"

for tool in shasum xxd pkgutil; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool missing: $tool (run this on macOS)"
done
PLISTBUDDY=/usr/libexec/PlistBuddy
[ -x "$PLISTBUDDY" ] || die "PlistBuddy not found (run this on macOS)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/saffire6usb.XXXXXX")"
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && hdiutil detach -quiet "$MOUNT" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

find_kext() { find "$1" -type d -name "FocusriteUSBAudio.kext" -print -quit 2>/dev/null || true; }

extract_from_pkg() {
  local pkg="$1" dest="$WORK/pkg"
  info "Expanding $(basename "$pkg")"
  pkgutil --expand-full "$pkg" "$dest" >/dev/null || die "could not expand $pkg"
  find_kext "$dest"
}

# 1. Locate the original kext
case "$INPUT" in
  *.kext|*.kext/)
    SRC_KEXT="${INPUT%/}" ;;
  *.pkg)
    SRC_KEXT="$(extract_from_pkg "$INPUT")" ;;
  *.dmg)
    info "Mounting $(basename "$INPUT")"
    MOUNT="$WORK/mnt"; mkdir -p "$MOUNT"
    hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$INPUT" || die "could not mount $INPUT"
    PKG="$(find "$MOUNT" -maxdepth 3 -name "*.pkg" -print -quit 2>/dev/null || true)"
    [ -n "$PKG" ] || die "no .pkg found inside the dmg"
    SRC_KEXT="$(extract_from_pkg "$PKG")" ;;
  *)
    die "unsupported input: $INPUT (expected .dmg, .pkg or .kext)" ;;
esac
[ -n "${SRC_KEXT:-}" ] && [ -d "$SRC_KEXT" ] || die "FocusriteUSBAudio.kext not found in $INPUT"
info "Found kext: $SRC_KEXT"

SRC_BIN="$SRC_KEXT/Contents/MacOS/FocusriteUSBAudio"
[ -f "$SRC_BIN" ] || die "kext binary missing: $SRC_BIN"

# 2. Verify it is exactly the official 3.0 binary
SHA="$(shasum -a 256 "$SRC_BIN" | awk '{print $1}')"
if [ "$SHA" = "$PATCHED_SHA256" ]; then
  die "this kext is already patched ($PATCHED_VERSION). Nothing to do."
fi
[ "$SHA" = "$ORIG_SHA256" ] || die "unexpected binary (sha256 $SHA). Only the official Focusrite driver 3.0 (Saffire 6 USB 1.1) is supported."
info "Original Focusrite 3.0 binary verified"

# 3. Copy to output
mkdir -p "$OUTDIR"
DST_KEXT="$OUTDIR/FocusriteUSBAudio.kext"
[ -e "$DST_KEXT" ] && die "$DST_KEXT already exists. Remove it or choose another output_dir."
cp -R "$SRC_KEXT" "$DST_KEXT"
rm -rf "$DST_KEXT/Contents/_CodeSignature"
DST_BIN="$DST_KEXT/Contents/MacOS/FocusriteUSBAudio"

# 4. Apply byte patches (with verification)
for p in "${PATCHES[@]}"; do
  IFS='|' read -r off orig new <<<"$p"
  len=$(( ${#orig} / 2 ))
  actual="$(xxd -p -s "$off" -l "$len" "$DST_BIN" | tr -d '\n')"
  [ "$actual" = "$orig" ] || die "unexpected bytes at $off: $actual"
  printf "$(echo "$new" | sed 's/../\\x&/g')" | dd of="$DST_BIN" bs=1 seek=$((off)) conv=notrunc 2>/dev/null
  info "Patched $len bytes at $off"
done

SHA="$(shasum -a 256 "$DST_BIN" | awk '{print $1}')"
[ "$SHA" = "$PATCHED_SHA256" ] || die "patched binary checksum mismatch ($SHA). Aborting."

# 5. Bump version
"$PLISTBUDDY" -c "Set :CFBundleVersion $PATCHED_VERSION" "$DST_KEXT/Contents/Info.plist"

info "Done: $DST_KEXT (version $PATCHED_VERSION)"
echo
echo "Next step:  sudo ./install.sh \"$DST_KEXT\""
