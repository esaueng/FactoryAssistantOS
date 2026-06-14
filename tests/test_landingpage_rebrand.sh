#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
landing="$ROOT/landingpage"
html="$landing/rootfs/usr/share/www/index.html"
logo="$landing/rootfs/usr/share/www/static/icons/factory-assistant-logo.svg"
dockerfile="$landing/Dockerfile"
workflow="$ROOT/.github/workflows/mirror-fa-plugins.yml"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$html" ] || fail "landingpage index.html is missing"
[ -f "$logo" ] || fail "landingpage Factory Assistant logo is missing"
[ -f "$dockerfile" ] || fail "landingpage Dockerfile is missing"

grep -q '<title>Factory Assistant OS</title>' "$html" \
    || fail "landingpage title is not Factory Assistant OS"
grep -q 'Preparing Factory Assistant' "$html" \
    || fail "landingpage does not show the Factory Assistant preparing copy"
grep -q 'Factory Assistant is based on Home Assistant\.' "$html" \
    || fail "landingpage is missing factual upstream attribution"
grep -q 'Monitoring only' "$html" \
    || fail "landingpage is missing the monitoring-only safety posture"

if grep -Eiq 'Home Assistant</title|alt="Home Assistant"|ha-landing-page|logo_ohf|ohf\.svg|frontend_latest|frontend_es5' "$html"; then
    fail "landingpage still contains upstream Home Assistant-branded UI hooks"
fi

if find "$landing/rootfs/usr/share/www/static" -type f | grep -Eiq '(ohf|home-assistant|logo_ha)'; then
    fail "landingpage static assets include upstream/OHF branding"
fi

grep -q 'io.hass.type="landingpage"' "$dockerfile" \
    || fail "landingpage image label must stay upstream-compatible"
grep -q 'COPY rootfs /' "$dockerfile" \
    || fail "landingpage Dockerfile must copy the local branded rootfs"

if grep -q 'home-assistant/generic-x86-64-homeassistant:landingpage' "$workflow"; then
    fail "mirror workflow still publishes the upstream Home Assistant landingpage image"
fi
grep -q 'docker buildx build' "$workflow" \
    || fail "mirror workflow does not build the local Factory Assistant landingpage image"
grep -q 'ghcr.io/esaueng/generic-x86-64-homeassistant:landingpage' "$workflow" \
    || fail "mirror workflow does not publish the expected landingpage tag"

echo "ok  landingpage is locally branded and workflow-built"
