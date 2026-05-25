#!/bin/sh
#
# build-legacy-intel.sh — produce a Catalina-compatible (macOS 10.15+)
# Intel x86_64 build. This is a one-off frozen variant — it will NOT
# track future releases.
#
# Why a separate script:
#   - Current build.sh uses the host Go (1.26+), which dropped Catalina
#     support
#   - Current XMRig 6.26.0 is built against macOS 11+, refuses to load
#     on 10.15
#
# To produce a 10.15-compatible binary we need:
#   - go@1.22 (last Go to support darwin 10.15)
#   - XMRig 6.15.0 (last XMRig with macOS 10.13/10.15 target)
#   - thinminerpro-intel (the upstream Intel binary, already at 10.15)
#   - LSMinimumSystemVersion=10.15 in the Info.plist
#   - MACOSX_DEPLOYMENT_TARGET=10.15 at link time
#
# Usage:
#   sh scripts/build-legacy-intel.sh
#
# Output: out/Unmineable-Mac-<VERSION>-X86-Legacy.zip
#
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NAME="Unmineable-Mac"
OUT="out"
APP="$NAME.app"
VERSION=$(sed -n 's/.*"version": "\(.*\)",/\1/p' package.json)
MIN_OS="10.15"

# --- Pre-flight: Go 1.22 must be available ----------------------------------
GO122="/opt/homebrew/opt/go@1.22/bin/go"
[ -x "$GO122" ] || GO122="/usr/local/opt/go@1.22/bin/go"
if [ ! -x "$GO122" ]; then
  echo "ERROR: go@1.22 not installed. Run: brew install go@1.22" >&2
  exit 1
fi
echo "==> Using Go: $($GO122 version)"

# --- Pre-flight: XMRig 6.15.0 (10.13 minOS) --------------------------------
XMRIG_LEGACY_DIR="$ROOT/.legacy-cache"
XMRIG_LEGACY="$XMRIG_LEGACY_DIR/xmrig-6.15.0/xmrig"
if [ ! -x "$XMRIG_LEGACY" ]; then
  echo "==> Fetching XMRig 6.15.0 (macOS 10.13+ build)"
  mkdir -p "$XMRIG_LEGACY_DIR"
  curl -sL -o "$XMRIG_LEGACY_DIR/xmrig.tgz" \
    "https://github.com/xmrig/xmrig/releases/download/v6.15.0/xmrig-6.15.0-macos-x64.tar.gz"
  tar -xzf "$XMRIG_LEGACY_DIR/xmrig.tgz" -C "$XMRIG_LEGACY_DIR"
  rm -f "$XMRIG_LEGACY_DIR/xmrig.tgz"
fi
[ -x "$XMRIG_LEGACY" ] || { echo "ERROR: XMRig 6.15.0 not extracted to $XMRIG_LEGACY" >&2; exit 1; }
echo "==> XMRig 6.15.0 ready at $XMRIG_LEGACY"

# --- Pre-flight: thinminerpro-intel already shipped at minOS 10.15 ---------
if [ ! -d "assets/miner/thinminerpro-intel" ]; then
  echo "==> Fetching thinminerpro-intel"
  sh scripts/fetchMiners.sh
fi

# --- Build the Svelte UI ---------------------------------------------------
echo "==> Building UI"
npm run build > /dev/null

# --- Build the Go binary (x86_64, MACOSX_DEPLOYMENT_TARGET=10.15) ---------
rm -rf "$OUT/$APP" 2>/dev/null || true
mkdir -p "$OUT/$APP/Contents/MacOS" "$OUT/$APP/Contents/Resources"

cat > "$OUT/$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$NAME</string>
	<key>CFBundleIconFile</key>
	<string>icon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>io.shiftingeden.Unmineable-Mac</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_OS</string>
	<key>LSUIElement</key>
	<string>1</string>
</dict>
</plist>
EOF

echo "==> Building Go (1.22, x86_64, minOS=$MIN_OS)"
MACOSX_DEPLOYMENT_TARGET="$MIN_OS" \
  GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 \
  CC="clang -arch x86_64" CXX="clang++ -arch x86_64" \
  "$GO122" build -o "$OUT/$APP/Contents/MacOS/$NAME"

# --- Stage assets ----------------------------------------------------------
echo "==> Staging assets"
cp -r icon.icns "$OUT/$APP/Contents/Resources/"
cp -r dist     "$OUT/$APP/Contents/Resources/"
mkdir -p "$OUT/$APP/Contents/Resources/assets/miner"
# Use the OLD XMRig (10.13 minOS) — replaces the modern build that needs 11+
cp "$XMRIG_LEGACY" "$OUT/$APP/Contents/Resources/assets/miner/xmrig"
chmod +x "$OUT/$APP/Contents/Resources/assets/miner/xmrig"
cp -r assets/miner/thinminerpro-intel "$OUT/$APP/Contents/Resources/assets/miner/"

# --- Sanity check the minOS load commands ---------------------------------
echo "==> Verifying minOS load commands"
for f in \
  "$OUT/$APP/Contents/MacOS/$NAME" \
  "$OUT/$APP/Contents/Resources/assets/miner/xmrig" \
  "$OUT/$APP/Contents/Resources/assets/miner/thinminerpro-intel/thinminerpro" \
; do
  printf "    %s — " "$(basename "$f")"
  otool -l "$f" 2>/dev/null | grep -E "minos|version " | head -1 | tr -s ' '
done

# --- Zip up ---------------------------------------------------------------
ZIP_NAME="$NAME-$VERSION-X86-Legacy.zip"
( cd "$OUT" && rm -f "$ZIP_NAME" && zip -q -9 -r "$ZIP_NAME" "$APP" )
echo "==> Done: $OUT/$ZIP_NAME"
ls -lh "$OUT/$ZIP_NAME"
