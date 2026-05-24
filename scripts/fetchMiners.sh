#!/bin/sh
#
# fetchMiners.sh — download the miner binaries that macMineable bundles.
#
# Run this on macOS once before `npm run build:app`. It populates
# assets/miner/ with:
#
#   assets/miner/xmrig                  XMRig (Intel / x86_64)        — CPU / RandomX
#   assets/miner/xmrig-m1               XMRig (Apple Silicon / arm64) — CPU / RandomX
#   assets/miner/thinminerpro/          Thinminerpro                  — GPU / KawPow
#       thinminerpro                    Apple Silicon build
#       thinminerpro-intel              Intel build
#       config.json                     pool/worker config (patched at runtime)
#
# The binaries are NOT committed to the repo — they are large and have their
# own licenses. This script fetches them from the upstream GitHub releases.
#
set -eu

XMRIG_VERSION="6.26.0"

# Thinminerpro release assets (see https://github.com/rezahussain/thinminerpro).
# A newer 2022_09_04 build exists; swap these URLs if you want to try it.
THINMINERPRO_ARM_URL="https://github.com/rezahussain/thinminerpro/releases/download/2022_03_12_arm_release/2022_03_12_arm_release.zip"
THINMINERPRO_INTEL_URL="https://github.com/rezahussain/thinminerpro/releases/download/2022_02_20_intel/thinminerpro_intel.zip"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MINER_DIR="$ROOT/assets/miner"
TM_DIR="$MINER_DIR/thinminerpro"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$MINER_DIR" "$TM_DIR"

# ---------------------------------------------------------------------------
# XMRig — CPU miner (RandomX)
# ---------------------------------------------------------------------------
echo "==> Downloading XMRig $XMRIG_VERSION"

fetch_xmrig() {
  arch="$1"   # arm64 | x64
  dest="$2"   # output binary name
  url="https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-macos-${arch}.tar.gz"

  echo "    - $arch -> assets/miner/$dest"
  curl -L --fail --progress-bar -o "$TMP/xmrig-$arch.tar.gz" "$url"

  mkdir -p "$TMP/xmrig-$arch"
  tar -xzf "$TMP/xmrig-$arch.tar.gz" -C "$TMP/xmrig-$arch"

  bin="$(find "$TMP/xmrig-$arch" -type f -name xmrig | head -n1)"
  if [ -z "$bin" ]; then
    echo "ERROR: xmrig binary not found in the $arch tarball" >&2
    exit 1
  fi
  cp "$bin" "$MINER_DIR/$dest"
  chmod +x "$MINER_DIR/$dest"
}

fetch_xmrig "arm64" "xmrig-m1"
fetch_xmrig "x64" "xmrig"

# ---------------------------------------------------------------------------
# Thinminerpro — GPU miner (KawPow, Metal)
# ---------------------------------------------------------------------------
echo "==> Downloading Thinminerpro (GPU / KawPow)"

fetch_thinminerpro() {
  url="$1"    # release zip url
  dest="$2"   # output binary name (thinminerpro | thinminerpro-intel)
  label="$3"

  echo "    - $label -> assets/miner/thinminerpro/$dest"
  curl -L --fail --progress-bar -o "$TMP/$dest.zip" "$url"

  mkdir -p "$TMP/$dest"
  unzip -o -q "$TMP/$dest.zip" -d "$TMP/$dest"

  bin="$(find "$TMP/$dest" -type f -name thinminerpro | head -n1)"
  if [ -z "$bin" ]; then
    echo "ERROR: thinminerpro binary not found in the $label zip" >&2
    exit 1
  fi
  cp "$bin" "$TM_DIR/$dest"
  chmod +x "$TM_DIR/$dest"

  # Keep the first config.json we find as the template the app patches.
  if [ ! -f "$TM_DIR/config.json" ]; then
    cfg="$(find "$TMP/$dest" -type f -name config.json | head -n1)"
    [ -n "$cfg" ] && cp "$cfg" "$TM_DIR/config.json"
  fi
}

fetch_thinminerpro "$THINMINERPRO_ARM_URL" "thinminerpro" "Apple Silicon"
fetch_thinminerpro "$THINMINERPRO_INTEL_URL" "thinminerpro-intel" "Intel"

# Fallback config.json if the release archives did not ship one. macMineable
# rewrites the "user" field at runtime; verify the key names against the real
# Thinminerpro config if mining fails to connect.
if [ ! -f "$TM_DIR/config.json" ]; then
  echo "    - writing a fallback config.json"
  cat > "$TM_DIR/config.json" <<'EOF'
{
  "user": "REPLACED_AT_RUNTIME",
  "host": "kawpow.unmineable.com",
  "port": 3333
}
EOF
fi

# ---------------------------------------------------------------------------
# Clear the macOS quarantine flag so the unsigned third-party binaries can run.
# Gatekeeper may still prompt on first launch — allow them in System Settings.
# ---------------------------------------------------------------------------
xattr -dr com.apple.quarantine "$MINER_DIR" 2>/dev/null || true

echo "==> Done. Miner binaries are in assets/miner/"
ls -la "$MINER_DIR" "$TM_DIR"
