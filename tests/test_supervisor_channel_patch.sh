#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-supervisor-channel-patch.sh"
component_script="$ROOT/scripts/verify-component-ownership.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
supervisor_doc="$ROOT/docs/forks/supervisor/README.md"
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

echo "ok  Supervisor fork channel patch verifier enforces the Factory Assistant version URL"
