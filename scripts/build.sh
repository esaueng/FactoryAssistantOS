#!/usr/bin/env bash
# Build the Factory Assistant OS image for the given target (default:
# generic_x86_64) using the upstream containerized build environment.
#
# Requires: Linux x86-64 host, Docker, ~50 GB free disk. The first build
# compiles a full Buildroot system and takes multiple hours.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${TARGET:-generic_x86_64}"
UP="$ROOT/upstream/operating-system"

"$ROOT/scripts/bootstrap.sh"
"$ROOT/scripts/apply-overlay.sh"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is required (the upstream build runs in a container)." >&2
    exit 1
fi

echo ">>> Building target '$TARGET' via upstream build container"
echo ">>> (If this invocation fails at your pinned tag, follow the upstream"
echo ">>>  Documentation/development.md inside upstream/operating-system.)"
cd "$UP"
exec scripts/enter.sh make "$TARGET"
