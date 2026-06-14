#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readme="$ROOT/README.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
release_doc="$ROOT/RELEASE.md"
readme_text="$(tr '\n' ' ' < "$readme" | sed 's/[[:space:]][[:space:]]*/ /g')"
release_text="$(tr '\n' ' ' < "$release_doc" | sed 's/[[:space:]][[:space:]]*/ /g')"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$readme" ] || fail "README.md is missing"
[ -f "$arch_doc" ] || fail "architecture doc is missing"
[ -f "$release_doc" ] || fail "release runbook is missing"

grep -q 'P1 | Verified x86-64 image build' "$arch_doc" \
    || fail "architecture doc no longer records the P1 buildable/bootable milestone"
grep -q 'complete for generic x86-64 17.3 release' "$arch_doc" \
    || fail "architecture doc no longer records P1 as complete"
grep -q 'trusted OTA remains the P2 blocker' "$arch_doc" \
    || fail "architecture doc no longer names trusted OTA as the P2 blocker"
grep -q 'Trusted RAUC signing input wiring | ✅' "$release_doc" \
    || fail "release runbook no longer records verified trusted RAUC signing wiring"

if grep -qi 'Pre-alpha scaffold' "$readme"; then
    fail "README still describes the project as a pre-alpha scaffold"
fi
if grep -qi 'has not yet been CI-verified end to end' "$readme"; then
    fail "README still says the build pipeline has not been CI-verified end to end"
fi

grep -q 'P0 foundations and P1 buildable/bootable image work are complete' "$readme" \
    || fail "README status does not summarize completed P0/P1 work"
grep -q 'P2 is nearly complete' "$readme" \
    || fail "README status does not summarize P2 state"
case "$readme_text" in
    *"trusted OTA remains the P2 blocker"*) ;;
    *) fail "README status does not identify trusted OTA as the remaining P2 blocker";;
esac
grep -q 'P3 industrial product experience is partial' "$readme" \
    || fail "README status does not summarize partial P3 state"
grep -q 'frontend fork has the visible product rebrand' "$readme" \
    || fail "README status does not record completed visible frontend rebrand work"
grep -q "native read-only \`fa-machine-card\`" "$readme" \
    || fail "README status does not record the implemented native machine card"
grep -q "native read-only \`fa-andon-view\`" "$readme" \
    || fail "README status does not record the implemented native andon view"
grep -q "native read-only \`factory-wallboard-kiosk\`" "$readme" \
    || fail "README status does not record the implemented native wallboard kiosk"
case "$readme_text" in
    *"native industrial onboarding wizard"*) ;;
    *) fail "README status does not name the remaining native onboarding work";;
esac
grep -q 'frontend fork has visible rebrand/About/local-first onboarding bridge' "$arch_doc" \
    || fail "architecture status does not distinguish completed frontend bridge work"
grep -q "native read-only \`fa-machine-card\`" "$arch_doc" \
    || fail "architecture status does not record the implemented native machine card"
grep -q "native read-only \`fa-andon-view\`" "$arch_doc" \
    || fail "architecture status does not record the implemented native andon view"
grep -q "native read-only \`factory-wallboard-kiosk\`" "$arch_doc" \
    || fail "architecture status does not record the implemented native wallboard kiosk"
if grep -q 'frontend branding/onboarding' "$release_doc"; then
    fail "release runbook still says broad frontend branding/onboarding is unresolved"
fi
case "$release_text" in
    *"native navigation components and industrial onboarding wizard integration"*) ;;
    *) fail "release runbook does not name the remaining native frontend P3 work";;
esac
if grep -q 'native navigation/andon/kiosk components' "$release_doc"; then
    fail "release runbook still lists native andon as remaining P3 work"
fi
if grep -q 'native navigation/kiosk components' "$release_doc"; then
    fail "release runbook still lists native kiosk as remaining P3 work"
fi

echo "ok  README roadmap status matches current architecture and release evidence"
