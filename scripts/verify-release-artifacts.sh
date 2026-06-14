#!/usr/bin/env bash
# Verify Factory Assistant OS release assets before upload/publication.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
release_dir="$ROOT/release"
board="generic-x86-64"
trusted=0

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-artifacts.sh [--release-dir release] [--board generic-x86-64] [--trusted]

Checks the release directory for the flash image, SHA256SUMS, license bundle,
and, for trusted releases, a RAUC bundle, RAUC trust manifest, and trusted
release notes. It also rejects accidental publication of signing material.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --release-dir) release_dir="$2"; shift 2;;
        --board)       board="$2"; shift 2;;
        --trusted)     trusted=1; shift;;
        -h|--help)     usage; exit 0;;
        *)             die "unknown argument: $1";;
    esac
done

[ -d "$release_dir" ] || die "release directory not found: $release_dir"
release_dir="$(cd "$release_dir" && pwd -P)"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

shopt -s nullglob
images=("$release_dir"/faos_"$board"-*.img.xz)
raucbs=("$release_dir"/faos_"$board"-*.raucb)
legal=("$release_dir"/faos_"$board"-legal-info.tar.gz)
secrets=("$release_dir"/*.key "$release_dir"/*.pem "$release_dir"/*.crt "$release_dir"/*.csr)
shopt -u nullglob

[ "${#images[@]}" -gt 0 ] || die "release requires a faos_${board}-*.img.xz image"
[ -f "$release_dir/SHA256SUMS" ] || die "release requires SHA256SUMS"
[ "${#legal[@]}" -gt 0 ] || die "release requires faos_${board}-legal-info.tar.gz"

if [ "${#secrets[@]}" -gt 0 ]; then
    die "release directory contains signing material: ${secrets[*]}"
fi

if [ "$trusted" -eq 1 ]; then
    [ "${#raucbs[@]}" -gt 0 ] || die "trusted release requires a RAUC bundle"
    [ -f "$release_dir/RELEASE_NOTES.md" ] || die "trusted release requires RELEASE_NOTES.md"
    [ -f "$release_dir/RAUC_TRUST.json" ] || die "trusted release requires RAUC_TRUST.json"
    grep -q 'RAUC bundles are signed with the configured Factory Assistant OTA signing key' "$release_dir/RELEASE_NOTES.md" \
        || die "trusted release notes must state Factory Assistant RAUC signing"
    grep -q 'not a safety device' "$release_dir/RELEASE_NOTES.md" \
        || die "trusted release notes must include the safety disclaimer"
    if grep -Eq 'self-signed|flash-only|NOT trusted|WARNING: Manual development build' "$release_dir/RELEASE_NOTES.md"; then
        die "trusted release notes contain development/untrusted wording"
    fi
fi

python3 - "$release_dir" "$trusted" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
trusted = sys.argv[2] == "1"
sums = root / "SHA256SUMS"
seen = set()

for lineno, line in enumerate(sums.read_text(encoding="utf-8").splitlines(), 1):
    if not line.strip():
        continue
    parts = line.split()
    if len(parts) != 2:
        raise SystemExit(f"malformed SHA256SUMS line {lineno}")
    expected, name = parts
    if "/" in name or name.startswith("."):
        raise SystemExit(f"unsafe checksum path: {name}")
    path = root / name
    if not path.is_file():
        raise SystemExit(f"checksum entry is missing file: {name}")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual.lower() != expected.lower():
        raise SystemExit(f"checksum mismatch: {name}")
    seen.add(name)

required_patterns = (
    (lambda n: n.endswith(".img.xz"), "image"),
    (lambda n: n == "SHA256SUMS", "SHA256SUMS"),
    (lambda n: n.endswith("-legal-info.tar.gz"), "legal-info bundle"),
)
for predicate, label in required_patterns:
    if label == "SHA256SUMS":
        continue
    if not any(predicate(name) for name in seen):
        raise SystemExit(f"SHA256SUMS does not list the {label}")

if trusted and not any(name.endswith(".raucb") for name in seen):
    raise SystemExit("SHA256SUMS does not list the RAUC bundle")
if trusted:
    if "RAUC_TRUST.json" not in seen:
        raise SystemExit("SHA256SUMS does not list RAUC_TRUST.json")
    manifest = json.loads((root / "RAUC_TRUST.json").read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise SystemExit("RAUC_TRUST.json schema_version must be 1")
    if manifest.get("private_key_material") is not False:
        raise SystemExit("RAUC_TRUST.json must state that it contains no private key material")
    if manifest.get("verified_by_keyring") is not True:
        raise SystemExit("RAUC_TRUST.json must state the signing certificate verified against the keyring")
    keyring = manifest.get("keyring") or {}
    signing = manifest.get("signing_certificate") or {}
    for label, cert in (("keyring", keyring), ("signing_certificate", signing)):
        for field in ("subject", "sha256_fingerprint", "not_before", "not_after"):
            if not cert.get(field):
                raise SystemExit(f"RAUC_TRUST.json {label} missing {field}")
    for field in ("issuer", "serial"):
        if not signing.get(field):
            raise SystemExit(f"RAUC_TRUST.json signing_certificate missing {field}")
PY

cat <<EOF
release artifact verification passed
  release dir: $release_dir
  board: $board
  images: ${#images[@]}
  rauc bundles: ${#raucbs[@]}
  legal-info bundles: ${#legal[@]}
EOF
