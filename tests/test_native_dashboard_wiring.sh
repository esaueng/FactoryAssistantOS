#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
overview="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/dashboards/factory-overview.yaml"
andon="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/dashboards/andon.yaml"
wallboard="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/dashboards/wallboard.yaml"
ui_doc="$ROOT/docs/UI_DESIGN.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
release_doc="$ROOT/RELEASE.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$overview" ] || fail "Plant overview dashboard is missing"
[ -f "$andon" ] || fail "andon dashboard is missing"
[ -f "$wallboard" ] || fail "wallboard dashboard is missing"

python3 - "$overview" "$andon" "$wallboard" <<'PY'
import sys
import yaml

overview_path, andon_path, wallboard_path = sys.argv[1:]


def load(path):
    with open(path, "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def cards(node):
    if isinstance(node, dict):
        if "type" in node:
            yield node
        for value in node.values():
            yield from cards(value)
    elif isinstance(node, list):
        for value in node:
            yield from cards(value)


overview_cards = list(cards(load(overview_path)))
andon_cards = list(cards(load(andon_path)))
wallboard_cards = list(cards(load(wallboard_path)))

machine_cards = [
    card for card in overview_cards if card.get("type") == "custom:fa-machine-card"
]
if len(machine_cards) < 3:
    raise SystemExit("Plant overview must wire native custom:fa-machine-card tiles")

required_machine_fields = {"title", "line", "machine", "status_entity"}
for card in machine_cards:
    missing = required_machine_fields.difference(card)
    if missing:
        raise SystemExit(f"fa-machine-card missing required fields: {sorted(missing)}")
    if card.get("tap_action") not in (None, "detail_only"):
        raise SystemExit("fa-machine-card tap_action must stay detail_only")
    if card.get("control_affordances_allowed") not in (None, False):
        raise SystemExit("fa-machine-card must not allow control affordances")

if not any(card.get("oee_entity") for card in machine_cards):
    raise SystemExit("At least one fa-machine-card must wire OEE telemetry")
if not any(card.get("maintenance_entity") for card in machine_cards):
    raise SystemExit("At least one fa-machine-card must wire maintenance telemetry")

overview_andon = [
    card for card in overview_cards if card.get("type") == "custom:fa-andon-view"
]
andon_native = [
    card for card in andon_cards if card.get("type") == "custom:fa-andon-view"
]
if len(overview_andon) != 1:
    raise SystemExit("Plant overview Alerts view must use custom:fa-andon-view")
if len(andon_native) != 1:
    raise SystemExit("Andon dashboard must use custom:fa-andon-view")

for card in overview_andon + andon_native:
    if card.get("acknowledge_is_bookkeeping") is not True:
        raise SystemExit("fa-andon-view must mark acknowledge as bookkeeping only")
    if card.get("safety_alarm_claim_allowed") is not False:
        raise SystemExit("fa-andon-view must explicitly disallow safety alarm claims")
    severities = {alert.get("severity") for alert in card.get("alerts", [])}
    if not {"critical", "warning", "info"}.issubset(severities):
        raise SystemExit("fa-andon-view must include critical, warning, and info alerts")

kiosk_cards = [
    card
    for card in wallboard_cards
    if card.get("type") == "custom:factory-wallboard-kiosk"
]
if len(kiosk_cards) != 1:
    raise SystemExit("Wallboard dashboard must include custom:factory-wallboard-kiosk")
kiosk = kiosk_cards[0]
if kiosk.get("hide_sidebar") is not True or kiosk.get("hide_header") is not True:
    raise SystemExit("factory-wallboard-kiosk must hide sidebar and header")
if kiosk.get("interaction") != "view_only":
    raise SystemExit("factory-wallboard-kiosk must remain view-only")
if kiosk.get("type_scale") != 1.6:
    raise SystemExit("factory-wallboard-kiosk must keep the 1.6 wallboard scale")
PY

for phrase in \
    'dashboard wiring is implemented' \
    'custom:fa-machine-card' \
    'custom:fa-andon-view' \
    'custom:factory-wallboard-kiosk'; do
    grep -q "$phrase" "$ui_doc" "$defaults_doc" "$arch_doc" "$release_doc" \
        || fail "dashboard wiring docs are missing expected text: $phrase"
done

if grep -Eq 'stock cards until|stock-card compatible until dashboard wiring|dashboard wiring.*remain|dashboard wiring and industrial onboarding wizard integration' \
    "$ui_doc" "$defaults_doc" "$arch_doc" "$release_doc"; then
    fail "status docs still list native dashboard wiring as unresolved"
fi

echo "ok  native Factory Assistant dashboard wiring is shipped"
