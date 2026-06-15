#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-supervisor-channel-patch.sh"
component_script="$ROOT/scripts/verify-component-ownership.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
supervisor_doc="$ROOT/docs/forks/supervisor/README.md"
version_doc="$ROOT/version-service/README.md"
pages_workflow="$ROOT/.github/workflows/pages.yml"
apparmor_profile="$ROOT/version-service/apparmor_stable.txt"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

write_supervisor_const() {
    local dir="$1"
    local version_url="$2"

    mkdir -p "$dir/supervisor"
    cat > "$dir/supervisor/const.py" <<EOF
URL_HASSIO_APPARMOR = "https://version.home-assistant.io/apparmor_{channel}.txt"
URL_HASSIO_VERSION = "$version_url"
EOF
}

[ -x "$script" ] || fail "Supervisor channel patch verifier is missing or not executable"

patched="$tmp/patched-supervisor"
write_supervisor_const "$patched" "https://esaueng.github.io/FactoryAssistantOS/{channel}.json"
"$script" \
    --channel "$ROOT/version-service/stable.json" \
    --source "$patched" > "$tmp/ok.out"
grep -q 'supervisor channel patch verification passed' "$tmp/ok.out" \
    || fail "Supervisor channel patch verifier success output is missing"
grep -q 'URL_HASSIO_VERSION: https://esaueng.github.io/FactoryAssistantOS/{channel}.json' "$tmp/ok.out" \
    || fail "Supervisor channel patch verifier does not report the patched URL"

upstream="$tmp/upstream-supervisor"
write_supervisor_const "$upstream" "https://version.home-assistant.io/{channel}.json"
if "$script" --channel "$ROOT/version-service/stable.json" --source "$upstream" \
    2> "$tmp/upstream.err"; then
    fail "Supervisor channel patch verifier allowed the upstream version URL"
fi
grep -q 'Supervisor fork must patch URL_HASSIO_VERSION' "$tmp/upstream.err" \
    || fail "upstream URL rejection did not explain the required Supervisor patch"

grep -q 'scripts/verify-supervisor-channel-patch.sh' "$component_script" \
    || fail "component ownership preflight does not verify the Supervisor channel patch"
grep -q 'scripts/verify-supervisor-channel-patch.sh' "$release_doc" \
    || fail "release runbook does not document Supervisor channel patch verification"
grep -q 'scripts/verify-supervisor-channel-patch.sh' "$build_doc" \
    || fail "OS build docs do not document Supervisor channel patch verification"
grep -q 'scripts/verify-supervisor-channel-patch.sh' "$supervisor_doc" \
    || fail "Supervisor fork docs do not document the verifier"
grep -q 'repo="esaueng/factory-assistant-supervisor"' "$script" \
    || fail "Supervisor channel patch verifier default repo does not match the live fork"
grep -q -- '--repo esaueng/factory-assistant-supervisor' "$supervisor_doc" \
    || fail "Supervisor fork docs do not point the verifier at the live fork"
if grep -q 'esaueng/supervisor' "$script" "$supervisor_doc"; then
    fail "Supervisor channel patch verifier or docs still point at stale esaueng/supervisor repo"
fi
[ -f "$apparmor_profile" ] || fail "Factory Assistant AppArmor profile endpoint source is missing"
grep -q 'apparmor_stable.txt' "$pages_workflow" \
    || fail "Pages workflow does not publish the Supervisor AppArmor profile"
grep -q 'apparmor_{stable,beta,dev}.txt' "$supervisor_doc" \
    || fail "Supervisor fork docs do not document the all-channel AppArmor profile endpoints"
for channel in stable beta dev; do
    [ -f "$ROOT/version-service/$channel.json" ] \
        || fail "version service is missing $channel.json for Supervisor channel $channel"
    grep -q "\"channel\": \"$channel\"" "$ROOT/version-service/$channel.json" \
        || fail "$channel.json does not declare channel $channel"
    if ! python3 - "$ROOT/version-service/$channel.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
hassos = data.get("hassos", {})
homeassistant = data.get("homeassistant", {})
if hassos.get("generic-x86-64") != hassos.get("qemux86-64"):
    raise SystemExit(1)
if homeassistant.get("qemux86-64") != homeassistant.get("default"):
    raise SystemExit(1)
PY
    then
        fail "$channel.json does not include both OS board and Supervisor machine aliases"
    fi
    [ -f "$ROOT/version-service/apparmor_$channel.txt" ] \
        || fail "version service is missing apparmor_$channel.txt for Supervisor channel $channel"
    grep -q "$channel.json" "$version_doc" \
        || fail "version-service docs do not document $channel.json"
    grep -q "apparmor_$channel.txt" "$version_doc" \
        || fail "version-service docs do not document apparmor_$channel.txt"
done
generated_channel="$tmp/generated-dev.json"
"$ROOT/version-service/generate-channel.sh" \
    --channel dev --supervisor 2026.6.0 --core 2026.6.0 \
    --os-board generic-x86-64 --os-version 17.3 \
    --out "$generated_channel" >/dev/null
if ! python3 - "$generated_channel" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
hassos = data.get("hassos", {})
homeassistant = data.get("homeassistant", {})
if hassos.get("generic-x86-64") != hassos.get("qemux86-64"):
    raise SystemExit(1)
if homeassistant.get("qemux86-64") != homeassistant.get("default"):
    raise SystemExit(1)
PY
then
    fail "channel generator does not include the qemux86-64 Supervisor machine alias"
fi
grep -q 'for channel in stable beta dev' "$pages_workflow" \
    || fail "Pages workflow does not validate and publish all Supervisor channels"
grep -q 'running Supervisor update-channel URL preflight' "$release_doc" \
    || fail "release runbook does not list the running Supervisor channel preflight as applied"
grep -q 'running fork: P2 verified by Supervisor channel patch preflight' "$build_doc" \
    || fail "OS build checklist does not mark the running Supervisor channel as preflight-verified"
if grep -Eq 'Still Phase 2/P3: running[[:space:]]+Supervisor update-channel URL|running: \*\*P2 \(Supervisor fork\)\*\*|core\+plugins: needs Supervisor fork' "$release_doc" "$build_doc"; then
    fail "status docs still list the verified Supervisor channel patch as unresolved"
fi

echo "ok  Supervisor fork channel patch verifier enforces the Factory Assistant version URL"
