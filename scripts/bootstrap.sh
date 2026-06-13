#!/usr/bin/env bash
# Fetch the pinned upstream Home Assistant OS source tree into upstream/.
# Idempotent: re-running verifies the checkout matches the pin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../upstream.env
source "$ROOT/upstream.env"

CHECKOUT="$ROOT/upstream/operating-system"
mkdir -p "$ROOT/upstream"

if [ ! -d "$CHECKOUT/.git" ]; then
    echo ">>> Cloning $UPSTREAM_OS_REPO @ $UPSTREAM_OS_REF"
    git clone --branch "$UPSTREAM_OS_REF" --depth 1 "$UPSTREAM_OS_REPO" "$CHECKOUT"
else
    current="$(git -C "$CHECKOUT" describe --tags --always)"
    echo ">>> Existing checkout at $current (pin: $UPSTREAM_OS_REF)"
    if [ "$current" != "$UPSTREAM_OS_REF" ]; then
        echo ">>> Pin changed; fetching $UPSTREAM_OS_REF"
        git -C "$CHECKOUT" fetch --depth 1 origin "refs/tags/$UPSTREAM_OS_REF:refs/tags/$UPSTREAM_OS_REF"
        git -C "$CHECKOUT" checkout "$UPSTREAM_OS_REF"
    fi
fi

echo ">>> Initializing submodules (Buildroot — large download)"
git -C "$CHECKOUT" submodule update --init

echo ">>> Upstream tree ready at upstream/operating-system"
echo ">>> Next: scripts/apply-overlay.sh"
