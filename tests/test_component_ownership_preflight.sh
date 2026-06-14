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
    case "$repo" in
      esaueng/FactoryAssistantOS|\
      esaueng/factory-assistant-core|\
      esaueng/factory-assistant-supervisor|\
      esaueng/factory-assistant-frontend|\
      esaueng/factory-assistant-addons|\
      esaueng/factory-assistant-cli)
        ;;
      *)
        printf 'unexpected repo: %s\n' "$repo" >&2
        exit 9
        ;;
    esac
    if [ "$mode" = "missing_repo" ] && [ "$repo" = "esaueng/factory-assistant-frontend" ]; then
        echo "not found" >&2
        exit 1
    fi
    printf '%s\n' "$repo"
    exit 0
fi

if [ "$1" = "api" ]; then
    for arg in "$@"; do
        case "$arg" in
          /repos/esaueng/factory-assistant-supervisor/contents/supervisor/const.py*)
            if [ "$mode" = "bad_supervisor_patch" ]; then
                printf '%s\n' 'URL_HASSIO_VERSION = "https://version.home-assistant.io/{channel}.json"'
            else
                printf '%s\n' 'URL_HASSIO_VERSION = "https://esaueng.github.io/FactoryAssistantOS/{channel}.json"'
            fi
            exit 0
            ;;
          /repos/esaueng/factory-assistant-addons/contents/repository.yaml*)
            printf '%s\n' 'name: Factory Assistant Add-ons'
            printf '%s\n' 'url: "https://github.com/esaueng/factory-assistant-addons"'
            exit 0
            ;;
          /repos/esaueng/factory-assistant-addons/contents/opcua-mqtt-bridge/config.yaml*)
            cat <<'YAML'
name: OPC UA → MQTT Bridge (read-only)
slug: opcua_mqtt_bridge
startup: services
boot: manual
arch:
  - amd64
host_network: false
hassio_api: false
homeassistant_api: false
options:
  opcua:
    write_nodes_allowed: false
schema:
  opcua:
    write_nodes_allowed: bool
YAML
            exit 0
            ;;
          /repos/esaueng/factory-assistant-addons/contents/plc-gateway-helper/config.yaml*)
            if [ "$mode" = "bad_addon_manifest" ]; then
                cat <<'YAML'
name: PLC Gateway Helper (read-only)
slug: plc_gateway_helper
startup: services
boot: auto
arch:
  - amd64
host_network: false
hassio_api: false
homeassistant_api: false
options:
  modbus:
    allowed_function_codes:
      - 3
      - 4
    write_functions_allowed: false
    safety_controller_allowed: false
schema:
  modbus:
    allowed_function_codes:
      - int(3,4)
    write_functions_allowed: bool
    safety_controller_allowed: bool
YAML
            else
                cat <<'YAML'
name: PLC Gateway Helper (read-only)
slug: plc_gateway_helper
startup: services
boot: manual
arch:
  - amd64
host_network: false
hassio_api: false
homeassistant_api: false
options:
  modbus:
    allowed_function_codes:
      - 3
      - 4
    write_functions_allowed: false
    safety_controller_allowed: false
schema:
  modbus:
    allowed_function_codes:
      - int(3,4)
    write_functions_allowed: bool
    safety_controller_allowed: bool
YAML
            fi
            exit 0
            ;;
          /repos/esaueng/factory-assistant-addons/contents/historian-storage/config.yaml*)
            cat <<'YAML'
name: Historian Storage (telemetry → TSDB)
slug: historian_storage
startup: services
boot: manual
arch:
  - amd64
host_network: false
hassio_api: false
homeassistant_api: false
options:
  cloud_export_enabled: false
schema:
  cloud_export_enabled: bool
YAML
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

cat > "$tmp/registry-check" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

owner="$1"
package="$2"
tag="$3"

printf '%s/%s:%s\n' "$owner" "$package" "$tag" >> "${FAKE_REGISTRY_LOG:?}"

if [ "${FAKE_REGISTRY_MODE:-ok}" = "missing_image" ] \
    && [ "$package" = "amd64-hassio-cli" ]; then
    exit 1
fi
EOF
chmod +x "$tmp/registry-check"

FAKE_REGISTRY_LOG="$tmp/registry.log" \
FAOS_GH_BIN="$tmp/gh" \
FAOS_REGISTRY_CHECK_BIN="$tmp/registry-check" \
"$script" \
    --channel "$ROOT/version-service/stable.json" \
    --owner esaueng > "$tmp/ok.out"
grep -q 'component ownership preflight passed' "$tmp/ok.out" \
    || fail "component ownership preflight success output is missing"
grep -q 'repos: 6' "$tmp/ok.out" \
    || fail "component ownership preflight did not check every required repo"
grep -q 'image tags: 7' "$tmp/ok.out" \
    || fail "component ownership preflight did not check every channel image tag"
grep -q 'supervisor channel patch: verified' "$tmp/ok.out" \
    || fail "component ownership preflight does not report Supervisor channel patch verification"
grep -q 'industrial add-on manifests: verified' "$tmp/ok.out" \
    || fail "component ownership preflight does not report add-on manifest verification"
grep -q 'esaueng/generic-x86-64-homeassistant:2026.6.0' "$tmp/registry.log" \
    || fail "component ownership preflight did not verify the Core image tag"
grep -q 'esaueng/amd64-hassio-cli:2026.6.0' "$tmp/registry.log" \
    || fail "component ownership preflight did not verify the CLI image tag"

if FAKE_REGISTRY_LOG="$tmp/missing-repo-registry.log" \
    FAKE_GH_MODE=missing_repo \
    FAOS_GH_BIN="$tmp/gh" \
    FAOS_REGISTRY_CHECK_BIN="$tmp/registry-check" \
    "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/missing-repo.err"; then
    fail "component ownership preflight allowed a missing component fork"
fi
grep -q 'required component repository is not accessible: esaueng/factory-assistant-frontend' "$tmp/missing-repo.err" \
    || fail "missing repo rejection did not identify the inaccessible fork"

if FAKE_REGISTRY_LOG="$tmp/missing-image-registry.log" \
    FAKE_REGISTRY_MODE=missing_image \
    FAOS_GH_BIN="$tmp/gh" \
    FAOS_REGISTRY_CHECK_BIN="$tmp/registry-check" \
    "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/missing-image.err"; then
    fail "component ownership preflight allowed a missing GHCR image tag"
fi
grep -q 'channel image tag is not anonymously pullable: ghcr.io/esaueng/amd64-hassio-cli:2026.6.0' "$tmp/missing-image.err" \
    || fail "missing image-tag rejection did not identify the absent tag"

python3 - "$ROOT/version-service/stable.json" "$tmp/bad-channel.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
data["images"]["core"] = "ghcr.io/home-assistant/{machine}-homeassistant"
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

if FAKE_REGISTRY_LOG="$tmp/bad-channel-registry.log" \
    FAOS_GH_BIN="$tmp/gh" \
    FAOS_REGISTRY_CHECK_BIN="$tmp/registry-check" \
    "$script" \
    --channel "$tmp/bad-channel.json" --owner esaueng \
    2> "$tmp/bad-channel.err"; then
    fail "component ownership preflight allowed an upstream channel image"
fi
grep -q 'channel image is not under ghcr.io/esaueng' "$tmp/bad-channel.err" \
    || fail "bad channel rejection did not identify registry ownership drift"

if FAKE_REGISTRY_LOG="$tmp/bad-supervisor-registry.log" \
    FAKE_GH_MODE=bad_supervisor_patch \
    FAOS_GH_BIN="$tmp/gh" \
    FAOS_REGISTRY_CHECK_BIN="$tmp/registry-check" \
    "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/bad-supervisor.err"; then
    fail "component ownership preflight allowed an unpatched Supervisor fork"
fi
grep -q 'Supervisor fork must patch URL_HASSIO_VERSION' "$tmp/bad-supervisor.err" \
    || fail "bad Supervisor fork rejection did not identify the required channel patch"

if FAKE_REGISTRY_LOG="$tmp/bad-addon-registry.log" \
    FAKE_GH_MODE=bad_addon_manifest \
    FAOS_GH_BIN="$tmp/gh" \
    FAOS_REGISTRY_CHECK_BIN="$tmp/registry-check" \
    "$script" \
    --channel "$ROOT/version-service/stable.json" --owner esaueng \
    2> "$tmp/bad-addon.err"; then
    fail "component ownership preflight allowed a published add-on manifest drift"
fi
grep -q 'published add-on plc_gateway_helper must be boot: manual' "$tmp/bad-addon.err" \
    || fail "bad add-on manifest rejection did not identify manual-boot drift"

grep -q 'scripts/verify-component-ownership.sh' "$release_doc" \
    || fail "release runbook does not document component ownership preflight"
grep -q 'industrial add-on manifests' "$release_doc" \
    || fail "release runbook does not document published industrial add-on manifest verification"
grep -q 'scripts/verify-component-ownership.sh' "$build_doc" \
    || fail "OS build docs do not document component ownership preflight"
grep -q 'industrial add-on manifests' "$build_doc" \
    || fail "OS build docs do not document published industrial add-on manifest verification"
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
grep -q 'verify_industrial_addons' "$script" \
    || fail "component ownership preflight does not validate the published industrial add-ons"
grep -q 'GH_COMPONENT_READ_TOKEN' "$workflow" \
    || fail "build workflow does not provide a GitHub token for component ownership verification"
grep -q 'packages: read' "$workflow" \
    || fail "build workflow permissions do not allow GHCR package reads if future metadata checks need them"

echo "ok  component ownership preflight validates esaueng repos and channel image tags"
