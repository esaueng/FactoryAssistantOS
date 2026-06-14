#!/usr/bin/env bash
# Verify P2 component repositories and public channel image tags are esaueng-owned.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
channel="$ROOT/version-service/stable.json"
owner="esaueng"
gh_bin="${FAOS_GH_BIN:-gh}"
curl_bin="${FAOS_CURL_BIN:-curl}"
registry_check_bin="${FAOS_REGISTRY_CHECK_BIN:-}"

usage() {
    cat <<'EOF'
Usage: scripts/verify-component-ownership.sh [--channel version-service/stable.json] [--owner esaueng]

Checks that required component forks are accessible under the owner, that the
Factory Assistant channel points only at ghcr.io/<owner> images, and that every
exact channel image tag resolves for anonymous device pulls.

Requires an authenticated GitHub CLI with repository read access.
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
if [ -n "$registry_check_bin" ]; then
    command -v "$registry_check_bin" >/dev/null 2>&1 \
        || die "registry check helper is required: $registry_check_bin"
else
    command -v "$curl_bin" >/dev/null 2>&1 || die "curl is required: $curl_bin"
fi

channel="$(canonical_file "$channel")"
registry="ghcr.io/$owner"

required_repos=(
    FactoryAssistantOS
    factory-assistant-core
    factory-assistant-supervisor
    factory-assistant-frontend
    factory-assistant-addons
    factory-assistant-cli
)

for repo in "${required_repos[@]}"; do
    if ! "$gh_bin" repo view "$owner/$repo" --json nameWithOwner --jq .nameWithOwner >/dev/null; then
        die "required component repository is not accessible: $owner/$repo"
    fi
done

image_output="$(python3 - "$channel" "$registry" <<'PY'
import json
import sys

channel_path, registry = sys.argv[1:3]
with open(channel_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

images = data.get("images") or {}
required = ["core", "supervisor", "cli", "dns", "audio", "observer", "multicast"]
versions = {
    "core": (data.get("homeassistant") or {}).get("default"),
    "supervisor": data.get("supervisor"),
    "cli": data.get("cli"),
    "dns": data.get("dns"),
    "audio": data.get("audio"),
    "observer": data.get("observer"),
    "multicast": data.get("multicast"),
}

for name in required:
    image = images.get(name)
    if not image:
        raise SystemExit(f"channel image is missing: {name}")
    tag = versions.get(name)
    if not tag:
        raise SystemExit(f"channel version is missing for image: {name}")
    if not image.startswith(registry + "/"):
        raise SystemExit(f"channel image is not under {registry}: {name}={image}")
    if "ghcr.io/home-assistant/" in image:
        raise SystemExit(f"channel image points at upstream registry: {name}={image}")
    package = image[len(registry) + 1:].split(":", 1)[0]
    package = package.replace("{arch}", "amd64").replace("{machine}", "generic-x86-64")
    if "{" in package or "}" in package:
        raise SystemExit(f"channel image contains an unresolved package placeholder: {name}={image}")
    print(f"{name}\t{package}\t{tag}")
PY
)"
mapfile -t image_rows <<< "$image_output"

verify_registry_tag() {
    local package="$1"
    local tag="$2"
    local token
    local status

    if [ -n "$registry_check_bin" ]; then
        if ! "$registry_check_bin" "$owner" "$package" "$tag"; then
            die "channel image tag is not anonymously pullable: $registry/$package:$tag"
        fi
        return
    fi

    token="$("$curl_bin" -fsSL "https://ghcr.io/token?scope=repository:$owner/$package:pull" \
        | python3 -c 'import json, sys; print(json.load(sys.stdin).get("token", ""))')" \
        || die "failed to get anonymous GHCR pull token for: $registry/$package"
    [ -n "$token" ] || die "anonymous GHCR pull token was empty for: $registry/$package"

    status="$("$curl_bin" -sS -o /dev/null -w '%{http_code}' \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
        "https://ghcr.io/v2/$owner/$package/manifests/$tag" || true)"
    if [ "$status" != "200" ]; then
        die "channel image tag is not anonymously pullable: $registry/$package:$tag (HTTP $status)"
    fi
}

fetch_addon_file() {
    local path="$1"

    "$gh_bin" api \
        -H "Accept: application/vnd.github.raw" \
        "/repos/$owner/factory-assistant-addons/contents/$path" \
        || die "published add-on repository is missing required file: $path"
}

require_text() {
    local label="$1"
    local haystack="$2"
    local needle="$3"

    grep -Fq -- "$needle" <<< "$haystack" \
        || die "$label missing required text: $needle"
}

reject_text() {
    local label="$1"
    local haystack="$2"
    local needle="$3"

    if grep -Fq -- "$needle" <<< "$haystack"; then
        die "$label contains forbidden text: $needle"
    fi
}

verify_addon_manifest() {
    local addon_id="$1"
    local path="$2"
    local config

    config="$(fetch_addon_file "$path/config.yaml")"
    require_text "published add-on $addon_id" "$config" "slug: $addon_id"
    require_text "published add-on $addon_id" "$config" "startup: services"
    if ! grep -Eq '^boot:[[:space:]]*manual$' <<< "$config"; then
        die "published add-on $addon_id must be boot: manual"
    fi
    require_text "published add-on $addon_id" "$config" "host_network: false"
    require_text "published add-on $addon_id" "$config" "hassio_api: false"
    require_text "published add-on $addon_id" "$config" "homeassistant_api: false"
    require_text "published add-on $addon_id" "$config" "- amd64"
    reject_text "published add-on $addon_id" "$config" "privileged: true"

    case "$addon_id" in
        opcua_mqtt_bridge)
            require_text "published add-on $addon_id" "$config" "write_nodes_allowed: false"
            ;;
        plc_gateway_helper)
            require_text "published add-on $addon_id" "$config" "allowed_function_codes:"
            require_text "published add-on $addon_id" "$config" "- 3"
            require_text "published add-on $addon_id" "$config" "- 4"
            require_text "published add-on $addon_id" "$config" "write_functions_allowed: false"
            require_text "published add-on $addon_id" "$config" "safety_controller_allowed: false"
            ;;
        historian_storage)
            require_text "published add-on $addon_id" "$config" "cloud_export_enabled: false"
            ;;
        *)
            die "unknown industrial add-on id: $addon_id"
            ;;
    esac
}

verify_industrial_addons() {
    local repository

    repository="$(fetch_addon_file repository.yaml)"
    require_text "published add-on repository" "$repository" "name: Factory Assistant Add-ons"
    require_text "published add-on repository" "$repository" \
        'url: "https://github.com/esaueng/factory-assistant-addons"'

    verify_addon_manifest opcua_mqtt_bridge opcua-mqtt-bridge
    verify_addon_manifest plc_gateway_helper plc-gateway-helper
    verify_addon_manifest historian_storage historian-storage
}

for row in "${image_rows[@]}"; do
    IFS=$'\t' read -r _component package tag <<< "$row"
    verify_registry_tag "$package" "$tag"
done

verify_industrial_addons

FAOS_GH_BIN="$gh_bin" "$ROOT/scripts/verify-supervisor-channel-patch.sh" \
    --channel "$channel" \
    --repo "$owner/factory-assistant-supervisor" >/dev/null

cat <<EOF
component ownership preflight passed
  owner: $owner
  channel: $channel
  registry: $registry
  repos: ${#required_repos[@]}
  image tags: ${#image_rows[@]}
  industrial add-on manifests: verified
  supervisor channel patch: verified
EOF
