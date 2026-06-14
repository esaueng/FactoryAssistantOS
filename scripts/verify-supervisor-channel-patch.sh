#!/usr/bin/env bash
# Verify the Supervisor fork reads the Factory Assistant version channel.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
channel="$ROOT/version-service/stable.json"
source_dir=""
repo="esaueng/factory-assistant-supervisor"
ref=""
gh_bin="${FAOS_GH_BIN:-gh}"

usage() {
    cat <<'EOF'
Usage: scripts/verify-supervisor-channel-patch.sh [--channel version-service/stable.json] [--source supervisor-checkout | --repo esaueng/factory-assistant-supervisor] [--ref version]

Checks supervisor/const.py for the required Factory Assistant patch:
  URL_HASSIO_VERSION = "https://esaueng.github.io/FactoryAssistantOS/{channel}.json"

With --source, reads a local Supervisor checkout. Without --source, fetches the
file from GitHub using gh at the Supervisor version pinned by the channel.
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

canonical_dir() {
    local path="$1"

    [ -n "$path" ] || die "empty directory path"
    [ -d "$path" ] || die "directory not found: $path"
    (cd "$path" && pwd -P)
}

while [ $# -gt 0 ]; do
    case "$1" in
        --channel) channel="$2"; shift 2;;
        --source)  source_dir="$2"; shift 2;;
        --repo)    repo="$2"; shift 2;;
        --ref)     ref="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *)         die "unknown argument: $1";;
    esac
done

command -v python3 >/dev/null 2>&1 || die "python3 is required"
channel="$(canonical_file "$channel")"

# shellcheck source=../branding/identity.env
source "$ROOT/branding/identity.env"
case "$FAOS_VERSION_CHANNEL_URL" in
    */stable.json)
        expected_url="${FAOS_VERSION_CHANNEL_URL%/stable.json}/{channel}.json"
        ;;
    *)
        die "FAOS_VERSION_CHANNEL_URL must end with /stable.json to derive Supervisor URL_HASSIO_VERSION"
        ;;
esac

if [ -z "$ref" ]; then
    ref="$(python3 - "$channel" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
version = data.get("supervisor")
if not version:
    raise SystemExit("channel is missing supervisor version")
print(version)
PY
)"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
const_file="$tmp/const.py"
source_label="$repo@$ref"

if [ -n "$source_dir" ]; then
    source_dir="$(canonical_dir "$source_dir")"
    local_const="$source_dir/supervisor/const.py"
    [ -f "$local_const" ] || die "Supervisor const.py not found: $local_const"
    cp "$local_const" "$const_file"
    source_label="$source_dir"
else
    command -v "$gh_bin" >/dev/null 2>&1 || die "GitHub CLI is required: $gh_bin"
    if ! "$gh_bin" api \
        -H "Accept: application/vnd.github.raw" \
        "/repos/$repo/contents/supervisor/const.py?ref=$ref" > "$const_file"; then
        die "failed to fetch supervisor/const.py from $repo at $ref"
    fi
fi

actual_url="$(python3 - "$const_file" <<'PY'
import ast
import sys

for line in open(sys.argv[1], "r", encoding="utf-8"):
    stripped = line.strip()
    if not stripped.startswith("URL_HASSIO_VERSION"):
        continue
    name, sep, value = stripped.partition("=")
    if sep and name.strip() == "URL_HASSIO_VERSION":
        try:
            print(ast.literal_eval(value.strip()))
        except Exception as exc:
            raise SystemExit(f"could not parse URL_HASSIO_VERSION: {exc}")
        break
else:
    raise SystemExit("URL_HASSIO_VERSION not found")
PY
)" || die "$actual_url"

if [ "$actual_url" != "$expected_url" ]; then
    die "Supervisor fork must patch URL_HASSIO_VERSION to $expected_url (found $actual_url)"
fi

cat <<EOF
supervisor channel patch verification passed
  channel: $channel
  supervisor ref: $ref
  source: $source_label
  URL_HASSIO_VERSION: $actual_url
EOF
