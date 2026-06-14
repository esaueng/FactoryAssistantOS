#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/configure-github-rauc-secrets.sh"
release_doc="$ROOT/RELEASE.md"
build_doc="$ROOT/docs/OS_BUILD.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

openssl genrsa -out "$tmp/faos-ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "$tmp/faos-ca.key" -sha256 -days 30 \
    -out "$tmp/faos-ca.crt" \
    -subj "/O=Factory Assistant/CN=Factory Assistant OS Test OTA Root CA" >/dev/null 2>&1

openssl genrsa -out "$tmp/faos-ota.key" 2048 >/dev/null 2>&1
openssl req -new -key "$tmp/faos-ota.key" \
    -out "$tmp/faos-ota.csr" \
    -subj "/O=Factory Assistant/CN=Factory Assistant OS Test OTA Signing" >/dev/null 2>&1
openssl x509 -req -in "$tmp/faos-ota.csr" \
    -CA "$tmp/faos-ca.crt" -CAkey "$tmp/faos-ca.key" -CAcreateserial \
    -sha256 -days 30 -out "$tmp/faos-ota.crt" >/dev/null 2>&1

cat > "$tmp/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log="${FAKE_GH_LOG:?}"
repo=""
name=""

[ "$1" = "secret" ] && [ "$2" = "set" ] || {
    printf 'unexpected gh command: %s\n' "$*" >&2
    exit 9
}
name="$3"
shift 3

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo) repo="$2"; shift 2;;
        *) printf 'unexpected gh args: %s\n' "$*" >&2; exit 9;;
    esac
done

[ "$repo" = "esaueng/FactoryAssistantOS" ] || {
    printf 'unexpected repo: %s\n' "$repo" >&2
    exit 9
}

cat > "${log}.${name}.pem"
printf '%s\n' "$name" >> "$log"
EOF
chmod +x "$tmp/gh"

FAKE_GH_LOG="$tmp/gh.log" FAOS_GH_BIN="$tmp/gh" "$script" \
    --repo esaueng/FactoryAssistantOS \
    --keyring "$tmp/faos-ca.crt" \
    --cert "$tmp/faos-ota.crt" \
    --key "$tmp/faos-ota.key" > "$tmp/ok.out"

grep -q 'GitHub RAUC release secrets configured' "$tmp/ok.out" \
    || fail "secret installer success output is missing"

expected_order="$tmp/expected-order"
cat > "$expected_order" <<'EOF'
FAOS_RAUC_KEYRING_PEM
FAOS_RAUC_CERT_PEM
FAOS_RAUC_KEY_PEM
EOF
cmp "$expected_order" "$tmp/gh.log"
cmp "$tmp/faos-ca.crt" "$tmp/gh.log.FAOS_RAUC_KEYRING_PEM.pem"
cmp "$tmp/faos-ota.crt" "$tmp/gh.log.FAOS_RAUC_CERT_PEM.pem"
cmp "$tmp/faos-ota.key" "$tmp/gh.log.FAOS_RAUC_KEY_PEM.pem"

if FAOS_GH_BIN="$tmp/gh" "$script" \
    --repo esaueng/FactoryAssistantOS \
    --keyring "$ROOT/branding/identity.env" \
    --cert "$tmp/faos-ota.crt" \
    --key "$tmp/faos-ota.key" 2> "$tmp/repo-source.err"; then
    fail "secret installer allowed RAUC material from inside the repository"
fi
grep -q 'RAUC keyring must be supplied from outside this repository' "$tmp/repo-source.err" \
    || fail "repo-source rejection did not identify the external keyring requirement"

grep -q 'scripts/configure-github-rauc-secrets.sh' "$release_doc" \
    || fail "release runbook does not document the GitHub RAUC secret installer"
grep -q 'scripts/configure-github-rauc-secrets.sh' "$build_doc" \
    || fail "OS build docs do not document the GitHub RAUC secret installer"

echo "ok  GitHub RAUC secret installer validates and uploads trusted OTA secrets"
