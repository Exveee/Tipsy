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
case "$CONFIG" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 1;; esac
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Tipsy.app"

"$ROOT/Scripts/bundle.sh" "$CONFIG"

# Verify the freshly built bundle before touching /Applications.
[ -d "$ROOT/dist/Tipsy.app" ] || { echo "Build failed: $ROOT/dist/Tipsy.app missing" >&2; exit 1; }
if ! codesign --verify --strict "$ROOT/dist/Tipsy.app"; then
  echo "Refusing: signature verification failed for $ROOT/dist/Tipsy.app" >&2
  exit 1
fi
echo "==> Built bundle signing identity:"
codesign -dvv "$ROOT/dist/Tipsy.app"

echo "==> Installing to $DEST"
# Refuse to follow a symlink at the destination (could redirect rm -rf elsewhere).
[ -L "$DEST" ] && { echo "Refusing: $DEST is a symlink" >&2; exit 1; }
# Quit a running copy so the bundle can be replaced.
pkill -f "/Applications/Tipsy.app/Contents/MacOS/Tipsy" 2>/dev/null || true
sleep 0.3
rm -rf "$DEST"
cp -R "$ROOT/dist/Tipsy.app" "$DEST"

echo "==> Installed. Launch from Launchpad/Applications, or:"
echo "    open \"$DEST\""
