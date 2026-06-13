#!/usr/bin/env bash
#
# Creates a self-signed code-signing certificate in the login keychain so that
# Tipsy gets a STABLE code signature across rebuilds. macOS keys the
# Accessibility (TCC) grant to the signature's designated requirement, so a
# stable identity means the permission survives rebuilds — no more re-granting.
#
# This is NOT a Developer ID cert (that needs a paid Apple Developer account and
# is only required for distribution / notarization). It is enough for stable
# local permissions.
#
# The cert is valid for 825 days (Apple's max leaf validity, ~2.25 years); rerun
# this script to mint a fresh identity when it expires.
#
# Idempotent: does nothing if the identity already exists.
# Usage: ./Scripts/make-signing-cert.sh

set -euo pipefail

NAME="Tipsy Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "$NAME"; then
  echo "==> Identity '$NAME' already exists — nothing to do."
  exit 0
fi

echo "==> Creating self-signed code-signing certificate '$NAME'"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cfg" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

# Generate an 825-day self-signed cert + private key.
# 825 days is Apple's max leaf-certificate validity (~2.25 years).
# Restrict permissions so the temp private key is written 0600, never world-readable.
umask 077
openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cfg" 2>/dev/null

# Import key and cert separately as PEM, pre-authorizing codesign to use the key.
# (Avoids PKCS#12 MAC incompatibilities between OpenSSL 3 and Apple Security.)
# macOS pairs the cert with its matching private key into a code-signing identity.
security import "$TMP/key.pem" -k "$KEYCHAIN" -T /usr/bin/codesign
security import "$TMP/cert.pem" -k "$KEYCHAIN" -T /usr/bin/codesign

# Set the key partition list so non-interactive codesign can use the key without
# prompting. Uses an empty keychain password (-k "") which is the common default.
# If the login keychain has a non-empty password this is a no-op (|| true) and you
# may be prompted once on the first codesign — choose 'Always Allow'.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || true

echo "==> Done. Verify with: security find-identity -v -p codesigning"
echo "    Build signed:        ./Scripts/bundle.sh release"
echo
echo "Note: this identity is valid for 825 days (~2.25 years) — rerun this"
echo "script to renew it when it expires. The partition list is pre-set for"
echo "non-interactive codesign, but if your login keychain has a password the"
echo "first 'codesign' run may still show a one-time prompt — choose 'Always"
echo "Allow'. The next Accessibility grant for Tipsy is also a one-time step;"
echo "after that the permission persists across rebuilds."
