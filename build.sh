#!/bin/sh
# https://xie.infoq.cn/article/4b954f196d6d4a288c8c6981c

NAME="Unmineable-Mac"
OUT="out"
APP="$NAME.app"
VERSION=$(sed -n 's/.*"version": "\(.*\)",/\1/p' package.json)

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
MACOSX_DEPLOYMENT_TARGET=12.0 "$GO_BIN" build -o $OUT/$APP/Contents/MacOS/$NAME
if [ $? -ne 0 ]; then
  echo "go build failed" >&2
  exit 1
fi

echo "Copying files"
cp -r icon.icns $OUT/$APP/Contents/Resources
cp -r assets $OUT/$APP/Contents/Resources
cp -r dist $OUT/$APP/Contents/Resources

echo "Compressing '$APP'"
cd $OUT
zip -q -9 -r $NAME-$VERSION.zip $APP

echo "Done!"
