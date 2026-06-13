#!/usr/bin/env bash
# Apply the Factory Assistant rebrand + configuration overlay onto the
# upstream checkout produced by scripts/bootstrap.sh.
#
# Three mechanisms, all idempotent:
#   1. File overlay  — buildroot-external/** is rsync'd over the upstream
#      buildroot-external/ at identical relative paths.
#   2. Targeted edits — product identity values are rewritten in upstream's
#      buildroot-external/meta (variable names stay upstream-compatible).
#   3. Defconfig fragment — configs/factory-assistant.config is appended to
#      the upstream generic_x86_64 defconfig (in kconfig defconfigs the last
#      assignment of a symbol wins).
#
# See docs/OS_BUILD.md for the full rebrand checklist, including Phase 2
# items this script intentionally does NOT cover yet.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../branding/identity.env
source "$ROOT/branding/identity.env"

UP="$ROOT/upstream/operating-system"
EXT="$UP/buildroot-external"
MARKER="# >>> factory-assistant overlay (managed by scripts/apply-overlay.sh) >>>"

if [ ! -d "$EXT" ]; then
    echo "ERROR: $EXT not found — run scripts/bootstrap.sh first." >&2
    exit 1
fi

echo ">>> 1/3 Overlaying buildroot-external/ files"
rsync -a --exclude 'README.md' "$ROOT/buildroot-external/" "$EXT/"

echo ">>> 2/3 Rebranding product identity in buildroot-external/meta"
meta="$EXT/meta"
if [ ! -f "$meta" ]; then
    echo "ERROR: $meta not found. Upstream layout changed at this tag;" >&2
    echo "       update this script and the checklist in docs/OS_BUILD.md." >&2
    exit 1
fi
sed -i "s|^HASSOS_NAME=.*|HASSOS_NAME=\"${FAOS_NAME}\"|" "$meta"
sed -i "s|^HASSOS_ID=.*|HASSOS_ID=${FAOS_ID}|" "$meta"
if ! grep -q "^HASSOS_ID=${FAOS_ID}$" "$meta"; then
    echo "ERROR: identity rebrand did not take effect in $meta —" >&2
    echo "       inspect the file and adjust the sed patterns for this tag." >&2
    exit 1
fi

echo ">>> 3/3 Appending defconfig fragment to generic_x86_64_defconfig"
frag="$ROOT/buildroot-external/configs/factory-assistant.config"
cfg="$EXT/configs/generic_x86_64_defconfig"
if [ ! -f "$cfg" ]; then
    echo "ERROR: $cfg not found at this upstream tag." >&2
    exit 1
fi
if ! grep -qF "$MARKER" "$cfg"; then
    { printf '\n%s\n' "$MARKER"; cat "$frag"; } >> "$cfg"
else
    echo "    fragment already applied — skipping"
fi

cat <<'EOF'
>>> Overlay applied.

    NOT covered yet (Phase 2 — see docs/OS_BUILD.md §Rebrand checklist):
      - Supervisor/Core container registry + update channel URL (Supervisor fork)
      - RAUC signing keys/keyring (REQUIRED before shipping OTA updates)
      - Landing page + containerized CLI-plugin banner (landingpage/plugin-cli forks)
      - os-release ID compatibility check against the unmodified Supervisor

    Host console banner IS rebranded here (rootfs-overlay etc/issue + etc/motd).
    The generic-x86-64 GRUB config carries no product branding (functional A/B
    slot menu) — nothing to rebrand there; see docs/OS_BUILD.md §4.

    Next: scripts/build.sh  (or: cd upstream/operating-system && scripts/enter.sh make generic_x86_64)
EOF
