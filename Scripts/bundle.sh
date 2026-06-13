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

# App icon. Regenerate the .icns from the generator if iconutil is available,
# then copy it into the bundle (referenced by Info.plist's CFBundleIconFile).
if command -v iconutil >/dev/null 2>&1; then
  ( cd "$ROOT" && swift Scripts/make-icons.swift >/dev/null )
  iconutil -c icns "$ROOT/dist/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"
fi
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Code signing.
#
# SIGN_IDENTITY selects the codesign identity:
#   - unset         -> auto: use the local "Tipsy Local Signing" identity if it
#                      exists (stable signature -> persistent Accessibility
#                      grant; see Scripts/make-signing-cert.sh), else ad-hoc.
#   - "-"           -> force ad-hoc (signature changes per build).
#   - a real cert   -> Developer ID Application identity for distributable,
#                      notarizable builds (hardened runtime + secure timestamp).
#
# Example: SIGN_IDENTITY="Developer ID Application: Foo (TEAMID)" ./Scripts/bundle.sh release
LOCAL_IDENTITY="Tipsy Local Signing"
if [ -z "${SIGN_IDENTITY:-}" ]; then
  # Note: no -v (the self-signed cert is untrusted but still valid for signing).
  if security find-identity -p codesigning 2>/dev/null | grep -q "$LOCAL_IDENTITY"; then
    SIGN_IDENTITY="$LOCAL_IDENTITY"
  else
    SIGN_IDENTITY="-"
  fi
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "==> Signing ad-hoc (run Scripts/make-signing-cert.sh for stable permissions)"
  codesign --force --deep --sign - "$APP"
elif printf '%s' "$SIGN_IDENTITY" | grep -q "Developer ID"; then
  echo "==> Signing with Developer ID: $SIGN_IDENTITY (hardened runtime + timestamp)"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  echo "==> Signing with local identity: $SIGN_IDENTITY (stable signature)"
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"
fi

echo "==> Done: $APP"
