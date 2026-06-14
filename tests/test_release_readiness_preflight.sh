#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-release-readiness.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "release readiness preflight script is missing or not executable"

openssl genrsa -out "$tmp/faos-ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "$tmp/faos-ca.key" -sha256 -days 30 \
    -out "$tmp/faos-ca.crt" \
    -subj "/O=Factory Assistant/CN=Factory Assistant OS Test OTA Root CA" >/dev/null 2>&1

openssl genrsa -out "$tmp/faos-ota.key" 2048 >/dev/null 2>&1
openssl req -new -key "$tmp/faos-ota.key" \
    -out "$tmp/faos-ota.csr" \
    -subj "/O=Factory Assistant/CN=Factory Assistant OS Test OTA Signing" >/dev/null 2>&1
openssl x509 -req -in "$tmp/faos-ota.csr" \
    -CA "$tmp/faos-ca.crt" -CAkey "$tmp/faos-ca.key" -CAcreateserial \
    -sha256 -days 30 -out "$tmp/faos-ota.crt" >/dev/null 2>&1

"$script" \
    --channel "$ROOT/version-service/stable.json" \
    --keyring "$tmp/faos-ca.crt" \
    --cert "$tmp/faos-ota.crt" \
    --key "$tmp/faos-ota.key" > "$tmp/ok.out"

grep -q 'release readiness preflight passed' "$tmp/ok.out" \
    || fail "preflight success output is missing"
grep -q 'shipped branding: verified' "$tmp/ok.out" \
    || fail "preflight success output does not report shipped branding verification"
grep -q 'safety boundary: verified' "$tmp/ok.out" \
    || fail "preflight success output does not report safety-boundary verification"
grep -q 'scripts/verify-shipped-branding.sh' "$script" \
    || fail "preflight does not run the shipped branding verifier"
grep -q 'scripts/verify-safety-boundary.sh' "$script" \
    || fail "preflight does not run the safety-boundary verifier"

if "$script" --channel "$ROOT/version-service/stable.json" \
    --keyring "$tmp/faos-ca.crt" --cert "$tmp/faos-ota.crt" \
    2> "$tmp/missing-key.err"; then
    fail "preflight allowed missing RAUC signing key"
fi
grep -q 'trusted release readiness requires --keyring, --cert, and --key' "$tmp/missing-key.err" \
    || fail "missing key error did not explain the trusted RAUC requirement"

repo_key="$ROOT/faos-test-release-readiness.key"
cp "$tmp/faos-ota.key" "$repo_key"
trap 'rm -rf "$tmp"; rm -f "$repo_key"' EXIT
if "$script" --channel "$ROOT/version-service/stable.json" \
    --keyring "$tmp/faos-ca.crt" --cert "$tmp/faos-ota.crt" --key "$repo_key" \
    2> "$tmp/repo-key.err"; then
    fail "preflight allowed RAUC signing material from inside the repository"
fi
grep -q 'must be supplied from outside this repository' "$tmp/repo-key.err" \
    || fail "repo-local signing material rejection did not explain the boundary"

python3 - "$ROOT/version-service/stable.json" "$tmp/bad-channel.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
data["images"]["supervisor"] = "ghcr.io/home-assistant/{arch}-hassio-supervisor"
data["hassos"]["ota"] = "https://example.invalid/faos.raucb"
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

if "$script" --channel "$tmp/bad-channel.json" \
    --keyring "$tmp/faos-ca.crt" --cert "$tmp/faos-ota.crt" --key "$tmp/faos-ota.key" \
    2> "$tmp/bad-channel.err"; then
    fail "preflight allowed an upstream/default channel"
fi
grep -Eq 'channel image is not under ghcr.io/esaueng|OTA URL template must match|OTA URL template must contain' "$tmp/bad-channel.err" \
    || fail "bad channel rejection did not identify image or OTA template risk"

grep -q 'scripts/verify-release-readiness.sh' "$release_doc" \
    || fail "release runbook does not document the release-readiness preflight"
grep -q 'verify-shipped-branding.sh' "$release_doc" \
    || fail "release runbook does not connect release readiness to shipped branding verification"
grep -q 'verify-safety-boundary.sh' "$release_doc" \
    || fail "release runbook does not connect release readiness to safety-boundary verification"
grep -q 'scripts/verify-release-readiness.sh' "$build_doc" \
    || fail "OS build docs do not document the release-readiness preflight"

echo "ok  release readiness preflight validates trusted OTA inputs, policy gates, and channel wiring"
