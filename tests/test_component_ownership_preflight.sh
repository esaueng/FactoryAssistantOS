#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-component-ownership.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
workflow="$ROOT/.github/workflows/build-os-image.yml"
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
    for arg in "$@"; do
        case "$arg" in
          /repos/esaueng/supervisor/contents/supervisor/const.py*)
            if [ "$mode" = "bad_supervisor_patch" ]; then
                printf '%s\n' 'URL_HASSIO_VERSION = "https://version.home-assistant.io/{channel}.json"'
            else
                printf '%s\n' 'URL_HASSIO_VERSION = "https://esaueng.github.io/FactoryAssistantOS/{channel}.json"'
            fi
            exit 0
            ;;
        esac
    done

    package=""
    for arg in "$@"; do
        case "$arg" in
          /orgs/esaueng/packages/container/*)
            package="${arg##*/}"
            ;;
        esac
    done
    [ -n "$package" ] || {
        printf 'unexpected gh api args: %s\n' "$*" >&2
        exit 9
    }
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
grep -q 'supervisor channel patch: verified' "$tmp/ok.out" \
    || fail "component ownership preflight does not report Supervisor channel patch verification"

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

if FAKE_GH_MODE=bad_supervisor_patch FAOS_GH_BIN="$tmp/gh" "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/bad-supervisor.err"; then
    fail "component ownership preflight allowed an unpatched Supervisor fork"
fi
grep -q 'Supervisor fork must patch URL_HASSIO_VERSION' "$tmp/bad-supervisor.err" \
    || fail "bad Supervisor fork rejection did not identify the required channel patch"

grep -q 'scripts/verify-component-ownership.sh' "$release_doc" \
    || fail "release runbook does not document component ownership preflight"
grep -q 'scripts/verify-component-ownership.sh' "$build_doc" \
    || fail "OS build docs do not document component ownership preflight"
grep -q 'component ownership/channel work is verified' "$arch_doc" \
    || fail "architecture phase status does not mark P2 component ownership/channel work as verified"
grep -q 'trusted OTA remains the P2 blocker' "$arch_doc" \
    || fail "architecture phase status does not identify trusted OTA as the P2 blocker"
if grep -q 'partial: registry/channel/release wiring' "$arch_doc"; then
    fail "architecture phase status still undersells verified P2 ownership/channel work"
fi
grep -q 'scripts/verify-component-ownership.sh' "$workflow" \
    || fail "build workflow does not verify component ownership before trusted tag releases"
grep -q 'scripts/verify-supervisor-channel-patch.sh' "$script" \
    || fail "component ownership preflight does not call the Supervisor channel patch verifier"
grep -q 'GH_COMPONENT_READ_TOKEN' "$workflow" \
    || fail "build workflow does not provide a GitHub token for component ownership verification"
grep -q 'packages: read' "$workflow" \
    || fail "build workflow permissions do not allow GHCR package visibility checks"

echo "ok  component ownership preflight validates esaueng repos, channel images, and public GHCR packages"
