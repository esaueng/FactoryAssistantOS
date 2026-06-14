#!/usr/bin/env bash
# Verify the GitHub repository has the RAUC secrets required for trusted tags.
#
# This checks secret names only. GitHub never exposes secret values through
# `gh secret list`, and this script does not attempt to read or print them.
set -euo pipefail

repo="esaueng/FactoryAssistantOS"
gh_bin="${FAOS_GH_BIN:-gh}"

usage() {
    cat <<'EOF'
Usage: scripts/verify-github-rauc-secrets.sh [--repo esaueng/FactoryAssistantOS]

Checks that the repository has all three trusted-release RAUC secrets:
  FAOS_RAUC_KEYRING_PEM
  FAOS_RAUC_CERT_PEM
  FAOS_RAUC_KEY_PEM

Requires an authenticated GitHub CLI with permission to list repository
secrets. The script checks secret names only; it never reads secret values.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) repo="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) die "unknown argument: $1";;
    esac
done

command -v "$gh_bin" >/dev/null 2>&1 || die "GitHub CLI is required: $gh_bin"

required=(
    FAOS_RAUC_KEYRING_PEM
    FAOS_RAUC_CERT_PEM
    FAOS_RAUC_KEY_PEM
)

if ! secret_names="$("$gh_bin" secret list --repo "$repo" --json name --jq '.[].name')"; then
    die "failed to list GitHub secrets for $repo; check gh auth and repository access"
fi

missing=0
for name in "${required[@]}"; do
    if ! printf '%s\n' "$secret_names" | grep -Fxq "$name"; then
        echo "ERROR: missing required GitHub secret: $name" >&2
        missing=1
    fi
done

[ "$missing" -eq 0 ] || exit 2

cat <<EOF
GitHub RAUC release secrets are configured for $repo:
  FAOS_RAUC_KEYRING_PEM
  FAOS_RAUC_CERT_PEM
  FAOS_RAUC_KEY_PEM

Only secret names were checked; secret values were not read.
EOF
