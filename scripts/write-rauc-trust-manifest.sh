#!/usr/bin/env bash
# Write a public RAUC trust manifest for a trusted release.
set -euo pipefail

keyring=""
cert=""
out=""

usage() {
    cat <<'EOF'
Usage: scripts/write-rauc-trust-manifest.sh --keyring faos-ca.crt --cert faos-signing.crt --out release/RAUC_TRUST.json

Writes a non-secret JSON manifest with public certificate subjects,
fingerprints, validity dates, serials, and keyring verification status. It
never reads or emits the RAUC signing private key.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

canonical_file() {
    local path="$1"
    local dir

    [ -n "$path" ] || die "empty file path"
    [ -f "$path" ] || die "file not found: $path"
    dir="$(cd "$(dirname "$path")" && pwd -P)"
    printf '%s/%s\n' "$dir" "$(basename "$path")"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --keyring) keyring="$2"; shift 2;;
        --cert)    cert="$2"; shift 2;;
        --out)     out="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *)         die "unknown argument: $1";;
    esac
done

[ -n "$keyring" ] || die "--keyring is required"
[ -n "$cert" ] || die "--cert is required"
[ -n "$out" ] || die "--out is required"
command -v openssl >/dev/null 2>&1 || die "openssl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

keyring="$(canonical_file "$keyring")"
cert="$(canonical_file "$cert")"
out_dir="$(dirname "$out")"
[ -d "$out_dir" ] || die "output directory not found: $out_dir"
out_dir="$(cd "$out_dir" && pwd -P)"
out="$out_dir/$(basename "$out")"

if grep -q 'PRIVATE KEY' "$keyring" "$cert"; then
    die "trust manifest inputs must be public certificates only"
fi

if openssl verify -help 2>&1 | grep -q -- '-no-CApath'; then
    openssl verify -CAfile "$keyring" -no-CApath "$cert" >/dev/null \
        || die "RAUC signing certificate does not verify against the supplied keyring"
else
    openssl verify -CAfile "$keyring" "$cert" >/dev/null \
        || die "RAUC signing certificate does not verify against the supplied keyring"
fi

python3 - "$keyring" "$cert" "$out" <<'PY'
import json
import subprocess
import sys
from datetime import datetime, timezone

keyring, cert, out = sys.argv[1:4]


def openssl_x509(path, *args):
    result = subprocess.run(
        ["openssl", "x509", "-in", path, *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.stdout.strip()


def strip_prefix(text, prefix):
    return text[len(prefix):] if text.startswith(prefix) else text


def cert_info(path, include_issuer=False):
    dates = {}
    for line in openssl_x509(path, "-noout", "-dates").splitlines():
        key, value = line.split("=", 1)
        dates[key] = value

    data = {
        "subject": strip_prefix(
            openssl_x509(path, "-noout", "-subject", "-nameopt", "RFC2253"),
            "subject=",
        ),
        "sha256_fingerprint": strip_prefix(
            openssl_x509(path, "-noout", "-fingerprint", "-sha256"),
            "sha256 Fingerprint=",
        ),
        "not_before": dates["notBefore"],
        "not_after": dates["notAfter"],
    }
    if include_issuer:
        data["issuer"] = strip_prefix(
            openssl_x509(path, "-noout", "-issuer", "-nameopt", "RFC2253"),
            "issuer=",
        )
        data["serial"] = strip_prefix(
            openssl_x509(path, "-noout", "-serial"),
            "serial=",
        )
    return data


manifest = {
    "schema_version": 1,
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "private_key_material": False,
    "verified_by_keyring": True,
    "keyring": cert_info(keyring),
    "signing_certificate": cert_info(cert, include_issuer=True),
}

with open(out, "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY

cat <<EOF
RAUC trust manifest written
  output: $out
  keyring: $keyring
  signing certificate: $cert
EOF
