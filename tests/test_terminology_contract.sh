#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/ui/frontend_contract.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/ui/README.md"
onboarding_readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/README.md"
network_readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/network/README.md"
ui_doc="$ROOT/docs/UI_DESIGN.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
branding_doc="$ROOT/docs/BRANDING.md"
release_doc="$ROOT/RELEASE.md"
repo_readme="$ROOT/README.md"
motd="$ROOT/buildroot-external/rootfs-overlay/etc/motd"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$contract" ] || fail "frontend experience contract is missing"

python3 - "$contract" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

terminology = data.get("terminology") or {}
if terminology.get("status") != "os_shipped_handoff":
    raise SystemExit("terminology handoff must be explicitly OS-shipped")
if terminology.get("home_assistant_attribution") != "Factory Assistant is based on Home Assistant.":
    raise SystemExit("terminology contract must preserve canonical upstream attribution")
if terminology.get("cli_command") != "ha":
    raise SystemExit("terminology contract must preserve the upstream-compatible ha CLI command")
if terminology.get("cli_display_name") != "Factory Assistant CLI":
    raise SystemExit("terminology contract must use the Factory Assistant CLI product name")

canonical = terminology.get("canonical_user_terms") or {}
expected_terms = {
    "product": "Factory Assistant",
    "os": "Factory Assistant OS",
    "default_landing": "Plant overview",
    "site": "site",
    "line": "line",
    "cell": "cell",
    "station": "station",
    "machine": "machine",
    "wallboard": "Wallboard",
    "andon": "Andon",
}
for key, value in expected_terms.items():
    if canonical.get(key) != value:
        raise SystemExit(f"canonical terminology drifted for {key}: {canonical.get(key)!r}")

replacements = terminology.get("user_facing_replacements") or {}
for source, replacement in {
    "home": "Plant overview",
    "household": "site",
    "area": "line or cell",
    "Home Assistant CLI": "Factory Assistant CLI",
    "HA CLI": "Factory Assistant CLI",
}.items():
    if replacements.get(source) != replacement:
        raise SystemExit(f"missing terminology replacement {source!r} -> {replacement!r}")

forbidden = terminology.get("forbidden_user_facing_patterns") or []
for pattern in ("Home Assistant CLI", "HA CLI", "Home dashboard", "home-centric setup"):
    if pattern not in forbidden:
        raise SystemExit(f"forbidden user-facing pattern missing: {pattern}")

allowed = terminology.get("allowed_home_assistant_contexts") or []
for context in ("canonical upstream attribution", "internal upstream-compatible identifiers", "license and NOTICE provenance"):
    if context not in allowed:
        raise SystemExit(f"allowed Home Assistant context missing: {context}")
PY

for phrase in \
    'terminology contract' \
    'Plant overview' \
    'line or cell' \
    'Factory Assistant CLI' \
    'Factory Assistant is based on Home Assistant.'; do
    grep -q "$phrase" "$readme" "$onboarding_readme" "$network_readme" \
        "$ui_doc" "$defaults_doc" "$arch_doc" "$branding_doc" "$release_doc" \
        "$repo_readme" \
        || fail "docs are missing terminology handoff text: $phrase"
done

grep -q 'Factory Assistant CLI' "$motd" \
    || fail "MOTD must use the Factory Assistant CLI product name"

if grep -Eq 'terminology polish|Terminology pass .* P3|Industrial terminology .* remain' \
    "$ui_doc" "$arch_doc" "$release_doc" "$repo_readme"; then
    fail "status docs still list terminology cleanup as unresolved"
fi

echo "ok  terminology contract keeps product names and plant-floor labels aligned"
