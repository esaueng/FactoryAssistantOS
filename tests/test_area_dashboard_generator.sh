#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator="$ROOT/scripts/generate-area-dashboards.py"
model="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/site_model.example.yaml"
example="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/dashboards/area-dashboards.example.yaml"
config="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/configuration.yaml"
ui_doc="$ROOT/docs/UI_DESIGN.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
release_doc="$ROOT/RELEASE.md"
readme="$ROOT/README.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$generator" ] || fail "area dashboard generator is missing"
[ -f "$model" ] || fail "site model scaffold is missing"
[ -f "$example" ] || fail "generated area dashboard example is missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

PYTHONPYCACHEPREFIX="$tmp/pycache" python3 -m py_compile "$generator"
python3 "$generator" --site-model "$model" --output "$tmp/area-dashboards.yaml"

if grep -Eq '^- ' "$tmp/area-dashboards.yaml"; then
    fail "generated dashboard uses yamllint-hostile top-level list indentation"
fi

cmp -s "$tmp/area-dashboards.yaml" "$example" \
    || fail "checked-in area dashboard example is not generated from site_model.example.yaml"

python3 - "$tmp/area-dashboards.yaml" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

if data.get("title") != "Factory Assistant area dashboards":
    raise SystemExit("generated dashboard title drifted")

views = data.get("views") or []
paths = {view.get("path"): view for view in views}
for path in ("line1", "line2"):
    if path not in paths:
        raise SystemExit(f"missing generated view for {path}")


def cards(node):
    if isinstance(node, dict):
        if "type" in node:
            yield node
        for value in node.values():
            yield from cards(value)
    elif isinstance(node, list):
        for value in node:
            yield from cards(value)


all_cards = list(cards(data))
machine_cards = [
    card for card in all_cards if card.get("type") == "custom:fa-machine-card"
]
if len(machine_cards) != 2:
    raise SystemExit("example model should generate one native machine card per machine")

by_machine = {card.get("machine"): card for card in machine_cards}
press = by_machine.get("Press 03")
extruder = by_machine.get("Extruder 01")
if not press or not extruder:
    raise SystemExit("generated machine cards must preserve machine display names")

expected = {
    "Press 03": {
        "line": "Line 1",
        "cell": "Press cell",
        "status_entity": "binary_sensor.line1_press03_running",
    },
    "Extruder 01": {
        "line": "Line 2",
        "cell": "Extrusion cell",
        "status_entity": "binary_sensor.line2_extr01_running",
    },
}
for card in machine_cards:
    machine = card["machine"]
    for key, value in expected[machine].items():
        if card.get(key) != value:
            raise SystemExit(f"{machine} {key} drifted: {card.get(key)!r}")
    if card.get("tap_action") != "detail_only":
        raise SystemExit("machine cards must remain detail-only")
    if card.get("control_affordances_allowed") is not False:
        raise SystemExit("machine cards must explicitly disallow control affordances")

andon_cards = [card for card in all_cards if card.get("type") == "custom:fa-andon-view"]
if len(andon_cards) != 2:
    raise SystemExit("each generated line view must include a native line andon summary")
for card in andon_cards:
    if card.get("acknowledge_is_bookkeeping") is not True:
        raise SystemExit("area andon summaries must mark ack as bookkeeping")
    if card.get("safety_alarm_claim_allowed") is not False:
        raise SystemExit("area andon summaries must disallow safety alarm claims")
    alerts = card.get("alerts") or []
    if not alerts:
        raise SystemExit("area andon summaries must include line alert entities")
    if any(alert.get("severity") != "warning" for alert in alerts):
        raise SystemExit("generated example alert severities must default to warning")

history_cards = [card for card in all_cards if card.get("type") == "history-graph"]
if len(history_cards) < 2:
    raise SystemExit("each generated line view must include telemetry history")
PY

grep -q 'area-dashboards.example.yaml' "$config" \
    || fail "configuration template does not document generated area dashboards"

for phrase in \
    'area dashboard generator' \
    'area-dashboards.example.yaml' \
    'custom:fa-machine-card' \
    'custom:fa-andon-view'; do
    grep -q "$phrase" "$ui_doc" "$defaults_doc" "$arch_doc" "$release_doc" "$readme" \
        || fail "docs are missing generated area dashboard text: $phrase"
done

if grep -Eq 'area dashboard generation.*remain|area dashboards.*remain' \
    "$ui_doc" "$defaults_doc" "$arch_doc" "$release_doc" "$readme"; then
    fail "status docs still list area dashboard generation as unresolved"
fi

echo "ok  area dashboard generator creates native read-only line dashboards"
