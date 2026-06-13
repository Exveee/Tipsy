#!/usr/bin/env bash
#
# Build Tipsy and assemble a runnable Tipsy.app bundle.
# Works with the Swift toolchain only — no Xcode required.
#
# Usage: ./Scripts/bundle.sh [debug|release]   (default: release)

set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Tipsy.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT"

BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/Tipsy"

echo "==> Assembling bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tipsy"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Code signing.
#
# SIGN_IDENTITY selects the codesign identity:
#   - unset or "-"  -> ad-hoc signature (local/dev default). This keeps
#                      synthesized-input permissions persisting across launches.
#   - a real cert   -> Developer ID Application identity (CI / distributable
#                      builds), signed with the hardened runtime enabled.
#
# Example (CI): SIGN_IDENTITY="Developer ID Application: Foo (TEAMID)" ./Scripts/bundle.sh release
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "==> Signing ad-hoc"
  codesign --force --deep --sign - "$APP"
else
  echo "==> Signing with Developer ID: $SIGN_IDENTITY (hardened runtime)"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

echo "==> Done: $APP"
