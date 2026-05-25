#!/bin/sh
# https://xie.infoq.cn/article/4b954f196d6d4a288c8c6981c

NAME="Unmineable-Mac"
OUT="out"
APP="$NAME.app"
VERSION=$(sed -n 's/.*"version": "\(.*\)",/\1/p' package.json)

# Architecture switch — produce a separate build per CPU target so the .zip
# stays slim and users get exactly the miners that work on their hardware.
#   ARCH=arm64  → Apple Silicon (M1-M5+): arm64 Go binary + xmrig-m1 + kawpow-mac
#   ARCH=amd64  → Intel: amd64 Go binary + xmrig + legacy thinminerpro-intel
#   ARCH=""     → host default (arm64 on Apple Silicon hosts, etc.)
ARCH="${ARCH:-}"
case "$ARCH" in
  arm64)        ARCH_SUFFIX="-ARM"; GO_ARCH="arm64" ;;
  amd64|x86_64) ARCH_SUFFIX="-X86"; GO_ARCH="amd64" ;;
  "")           ARCH_SUFFIX="";     GO_ARCH="" ;;
  *) echo "Unknown ARCH=$ARCH (use arm64 or amd64)" >&2; exit 1 ;;
esac

# Miner binaries are not committed — make sure they were fetched first.
if [ ! -f "assets/miner/xmrig-m1" ] || [ ! -f "assets/miner/xmrig" ]; then
  echo "Miner binaries missing. Run: npm run fetch:miners" >&2
  exit 1
fi

rm -r $OUT/$APP 2>/dev/null || true

echo "Creating macOS app structure"
mkdir -p $OUT/$APP/Contents/{MacOS,Resources}

echo "Writing 'Info.plist'"
cat > $OUT/$APP/Contents/Info.plist << EOF
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
	<string>12.0</string>
	<key>LSUIElement</key>
  <string>1</string>
</dict>
</plist>
EOF

echo "Building Go app"

# Locate the Go toolchain. `go` is not always on PATH for non-login shells,
# so fall back to the usual Homebrew / official install locations.
GO_BIN="$(command -v go || true)"
if [ -z "$GO_BIN" ]; then
  for p in /opt/homebrew/bin/go /usr/local/bin/go /usr/local/go/bin/go "$HOME/go/bin/go"; do
    if [ -x "$p" ]; then GO_BIN="$p"; break; fi
  done
fi
if [ -z "$GO_BIN" ]; then
  echo "Go not found. Install it (brew install go) and make sure it is on PATH." >&2
  exit 1
fi

# Set MACOSX_DEPLOYMENT_TARGET so the produced binary's LC_BUILD_VERSION
# minos matches the Info.plist LSMinimumSystemVersion. Without this, Go
# inherits the host's current SDK (e.g. 26 on a Tahoe build host) and the
# app refuses to launch on older macOS versions even though it would
# otherwise run fine.
if [ -n "$GO_ARCH" ]; then
  # CGo cross-compilation: go disables CGo by default when GOOS/GOARCH differ
  # from host, but webview is a CGo wrapper around macOS WebKit so we MUST
  # have CGo. Apple's clang handles both arm64 and x86_64 natively, so pass
  # -arch <target> via CC/CXX.
  if [ "$GO_ARCH" = "amd64" ]; then CC_ARCH="x86_64"; else CC_ARCH="$GO_ARCH"; fi
  MACOSX_DEPLOYMENT_TARGET=12.0 \
    GOOS=darwin GOARCH="$GO_ARCH" CGO_ENABLED=1 \
    CC="clang -arch $CC_ARCH" CXX="clang++ -arch $CC_ARCH" \
    "$GO_BIN" build -o $OUT/$APP/Contents/MacOS/$NAME
else
  MACOSX_DEPLOYMENT_TARGET=12.0 "$GO_BIN" build -o $OUT/$APP/Contents/MacOS/$NAME
fi
if [ $? -ne 0 ]; then
  echo "go build failed" >&2
  exit 1
fi

echo "Copying files"
cp -r icon.icns $OUT/$APP/Contents/Resources
cp -r dist $OUT/$APP/Contents/Resources

# Per-arch asset selection — only ship the miner binaries that match the
# target architecture. Keeps the download slim and avoids confusion.
mkdir -p $OUT/$APP/Contents/Resources/assets/miner
cp -r assets/icons $OUT/$APP/Contents/Resources/assets/ 2>/dev/null || true
case "$ARCH" in
  arm64)
    cp assets/miner/xmrig-m1 $OUT/$APP/Contents/Resources/assets/miner/
    cp -r assets/miner/thinminerpro $OUT/$APP/Contents/Resources/assets/miner/
    ;;
  amd64|x86_64)
    cp assets/miner/xmrig $OUT/$APP/Contents/Resources/assets/miner/
    cp -r assets/miner/thinminerpro-intel $OUT/$APP/Contents/Resources/assets/miner/
    ;;
  *)
    # Host-default build — ship everything so the same .app runs on either arch.
    cp assets/miner/xmrig-m1 $OUT/$APP/Contents/Resources/assets/miner/ 2>/dev/null || true
    cp assets/miner/xmrig    $OUT/$APP/Contents/Resources/assets/miner/ 2>/dev/null || true
    [ -d assets/miner/thinminerpro ]       && cp -r assets/miner/thinminerpro       $OUT/$APP/Contents/Resources/assets/miner/
    [ -d assets/miner/thinminerpro-intel ] && cp -r assets/miner/thinminerpro-intel $OUT/$APP/Contents/Resources/assets/miner/
    ;;
esac

echo "Compressing '$APP'"
cd $OUT
ZIP_NAME="$NAME-$VERSION$ARCH_SUFFIX.zip"
rm -f "$ZIP_NAME"
zip -q -9 -r "$ZIP_NAME" "$APP"

echo "Done! → $OUT/$ZIP_NAME"
