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

# Generate a 10-year self-signed cert + private key.
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cfg" 2>/dev/null

# Import key and cert separately as PEM, pre-authorizing codesign to use the key.
# (Avoids PKCS#12 MAC incompatibilities between OpenSSL 3 and Apple Security.)
# macOS pairs the cert with its matching private key into a code-signing identity.
security import "$TMP/key.pem" -k "$KEYCHAIN" -T /usr/bin/codesign
security import "$TMP/cert.pem" -k "$KEYCHAIN" -T /usr/bin/codesign

echo "==> Done. Verify with: security find-identity -v -p codesigning"
echo "    Build signed:        ./Scripts/bundle.sh release"
echo
echo "Note: the first 'codesign' run may show a one-time keychain prompt —"
echo "choose 'Always Allow'. The next Accessibility grant for Tipsy is also a"
echo "one-time step; after that the permission persists across rebuilds."
