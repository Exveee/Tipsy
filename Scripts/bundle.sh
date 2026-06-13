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

# Ad-hoc signature so synthesized-input permissions persist across launches.
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
