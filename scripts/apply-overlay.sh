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

# Keep the os-release CPE *product* field upstream-compatible (haos) so the
# UNMODIFIED Supervisor still treats the OS as supported. The Supervisor's
# os/manager.py allowlists CPE products {hassos, haos}; a product of "faos"
# makes it mark the OS unsupported and disable OS update/management
# (docs/OS_BUILD.md §4 "os-release ID verification"). We still brand
# NAME/PRETTY_NAME ("Factory Assistant OS") and keep ID=${FAOS_ID} (which drives
# the faos_* image filename); only the CPE product — an internal OS-family
# identifier (AGENTS.md invariant 4) — stays haos. post-build.sh builds CPE_NAME
# from ${HASSOS_ID}; rewrite just that one field to the literal haos.
pb="$EXT/scripts/post-build.sh"
if [ ! -f "$pb" ]; then
    echo "ERROR: $pb not found at this upstream tag —" >&2
    echo "       the os-release writer moved; update this script and docs/OS_BUILD.md §4." >&2
    exit 1
fi
# shellcheck disable=SC2016  # ${HASSOS_ID} is matched LITERALLY in post-build.sh (a shell var there), not expanded here.
sed -i 's|cpe:2\.3:o:home-assistant:${HASSOS_ID}:|cpe:2.3:o:home-assistant:haos:|' "$pb"
if ! grep -q 'cpe:2.3:o:home-assistant:haos:' "$pb"; then
    echo "ERROR: CPE product override did not take in $pb — the CPE_NAME line moved;" >&2
    echo "       inspect post-build.sh and adjust the sed for this upstream tag." >&2
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

    Covered by the rootfs overlay (usr/sbin/hassos-supervisor):
      - Supervisor/Core container registry (SUPERVISOR_IMAGE)
      - Update channel URL (fallback stable.json)
    Covered by the meta/post-build edits above:
      - OS "supported" acceptance — CPE product kept = haos (post-build.sh), so
        the unmodified Supervisor does not flag the OS unsupported.

    NOT covered yet (Phase 2 — see docs/OS_BUILD.md §Rebrand checklist):
      - RAUC signing keys/keyring (REQUIRED before shipping OTA updates)
      - Landing page + containerized CLI-plugin banner (landingpage/plugin-cli forks)
      - Running Supervisor's update-channel URL (hardcoded in supervisor/const.py;
        needs the Supervisor fork — see docs/forks/supervisor/). Until that lands,
        the running Supervisor reads versions from version.home-assistant.io, NOT
        the esaueng channel, so the images map below is only honored after the
        Supervisor const patch is in the shipped Supervisor image.

    Host console banner IS rebranded here (rootfs-overlay etc/issue + etc/motd).
    The generic-x86-64 GRUB config carries no product branding (functional A/B
    slot menu) — nothing to rebrand there; see docs/OS_BUILD.md §4.

    Next: scripts/build.sh  (or: cd upstream/operating-system && scripts/enter.sh make generic_x86_64)
EOF
