#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/configuration.yaml"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
config_text="$(tr '\n' ' ' < "$config")"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

for banned in \
    'default_config:' \
    'cloud:' \
    'usage_prediction:' \
    'homeassistant_alerts:' \
    'my:'; do
    if grep -Eq "^[[:space:]]*${banned}" "$config"; then
        fail "industrial default configuration loads banned non-local default: $banned"
    fi
done

grep -q 'Local-first allowlist' "$config" \
    || fail "configuration.yaml does not explain the explicit local-first integration allowlist"
case "$config_text" in
    *"cloud/analytics"*"defaults intentionally omitted"*) ;;
    *) fail "configuration.yaml does not document cloud/analytics omission";;
esac

for required in \
    'backup:' \
    'config:' \
    'dhcp:' \
    'energy:' \
    'history:' \
    'logbook:' \
    'ssdp:' \
    'system_health:' \
    'zeroconf:'; do
    grep -Eq "^[[:space:]]*${required}" "$config" \
        || fail "local-first configuration is missing required integration: $required"
done

grep -q 'default_config is deliberately not used' "$defaults_doc" \
    || fail "industrial defaults doc does not document the default_config replacement"
grep -q 'cloud/analytics defaults are off' "$defaults_doc" \
    || fail "industrial defaults doc does not document cloud/analytics-off posture"
grep -q 'cloud/analytics defaults are off in the shipped template' "$arch_doc" \
    || fail "architecture status does not mention local-first cloud/analytics posture"

echo "ok  Core defaults are explicit, local-first, and cloud/analytics-off"
