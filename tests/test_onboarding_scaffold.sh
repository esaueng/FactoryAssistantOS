#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/site_model.example.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/README.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
ui_doc="$ROOT/docs/UI_DESIGN.md"
seed_script="$ROOT/buildroot-external/rootfs-overlay/usr/libexec/fa-seed-config"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$model" ] || fail "site onboarding model is missing"
[ -f "$readme" ] || fail "site onboarding README is missing"

python3 - "$model" <<'PY'
import re
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

if not isinstance(data, dict):
    raise SystemExit("site model must be a mapping")

site = data.get("site") or {}
for key in ("name", "slug", "time_zone", "ntp_servers"):
    if not site.get(key):
        raise SystemExit(f"site.{key} is required")
if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", site["slug"]):
    raise SystemExit("site.slug must be lowercase and URL/topic friendly")

local_first = data.get("local_first") or {}
if local_first.get("cloud") is not False:
    raise SystemExit("local_first.cloud must default false")
if local_first.get("analytics") is not False:
    raise SystemExit("local_first.analytics must default false")

network = data.get("network") or {}
if network.get("static_ip_guidance") is not True:
    raise SystemExit("network.static_ip_guidance must be true")
if not network.get("commissioning_host"):
    raise SystemExit("network.commissioning_host is required")

broker = data.get("broker") or {}
if broker.get("mosquitto_offer") is not True:
    raise SystemExit("broker.mosquitto_offer must be true")

safety = data.get("safety") or {}
if safety.get("monitoring_only") is not True:
    raise SystemExit("safety.monitoring_only must be true")
if safety.get("machine_control") is not False:
    raise SystemExit("safety.machine_control must be false")
if safety.get("safety_function") is not False:
    raise SystemExit("safety.safety_function must be false")

protocols = data.get("protocols") or {}
if protocols.get("mqtt", {}).get("command_topics_allowed") is not False:
    raise SystemExit("MQTT command topics must be disabled")
if protocols.get("modbus_tcp", {}).get("read_only") is not True:
    raise SystemExit("Modbus must be read-only")
if protocols.get("modbus_tcp", {}).get("allowed_function_codes") != [3, 4]:
    raise SystemExit("Modbus must only allow read function codes 3 and 4")
if protocols.get("opcua", {}).get("mode") != "subscribe_only":
    raise SystemExit("OPC UA must be subscribe_only")

lines = data.get("lines") or []
if not lines:
    raise SystemExit("at least one line is required")

seen = set()
id_re = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
for line in lines:
    for key in ("id", "name", "cells"):
        if not line.get(key):
            raise SystemExit(f"line.{key} is required")
    if not id_re.fullmatch(line["id"]):
        raise SystemExit(f"line id must be snake_case: {line['id']}")
    for cell in line["cells"]:
        for key in ("id", "name", "stations"):
            if not cell.get(key):
                raise SystemExit(f"cell.{key} is required")
        if not id_re.fullmatch(cell["id"]):
            raise SystemExit(f"cell id must be snake_case: {cell['id']}")
        for station in cell["stations"]:
            for key in ("id", "name", "machines"):
                if not station.get(key):
                    raise SystemExit(f"station.{key} is required")
            if not id_re.fullmatch(station["id"]):
                raise SystemExit(f"station id must be snake_case: {station['id']}")
            for machine in station["machines"]:
                for key in ("id", "name", "mqtt_topic_prefix", "entities"):
                    if not machine.get(key):
                        raise SystemExit(f"machine.{key} is required")
                if not id_re.fullmatch(machine["id"]):
                    raise SystemExit(f"machine id must be snake_case: {machine['id']}")
                if not machine["mqtt_topic_prefix"].startswith(f"fa/{site['slug']}/"):
                    raise SystemExit("machine MQTT prefix must follow fa/<site>/...")
                if machine["id"] in seen:
                    raise SystemExit(f"duplicate machine id: {machine['id']}")
                seen.add(machine["id"])
                if not any(entity.endswith("_running") for entity in machine["entities"]):
                    raise SystemExit(f"machine {machine['id']} lacks a *_running entity")
PY

for expected in \
    'site -> line -> cell -> station' \
    'Factory Assistant is a monitoring tool, not a safety device' \
    'read-only' \
    'fa/<site>/<area>/<device>/<measurement>' \
    'Mosquitto broker add-on' \
    'cloud and analytics remain off'; do
    grep -q "$expected" "$readme" \
        || fail "onboarding README is missing expected text: $expected"
done

grep -q 'onboarding/' "$seed_script" \
    || fail "seed script comments do not mention onboarding files are copied"
grep -q 'site_model.example.yaml' "$defaults_doc" \
    || fail "industrial defaults doc does not document the site model scaffold"
grep -q 'site/line/cell onboarding scaffold' "$arch_doc" \
    || fail "architecture phase status does not mention the onboarding scaffold"
grep -q 'line/cell taxonomy scaffold' "$ui_doc" \
    || fail "UI design doc does not mention the shipped taxonomy scaffold"

echo "ok  site/line/cell onboarding scaffold is shipped and documented"
