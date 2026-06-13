#!/usr/bin/env bash
#
# Removes Tipsy from /Applications. With --purge it also deletes the saved
# preferences and the local signing certificate.
#
# Usage:
#   ./Scripts/uninstall.sh           # quit + remove /Applications/Tipsy.app
#   ./Scripts/uninstall.sh --purge   # also remove preferences + signing cert

set -euo pipefail

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

BUNDLE_ID="de.rabbgmbh.tipsy"
APP="/Applications/Tipsy.app"

echo "==> Quitting Tipsy"
pkill -f "Tipsy.app/Contents/MacOS/Tipsy" 2>/dev/null || true
sleep 0.3

if [ -d "$APP" ]; then
  echo "==> Removing $APP"
  rm -rf "$APP"
else
  echo "==> $APP not present"
fi

if [ "$PURGE" = "1" ]; then
  echo "==> Removing preferences ($BUNDLE_ID)"
  defaults delete "$BUNDLE_ID" 2>/dev/null || true

  echo "==> Removing local signing certificate 'Tipsy Local Signing'"
  security delete-certificate -c "Tipsy Local Signing" 2>/dev/null || true
fi

echo
echo "Done. One manual step macOS does not allow scripting:"
echo "  System Settings → Privacy & Security → Accessibility → select Tipsy → −"
