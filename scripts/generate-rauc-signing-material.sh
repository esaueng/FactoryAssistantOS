#!/usr/bin/env bash
# Generate Factory Assistant RAUC CA/signing material outside this repository.
#
# This creates production-shaped X.509 inputs for configure-rauc-signing.sh.
# Keep the generated private keys offline or in dedicated release secret
# storage; never copy them into this repository.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

out_dir=""
ca_days="7300"
signing_days="1825"
force=0

usage() {
    cat <<'EOF'
Usage: scripts/generate-rauc-signing-material.sh --out-dir /secure/faos-rauc [options]

Options:
  --out-dir DIR       Required. External directory for generated material.
  --ca-days DAYS      Root CA validity in days (default: 7300).
  --signing-days DAYS Signing certificate validity in days (default: 1825).
  --force             Overwrite existing generated files in DIR.
  -h, --help          Show this help.

Generated files:
  faos-rauc-ca.key         Root CA private key (keep offline)
  faos-rauc-ca.crt         Root CA certificate / device keyring
  faos-rauc-signing.key    RAUC bundle signing private key
  faos-rauc-signing.csr    Signing certificate request
  faos-rauc-signing.crt    RAUC bundle signing certificate

The output directory must be outside this repository.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

positive_int() {
    case "$1" in
        ''|*[!0-9]*) return 1;;
        *) [ "$1" -gt 0 ];;
    esac
}

canonical_output_dir() {
    local path="$1"
    local parent
    local base

    [ -n "$path" ] || die "--out-dir is required"
    parent="$(dirname "$path")"
    base="$(basename "$path")"
    [ -d "$parent" ] || die "parent directory does not exist: $parent"
    parent="$(cd "$parent" && pwd -P)"
    printf '%s/%s\n' "$parent" "$base"
}

reject_repo_output() {
    local path="$1"

    case "$path" in
        "$ROOT" | "$ROOT"/*)
            die "RAUC signing material output must be outside this repository: $path"
            ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --out-dir)      out_dir="$2"; shift 2;;
        --ca-days)      ca_days="$2"; shift 2;;
        --signing-days) signing_days="$2"; shift 2;;
        --force)        force=1; shift;;
        -h|--help)      usage; exit 0;;
        *)              die "unknown argument: $1";;
    esac
done

command -v openssl >/dev/null 2>&1 || die "openssl is required"
positive_int "$ca_days" || die "--ca-days must be a positive integer"
positive_int "$signing_days" || die "--signing-days must be a positive integer"

out_dir="$(canonical_output_dir "$out_dir")"
reject_repo_output "$out_dir"

ca_key="$out_dir/faos-rauc-ca.key"
ca_crt="$out_dir/faos-rauc-ca.crt"
signing_key="$out_dir/faos-rauc-signing.key"
signing_csr="$out_dir/faos-rauc-signing.csr"
signing_crt="$out_dir/faos-rauc-signing.crt"

if [ "$force" -eq 0 ]; then
    for f in "$ca_key" "$ca_crt" "$signing_key" "$signing_csr" "$signing_crt"; do
        [ ! -e "$f" ] || die "refusing to overwrite existing file without --force: $f"
    done
fi

install -d -m 0700 "$out_dir"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/ca.cnf" <<'EOF'
[ req ]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca

[ dn ]
O = Factory Assistant
CN = Factory Assistant OS OTA Root CA

[ v3_ca ]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

cat > "$tmp/signing-req.cnf" <<'EOF'
[ req ]
distinguished_name = dn
prompt = no

[ dn ]
O = Factory Assistant
CN = Factory Assistant OS OTA Signing
EOF

cat > "$tmp/signing-ext.cnf" <<'EOF'
[ v3_codesign ]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

umask 077
openssl genrsa -out "$ca_key" 4096 >/dev/null 2>&1
openssl req -x509 -new -key "$ca_key" -sha256 -days "$ca_days" \
    -out "$ca_crt" -config "$tmp/ca.cnf" -extensions v3_ca >/dev/null 2>&1

openssl genrsa -out "$signing_key" 4096 >/dev/null 2>&1
openssl req -new -key "$signing_key" -out "$signing_csr" \
    -config "$tmp/signing-req.cnf" >/dev/null 2>&1
openssl x509 -req -in "$signing_csr" \
    -CA "$ca_crt" -CAkey "$ca_key" -CAserial "$tmp/ca.srl" -CAcreateserial \
    -sha256 -days "$signing_days" \
    -out "$signing_crt" -extfile "$tmp/signing-ext.cnf" \
    -extensions v3_codesign >/dev/null 2>&1

chmod 0600 "$ca_key" "$signing_key"
chmod 0644 "$ca_crt" "$signing_csr" "$signing_crt"

if openssl verify -help 2>&1 | grep -q -- '-no-CApath'; then
    openssl verify -CAfile "$ca_crt" -no-CApath "$signing_crt" >/dev/null
else
    openssl verify -CAfile "$ca_crt" "$signing_crt" >/dev/null
fi

openssl x509 -in "$signing_crt" -pubkey -noout > "$tmp/signing-cert.pub"
openssl rsa -in "$signing_key" -pubout > "$tmp/signing-key.pub" 2>/dev/null
cmp -s "$tmp/signing-cert.pub" "$tmp/signing-key.pub" \
    || die "generated signing key does not match signing certificate"

cat <<EOF
Generated Factory Assistant RAUC signing material outside this repository:
  CA private key:      $ca_key
  Device keyring CA:   $ca_crt
  Signing private key: $signing_key
  Signing CSR:         $signing_csr
  Signing certificate: $signing_crt

Local build wiring:
  scripts/configure-rauc-signing.sh --keyring "$ca_crt" --cert "$signing_crt" --key "$signing_key"

GitHub release secrets:
  scripts/configure-github-rauc-secrets.sh \\
    --repo esaueng/FactoryAssistantOS \\
    --keyring "$ca_crt" \\
    --cert "$signing_crt" \\
    --key "$signing_key"
EOF
