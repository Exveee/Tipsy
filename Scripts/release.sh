#!/usr/bin/env bash
#
# Local release flow: build + assemble Tipsy.app, then (when signing material
# is present) notarize and staple it. Replaces the old GitHub Actions release
# workflow — everything runs on your own machine.
#
# Environment variables:
#   SIGN_IDENTITY    codesign identity. Unset or "-" -> ad-hoc (no notarization).
#                    A real Developer ID enables the notarization path below,
#                    e.g. "Developer ID Application: Your Name (TEAMID)".
#   AC_API_KEY       path to the App Store Connect API key (.p8 file).
#   AC_API_KEY_ID    App Store Connect API key ID.
#   AC_API_ISSUER_ID App Store Connect API issuer ID.
#
# Notarization happens only when SIGN_IDENTITY is a real identity (not "-")
# AND all three AC_* variables are set. Otherwise this just produces the
# ad-hoc dist/Tipsy.app and says so.
#
# Usage: ./Scripts/release.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Tipsy.app"
ZIP="$ROOT/dist/Tipsy.zip"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "==> Building bundle"
SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/Scripts/bundle.sh" release

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "==> SIGN_IDENTITY not set (ad-hoc). Skipping notarization."
  echo "==> Done: $APP (ad-hoc signed, not notarized)"
  exit 0
fi

if [ -z "${AC_API_KEY:-}" ] || [ -z "${AC_API_KEY_ID:-}" ] || [ -z "${AC_API_ISSUER_ID:-}" ]; then
  echo "==> Signed with '$SIGN_IDENTITY' but notarization env (AC_API_KEY / AC_API_KEY_ID / AC_API_ISSUER_ID) is incomplete."
  echo "==> Skipping notarization."
  echo "==> Done: $APP (signed, not notarized)"
  exit 0
fi

echo "==> Zipping for notarization"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to notarytool (waiting for result)"
xcrun notarytool submit "$ZIP" \
  --key "$AC_API_KEY" \
  --key-id "$AC_API_KEY_ID" \
  --issuer "$AC_API_ISSUER_ID" \
  --wait

echo "==> Stapling"
xcrun stapler staple "$APP"

echo "==> Re-zipping stapled app"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $APP (signed + notarized + stapled), $ZIP"
