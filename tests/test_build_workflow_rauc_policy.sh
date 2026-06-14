#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/build-os-image.yml"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
build_doc_text="$(tr '\n' ' ' < "$build_doc")"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

grep -q "Trusted tag releases require all three RAUC secrets" "$workflow" \
    || fail "build workflow does not fail tag releases without trusted RAUC secrets"
grep -q "refs/tags/" "$workflow" \
    || fail "build workflow RAUC policy does not inspect tag builds"
grep -q "workflow_dispatch builds may still produce flash-only development artifacts" "$workflow" \
    || fail "build workflow does not scope self-signed fallback to manual development builds"
grep -q "scripts/verify-release-readiness.sh" "$workflow" \
    || fail "build workflow does not run the release-readiness preflight before trusted signing"
grep -q -- "--channel version-service/stable.json" "$workflow" \
    || fail "build workflow release preflight does not validate the stable channel"
grep -q "scripts/verify-shipped-branding.sh" "$workflow" \
    || fail "build workflow does not verify shipped branding before release builds"
grep -q "scripts/verify-safety-boundary.sh" "$workflow" \
    || fail "build workflow does not verify the shipped safety boundary before release builds"
grep -q "Scrub RAUC signing inputs" "$workflow" \
    || fail "build workflow does not scrub RAUC signing inputs after build"
grep -q 'upstream/operating-system/key.pem' "$workflow" \
    || fail "build workflow does not remove upstream RAUC signing key"
grep -q 'upstream/operating-system/cert.pem' "$workflow" \
    || fail "build workflow does not remove upstream RAUC signing certificate"
grep -q 'RUNNER_TEMP}/faos-rauc' "$workflow" \
    || fail "build workflow does not remove temporary RAUC secret files"

grep -q "scripts/generate-rauc-signing-material.sh" "$release_doc" \
    || fail "release runbook does not point operators at the RAUC key generator"
grep -q "Tag builds require all three RAUC secrets" "$release_doc" \
    || fail "release runbook does not document trusted tag-release enforcement"
grep -q "workflow_dispatch" "$release_doc" \
    || fail "release runbook does not distinguish manual flash-only builds"

grep -q "scripts/generate-rauc-signing-material.sh" "$build_doc" \
    || fail "OS build docs do not document the RAUC key generator"
case "$build_doc_text" in
    *"tag release workflow refuses to publish without all three RAUC secrets"*) ;;
    *) fail "OS build docs do not document the tag-release RAUC gate";;
esac
case "$build_doc_text" in
    *"scrubs the temporary RAUC PEM files and upstream build-tree signing inputs"*) ;;
    *) fail "OS build docs do not document CI RAUC signing input cleanup";;
esac

echo "ok  build workflow enforces trusted RAUC signing for tag releases"
