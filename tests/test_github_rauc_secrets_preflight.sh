#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-github-rauc-secrets.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "GitHub RAUC secret preflight script is missing or not executable"

cat > "$tmp/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${FAKE_GH_MODE:-ok}" in
  ok)
    printf '%s\n' \
      FAOS_RAUC_KEYRING_PEM \
      FAOS_RAUC_CERT_PEM \
      FAOS_RAUC_KEY_PEM \
      OTHER_SECRET
    ;;
  missing)
    printf '%s\n' \
      FAOS_RAUC_KEYRING_PEM \
      FAOS_RAUC_KEY_PEM
    ;;
  badargs)
    printf 'unexpected args: %s\n' "$*" >&2
    exit 9
    ;;
esac
EOF
chmod +x "$tmp/gh"

FAOS_GH_BIN="$tmp/gh" "$script" --repo esaueng/FactoryAssistantOS > "$tmp/ok.out"
grep -q 'GitHub RAUC release secrets are configured' "$tmp/ok.out" \
    || fail "secret preflight success output is missing"
grep -q 'esaueng/FactoryAssistantOS' "$tmp/ok.out" \
    || fail "secret preflight success output does not include the repository"

if FAKE_GH_MODE=missing FAOS_GH_BIN="$tmp/gh" \
    "$script" --repo esaueng/FactoryAssistantOS 2> "$tmp/missing.err"; then
    fail "secret preflight allowed a missing RAUC secret"
fi
grep -q 'missing required GitHub secret: FAOS_RAUC_CERT_PEM' "$tmp/missing.err" \
    || fail "missing-secret output did not identify the absent secret"

grep -q 'gh secret list --repo esaueng/FactoryAssistantOS' "$tmp/ok.out" \
    && fail "secret preflight must not print raw gh commands that imply secret values"

grep -q 'scripts/verify-github-rauc-secrets.sh' "$release_doc" \
    || fail "release runbook does not document GitHub RAUC secret preflight"
grep -q 'scripts/verify-github-rauc-secrets.sh' "$build_doc" \
    || fail "OS build docs do not document GitHub RAUC secret preflight"

echo "ok  GitHub RAUC secret preflight checks required release secrets"
