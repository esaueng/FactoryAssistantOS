#!/usr/bin/env bash
# Verify P2 component repositories and public GHCR packages are esaueng-owned.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
channel="$ROOT/version-service/stable.json"
owner="esaueng"
gh_bin="${FAOS_GH_BIN:-gh}"

usage() {
    cat <<'EOF'
Usage: scripts/verify-component-ownership.sh [--channel version-service/stable.json] [--owner esaueng]

Checks that required component forks are accessible under the owner, that the
Factory Assistant channel points only at ghcr.io/<owner> images, and that every
channel GHCR package resolves as public for anonymous device pulls.

Requires an authenticated GitHub CLI with repository and package read access.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

canonical_file() {
    local path="$1"
    local dir

    [ -n "$path" ] || die "empty file path"
    [ -f "$path" ] || die "file not found: $path"
    dir="$(cd "$(dirname "$path")" && pwd -P)"
    printf '%s/%s\n' "$dir" "$(basename "$path")"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --channel) channel="$2"; shift 2;;
        --owner)   owner="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *)         die "unknown argument: $1";;
    esac
done

command -v "$gh_bin" >/dev/null 2>&1 || die "GitHub CLI is required: $gh_bin"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

channel="$(canonical_file "$channel")"
registry="ghcr.io/$owner"

required_repos=(
    FactoryAssistantOS
    core
    supervisor
    frontend
    addons
    addons-industrial
    os-agent
    builder
    landingpage
)

for repo in "${required_repos[@]}"; do
    if ! "$gh_bin" repo view "$owner/$repo" --json nameWithOwner --jq .nameWithOwner >/dev/null; then
        die "required component repository is not accessible: $owner/$repo"
    fi
done

package_output="$(python3 - "$channel" "$registry" <<'PY'
import json
import sys

channel_path, registry = sys.argv[1:3]
with open(channel_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

images = data.get("images") or {}
required = ["core", "supervisor", "cli", "dns", "audio", "observer", "multicast"]

for name in required:
    image = images.get(name)
    if not image:
        raise SystemExit(f"channel image is missing: {name}")
    if not image.startswith(registry + "/"):
        raise SystemExit(f"channel image is not under {registry}: {name}={image}")
    if "ghcr.io/home-assistant/" in image:
        raise SystemExit(f"channel image points at upstream registry: {name}={image}")
    package = image[len(registry) + 1:].split(":", 1)[0]
    package = package.replace("{arch}", "amd64").replace("{machine}", "generic-x86-64")
    if "{" in package or "}" in package:
        raise SystemExit(f"channel image contains an unresolved package placeholder: {name}={image}")
    print(package)
PY
)"
mapfile -t packages <<< "$package_output"

for package in "${packages[@]}"; do
    if ! visibility="$("$gh_bin" api "/orgs/$owner/packages/container/$package" --jq .visibility)"; then
        die "required GHCR package is not accessible: $registry/$package"
    fi
    if [ "$visibility" != "public" ]; then
        die "required GHCR package must be public for anonymous device pulls: $registry/$package"
    fi
done

FAOS_GH_BIN="$gh_bin" "$ROOT/scripts/verify-supervisor-channel-patch.sh" \
    --channel "$channel" \
    --repo "$owner/supervisor" >/dev/null

cat <<EOF
component ownership preflight passed
  owner: $owner
  channel: $channel
  registry: $registry
  repos: ${#required_repos[@]}
  packages: ${#packages[@]}
  supervisor channel patch: verified
EOF
