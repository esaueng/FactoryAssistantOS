#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-published-channel.sh"
release_doc="$ROOT/RELEASE.md"
version_doc="$ROOT/version-service/README.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "published channel verifier script is missing or not executable"

local_channel="$tmp/local-stable.json"
published_channel="$tmp/published-stable.json"
cp "$ROOT/version-service/stable.json" "$local_channel"
cp "$local_channel" "$published_channel"

"$script" \
    --local "$local_channel" \
    --url "file://$published_channel" > "$tmp/ok.out"
grep -q 'published channel verification passed' "$tmp/ok.out" \
    || fail "published-channel verifier success output is missing"

python3 - "$local_channel" "$tmp/mismatch.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
data["hassos"]["generic-x86-64"] = "0.0-test"
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

if "$script" --local "$local_channel" --url "file://$tmp/mismatch.json" \
    2> "$tmp/mismatch.err"; then
    fail "published-channel verifier allowed drift from the local stable.json"
fi
grep -q 'published channel differs from local channel' "$tmp/mismatch.err" \
    || fail "published-channel drift rejection did not explain local/remote mismatch"

python3 - "$local_channel" "$tmp/upstream.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
data["images"]["core"] = "ghcr.io/home-assistant/{machine}-homeassistant"
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

if "$script" --local "$tmp/upstream.json" --url "file://$tmp/upstream.json" \
    2> "$tmp/upstream.err"; then
    fail "published-channel verifier allowed an upstream image reference"
fi
grep -q 'channel image is not under ghcr.io/esaueng' "$tmp/upstream.err" \
    || fail "upstream image rejection did not identify registry ownership"

grep -q 'scripts/verify-published-channel.sh' "$release_doc" \
    || fail "release runbook does not document published channel verification"
grep -q 'scripts/verify-published-channel.sh' "$version_doc" \
    || fail "version-service docs do not document published channel verification"

echo "ok  published channel verifier detects drift and upstream artifacts"
