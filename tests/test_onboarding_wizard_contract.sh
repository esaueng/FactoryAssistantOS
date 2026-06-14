#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/wizard_steps.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/README.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
ui_doc="$ROOT/docs/UI_DESIGN.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$contract" ] || fail "industrial onboarding wizard contract is missing"

python3 - "$contract" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

if not isinstance(data, dict):
    raise SystemExit("wizard contract must be a mapping")

wizard = data.get("wizard") or {}
if wizard.get("id") != "factory_assistant_industrial_onboarding":
    raise SystemExit("wizard id drifted")
if wizard.get("version") != 1:
    raise SystemExit("wizard version must be 1")
if wizard.get("home_centric_steps_allowed") is not False:
    raise SystemExit("home-centric onboarding steps must be disabled")
if wizard.get("requires_external_account") is not False:
    raise SystemExit("onboarding must not require an external account")

expected_steps = [
    "safety_boundary",
    "site_identity",
    "plant_hierarchy",
    "network_posture",
    "time_ntp",
    "mqtt_broker_offer",
    "privacy_defaults",
    "default_experience",
    "review_and_seed",
]
steps = data.get("steps")
if not isinstance(steps, list):
    raise SystemExit("wizard steps must be a list")
actual_steps = [step.get("id") for step in steps]
if actual_steps != expected_steps:
    raise SystemExit(f"unexpected wizard steps/order: {actual_steps}")

by_id = {step["id"]: step for step in steps}
for step in steps:
    step_id = step["id"]
    if step.get("writes_machine_state") is not False:
        raise SystemExit(f"{step_id} must not write machine state")
    safety = step.get("safety") or {}
    if safety.get("monitoring_only") is not True:
        raise SystemExit(f"{step_id} must be monitoring-only")
    if safety.get("machine_control") is not False:
        raise SystemExit(f"{step_id} must not allow machine control")
    if safety.get("safety_function") is not False:
        raise SystemExit(f"{step_id} must not claim safety function behavior")

if by_id["safety_boundary"].get("acknowledgement_required") is not True:
    raise SystemExit("safety boundary acknowledgement is required")

site = by_id["site_identity"]
required_site_fields = site.get("required_fields") or []
for field in ("site.name", "site.slug", "site.time_zone", "site.ntp_servers"):
    if field not in required_site_fields:
        raise SystemExit(f"site identity missing required field: {field}")

hierarchy = by_id["plant_hierarchy"]
if hierarchy.get("model_source") != "site_model.example.yaml":
    raise SystemExit("plant hierarchy must consume site_model.example.yaml")
if hierarchy.get("taxonomy") != ["site", "line", "cell", "station", "machine"]:
    raise SystemExit("plant hierarchy taxonomy drifted")

network = by_id["network_posture"]
if network.get("helper") != "fa-network-posture":
    raise SystemExit("network posture step must use fa-network-posture")
if network.get("helper_output_format") != "json":
    raise SystemExit("network posture step must consume fa-network-posture JSON")
if network.get("read_only") is not True:
    raise SystemExit("network posture step must be read-only")
for check in ("default_route", "global_address", "static_ip_guidance"):
    if check not in (network.get("checks") or []):
        raise SystemExit(f"network posture missing check: {check}")

time = by_id["time_ntp"]
if time.get("required") is not True:
    raise SystemExit("NTP step must be required")
for check in ("ntp_synchronized", "time_zone_set"):
    if check not in (time.get("checks") or []):
        raise SystemExit(f"NTP step missing check: {check}")

mqtt = by_id["mqtt_broker_offer"]
if mqtt.get("action") != "offer_addon":
    raise SystemExit("MQTT step must offer the broker add-on")
if mqtt.get("addon") != "mosquitto":
    raise SystemExit("MQTT step must offer Mosquitto")
if mqtt.get("command_topics_allowed") is not False:
    raise SystemExit("MQTT step must disallow command topics")

privacy = by_id["privacy_defaults"]
if privacy.get("cloud_enabled") is not False:
    raise SystemExit("cloud must default off")
if privacy.get("analytics_enabled") is not False:
    raise SystemExit("analytics must default off")
if privacy.get("external_account_required") is not False:
    raise SystemExit("external account must not be required")

experience = by_id["default_experience"]
expected_dashboards = {
    "main": "dashboards/factory-overview.yaml",
    "andon": "dashboards/andon.yaml",
    "wallboard": "dashboards/wallboard.yaml",
}
if experience.get("dashboards") != expected_dashboards:
    raise SystemExit("default dashboard contract drifted")
if experience.get("default_landing_view") != "Plant overview":
    raise SystemExit("default landing view must be Plant overview")

review = by_id["review_and_seed"]
if review.get("seed_tree") != "/usr/share/factory-assistant":
    raise SystemExit("review step must seed the shipped Factory Assistant tree")
if review.get("overwrite_existing_config") is not False:
    raise SystemExit("review step must not overwrite existing config")
PY

for expected in \
    'wizard_steps.yaml' \
    'industrial onboarding wizard contract' \
    'NTP' \
    'static IP' \
    'Mosquitto broker add-on' \
    'Plant overview'; do
    grep -q "$expected" "$readme" \
        || fail "onboarding README is missing expected wizard text: $expected"
done

grep -q 'wizard_steps.yaml' "$defaults_doc" \
    || fail "industrial defaults doc does not mention the wizard contract"
grep -q 'industrial onboarding wizard contract' "$arch_doc" \
    || fail "architecture status does not mention the wizard contract"
grep -q 'wizard_steps.yaml' "$ui_doc" \
    || fail "UI design doc does not mention the wizard contract"

echo "ok  industrial onboarding wizard contract is shipped and documented"
