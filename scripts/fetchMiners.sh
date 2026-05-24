#!/bin/sh
#
# fetchMiners.sh — download the miner binaries that macMineable bundles.
#
# Run this on macOS once before `npm run build:app`. It populates
# assets/miner/ with:
#
#   assets/miner/xmrig                   XMRig (Intel / x86_64)        — CPU / RandomX
#   assets/miner/xmrig-m1                XMRig (Apple Silicon / arm64) — CPU / RandomX
#   assets/miner/thinminerpro/           Thinminerpro, Apple Silicon   — GPU / KawPow
#   assets/miner/thinminerpro-intel/     Thinminerpro, Intel           — GPU / KawPow
#
# Each Thinminerpro folder holds the binary (named `thinminerpro`) plus all
# of its release resources — config.json, the Metal shader library, etc. The
# whole release folder is copied, because the miner traps on launch if its
# resources are missing.
#
# The binaries are NOT committed to the repo — they are large and have their
# own licenses. This script fetches them from the upstream GitHub releases.
#
set -eu

XMRIG_VERSION="6.26.0"

# Thinminerpro release assets (see https://github.com/rezahussain/thinminerpro).
# The 2022_09_04 build is the one that actually mines on Apple Silicon (M-series);
# earlier builds trap while building the KawPow cache. The Intel build is the
# last Intel-specific release and is best-effort only.
THINMINERPRO_ARM_URL="https://github.com/rezahussain/thinminerpro/releases/download/2022_09_04/thinminerpro.zip"
THINMINERPRO_INTEL_URL="https://github.com/rezahussain/thinminerpro/releases/download/2022_02_20_intel/thinminerpro_intel.zip"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MINER_DIR="$ROOT/assets/miner"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$MINER_DIR"

# adhoc_sign re-signs a binary with an ad-hoc signature. Apple Silicon kills
# binaries with a missing or invalid code signature ("Trace/BPT trap: 5"),
# and copying a binary out of an archive can invalidate its signature.
adhoc_sign() {
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$1" 2>/dev/null || true
  fi
}

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
  adhoc_sign "$MINER_DIR/$dest"
}

fetch_xmrig "arm64" "xmrig-m1"
fetch_xmrig "x64" "xmrig"

# ---------------------------------------------------------------------------
# Thinminerpro — GPU miner (KawPow, Metal)
# ---------------------------------------------------------------------------
echo "==> Downloading Thinminerpro (GPU / KawPow)"

fetch_thinminerpro() {
  url="$1"      # release zip url
  destdir="$2"  # output dir name (thinminerpro | thinminerpro-intel)
  label="$3"

  echo "    - $label -> assets/miner/$destdir/"
  curl -L --fail --progress-bar -o "$TMP/$destdir.zip" "$url"

  mkdir -p "$TMP/$destdir"
  unzip -o -q "$TMP/$destdir.zip" -d "$TMP/$destdir"

  bin="$(find "$TMP/$destdir" -type f -name thinminerpro | head -n1)"
  if [ -z "$bin" ]; then
    echo "ERROR: thinminerpro binary not found in the $label zip" >&2
    exit 1
  fi

  # Copy the WHOLE folder the binary lives in (resources, shaders, config).
  srcdir="$(dirname "$bin")"
  rm -rf "$MINER_DIR/$destdir"
  mkdir -p "$MINER_DIR/$destdir"
  cp -R "$srcdir"/. "$MINER_DIR/$destdir/"

  chmod +x "$MINER_DIR/$destdir/thinminerpro"
  adhoc_sign "$MINER_DIR/$destdir/thinminerpro"

  # Provide a config.json if the release did not ship one. macMineable
  # rewrites "user" (and ensures chosenURL/chosenPort) at runtime.
  if [ ! -f "$MINER_DIR/$destdir/config.json" ]; then
    echo "      (writing a fallback config.json)"
    cat > "$MINER_DIR/$destdir/config.json" <<'EOF'
{
  "user": "REPLACED_AT_RUNTIME",
  "chosenURL": "kp.unmineable.com",
  "chosenPort": 3333,
  "deviceNumber": 0,
  "intensity": 10371840
}
EOF
  fi
}

fetch_thinminerpro "$THINMINERPRO_ARM_URL" "thinminerpro" "Apple Silicon"
fetch_thinminerpro "$THINMINERPRO_INTEL_URL" "thinminerpro-intel" "Intel"

# ---------------------------------------------------------------------------
# Clear the macOS quarantine flag so the third-party binaries can run.
# Gatekeeper may still prompt on first launch — allow them in System Settings.
# ---------------------------------------------------------------------------
xattr -dr com.apple.quarantine "$MINER_DIR" 2>/dev/null || true

echo "==> Done. Miner binaries are in assets/miner/"
ls -la "$MINER_DIR"
