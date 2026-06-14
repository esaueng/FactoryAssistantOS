#!/usr/bin/env bash
# Validate external Factory Assistant RAUC inputs and upload release secrets.
#
# This script never generates key material and never reads secrets back from
# GitHub. It validates user-supplied files from outside this repository, then
# streams them to `gh secret set` through stdin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

repo="esaueng/FactoryAssistantOS"
gh_bin="${FAOS_GH_BIN:-gh}"
keyring="${FAOS_RAUC_KEYRING:-}"
cert="${FAOS_RAUC_CERT:-}"
key="${FAOS_RAUC_KEY:-}"

usage() {
    cat <<'EOF'
Usage: scripts/configure-github-rauc-secrets.sh --keyring /secure/faos-ca.crt --cert /secure/faos-ota.crt --key /secure/faos-ota.key [--repo esaueng/FactoryAssistantOS]

Environment equivalents:
  FAOS_RAUC_KEYRING  Factory Assistant OTA root CA certificate
  FAOS_RAUC_CERT     Factory Assistant OTA signing certificate
  FAOS_RAUC_KEY      Factory Assistant OTA signing private key
  FAOS_GH_BIN        GitHub CLI path (default: gh)

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

set_secret_from_file() {
    local name="$1"
    local file="$2"

    "$gh_bin" secret set "$name" --repo "$repo" < "$file" >/dev/null
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)    repo="$2"; shift 2;;
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
command -v "$gh_bin" >/dev/null 2>&1 || die "GitHub CLI is required: $gh_bin"

keyring="$(canonical_file "$keyring")"
cert="$(canonical_file "$cert")"
key="$(canonical_file "$key")"

reject_repo_source "RAUC keyring" "$keyring"
reject_repo_source "RAUC signing certificate" "$cert"
reject_repo_source "RAUC signing private key" "$key"

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

set_secret_from_file FAOS_RAUC_KEYRING_PEM "$keyring"
set_secret_from_file FAOS_RAUC_CERT_PEM "$cert"
set_secret_from_file FAOS_RAUC_KEY_PEM "$key"

cat <<EOF
GitHub RAUC release secrets configured for $repo:
  FAOS_RAUC_KEYRING_PEM
  FAOS_RAUC_CERT_PEM
  FAOS_RAUC_KEY_PEM

Secret values were streamed to GitHub through stdin and were not printed.
EOF
