#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin="$ROOT/plugin-cli"
entrypoint="$plugin/rootfs/usr/bin/cli.sh"
dockerfile="$plugin/Dockerfile"
workflow="$ROOT/.github/workflows/mirror-fa-plugins.yml"
os_doc="$ROOT/docs/OS_BUILD.md"
branding_doc="$ROOT/docs/BRANDING.md"
release_doc="$ROOT/RELEASE.md"
expected_cli_tag="ghcr.io/esaueng/amd64-hassio-cli:\${ver}"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$dockerfile" ] || fail "plugin-cli Dockerfile is missing"
[ -f "$entrypoint" ] || fail "plugin-cli branded entrypoint is missing"

grep -q 'FROM ghcr.io/home-assistant/amd64-hassio-cli:' "$dockerfile" \
    || fail "plugin-cli must inherit the pinned upstream-compatible amd64 CLI image"
grep -q 'io.hass.type="cli"' "$dockerfile" \
    || fail "plugin-cli image label must stay upstream-compatible"
grep -q 'COPY rootfs /' "$dockerfile" \
    || fail "plugin-cli Dockerfile must copy the local branded rootfs"
grep -q 'org.opencontainers.image.title="Factory Assistant CLI Plugin"' "$dockerfile" \
    || fail "plugin-cli image title must be Factory Assistant branded"

grep -q 'Factory Assistant CLI' "$entrypoint" \
    || fail "CLI banner does not show the Factory Assistant product name"
grep -q 'Factory Assistant is based on Home Assistant\.' "$entrypoint" \
    || fail "CLI banner is missing factual upstream attribution"
grep -q 'Monitoring only' "$entrypoint" \
    || fail "CLI banner is missing the monitoring-only safety posture"
grep -q 'not a safety device' "$entrypoint" \
    || fail "CLI banner is missing the non-safety disclaimer"
grep -q 'fa >' "$entrypoint" \
    || fail "CLI prompt is not Factory Assistant branded"

if grep -Eiq 'ha banner|Home Assistant CLI|HA CLI' "$entrypoint"; then
    fail "CLI entrypoint still contains upstream Home Assistant-branded banner text"
fi

if grep -Eq 'copy[[:space:]]+cli[[:space:]]' "$workflow"; then
    fail "mirror workflow still publishes the upstream Home Assistant CLI plugin image"
fi
grep -q 'actions/checkout@v4' "$workflow" \
    || fail "mirror workflow must check out local build contexts before building plugin-cli"
grep -q 'docker buildx build' "$workflow" \
    || fail "mirror workflow does not build local plugin images"
grep -q 'plugin-cli' "$workflow" \
    || fail "mirror workflow does not build the local Factory Assistant CLI plugin"
grep -q "$expected_cli_tag" "$workflow" \
    || fail "mirror workflow does not publish the expected CLI plugin tag"

if grep -Eq 'Containerized CLI-plugin banner.*P2' "$os_doc"; then
    fail "OS build checklist still marks CLI banner as unresolved P2 work"
fi
if grep -Eq 'CLI banner/MOTD.*P2' "$branding_doc"; then
    fail "branding checklist still marks CLI banner as unresolved P2 work"
fi
if grep -q 'containerized CLI-plugin banner' "$release_doc"; then
    fail "release checklist still lists the CLI plugin banner as remaining Phase 2 work"
fi

echo "ok  CLI plugin is locally branded and workflow-built"
