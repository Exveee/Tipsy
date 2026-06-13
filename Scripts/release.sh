#!/usr/bin/env bash
#
# Local release flow: build + assemble Tipsy.app, then (when signing material
# is present) notarize and staple it. Replaces the old GitHub Actions release
# workflow — everything runs on your own machine.
#
# Environment variables:
#   SIGN_IDENTITY        codesign identity. Unset or "-" -> ad-hoc (no notarization).
#                        A real Developer ID enables the notarization path below,
#                        e.g. "Developer ID Application: Your Name (TEAMID)".
#   AC_KEYCHAIN_PROFILE  PREFERRED. Name of a stored notarytool keychain profile.
#                        When set, credentials are read from the keychain and no
#                        secrets/ids appear in the process argv (safe from `ps`).
#                        One-time setup (stores the credentials in the keychain):
#                          xcrun notarytool store-credentials "$AC_KEYCHAIN_PROFILE" \
#                            --key "<.p8 path>" --key-id "<id>" --issuer "<issuer>"
#   AC_API_KEY           Fallback path to the App Store Connect API key (.p8 file).
#   AC_API_KEY_ID        Fallback App Store Connect API key ID.
#   AC_API_ISSUER_ID     Fallback App Store Connect API issuer ID.
#                        NOTE: the AC_API_* fallback passes --key-id / --issuer on
#                        the command line, exposing those ids to any local `ps`.
#                        Prefer AC_KEYCHAIN_PROFILE, which keeps them out of argv.
#
# Notarization happens only when SIGN_IDENTITY is a real identity (not "-")
# AND notarization credentials are available — EITHER AC_KEYCHAIN_PROFILE is set,
# OR all three AC_API_* variables are set. Otherwise this just produces the
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

have_full_api_trio=false
if [ -n "${AC_API_KEY:-}" ] && [ -n "${AC_API_KEY_ID:-}" ] && [ -n "${AC_API_ISSUER_ID:-}" ]; then
  have_full_api_trio=true
fi

if [ -z "${AC_KEYCHAIN_PROFILE:-}" ] && [ "$have_full_api_trio" = false ]; then
  echo "==> Signed with '$SIGN_IDENTITY' but no notarization credentials available."
  echo "==> Set AC_KEYCHAIN_PROFILE (preferred) or the full AC_API_KEY / AC_API_KEY_ID / AC_API_ISSUER_ID trio."
  echo "==> Skipping notarization."
  echo "==> Done: $APP (signed, not notarized)"
  exit 0
fi

echo "==> Zipping for notarization"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to notarytool (waiting for result)"
if [ -n "${AC_KEYCHAIN_PROFILE:-}" ]; then
  # Preferred: credentials come from the keychain; nothing sensitive in argv.
  xcrun notarytool submit "$ZIP" \
    --keychain-profile "$AC_KEYCHAIN_PROFILE" \
    --wait
else
  # Fallback: exposes --key-id / --issuer to local `ps`. Prefer AC_KEYCHAIN_PROFILE.
  xcrun notarytool submit "$ZIP" \
    --key "$AC_API_KEY" \
    --key-id "$AC_API_KEY_ID" \
    --issuer "$AC_API_ISSUER_ID" \
    --wait
fi

echo "==> Stapling"
xcrun stapler staple "$APP"

echo "==> Re-zipping stapled app"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $APP (signed + notarized + stapled), $ZIP"
