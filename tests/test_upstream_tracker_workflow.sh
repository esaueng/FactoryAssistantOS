#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$ROOT/.github/workflows/upstream-tracker.yml"
build_doc="$ROOT/docs/OS_BUILD.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$workflow" ] || fail "upstream tracker workflow is missing"

grep -q 'name: Track upstream releases and security' "$workflow" \
    || fail "upstream tracker workflow has the wrong name"
grep -q 'schedule:' "$workflow" \
    || fail "upstream tracker is not scheduled"
grep -q 'workflow_dispatch:' "$workflow" \
    || fail "upstream tracker cannot be run manually"
grep -q 'issues: write' "$workflow" \
    || fail "upstream tracker cannot maintain the tracking issue"
grep -q 'contents: read' "$workflow" \
    || fail "upstream tracker should only read repository contents"
grep -q 'actions/github-script@v7' "$workflow" \
    || fail "upstream tracker does not use the GitHub API helper"
grep -q 'fs.readFileSync("upstream.env"' "$workflow" \
    || fail "upstream tracker does not read pinned upstream repos"
grep -q 'github.rest.repos.getLatestRelease' "$workflow" \
    || fail "upstream tracker does not check latest upstream releases"
grep -q 'github.rest.repos.listTags' "$workflow" \
    || fail "upstream tracker does not fall back to upstream tags"
grep -q 'GET /repos/{owner}/{repo}/security-advisories' "$workflow" \
    || fail "upstream tracker does not query repository security advisories"
grep -q 'state: "published"' "$workflow" \
    || fail "upstream tracker does not limit advisory checks to published advisories"
grep -q 'Latest published advisory' "$workflow" \
    || fail "upstream tracker issue table does not surface latest advisory status"
grep -q 'repository security advisory API' "$workflow" \
    || fail "upstream tracker does not describe the automated security advisory check"
grep -q 'Upstream release/security tracking' "$workflow" \
    || fail "upstream tracker does not maintain the expected standing issue"

for expected in \
    'GitHub Security Advisories' \
    'rebrand checklist' \
    'Home Assistant/OHF marks' \
    'monitoring-only safety boundary' \
    'does not modify pins, merge upstream code'
do
    grep -q "$expected" "$workflow" \
        || fail "upstream tracker is missing expected review gate: $expected"
done

grep -q '.github/workflows/upstream-tracker.yml' "$build_doc" \
    || fail "OS build docs do not document the upstream tracker workflow"
grep -q 'upstream release/security tracker' "$arch_doc" \
    || fail "architecture phase status does not mention the upstream tracker"

echo "ok  upstream release/security tracker is scheduled and security-aware"
