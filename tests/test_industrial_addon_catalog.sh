#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
catalog="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/addons/industrial_addons.catalog.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/addons/README.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
seed_script="$ROOT/buildroot-external/rootfs-overlay/usr/libexec/fa-seed-config"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$catalog" ] || fail "industrial add-on catalog is missing"
[ -f "$readme" ] || fail "industrial add-on README is missing"

python3 - "$catalog" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

if not isinstance(data, dict):
    raise SystemExit("catalog must be a mapping")

addons = data.get("addons")
if not isinstance(addons, list):
    raise SystemExit("catalog.addons must be a list")

catalog = data.get("catalog") or {}
if catalog.get("repository") != "factory-assistant-addons":
    raise SystemExit("catalog must target the live factory-assistant-addons repository")
if catalog.get("repository_url") != "https://github.com/esaueng/factory-assistant-addons":
    raise SystemExit("catalog must name the factory-assistant-addons repository URL")

expected_ids = [
    "opcua_mqtt_bridge",
    "plc_gateway_helper",
    "historian_storage",
]
seen_ids = [addon.get("id") for addon in addons]
if seen_ids != expected_ids:
    raise SystemExit(f"unexpected add-on ids/order: {seen_ids}")

for addon in addons:
    addon_id = addon["id"]
    if addon.get("status") != "available":
        raise SystemExit(f"{addon_id} must be marked available now that the add-on repo ships it")
    if addon.get("repository") != "factory-assistant-addons":
        raise SystemExit(f"{addon_id} must live in factory-assistant-addons")
    if addon.get("local_first") is not True:
        raise SystemExit(f"{addon_id} must be local_first")
    packaging = addon.get("packaging") or {}
    if packaging.get("repository") != "factory-assistant-addons":
        raise SystemExit(f"{addon_id} packaging must target factory-assistant-addons")
    if packaging.get("slug") != addon_id:
        raise SystemExit(f"{addon_id} packaging slug must match the add-on id")
    expected_image = f"ghcr.io/esaueng/{{arch}}-addon-{addon_id.replace('_', '-')}"
    if packaging.get("image") != expected_image:
        raise SystemExit(f"{addon_id} packaging image drifted")
    if "amd64" not in (packaging.get("arch") or []):
        raise SystemExit(f"{addon_id} packaging must support generic x86-64 / amd64")
    if packaging.get("boot") != "manual":
        raise SystemExit(f"{addon_id} must not auto-start before operator setup")
    if packaging.get("startup") != "services":
        raise SystemExit(f"{addon_id} must use the Home Assistant services startup class")
    if packaging.get("host_network") is not False:
        raise SystemExit(f"{addon_id} must not require host networking")
    if packaging.get("privileged") is not False:
        raise SystemExit(f"{addon_id} must not require privileged mode")
    options_schema = addon.get("options_schema") or {}
    if not isinstance(options_schema, dict) or not options_schema:
        raise SystemExit(f"{addon_id} must define an option schema contract")
    safety = addon.get("safety") or {}
    if safety.get("monitoring_only") is not True:
        raise SystemExit(f"{addon_id} must be monitoring_only")
    if safety.get("machine_control") is not False:
        raise SystemExit(f"{addon_id} must not allow machine control")
    if safety.get("safety_function") is not False:
        raise SystemExit(f"{addon_id} must not claim safety function behavior")

opcua = addons[0]
if opcua.get("depends_on") != ["mosquitto"]:
    raise SystemExit("OPC UA bridge must depend on Mosquitto")
opcua_cfg = opcua.get("opcua") or {}
if opcua_cfg.get("mode") != "subscribe_only":
    raise SystemExit("OPC UA bridge must be subscribe_only")
if opcua_cfg.get("write_nodes_allowed") is not False:
    raise SystemExit("OPC UA bridge must disallow writes")
mqtt_cfg = opcua.get("mqtt") or {}
if mqtt_cfg.get("discovery") is not True:
    raise SystemExit("OPC UA bridge must publish MQTT discovery")
if mqtt_cfg.get("command_topics_allowed") is not False:
    raise SystemExit("OPC UA bridge must disallow command topics")
if mqtt_cfg.get("topic_shape") != "fa/<site>/<area>/<device>/<measurement>":
    raise SystemExit("OPC UA bridge topic shape drifted")
opcua_options = opcua.get("options_schema") or {}
for field in ("endpoint_url", "node_allowlist", "publish_interval_seconds", "security_policy"):
    if field not in opcua_options:
        raise SystemExit(f"OPC UA bridge option schema missing {field}")
if opcua_options.get("write_nodes_allowed") is not False:
    raise SystemExit("OPC UA bridge option schema must hard-disable writes")

plc = addons[1]
modbus = plc.get("modbus_tcp") or {}
if modbus.get("read_only") is not True:
    raise SystemExit("PLC helper Modbus contract must be read-only")
if modbus.get("allowed_function_codes") != [3, 4]:
    raise SystemExit("PLC helper must only allow Modbus function codes 3 and 4")
if modbus.get("write_functions_allowed") is not False:
    raise SystemExit("PLC helper must disallow Modbus write functions")
if modbus.get("safety_controller_allowed") is not False:
    raise SystemExit("PLC helper must not target safety controllers")
plc_options = plc.get("options_schema") or {}
for field in ("register_map_path", "poll_interval_seconds", "unit_id", "mqtt_discovery"):
    if field not in plc_options:
        raise SystemExit(f"PLC helper option schema missing {field}")
if plc_options.get("allowed_function_codes") != [3, 4]:
    raise SystemExit("PLC helper option schema must restrict function codes to 3 and 4")
if plc_options.get("write_functions_allowed") is not False:
    raise SystemExit("PLC helper option schema must hard-disable writes")

historian = addons[2]
if historian.get("cloud_required") is not False:
    raise SystemExit("Historian must not require cloud services")
if historian.get("machine_control") is not False:
    raise SystemExit("Historian must not implement machine control")
engines = historian.get("engines") or []
if sorted(engines) != ["influxdb", "timescaledb"]:
    raise SystemExit("Historian engines must be InfluxDB and TimescaleDB")
inputs = historian.get("inputs") or []
if "mqtt" not in inputs or "core_recorder_export" not in inputs:
    raise SystemExit("Historian must accept MQTT and Core recorder export inputs")
historian_options = historian.get("options_schema") or {}
for field in ("engine", "retention_days", "local_volume", "cloud_export_enabled"):
    if field not in historian_options:
        raise SystemExit(f"Historian option schema missing {field}")
if historian_options.get("cloud_export_enabled") is not False:
    raise SystemExit("Historian option schema must default cloud export off")
PY

for expected in \
    'OPC UA' \
    'PLC gateway' \
    'historian' \
    'available' \
    'manifest contract' \
    'option schemas' \
    'read-only' \
    'not a safety device' \
    'Mosquitto broker add-on'; do
    grep -q "$expected" "$readme" \
        || fail "industrial add-on README is missing expected text: $expected"
done

grep -q 'addons/' "$seed_script" \
    || fail "seed script comments do not mention add-on catalog files are copied"
grep -q 'addons/industrial_addons.catalog.yaml' "$defaults_doc" \
    || fail "industrial defaults doc does not mention the add-on catalog"
grep -q 'factory-assistant-addons' "$defaults_doc" \
    || fail "industrial defaults doc does not mention the live add-on repository"
grep -q 'factory-assistant-addons' "$arch_doc" \
    || fail "architecture repo map does not mention the live add-on repository"
grep -q 'factory-assistant-addons' "$readme" \
    || fail "industrial add-on README does not mention the live add-on repository"
grep -q 'industrial add-on catalog' "$arch_doc" \
    || fail "architecture phase status does not mention the industrial add-on catalog"

echo "ok  industrial add-on catalog is shipped and constrained to monitoring"
