#!/usr/bin/env bash
# Verify the published update channel matches the local release channel.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
local_channel="$ROOT/version-service/stable.json"
url=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-published-channel.sh [--local version-service/stable.json] [--url https://.../stable.json]

Fetches the published channel document, compares it with the local channel
file, and verifies it points only at Factory Assistant-owned image and OTA
locations. The --url default comes from branding/identity.env.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --local) local_channel="$2"; shift 2;;
        --url)   url="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) die "unknown argument: $1";;
    esac
done

[ -f "$local_channel" ] || die "local channel not found: $local_channel"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

# shellcheck source=../branding/identity.env
source "$ROOT/branding/identity.env"
url="${url:-$FAOS_VERSION_CHANNEL_URL}"

python3 - "$local_channel" "$url" "$FAOS_CONTAINER_REGISTRY" "$FAOS_OTA_URL_TEMPLATE" <<'PY'
import json
import sys
import urllib.request

local_path, url, expected_registry, expected_ota = sys.argv[1:5]

def die(message):
    raise SystemExit(message)

with open(local_path, "r", encoding="utf-8") as fh:
    local = json.load(fh)

try:
    with urllib.request.urlopen(url, timeout=20) as response:
        raw = response.read()
except Exception as exc:
    die(f"failed to fetch published channel: {exc}")

try:
    published = json.loads(raw.decode("utf-8"))
except Exception as exc:
    die(f"published channel is not valid JSON: {exc}")

if published != local:
    die("published channel differs from local channel")

if published.get("channel") != "stable":
    die("published channel must be stable")

hassos = published.get("hassos") or {}
ota = hassos.get("ota")
if ota != expected_ota:
    die("published channel OTA URL template does not match branding/identity.env")
if "{version}" not in ota or "{board}" not in ota or not ota.startswith("https://"):
    die("published channel OTA URL template must contain {version}, {board}, and use https")
if "generic-x86-64" not in hassos:
    die("published channel is missing generic-x86-64")

images = published.get("images") or {}
for name, image in sorted(images.items()):
    if not image.startswith(expected_registry + "/"):
        die(f"channel image is not under {expected_registry}: {name}={image}")
    if "ghcr.io/home-assistant/" in image:
        die(f"channel image points at upstream registry: {name}={image}")
    if "REPLACE-" in image or ".example" in image or "example." in image:
        die(f"channel image contains placeholder text: {name}={image}")
PY

cat <<EOF
published channel verification passed
  local: $local_channel
  url: $url
  registry: $FAOS_CONTAINER_REGISTRY
  OTA template: $FAOS_OTA_URL_TEMPLATE
EOF
