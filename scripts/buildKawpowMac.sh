#!/bin/sh
#
# buildKawpowMac.sh — build our open-source KawPow miner and install it as the
# Unmineable-Mac "thinminerpro" slot.
#
# Replaces upstream Thinminerpro (closed-source, broken on M3+ Apple Silicon)
# with the in-repo Swift+Metal miner under kawpow-mac/. The Go wrapper still
# launches `./thinminerpro` from `assets/miner/thinminerpro/`, so we deposit
# the kawpow-mac binary there under the same name.
#
# NOTE: as of this revision, kawpow-mac connects and submits shares but the
# pool rejects them with "Low difficulty share" — same end-user behaviour as
# upstream Thinminerpro on M3+. The advantage is the source is in this repo
# and debuggable. See kawpow-mac/README.md for the milestone tracker.
#
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$ROOT/kawpow-mac"
DEST="$ROOT/assets/miner/thinminerpro"
KAWPOW_MAC_REPO="https://github.com/shiftingeden/kawpow-mac.git"

# Clone kawpow-mac if missing (it's a sibling repo, not tracked here).
if [ ! -d "$PROJ" ]; then
  echo "==> $PROJ not found — cloning from $KAWPOW_MAC_REPO"
  git clone "$KAWPOW_MAC_REPO" "$PROJ"
fi
if [ ! -f "$PROJ/Package.swift" ]; then
  echo "ERROR: $PROJ exists but is not a kawpow-mac checkout" >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "ERROR: swift toolchain not found (install Xcode Command Line Tools)" >&2
  exit 1
fi

echo "==> Building kawpow-mac (release)"
( cd "$PROJ" && swift build -c release )

SRC_BIN="$PROJ/.build/release/kawpow-mac"
SRC_BUNDLE="$PROJ/.build/release/kawpow-mac_kawpow-mac.bundle"

if [ ! -x "$SRC_BIN" ]; then
  echo "ERROR: build did not produce $SRC_BIN" >&2
  exit 1
fi
if [ ! -d "$SRC_BUNDLE" ]; then
  echo "ERROR: build did not produce $SRC_BUNDLE (Metal shaders missing)" >&2
  exit 1
fi

echo "==> Installing into $DEST (renaming binary → 'thinminerpro')"
mkdir -p "$DEST"
rm -f "$DEST/thinminerpro"
rm -rf "$DEST/kawpow-mac_kawpow-mac.bundle"
# Stale shader from a previous upstream-thinminerpro install — no longer used.
rm -f "$DEST/default.metallib"
cp "$SRC_BIN" "$DEST/thinminerpro"
cp -R "$SRC_BUNDLE" "$DEST/kawpow-mac_kawpow-mac.bundle"
chmod +x "$DEST/thinminerpro"

# Ad-hoc sign so Gatekeeper does not trap the binary on launch.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$DEST/thinminerpro" 2>/dev/null || true
fi

# Provide a fallback config.json (Unmineable-Mac patches user/pool at runtime).
if [ ! -f "$DEST/config.json" ]; then
  cat > "$DEST/config.json" <<'EOF'
{
  "user": "REPLACED_AT_RUNTIME",
  "chosenURL": "kp.unmineable.com",
  "chosenPort": 3333,
  "deviceNumber": 0,
  "intensity": 10371840
}
EOF
fi

echo "==> Installed:"
ls -la "$DEST"
