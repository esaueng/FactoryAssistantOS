#!/usr/bin/env bash
# Verify the channel's OTA URL resolves to the release bundle we are shipping.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
channel="$ROOT/version-service/stable.json"
board="generic-x86-64"
release_dir="$ROOT/release"

usage() {
    cat <<'EOF'
Usage: scripts/verify-ota-channel-artifact.sh [--channel version-service/stable.json] [--board generic-x86-64] [--release-dir release]

Resolves the channel hassos.ota template for the selected board/version and
checks that the release directory contains the exact RAUC bundle filename and
that SHA256SUMS covers it.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --channel) channel="$2"; shift 2;;
        --board) board="$2"; shift 2;;
        --release-dir) release_dir="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) die "unknown argument: $1";;
    esac
done

[ -f "$channel" ] || die "channel document not found: $channel"
[ -d "$release_dir" ] || die "release directory not found: $release_dir"
release_dir="$(cd "$release_dir" && pwd -P)"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

verification_output="$(python3 - "$channel" "$board" "$release_dir" <<'PY'
import hashlib
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

channel_path, board, release_dir = sys.argv[1:4]
release = Path(release_dir)

with open(channel_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

def die(message):
    raise SystemExit(message)

hassos = data.get("hassos") or {}
version = hassos.get(board)
if not version:
    die(f"channel is missing hassos version for board: {board}")

template = hassos.get("ota")
if not template:
    die("channel is missing hassos.ota template")
if "{version}" not in template or "{board}" not in template:
    die("OTA URL template must contain {version} and {board}")
if not template.startswith("https://"):
    die("OTA URL template must use https")

resolved = template.replace("{version}", version).replace("{board}", board)
bundle_name = Path(urlparse(resolved).path).name
expected_name = f"faos_{board}-{version}.raucb"
if bundle_name != expected_name:
    die(f"resolved OTA bundle filename drifted: expected {expected_name}, got {bundle_name}")

bundle_path = release / bundle_name
if not bundle_path.is_file():
    die(f"release directory missing channel OTA bundle: {bundle_name}")

sums = release / "SHA256SUMS"
if not sums.is_file():
    die("release directory is missing SHA256SUMS")

seen = False
actual = hashlib.sha256(bundle_path.read_bytes()).hexdigest()
for lineno, line in enumerate(sums.read_text(encoding="utf-8").splitlines(), 1):
    if not line.strip():
        continue
    parts = line.split()
    if len(parts) != 2:
        die(f"malformed SHA256SUMS line {lineno}")
    expected, name = parts
    if name == bundle_name:
        seen = True
        if expected.lower() != actual.lower():
            die(f"checksum mismatch for channel OTA bundle: {bundle_name}")
        break

if not seen:
    die(f"SHA256SUMS does not list channel OTA bundle: {bundle_name}")

print(resolved)
print(bundle_name)
PY
)"
resolved_url="$(printf '%s\n' "$verification_output" | sed -n '1p')"

cat <<EOF
OTA channel artifact verification passed
  channel: $channel
  board: $board
  release dir: $release_dir
  resolved OTA URL: $resolved_url
EOF
