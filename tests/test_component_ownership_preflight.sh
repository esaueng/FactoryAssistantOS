#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-component-ownership.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "component ownership preflight script is missing or not executable"

cat > "$tmp/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mode="${FAKE_GH_MODE:-ok}"

if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
    repo="$3"
    if [ "$mode" = "missing_repo" ] && [ "$repo" = "esaueng/frontend" ]; then
        echo "not found" >&2
        exit 1
    fi
    printf '%s\n' "$repo"
    exit 0
fi

if [ "$1" = "api" ]; then
    package="${2##*/}"
    if [ "$mode" = "missing_package" ] && [ "$package" = "amd64-hassio-observer" ]; then
        echo "not found" >&2
        exit 1
    fi
    if [ "$mode" = "private_package" ] && [ "$package" = "amd64-hassio-cli" ]; then
        printf 'private\n'
        exit 0
    fi
    printf 'public\n'
    exit 0
fi

printf 'unexpected gh args: %s\n' "$*" >&2
exit 9
EOF
chmod +x "$tmp/gh"

FAOS_GH_BIN="$tmp/gh" "$script" \
    --channel "$ROOT/version-service/stable.json" \
    --owner esaueng > "$tmp/ok.out"
grep -q 'component ownership preflight passed' "$tmp/ok.out" \
    || fail "component ownership preflight success output is missing"
grep -q 'repos: 9' "$tmp/ok.out" \
    || fail "component ownership preflight did not check every required repo"
grep -q 'packages: 7' "$tmp/ok.out" \
    || fail "component ownership preflight did not check every channel package"

if FAKE_GH_MODE=missing_repo FAOS_GH_BIN="$tmp/gh" "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/missing-repo.err"; then
    fail "component ownership preflight allowed a missing component fork"
fi
grep -q 'required component repository is not accessible: esaueng/frontend' "$tmp/missing-repo.err" \
    || fail "missing repo rejection did not identify the inaccessible fork"

if FAKE_GH_MODE=missing_package FAOS_GH_BIN="$tmp/gh" "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/missing-package.err"; then
    fail "component ownership preflight allowed a missing GHCR package"
fi
grep -q 'required GHCR package is not accessible: ghcr.io/esaueng/amd64-hassio-observer' "$tmp/missing-package.err" \
    || fail "missing package rejection did not identify the absent package"

if FAKE_GH_MODE=private_package FAOS_GH_BIN="$tmp/gh" "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/private-package.err"; then
    fail "component ownership preflight allowed a private package"
fi
grep -q 'required GHCR package must be public for anonymous device pulls: ghcr.io/esaueng/amd64-hassio-cli' "$tmp/private-package.err" \
    || fail "private package rejection did not explain anonymous pull requirement"

python3 - "$ROOT/version-service/stable.json" "$tmp/bad-channel.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
data["images"]["core"] = "ghcr.io/home-assistant/{machine}-homeassistant"
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

if FAOS_GH_BIN="$tmp/gh" "$script" \
    --channel "$tmp/bad-channel.json" --owner esaueng \
    2> "$tmp/bad-channel.err"; then
    fail "component ownership preflight allowed an upstream channel image"
fi
grep -q 'channel image is not under ghcr.io/esaueng' "$tmp/bad-channel.err" \
    || fail "bad channel rejection did not identify registry ownership drift"

grep -q 'scripts/verify-component-ownership.sh' "$release_doc" \
    || fail "release runbook does not document component ownership preflight"
grep -q 'scripts/verify-component-ownership.sh' "$build_doc" \
    || fail "OS build docs do not document component ownership preflight"

echo "ok  component ownership preflight validates esaueng repos, channel images, and public GHCR packages"
