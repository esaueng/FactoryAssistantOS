#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/write-rauc-trust-manifest.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "RAUC trust manifest writer is missing or not executable"

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

"$script" \
    --keyring "$tmp/faos-ca.crt" \
    --cert "$tmp/faos-ota.crt" \
    --out "$tmp/RAUC_TRUST.json" > "$tmp/ok.out"
grep -q 'RAUC trust manifest written' "$tmp/ok.out" \
    || fail "trust manifest writer success output is missing"

python3 - "$tmp/RAUC_TRUST.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

if data.get("schema_version") != 1:
    raise SystemExit("schema_version must be 1")
if data.get("private_key_material") is not False:
    raise SystemExit("manifest must explicitly state it contains no private key material")
if data.get("verified_by_keyring") is not True:
    raise SystemExit("manifest must state signing certificate verified against keyring")

keyring = data.get("keyring") or {}
signing = data.get("signing_certificate") or {}
for label, cert in (("keyring", keyring), ("signing_certificate", signing)):
    for field in ("subject", "sha256_fingerprint", "not_before", "not_after"):
        if not cert.get(field):
            raise SystemExit(f"{label} missing {field}")
if not signing.get("issuer"):
    raise SystemExit("signing certificate missing issuer")
if not signing.get("serial"):
    raise SystemExit("signing certificate missing serial")
PY

openssl genrsa -out "$tmp/other-ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "$tmp/other-ca.key" -sha256 -days 30 \
    -out "$tmp/other-ca.crt" \
    -subj "/O=Factory Assistant/CN=Untrusted Test CA" >/dev/null 2>&1

if "$script" --keyring "$tmp/other-ca.crt" --cert "$tmp/faos-ota.crt" \
    --out "$tmp/bad.json" 2> "$tmp/bad.err"; then
    fail "trust manifest writer allowed a signing certificate outside the keyring chain"
fi
grep -q 'does not verify against the supplied keyring' "$tmp/bad.err" \
    || fail "bad trust chain rejection did not explain the RAUC keyring mismatch"

echo "ok  RAUC trust manifest records public trusted OTA certificate facts"
