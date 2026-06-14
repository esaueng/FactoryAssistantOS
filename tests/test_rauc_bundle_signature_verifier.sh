#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-rauc-bundle-signature.sh"
workflow="$ROOT/.github/workflows/build-os-image.yml"
release_doc="$ROOT/RELEASE.md"
bash_bin="$(command -v bash)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

make_release_dir() {
    local dir="$1"

    mkdir -p "$dir"
    printf 'trusted rauc bundle\n' > "$dir/faos_generic-x86-64-17.3.raucb"
}

make_fake_rauc() {
    local mode="$1"
    local bindir="$tmp/fake-rauc-$mode"

    mkdir -p "$bindir"
    cat > "$bindir/rauc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log="${FAKE_RAUC_LOG:?}"
mode="${FAKE_RAUC_MODE:?}"

printf '%s\n' "$*" >> "$log"

if [ "$#" -ne 4 ] || [ "$1" != "info" ] || [ "$2" != "--keyring" ]; then
    echo "unexpected rauc invocation: $*" >&2
    exit 64
fi

if [ "$mode" = "fail" ]; then
    echo "signature rejected by fake rauc" >&2
    exit 1
fi

exit 0
EOF
    chmod +x "$bindir/rauc"
    printf '%s\n' "$bindir"
}

[ -x "$script" ] || fail "RAUC bundle signature verifier script is missing or not executable"

release="$tmp/release"
keyring="$tmp/keyring.pem"
make_release_dir "$release"
printf 'public keyring\n' > "$keyring"
release_real="$(cd "$release" && pwd -P)"
keyring_dir="$(cd "$(dirname "$keyring")" && pwd -P)"
keyring_real="$keyring_dir/$(basename "$keyring")"
fake_bin="$(make_fake_rauc pass)"
FAKE_RAUC_LOG="$tmp/rauc-ok.log" \
FAKE_RAUC_MODE=pass \
PATH="$fake_bin:$PATH" \
    "$script" --release-dir "$release" --board generic-x86-64 --keyring "$keyring" \
    > "$tmp/ok.out"
grep -q 'RAUC bundle signature verification passed' "$tmp/ok.out" \
    || fail "signature verifier success output is missing"
grep -q "info --keyring $keyring_real $release_real/faos_generic-x86-64-17.3.raucb" "$tmp/rauc-ok.log" \
    || fail "signature verifier did not call rauc info with the expected keyring and bundle"

failing_release="$tmp/failing-release"
make_release_dir "$failing_release"
fake_fail_bin="$(make_fake_rauc fail)"
if FAKE_RAUC_LOG="$tmp/rauc-fail.log" \
    FAKE_RAUC_MODE=fail \
    PATH="$fake_fail_bin:$PATH" \
        "$script" --release-dir "$failing_release" --board generic-x86-64 --keyring "$keyring" \
        > "$tmp/fail.out" 2> "$tmp/fail.err"; then
    fail "signature verifier allowed a RAUC bundle rejected by rauc"
fi
grep -q 'RAUC signature verification failed' "$tmp/fail.err" \
    || fail "signature rejection did not explain RAUC verification failure"

missing_rauc_release="$tmp/missing-rauc-release"
make_release_dir "$missing_rauc_release"
missing_tool_bin="$tmp/no-rauc-bin"
mkdir -p "$missing_tool_bin"
ln -s "$(command -v dirname)" "$missing_tool_bin/dirname"
ln -s "$(command -v basename)" "$missing_tool_bin/basename"
if PATH="$missing_tool_bin" \
    "$bash_bin" "$script" --release-dir "$missing_rauc_release" --board generic-x86-64 --keyring "$keyring" \
    > "$tmp/missing-rauc.out" 2> "$tmp/missing-rauc.err"; then
    fail "signature verifier allowed execution without rauc in PATH"
fi
grep -q 'rauc is required' "$tmp/missing-rauc.err" \
    || fail "missing rauc rejection did not explain the required tool"

grep -q 'scripts/verify-rauc-bundle-signature.sh' "$workflow" \
    || fail "build workflow does not verify RAUC bundle signatures before publishing"
grep -q 'apt-get install -y rauc' "$workflow" \
    || fail "build workflow does not install the RAUC verification tool"
grep -q 'scripts/verify-rauc-bundle-signature.sh' "$release_doc" \
    || fail "release runbook does not document RAUC bundle signature verification"

echo "ok  RAUC bundle signature verifier gates trusted OTA bundles"
