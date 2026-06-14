#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$ROOT/scripts/verify-safety-boundary.sh"
safety_doc="$ROOT/docs/SAFETY_BOUNDARY.md"
release_doc="$ROOT/RELEASE.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$script" ] || fail "safety-boundary verifier is missing or not executable"

"$script" > "$tmp/ok.out"
grep -q 'safety boundary verification passed' "$tmp/ok.out" \
    || fail "safety-boundary verifier success output is missing"

cat > "$tmp/local-bookkeeping.yaml" <<'EOF'
automation:
  - alias: "local helper cleanup"
    action:
      - service: input_boolean.turn_off
        target:
          entity_id: input_boolean.example_ack
      - service: persistent_notification.create
        data:
          title: "Informational"
          message: "Local bookkeeping only"
EOF
"$script" "$tmp/local-bookkeeping.yaml" > "$tmp/local-bookkeeping.out" \
    || fail "safety-boundary verifier rejected allowed local bookkeeping"

cat > "$tmp/control-service.yaml" <<'EOF'
automation:
  - alias: "forbidden machine command"
    action:
      - service: switch.turn_on
        target:
          entity_id: switch.line1_conveyor
EOF
if "$script" "$tmp/control-service.yaml" 2> "$tmp/control-service.err"; then
    fail "safety-boundary verifier allowed a machine-control service"
fi
grep -q 'machine/control service is forbidden' "$tmp/control-service.err" \
    || fail "control service rejection did not explain the safety boundary"

cat > "$tmp/control-domain.yaml" <<'EOF'
switch:
  - platform: template
    switches:
      line1_conveyor:
        value_template: "{{ false }}"
EOF
if "$script" "$tmp/control-domain.yaml" 2> "$tmp/control-domain.err"; then
    fail "safety-boundary verifier allowed a shipped control domain"
fi
grep -q 'machine/control domain is forbidden' "$tmp/control-domain.err" \
    || fail "control domain rejection did not explain the safety boundary"

grep -q 'scripts/verify-safety-boundary.sh' "$safety_doc" \
    || fail "safety boundary docs do not document the verifier"
grep -q 'scripts/verify-safety-boundary.sh' "$release_doc" \
    || fail "release checklist does not run the safety-boundary verifier"

echo "ok  shipped defaults are checked against the safety boundary"
