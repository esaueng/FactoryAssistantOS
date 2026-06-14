#!/usr/bin/env bash
# Verify branding/identity.env contains settled go-live endpoints.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
identity="$ROOT/branding/identity.env"

usage() {
    cat <<'EOF'
Usage: scripts/verify-identity-go-live.sh [--identity branding/identity.env]

Checks that Factory Assistant release identity values are settled for the
esaueng publication path: GHCR registry, GitHub Pages version channel, and
GitHub Releases RAUC OTA template. Placeholder .example / REPLACE-* values are
rejected before a trusted release is cut.
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

contains_placeholder() {
    case "$1" in
        *REPLACE-*|*.example*|*example.*)
            return 0
            ;;
    esac
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --identity) identity="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *)          die "unknown argument: $1";;
    esac
done

identity="$(canonical_file "$identity")"

# shellcheck source=../branding/identity.env
source "$identity"

required=(
    FAOS_CONTAINER_REGISTRY
    FAOS_VERSION_CHANNEL_URL
    FAOS_OTA_URL_TEMPLATE
)

for name in "${required[@]}"; do
    value="${!name:-}"
    [ -n "$value" ] || die "$name is required in $identity"
    if contains_placeholder "$value"; then
        die "identity go-live values still contain placeholders: $name=$value"
    fi
done

[ "$FAOS_CONTAINER_REGISTRY" = "ghcr.io/esaueng" ] \
    || die "FAOS_CONTAINER_REGISTRY must be ghcr.io/esaueng"
[ "$FAOS_VERSION_CHANNEL_URL" = "https://esaueng.github.io/FactoryAssistantOS/stable.json" ] \
    || die "FAOS_VERSION_CHANNEL_URL must be the esaueng GitHub Pages stable channel"

case "$FAOS_OTA_URL_TEMPLATE" in
    https://github.com/esaueng/FactoryAssistantOS/releases/download/*) ;;
    *) die "FAOS_OTA_URL_TEMPLATE must point at esaueng/FactoryAssistantOS GitHub Releases";;
esac
case "$FAOS_OTA_URL_TEMPLATE" in
    *"{version}"*"{board}"*) ;;
    *) die "FAOS_OTA_URL_TEMPLATE must contain {version} and {board}";;
esac
case "$FAOS_OTA_URL_TEMPLATE" in
    *"faos_{board}-{version}.raucb") ;;
    *) die "FAOS_OTA_URL_TEMPLATE must resolve to faos_{board}-{version}.raucb";;
esac

cat <<EOF
identity go-live verification passed
  identity: $identity
  registry: $FAOS_CONTAINER_REGISTRY
  channel URL: $FAOS_VERSION_CHANNEL_URL
  OTA template: $FAOS_OTA_URL_TEMPLATE
EOF
