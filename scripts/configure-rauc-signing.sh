#!/usr/bin/env bash
# Install Factory Assistant RAUC signing inputs into the upstream OS build tree.
#
# The source CA certificate and signing key/certificate must live outside this
# repository. This script copies them into the gitignored upstream checkout in
# the exact paths HAOS 17.3 uses during image assembly:
#   - /build/cert.pem and /build/key.pem for genimage RAUC bundle signing
#   - buildroot-external/ota/{rel,dev}-ca.pem for the baked device keyring
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

upstream="${FAOS_UPSTREAM_DIR:-$ROOT/upstream/operating-system}"
keyring="${FAOS_RAUC_KEYRING:-}"
cert="${FAOS_RAUC_CERT:-}"
key="${FAOS_RAUC_KEY:-}"

usage() {
    cat <<'EOF'
Usage: scripts/configure-rauc-signing.sh --keyring /secure/faos-ca.crt --cert /secure/faos-ota.crt --key /secure/faos-ota.key [--upstream upstream/operating-system]

Environment equivalents:
  FAOS_UPSTREAM_DIR  Upstream OS checkout (default: upstream/operating-system)
  FAOS_RAUC_KEYRING  Factory Assistant OTA root CA certificate
  FAOS_RAUC_CERT     Factory Assistant OTA signing certificate
  FAOS_RAUC_KEY      Factory Assistant OTA signing private key

The three signing input paths must exist and must be outside this repository.
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

canonical_dir() {
    local path="$1"

    [ -n "$path" ] || die "empty directory path"
    [ -d "$path" ] || die "directory not found: $path"
    (cd "$path" && pwd -P)
}

reject_repo_source() {
    local label="$1"
    local path="$2"

    case "$path" in
        "$ROOT" | "$ROOT"/*)
            die "$label must be supplied from outside this repository: $path"
            ;;
    esac
}

verify_cert_against_keyring() {
    local ca="$1"
    local signed_cert="$2"

    if openssl verify -help 2>&1 | grep -q -- '-no-CApath'; then
        openssl verify -CAfile "$ca" -no-CApath "$signed_cert" >/dev/null
    else
        openssl verify -CAfile "$ca" "$signed_cert" >/dev/null
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --upstream) upstream="$2"; shift 2;;
        --keyring) keyring="$2"; shift 2;;
        --cert)    cert="$2"; shift 2;;
        --key)     key="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *)         die "unknown argument: $1";;
    esac
done

[ -n "$keyring" ] || die "--keyring or FAOS_RAUC_KEYRING is required"
[ -n "$cert" ] || die "--cert or FAOS_RAUC_CERT is required"
[ -n "$key" ] || die "--key or FAOS_RAUC_KEY is required"
command -v openssl >/dev/null 2>&1 || die "openssl is required"

upstream="$(canonical_dir "$upstream")"
keyring="$(canonical_file "$keyring")"
cert="$(canonical_file "$cert")"
key="$(canonical_file "$key")"

reject_repo_source "RAUC keyring" "$keyring"
reject_repo_source "RAUC signing certificate" "$cert"
reject_repo_source "RAUC signing private key" "$key"

ota_dir="$upstream/buildroot-external/ota"
[ -d "$ota_dir" ] || die "$ota_dir not found; run make bootstrap && make overlay first"

openssl x509 -in "$keyring" -noout >/dev/null \
    || die "RAUC keyring is not a readable PEM X.509 certificate: $keyring"
openssl x509 -in "$cert" -noout >/dev/null \
    || die "RAUC signing certificate is not a readable PEM X.509 certificate: $cert"
openssl rsa -in "$key" -check -noout >/dev/null 2>&1 \
    || die "RAUC signing key is not a readable RSA private key: $key"
verify_cert_against_keyring "$keyring" "$cert" \
    || die "RAUC signing certificate does not verify against the supplied keyring"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
openssl x509 -in "$cert" -pubkey -noout > "$tmp/cert.pub"
openssl rsa -in "$key" -pubout > "$tmp/key.pub" 2>/dev/null
cmp -s "$tmp/cert.pub" "$tmp/key.pub" \
    || die "RAUC signing key does not match the signing certificate"

install -m 0644 "$keyring" "$ota_dir/rel-ca.pem"
install -m 0644 "$keyring" "$ota_dir/dev-ca.pem"
install -m 0644 "$cert" "$upstream/cert.pem"
install -m 0600 "$key" "$upstream/key.pem"

cat <<EOF
Configured Factory Assistant RAUC signing inputs:
  keyring -> $ota_dir/{rel,dev}-ca.pem
  cert    -> $upstream/cert.pem
  key     -> $upstream/key.pem

Builds from this upstream checkout will sign RAUC bundles with the supplied
Factory Assistant signing key and bake only the supplied Factory Assistant CA
into the device keyring.
EOF
