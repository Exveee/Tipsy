#!/usr/bin/env bash
#
# Build Tipsy and install it into /Applications so it shows up in Launchpad and
# the Applications folder. The Accessibility grant is keyed to the code-signing
# identity (not the path), so installing or moving the app keeps the grant when
# a stable signature is used (see Scripts/make-signing-cert.sh).
#
# Usage: ./Scripts/install.sh [debug|release]   (default: release)

set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Tipsy.app"

"$ROOT/Scripts/bundle.sh" "$CONFIG"

echo "==> Installing to $DEST"
# Quit a running copy so the bundle can be replaced.
pkill -f "/Applications/Tipsy.app/Contents/MacOS/Tipsy" 2>/dev/null || true
sleep 0.3
rm -rf "$DEST"
cp -R "$ROOT/dist/Tipsy.app" "$DEST"

echo "==> Installed. Launch from Launchpad/Applications, or:"
echo "    open \"$DEST\""
