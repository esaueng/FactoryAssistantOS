#!/usr/bin/env bash
# Verify trusted Factory Assistant OS RAUC bundles against the release keyring.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_dir="$ROOT/release"
board="generic-x86-64"
keyring=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-rauc-bundle-signature.sh --keyring faos-ca.crt [--release-dir release] [--board generic-x86-64]

Runs `rauc info --keyring` for every faos_<board>-*.raucb bundle in the
release directory. This proves the bundle signature verifies against the
Factory Assistant OTA CA before the trusted release is published.
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
        --release-dir) release_dir="$2"; shift 2;;
        --board)       board="$2"; shift 2;;
        --keyring)     keyring="$2"; shift 2;;
        -h|--help)     usage; exit 0;;
        *)             die "unknown argument: $1";;
    esac
done

[ -n "$keyring" ] || die "--keyring is required"
[ -d "$release_dir" ] || die "release directory not found: $release_dir"
release_dir="$(cd "$release_dir" && pwd -P)"
keyring="$(canonical_file "$keyring")"
command -v rauc >/dev/null 2>&1 || die "rauc is required"

shopt -s nullglob
bundles=("$release_dir"/faos_"$board"-*.raucb)
shopt -u nullglob

[ "${#bundles[@]}" -gt 0 ] || die "release requires a faos_${board}-*.raucb bundle"

for bundle in "${bundles[@]}"; do
    if ! rauc info --keyring "$keyring" "$bundle" >/dev/null; then
        die "RAUC signature verification failed: $bundle"
    fi
done

cat <<EOF
RAUC bundle signature verification passed
  release dir: $release_dir
  board: $board
  keyring: $keyring
  bundles: ${#bundles[@]}
EOF
