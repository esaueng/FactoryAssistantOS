#!/usr/bin/env bash
# Validate the Factory Assistant overlay repo without a full OS build.
#
# Covers what `make os` cannot cheaply check: shell scripts, the Core YAML
# templates (themes/dashboards/packages/configuration), the update-channel
# JSON + its schema, and Markdown cross-links. Operates on git-tracked files
# only, so the gitignored upstream/ build tree is never scanned.
#
# Required: bash, python3 (+ PyYAML), jq, git.
# Optional (used if present; CI installs them): shellcheck, yamllint,
#   check-jsonschema or python3-jsonschema.
#
# Exit non-zero if any required check fails. See AGENTS.md §Validation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0
section() { printf '\n=== %s ===\n' "$1"; }

# Collect tracked files by extension into arrays.
mapfile -t SH_FILES   < <(git ls-files '*.sh')
mapfile -t YAML_FILES < <(git ls-files '*.yaml' '*.yml')
mapfile -t JSON_FILES < <(git ls-files '*.json' '*.json.example')
mapfile -t MD_FILES   < <(git ls-files '*.md')

# --- 1. Shell scripts -------------------------------------------------------
section "Shell scripts (bash -n + shellcheck if present)"
if [ ${#SH_FILES[@]} -gt 0 ]; then
    for f in "${SH_FILES[@]}"; do
        if bash -n "$f"; then echo "ok  $f"; else echo "SYNTAX ERROR $f" >&2; fail=1; fi
    done
    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck "${SH_FILES[@]}" || fail=1
    else
        echo "(shellcheck not installed — skipped)"
    fi
fi

# --- 2. YAML structural parse (Home Assistant custom tags aware) ------------
section "YAML templates (structural parse)"
if [ ${#YAML_FILES[@]} -gt 0 ]; then
    python3 "$ROOT/scripts/lint_yaml.py" "${YAML_FILES[@]}" || fail=1
    if command -v yamllint >/dev/null 2>&1; then
        # Style pass on our own YAML (config: .yamllint). --strict so any
        # warning fails CI; line-length is disabled there for the comment-heavy
        # templates. Structural errors are already caught above.
        yamllint --strict "${YAML_FILES[@]}" || fail=1
    else
        echo "(yamllint not installed — style check skipped)"
    fi
fi

# --- 3. JSON syntax + channel schema ----------------------------------------
section "JSON (syntax + channel schema)"
SCHEMA="$ROOT/version-service/schema/channel.schema.json"
have_jsonschema=0
if command -v check-jsonschema >/dev/null 2>&1; then
    have_jsonschema=1
elif python3 -c 'import jsonschema' >/dev/null 2>&1; then
    have_jsonschema=2
fi
for f in "${JSON_FILES[@]}"; do
    if jq empty "$f" >/dev/null 2>&1; then echo "ok  $f (json)"; else echo "JSON ERROR $f" >&2; fail=1; fi
done
# Validate channel documents (version-service/*.json[.example]) against the schema.
mapfile -t CHANNEL_DOCS < <(git ls-files 'version-service/*.json' 'version-service/*.json.example')
if [ "$have_jsonschema" -eq 0 ]; then
    echo "(no JSON Schema validator — channel docs not schema-checked)"
else
    for f in "${CHANNEL_DOCS[@]}"; do
        [ "$f" = "version-service/schema/channel.schema.json" ] && continue
        if [ "$have_jsonschema" -eq 1 ]; then
            check-jsonschema --schemafile "$SCHEMA" "$f" || fail=1
        else
            python3 -c '
import json, sys, jsonschema
schema = json.load(open(sys.argv[1]))
jsonschema.validate(json.load(open(sys.argv[2])), schema)
print("ok  %s (schema)" % sys.argv[2])
' "$SCHEMA" "$f" || fail=1
        fi
    done
fi

# --- 4. Markdown cross-links ------------------------------------------------
section "Markdown cross-links"
if [ ${#MD_FILES[@]} -gt 0 ]; then
    python3 "$ROOT/scripts/lint_links.py" "${MD_FILES[@]}" || fail=1
fi

section "Result"
if [ "$fail" -ne 0 ]; then
    echo "lint: FAILED" >&2
    exit 1
fi
echo "lint: all checks passed"
