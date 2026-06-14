#!/usr/bin/env bash
# Verify shipped user-facing text does not regress to upstream branding.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
canonical="Factory Assistant is based on Home Assistant."

usage() {
    cat <<'EOF'
Usage: scripts/verify-shipped-branding.sh [file ...]

Checks shipped user-facing text for Factory Assistant branding rules:
canonical upstream attribution is required wherever the upstream product name
appears, and known upstream-branded UI strings/assets are rejected.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 0 ]; then
    files=("$@")
else
    files=(
        "$ROOT/buildroot-external/rootfs-overlay/etc/issue"
        "$ROOT/buildroot-external/rootfs-overlay/etc/motd"
        "$ROOT/buildroot-external/configs/factory-assistant.config"
        "$ROOT/branding/identity.env"
        "$ROOT/landingpage/rootfs/usr/share/www/index.html"
        "$ROOT/landingpage/rootfs/usr/share/doc/factory-assistant-landingpage/NOTICE"
        "$ROOT/plugin-cli/rootfs/usr/bin/cli.sh"
        "$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/README.md"
        "$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/examples/README.md"
    )
fi

for file in "${files[@]}"; do
    [ -f "$file" ] || die "branding audit file not found: $file"

    if grep -Eq 'Home Assistant</title|alt="Home Assistant"|Home Assistant CLI|HA CLI|ha-landing-page|logo_ohf|ohf\.svg|frontend_latest|frontend_es5' "$file"; then
        die "upstream-branded UI text or asset hook found in shipped file: $file"
    fi

    if grep -q 'Home Assistant' "$file" && ! grep -Fq "$canonical" "$file"; then
        die "shipped file must use canonical attribution \"$canonical\": $file"
    fi
done

if [ "$#" -eq 0 ]; then
    if find "$ROOT/landingpage/rootfs/usr/share/www/static" -type f | grep -Eiq '(ohf|home-assistant|logo_ha)'; then
        die "landingpage static assets include upstream/OHF branding"
    fi
fi

echo "shipped branding verification passed"
