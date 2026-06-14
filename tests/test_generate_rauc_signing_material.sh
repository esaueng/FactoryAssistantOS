#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

out="$tmp/faos-rauc"
script="$ROOT/scripts/generate-rauc-signing-material.sh"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

file_mode() {
    if stat -c '%a' "$1" >/dev/null 2>&1; then
        stat -c '%a' "$1"
    else
        stat -f '%Lp' "$1"
    fi
}

"$script" --out-dir "$out" --ca-days 3650 --signing-days 825 >"$tmp/generate.out"
grep -q 'scripts/configure-github-rauc-secrets.sh' "$tmp/generate.out" \
    || fail "generator output does not point at the validated GitHub secret installer"
if grep -q 'gh secret set FAOS_RAUC' "$tmp/generate.out"; then
    fail "generator output still recommends raw gh secret set commands"
fi

ca_key="$out/faos-rauc-ca.key"
ca_crt="$out/faos-rauc-ca.crt"
signing_key="$out/faos-rauc-signing.key"
signing_csr="$out/faos-rauc-signing.csr"
signing_crt="$out/faos-rauc-signing.crt"

for f in "$ca_key" "$ca_crt" "$signing_key" "$signing_csr" "$signing_crt"; do
    [ -f "$f" ] || fail "expected signing material is missing: $f"
done

[ "$(file_mode "$ca_key")" = "600" ] \
    || fail "CA private key must be mode 0600"
[ "$(file_mode "$signing_key")" = "600" ] \
    || fail "signing private key must be mode 0600"

openssl rsa -in "$ca_key" -check -noout >/dev/null 2>&1 \
    || fail "CA key is not a valid RSA private key"
openssl rsa -in "$signing_key" -check -noout >/dev/null 2>&1 \
    || fail "signing key is not a valid RSA private key"
openssl x509 -in "$ca_crt" -noout -text | grep -q 'CA:TRUE' \
    || fail "CA certificate is missing CA:TRUE basic constraints"
openssl x509 -in "$signing_crt" -noout -text | grep -q 'Code Signing' \
    || fail "signing certificate is missing the code-signing EKU"

if openssl verify -help 2>&1 | grep -q -- '-no-CApath'; then
    openssl verify -CAfile "$ca_crt" -no-CApath "$signing_crt" >/dev/null \
        || fail "signing certificate does not verify against generated CA"
else
    openssl verify -CAfile "$ca_crt" "$signing_crt" >/dev/null \
        || fail "signing certificate does not verify against generated CA"
fi

openssl x509 -in "$signing_crt" -pubkey -noout > "$tmp/signing-cert.pub"
openssl rsa -in "$signing_key" -pubout > "$tmp/signing-key.pub" 2>/dev/null
cmp -s "$tmp/signing-cert.pub" "$tmp/signing-key.pub" \
    || fail "signing key does not match signing certificate"

if "$script" --out-dir "$ROOT/branding" 2>"$tmp/reject.err"; then
    fail "generator allowed output inside the repository"
fi
grep -q 'outside this repository' "$tmp/reject.err" \
    || fail "repo-local output rejection did not explain the repository boundary"

echo "ok  RAUC signing material generator creates external trusted inputs"
