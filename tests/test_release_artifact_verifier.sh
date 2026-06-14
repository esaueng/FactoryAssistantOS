#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-release-artifacts.sh"
workflow="$ROOT/.github/workflows/build-os-image.yml"
release_doc="$ROOT/RELEASE.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

write_checksums() {
    local dir="$1"
    shift

    python3 - "$dir" "$@" <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
for name in sys.argv[2:]:
    digest = hashlib.sha256((root / name).read_bytes()).hexdigest()
    print(f"{digest}  {name}")
PY
}

make_release_dir() {
    local dir="$1"

    mkdir -p "$dir"
    printf 'flash image\n' > "$dir/faos_generic-x86-64-17.3.img.xz"
    printf 'trusted rauc bundle\n' > "$dir/faos_generic-x86-64-17.3.raucb"
    printf 'legal info archive\n' > "$dir/faos_generic-x86-64-legal-info.tar.gz"
    cat > "$dir/RAUC_TRUST.json" <<'EOF'
{
  "schema_version": 1,
  "private_key_material": false,
  "verified_by_keyring": true,
  "keyring": {
    "subject": "CN=Factory Assistant OS Test OTA Root CA,O=Factory Assistant",
    "sha256_fingerprint": "AA:BB",
    "not_before": "Jan  1 00:00:00 2026 GMT",
    "not_after": "Jan  1 00:00:00 2031 GMT"
  },
  "signing_certificate": {
    "subject": "CN=Factory Assistant OS Test OTA Signing,O=Factory Assistant",
    "issuer": "CN=Factory Assistant OS Test OTA Root CA,O=Factory Assistant",
    "serial": "01",
    "sha256_fingerprint": "CC:DD",
    "not_before": "Jan  1 00:00:00 2026 GMT",
    "not_after": "Jan  1 00:00:00 2031 GMT"
  }
}
EOF
    cat > "$dir/RELEASE_NOTES.md" <<'EOF'
Factory Assistant is based on Home Assistant. Monitoring appliance —
**not a safety device**.

RAUC bundles are signed with the configured Factory Assistant OTA signing key.
Devices built from this image trust only the configured Factory Assistant OTA CA.
EOF
    write_checksums "$dir" \
        faos_generic-x86-64-17.3.img.xz \
        faos_generic-x86-64-17.3.raucb \
        faos_generic-x86-64-legal-info.tar.gz \
        RAUC_TRUST.json > "$dir/SHA256SUMS"
}

[ -x "$script" ] || fail "release artifact verifier script is missing or not executable"

release="$tmp/release"
make_release_dir "$release"
"$script" --release-dir "$release" --board generic-x86-64 --trusted > "$tmp/ok.out"
grep -q 'release artifact verification passed' "$tmp/ok.out" \
    || fail "artifact verifier success output is missing"

missing_rauc="$tmp/missing-rauc"
make_release_dir "$missing_rauc"
rm "$missing_rauc"/faos_generic-x86-64-17.3.raucb
if "$script" --release-dir "$missing_rauc" --board generic-x86-64 --trusted \
    2> "$tmp/missing-rauc.err"; then
    fail "artifact verifier allowed trusted release without a RAUC bundle"
fi
grep -q 'trusted release requires a RAUC bundle' "$tmp/missing-rauc.err" \
    || fail "missing RAUC bundle rejection did not explain trusted release requirement"

leaked_secret="$tmp/leaked-secret"
make_release_dir "$leaked_secret"
printf 'private key\n' > "$leaked_secret/faos-rauc-signing.key"
if "$script" --release-dir "$leaked_secret" --board generic-x86-64 --trusted \
    2> "$tmp/leaked-secret.err"; then
    fail "artifact verifier allowed private signing material in release assets"
fi
grep -q 'release directory contains signing material' "$tmp/leaked-secret.err" \
    || fail "secret-leak rejection did not explain signing material risk"

bad_notes="$tmp/bad-notes"
make_release_dir "$bad_notes"
cat > "$bad_notes/RELEASE_NOTES.md" <<'EOF'
WARNING: Manual development build with a public self-signed RAUC certificate.
EOF
if "$script" --release-dir "$bad_notes" --board generic-x86-64 --trusted \
    2> "$tmp/bad-notes.err"; then
    fail "artifact verifier allowed untrusted release notes for trusted release"
fi
grep -q 'trusted release notes must state Factory Assistant RAUC signing' "$tmp/bad-notes.err" \
    || fail "bad release-notes rejection did not explain trusted signing requirement"

missing_trust="$tmp/missing-trust"
make_release_dir "$missing_trust"
rm "$missing_trust/RAUC_TRUST.json"
write_checksums "$missing_trust" \
    faos_generic-x86-64-17.3.img.xz \
    faos_generic-x86-64-17.3.raucb \
    faos_generic-x86-64-legal-info.tar.gz > "$missing_trust/SHA256SUMS"
if "$script" --release-dir "$missing_trust" --board generic-x86-64 --trusted \
    2> "$tmp/missing-trust.err"; then
    fail "artifact verifier allowed a trusted release without RAUC_TRUST.json"
fi
grep -q 'trusted release requires RAUC_TRUST.json' "$tmp/missing-trust.err" \
    || fail "missing trust manifest rejection did not explain trusted OTA provenance"

bad_checksum="$tmp/bad-checksum"
make_release_dir "$bad_checksum"
printf 'tamper\n' >> "$bad_checksum/faos_generic-x86-64-17.3.img.xz"
if "$script" --release-dir "$bad_checksum" --board generic-x86-64 --trusted \
    2> "$tmp/bad-checksum.err"; then
    fail "artifact verifier allowed checksum drift"
fi
grep -q 'checksum mismatch' "$tmp/bad-checksum.err" \
    || fail "checksum rejection did not identify checksum mismatch"

missing_rauc_checksum="$tmp/missing-rauc-checksum"
make_release_dir "$missing_rauc_checksum"
write_checksums "$missing_rauc_checksum" \
    faos_generic-x86-64-17.3.img.xz \
    faos_generic-x86-64-legal-info.tar.gz > "$missing_rauc_checksum/SHA256SUMS"
if "$script" --release-dir "$missing_rauc_checksum" --board generic-x86-64 --trusted \
    2> "$tmp/missing-rauc-checksum.err"; then
    fail "artifact verifier allowed a trusted RAUC bundle missing from SHA256SUMS"
fi
grep -q 'SHA256SUMS does not list the RAUC bundle' "$tmp/missing-rauc-checksum.err" \
    || fail "missing RAUC checksum rejection did not explain checksum coverage"

grep -q 'scripts/verify-release-artifacts.sh' "$workflow" \
    || fail "build workflow does not verify release artifacts before publishing"
grep -q 'scripts/write-rauc-trust-manifest.sh' "$workflow" \
    || fail "build workflow does not write the RAUC trust manifest"
grep -q 'release/RAUC_TRUST.json' "$workflow" \
    || fail "build workflow does not publish the RAUC trust manifest"
grep -q -- "--trusted" "$workflow" \
    || fail "build workflow artifact verification is not marked trusted"
grep -q 'scripts/verify-release-artifacts.sh' "$release_doc" \
    || fail "release runbook does not document artifact verification"
grep -q 'RAUC_TRUST.json' "$release_doc" \
    || fail "release runbook does not document the RAUC trust manifest"

echo "ok  release artifact verifier gates trusted release assets"
