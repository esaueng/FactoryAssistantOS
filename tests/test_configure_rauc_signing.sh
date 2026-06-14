#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

upstream="$tmp/upstream"
mkdir -p "$upstream/buildroot-external/ota"

openssl genrsa -out "$tmp/faos-ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "$tmp/faos-ca.key" -sha256 -days 30 \
    -out "$tmp/faos-ca.crt" \
    -subj "/O=Factory Assistant/CN=Factory Assistant OS Test OTA Root CA" >/dev/null 2>&1

openssl genrsa -out "$tmp/faos-ota.key" 2048 >/dev/null 2>&1
openssl req -new -key "$tmp/faos-ota.key" \
    -out "$tmp/faos-ota.csr" \
    -subj "/O=Factory Assistant/CN=Factory Assistant OS Test OTA Signing" >/dev/null 2>&1
openssl x509 -req -in "$tmp/faos-ota.csr" \
    -CA "$tmp/faos-ca.crt" -CAkey "$tmp/faos-ca.key" -CAcreateserial \
    -sha256 -days 30 -out "$tmp/faos-ota.crt" >/dev/null 2>&1

"$ROOT/scripts/configure-rauc-signing.sh" \
    --upstream "$upstream" \
    --keyring "$tmp/faos-ca.crt" \
    --cert "$tmp/faos-ota.crt" \
    --key "$tmp/faos-ota.key"

cmp "$tmp/faos-ca.crt" "$upstream/buildroot-external/ota/rel-ca.pem"
cmp "$tmp/faos-ca.crt" "$upstream/buildroot-external/ota/dev-ca.pem"
cmp "$tmp/faos-ota.crt" "$upstream/cert.pem"
cmp "$tmp/faos-ota.key" "$upstream/key.pem"

if openssl verify -help 2>&1 | grep -q -- '-no-CApath'; then
    openssl verify -CAfile "$upstream/buildroot-external/ota/rel-ca.pem" \
        -no-CApath "$upstream/cert.pem" >/dev/null
else
    openssl verify -CAfile "$upstream/buildroot-external/ota/rel-ca.pem" \
        "$upstream/cert.pem" >/dev/null
fi

if find "$upstream/buildroot-external/ota" -name '*.key' -o -name '*.csr' | grep -q .; then
    echo "secret signing material leaked into the Buildroot external OTA tree" >&2
    exit 1
fi

echo "ok  configure-rauc-signing installs trusted OTA inputs"
