#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-ota-channel-artifact.sh"
workflow="$ROOT/.github/workflows/build-os-image.yml"
release_doc="$ROOT/RELEASE.md"
version_doc="$ROOT/version-service/README.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

write_checksum() {
    local dir="$1"
    local file="$2"

    python3 - "$dir" "$file" <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
name = sys.argv[2]
print(f"{hashlib.sha256((root / name).read_bytes()).hexdigest()}  {name}")
PY
}

[ -x "$script" ] || fail "OTA channel artifact verifier script is missing or not executable"

release="$tmp/release"
mkdir -p "$release"
bundle="faos_generic-x86-64-17.3.raucb"
printf 'trusted bundle\n' > "$release/$bundle"
write_checksum "$release" "$bundle" > "$release/SHA256SUMS"

"$script" \
    --channel "$ROOT/version-service/stable.json" \
    --board generic-x86-64 \
    --release-dir "$release" > "$tmp/ok.out"
grep -q 'OTA channel artifact verification passed' "$tmp/ok.out" \
    || fail "OTA channel artifact verifier success output is missing"
grep -q 'https://github.com/esaueng/FactoryAssistantOS/releases/download/17.3/faos_generic-x86-64-17.3.raucb' "$tmp/ok.out" \
    || fail "OTA verifier output does not show the resolved OTA URL"

missing="$tmp/missing-release"
mkdir -p "$missing"
touch "$missing/SHA256SUMS"
if "$script" --channel "$ROOT/version-service/stable.json" \
    --board generic-x86-64 --release-dir "$missing" 2> "$tmp/missing.err"; then
    fail "OTA verifier allowed a release dir without the channel RAUC bundle"
fi
grep -q 'release directory missing channel OTA bundle' "$tmp/missing.err" \
    || fail "missing bundle rejection did not identify channel artifact mismatch"

unlisted="$tmp/unlisted-release"
mkdir -p "$unlisted"
printf 'trusted bundle\n' > "$unlisted/$bundle"
touch "$unlisted/SHA256SUMS"
if "$script" --channel "$ROOT/version-service/stable.json" \
    --board generic-x86-64 --release-dir "$unlisted" 2> "$tmp/unlisted.err"; then
    fail "OTA verifier allowed a channel RAUC bundle missing from SHA256SUMS"
fi
grep -q 'SHA256SUMS does not list channel OTA bundle' "$tmp/unlisted.err" \
    || fail "unlisted bundle rejection did not identify checksum coverage"

python3 - "$ROOT/version-service/stable.json" "$tmp/bad-template.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
data["hassos"]["ota"] = "https://github.com/esaueng/FactoryAssistantOS/releases/download/{version}/faos.raucb"
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

if "$script" --channel "$tmp/bad-template.json" \
    --board generic-x86-64 --release-dir "$release" 2> "$tmp/bad-template.err"; then
    fail "OTA verifier allowed an OTA template without the board placeholder"
fi
grep -q 'OTA URL template must contain {version} and {board}' "$tmp/bad-template.err" \
    || fail "bad OTA template rejection did not explain placeholder requirements"

grep -q 'scripts/verify-ota-channel-artifact.sh' "$release_doc" \
    || fail "release runbook does not document OTA channel artifact verification"
grep -q 'scripts/verify-ota-channel-artifact.sh' "$version_doc" \
    || fail "version-service docs do not document OTA channel artifact verification"
grep -q 'scripts/verify-ota-channel-artifact.sh' "$workflow" \
    || fail "build workflow does not verify the channel OTA artifact before publishing"

echo "ok  OTA channel artifact verifier ties channel URLs to release bundles"
