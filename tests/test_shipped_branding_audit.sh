#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-shipped-branding.sh"
issue="$ROOT/buildroot-external/rootfs-overlay/etc/issue"
motd="$ROOT/buildroot-external/rootfs-overlay/etc/motd"
identity="$ROOT/branding/identity.env"
defconfig="$ROOT/buildroot-external/configs/factory-assistant.config"
branding_doc="$ROOT/docs/BRANDING.md"
asset_doc="$ROOT/branding/assets/README.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

canonical="Factory Assistant is based on Home Assistant."

[ -x "$script" ] || fail "shipped branding verifier is missing or not executable"

"$script" > "$tmp/ok.out"
grep -q 'shipped branding verification passed' "$tmp/ok.out" \
    || fail "shipped branding verifier success output is missing"

bad="$tmp/bad-issue"
cat > "$bad" <<'EOF'
Factory Assistant OS - industrial monitoring appliance
Based on Home Assistant. Monitoring only: not a safety device.
EOF
if "$script" "$bad" 2> "$tmp/bad.err"; then
    fail "shipped branding verifier allowed noncanonical upstream attribution"
fi
grep -q 'canonical attribution' "$tmp/bad.err" \
    || fail "noncanonical attribution rejection did not explain the branding rule"

for file in "$issue" "$motd" "$identity" "$defconfig"; do
    grep -q "$canonical" "$file" \
        || fail "$file does not use canonical upstream attribution"
done

grep -q 'Factory Assistant CLI' "$motd" \
    || fail "MOTD CLI note does not use the Factory Assistant CLI product name"

bad_motd="$tmp/bad-motd"
cat > "$bad_motd" <<'EOF'
Welcome to Factory Assistant OS.

Factory Assistant is based on Home Assistant.
Monitoring appliance - not a safety device.

Use `ha` to access the CLI.
EOF
if "$script" "$bad_motd" 2> "$tmp/bad-motd.err"; then
    fail "shipped branding verifier allowed a generic MOTD CLI note"
fi
grep -q 'Factory Assistant CLI' "$tmp/bad-motd.err" \
    || fail "generic MOTD CLI note rejection did not explain the product-name rule"

grep -q 'scripts/verify-shipped-branding.sh' "$branding_doc" \
    || fail "branding docs do not document the shipped branding verifier"
grep -q 'Master mark landed' "$asset_doc" \
    || fail "brand asset README does not document the landed master mark"
grep -q 'logo.svg' "$asset_doc" \
    || fail "brand asset README does not document logo.svg provenance"
grep -q 'icon.svg' "$asset_doc" \
    || fail "brand asset README does not document icon.svg provenance"
if grep -q 'specs only' "$asset_doc" \
    || grep -q 'no artwork is created' "$asset_doc" \
    || grep -q 'holds only this README' "$asset_doc"; then
    fail "brand asset README still describes the landed SVG assets as absent"
fi

echo "ok  shipped user-facing branding is broadly audited"
