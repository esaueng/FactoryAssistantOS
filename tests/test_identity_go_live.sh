#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-identity-go-live.sh"
identity="$ROOT/branding/identity.env"
readiness="$ROOT/scripts/verify-release-readiness.sh"
release_doc="$ROOT/RELEASE.md"
version_doc="$ROOT/version-service/README.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "identity go-live verifier script is missing or not executable"

"$script" --identity "$identity" > "$tmp/ok.out"
grep -q 'identity go-live verification passed' "$tmp/ok.out" \
    || fail "identity verifier success output is missing"
grep -q 'ghcr.io/esaueng' "$tmp/ok.out" \
    || fail "identity verifier success output does not include the registry"
grep -q 'https://esaueng.github.io/FactoryAssistantOS/stable.json' "$tmp/ok.out" \
    || fail "identity verifier success output does not include the channel URL"

bad_identity="$tmp/bad-identity.env"
cat > "$bad_identity" <<'EOF'
FAOS_NAME="Factory Assistant OS"
FAOS_ID="faos"
FAOS_HOSTNAME="factory-assistant"
FAOS_ISSUE="Factory Assistant OS - industrial monitoring appliance. Factory Assistant is based on Home Assistant."
FAOS_CONTAINER_REGISTRY="ghcr.io/REPLACE-ORG"
FAOS_VERSION_CHANNEL_URL="https://version.factory-assistant.example/stable.json"
FAOS_OTA_URL_TEMPLATE="https://updates.factory-assistant.example/{version}/faos_generic-x86-64.raucb"
EOF

if "$script" --identity "$bad_identity" 2> "$tmp/bad.err"; then
    fail "identity verifier allowed placeholder go-live values"
fi
grep -q 'identity go-live values still contain placeholders' "$tmp/bad.err" \
    || fail "placeholder rejection did not explain go-live identity drift"

missing_board="$tmp/missing-board.env"
cp "$identity" "$missing_board"
python3 - "$missing_board" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    "faos_{board}-{version}.raucb",
    "faos_generic-x86-64-{version}.raucb",
)
path.write_text(text, encoding="utf-8")
PY

if "$script" --identity "$missing_board" 2> "$tmp/missing-board.err"; then
    fail "identity verifier allowed OTA template without board placeholder"
fi
grep -q 'FAOS_OTA_URL_TEMPLATE must contain {version} and {board}' "$tmp/missing-board.err" \
    || fail "bad OTA template rejection did not explain placeholder requirements"

grep -q 'scripts/verify-identity-go-live.sh' "$readiness" \
    || fail "release readiness preflight does not run identity go-live verification"
grep -q 'identity go-live: verified' "$readiness" \
    || fail "release readiness success output does not report identity verification"
grep -q 'scripts/verify-identity-go-live.sh' "$release_doc" \
    || fail "release runbook does not document identity go-live verification"
grep -q 'scripts/verify-identity-go-live.sh' "$version_doc" \
    || fail "version-service docs do not document identity go-live verification"
if grep -Fq 'Resolve the ' "$release_doc" \
    && grep -Fq 'go-live placeholders' "$release_doc"; then
    fail "release runbook still lists settled identity go-live values as unresolved placeholders"
fi

echo "ok  identity go-live verifier rejects placeholder registry, channel, and OTA values"
