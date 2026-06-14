#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/ui/frontend_contract.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/ui/README.md"
ui_doc="$ROOT/docs/UI_DESIGN.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
license_doc="$ROOT/docs/LICENSE_COMPLIANCE.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$contract" ] || fail "frontend experience contract is missing"
[ -f "$readme" ] || fail "frontend experience README is missing"

python3 - "$contract" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

if not isinstance(data, dict):
    raise SystemExit("frontend contract must be a mapping")

contract = data.get("contract") or {}
if contract.get("id") != "factory_assistant_frontend_experience":
    raise SystemExit("frontend contract id drifted")
if contract.get("version") != 1:
    raise SystemExit("frontend contract version must be 1")
if contract.get("consumer") != "frontend":
    raise SystemExit("frontend contract must target the frontend fork")
if contract.get("status") != "contract_for_frontend_fork":
    raise SystemExit("frontend contract status must identify fork handoff")

branding = data.get("branding") or {}
if branding.get("product_name") != "Factory Assistant":
    raise SystemExit("frontend product name must be Factory Assistant")
if branding.get("home_assistant_as_brand") is not False:
    raise SystemExit("frontend must not use Home Assistant as branding")

landing = data.get("default_experience") or {}
if landing.get("default_route") != "/lovelace":
    raise SystemExit("default route must remain the seeded Lovelace dashboard")
if landing.get("default_dashboard") != "dashboards/factory-overview.yaml":
    raise SystemExit("default dashboard contract must point at Plant overview")
if landing.get("andon_dashboard") != "dashboards/andon.yaml":
    raise SystemExit("andon dashboard path drifted")
if landing.get("wallboard_dashboard") != "dashboards/wallboard.yaml":
    raise SystemExit("wallboard dashboard path drifted")

navigation = data.get("navigation") or {}
expected_primary = ["Plant overview", "Alerts", "Energy", "History", "Logbook", "Maintenance"]
if navigation.get("primary_items") != expected_primary:
    raise SystemExit("frontend primary navigation contract drifted")
for item in ("Media", "Map", "To-do"):
    if item not in (navigation.get("hidden_by_default") or []):
        raise SystemExit(f"home-centric navigation item must be hidden by default: {item}")
if navigation.get("settings_visibility") != "admin_only":
    raise SystemExit("settings must remain admin-only in the frontend contract")

machine_card = data.get("machine_card") or {}
if machine_card.get("component") != "fa-machine-card":
    raise SystemExit("frontend contract must define fa-machine-card")
if machine_card.get("tap_action") != "detail_only":
    raise SystemExit("machine-card tap action must be detail-only")
if machine_card.get("control_affordances_allowed") is not False:
    raise SystemExit("machine-card must not allow control affordances")
if machine_card.get("freshness_required") is not True:
    raise SystemExit("machine-card must require freshness indicators")
if machine_card.get("stale_after_intervals") != 3:
    raise SystemExit("machine-card stale threshold must be 3 update intervals")
if machine_card.get("offline_after_intervals") != 10:
    raise SystemExit("machine-card offline threshold must be 10 update intervals")
states = machine_card.get("states") or {}
expected_states = ["running", "idle", "blocked", "down", "maintenance", "offline"]
if sorted(states) != sorted(expected_states):
    raise SystemExit("machine-card state vocabulary drifted")
for state in expected_states:
    value = states[state]
    for field in ("label", "icon", "color_token"):
        if field not in value:
            raise SystemExit(f"{state} state missing {field}")

kiosk = data.get("kiosk_mode") or {}
if kiosk.get("component") != "factory-wallboard-kiosk":
    raise SystemExit("kiosk contract must name the wallboard kiosk component")
if kiosk.get("hide_sidebar") is not True or kiosk.get("hide_header") is not True:
    raise SystemExit("kiosk mode must hide sidebar and header")
if kiosk.get("type_scale") != 1.6:
    raise SystemExit("kiosk type scale must remain 1.6")
if kiosk.get("interaction") != "view_only":
    raise SystemExit("kiosk mode must be view-only")

andon = data.get("andon_view") or {}
if andon.get("component") != "fa-andon-view":
    raise SystemExit("andon contract must name fa-andon-view")
if andon.get("acknowledge_is_bookkeeping") is not True:
    raise SystemExit("andon acknowledge must stay bookkeeping-only")
if andon.get("safety_alarm_claim_allowed") is not False:
    raise SystemExit("andon view must not claim safety alarm behavior")

about = data.get("about_panel") or {}
if about.get("component") != "factory-about-panel":
    raise SystemExit("frontend contract must define the Factory Assistant About panel")
if about.get("product_name") != "Factory Assistant":
    raise SystemExit("About panel must use the Factory Assistant product name")
if about.get("upstream_attribution") != "Factory Assistant is based on Home Assistant.":
    raise SystemExit("About panel must carry canonical upstream attribution")
if about.get("non_affiliation_notice_required") is not True:
    raise SystemExit("About panel must require the non-affiliation notice")
links = about.get("links") or {}
safety_link = links.get("safety_boundary") or {}
if safety_link.get("document") != "docs/SAFETY_BOUNDARY.md" or safety_link.get("required") is not True:
    raise SystemExit("About panel must link the normative safety boundary")
license_link = links.get("open_source_licenses") or {}
if license_link.get("release_artifact") != "legal-info" or license_link.get("required") is not True:
    raise SystemExit("About panel must link the per-release open source license bundle")

safety = data.get("safety") or {}
if safety.get("monitoring_only") is not True:
    raise SystemExit("frontend contract must be monitoring-only")
if safety.get("machine_control") is not False:
    raise SystemExit("frontend contract must disallow machine control")
if safety.get("control_surfaces_allowed") is not False:
    raise SystemExit("frontend contract must disallow control surfaces")
if "Factory Assistant is a monitoring tool, not a safety device." not in safety.get("required_disclaimer", ""):
    raise SystemExit("frontend contract is missing the required UI disclaimer")
PY

for expected in \
    'frontend_contract.yaml' \
    'fa-machine-card' \
    'About panel' \
    'Open source licenses' \
    'Safety boundary' \
    'kiosk' \
    'view-only' \
    'monitoring tool, not a safety device'; do
    grep -q "$expected" "$readme" \
        || fail "frontend contract README is missing expected text: $expected"
done

grep -q 'frontend_contract.yaml' "$ui_doc" \
    || fail "UI design doc does not mention the frontend contract"
grep -q 'frontend_contract.yaml' "$defaults_doc" \
    || fail "industrial defaults doc does not mention the frontend contract"
grep -q 'frontend experience contract' "$arch_doc" \
    || fail "architecture phase status does not mention the frontend experience contract"
grep -q 'about_panel' "$ui_doc" \
    || fail "UI design doc does not mention the About panel contract key"
grep -q 'about_panel' "$license_doc" \
    || fail "license compliance doc does not mention the About panel contract key"

echo "ok  frontend experience contract is shipped and constrained to monitoring"
