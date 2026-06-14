#!/usr/bin/env bash
# Verify local release readiness before cutting a Factory Assistant OS tag.
#
# This preflight does not build the OS image. It checks the release inputs that
# can be validated cheaply and must be true before trusted OTA publication:
# Factory Assistant RAUC signing material from outside the repo, shipped
# branding/safety policy, and a channel document that points at
# Factory Assistant-owned images and OTA URLs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

channel="$ROOT/version-service/stable.json"
keyring="${FAOS_RAUC_KEYRING:-}"
cert="${FAOS_RAUC_CERT:-}"
key="${FAOS_RAUC_KEY:-}"

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-readiness.sh --keyring /secure/faos-ca.crt --cert /secure/faos-ota.crt --key /secure/faos-ota.key [--channel version-service/stable.json]

Environment equivalents:
  FAOS_RAUC_KEYRING  Factory Assistant OTA root CA certificate
  FAOS_RAUC_CERT     Factory Assistant OTA signing certificate
  FAOS_RAUC_KEY      Factory Assistant OTA signing private key

The three signing input paths must exist and must be outside this repository.
This also runs the shipped branding and safety-boundary verifiers.
Run this before cutting a v* release tag.
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

while [ $# -gt 0 ]; do
    case "$1" in
        --channel) channel="$2"; shift 2;;
        --keyring) keyring="$2"; shift 2;;
        --cert)    cert="$2"; shift 2;;
        --key)     key="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *)         die "unknown argument: $1";;
    esac
done

if [ -z "$keyring" ] || [ -z "$cert" ] || [ -z "$key" ]; then
    die "trusted release readiness requires --keyring, --cert, and --key"
fi
command -v openssl >/dev/null 2>&1 || die "openssl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

"$ROOT/scripts/verify-shipped-branding.sh" >/dev/null
"$ROOT/scripts/verify-safety-boundary.sh" >/dev/null
"$ROOT/scripts/verify-identity-go-live.sh" >/dev/null

channel="$(canonical_file "$channel")"
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

# shellcheck source=../branding/identity.env
source "$ROOT/branding/identity.env"

python3 - "$channel" "$FAOS_CONTAINER_REGISTRY" "$FAOS_OTA_URL_TEMPLATE" <<'PY'
import json
import sys

channel_path, expected_registry, expected_ota = sys.argv[1:4]
with open(channel_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

def die(message):
    raise SystemExit(message)

if data.get("channel") != "stable":
    die("channel document must be the stable release channel")

hassos = data.get("hassos") or {}
ota = hassos.get("ota")
if ota != expected_ota:
    die("OTA URL template must match branding/identity.env FAOS_OTA_URL_TEMPLATE")
if "{version}" not in ota or "{board}" not in ota or not ota.startswith("https://"):
    die("OTA URL template must contain {version}, {board}, and use https")
if "generic-x86-64" not in hassos:
    die("channel hassos map must include generic-x86-64")

images = data.get("images") or {}
required = ["core", "supervisor", "cli", "dns", "audio", "observer", "multicast"]
for name in required:
    image = images.get(name)
    if not image:
        die(f"channel image is missing: {name}")
    if not image.startswith(expected_registry + "/"):
        die(f"channel image is not under {expected_registry}: {name}={image}")
    if "ghcr.io/home-assistant/" in image:
        die(f"channel image points at upstream registry: {name}={image}")
    if "REPLACE-" in image or ".example" in image or "example." in image:
        die(f"channel image still contains placeholder text: {name}={image}")

for key in ("supervisor", "dns", "audio", "cli", "multicast", "observer"):
    if not data.get(key):
        die(f"channel component version is missing: {key}")
if not (data.get("homeassistant") or {}).get("default"):
    die("channel Core version is missing")
PY

cat <<EOF
release readiness preflight passed
  channel: $channel
  registry: $FAOS_CONTAINER_REGISTRY
  OTA template: $FAOS_OTA_URL_TEMPLATE
  shipped branding: verified
  safety boundary: verified
  identity go-live: verified
  RAUC keyring: $keyring
  RAUC signing cert: $cert
  RAUC signing key: external private key verified

You can cut a trusted tag release after the upstream tracker/security review,
license bundle, and boot-test checklist are complete.
EOF
