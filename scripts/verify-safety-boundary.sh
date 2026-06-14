#!/usr/bin/env bash
# Verify shipped Factory Assistant defaults stay monitoring-only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

usage() {
    cat <<'EOF'
Usage: scripts/verify-safety-boundary.sh [yaml-file ...]

Scans shipped Factory Assistant YAML defaults for machine-control domains,
forbidden services, and safety contract booleans that drift away from the
monitoring-only boundary. Local helper bookkeeping is allowed.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 0 ]; then
    files=("$@")
else
    mapfile -t files < <(
        find "$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant" \
            -type f \( -name '*.yaml' -o -name '*.yml' \) | sort
    )
fi

python3 - "${files[@]}" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML is required for safety-boundary verification") from exc


class Loader(yaml.SafeLoader):
    pass


def ha_tag(loader, node):
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    return loader.construct_mapping(node)


for tag in (
    "!include",
    "!include_dir_named",
    "!include_dir_merge_named",
    "!include_dir_list",
    "!include_dir_merge_list",
    "!secret",
    "!env_var",
    "!input",
):
    Loader.add_constructor(tag, ha_tag)


BANNED_TOP_LEVEL_DOMAINS = {
    "alarm_control_panel",
    "button",
    "climate",
    "cover",
    "fan",
    "light",
    "lock",
    "switch",
}
BANNED_SERVICE_DOMAINS = BANNED_TOP_LEVEL_DOMAINS | {
    "modbus",
    "mqtt",
    "scene",
    "script",
}
ALLOWED_SERVICES = {
    "input_boolean.turn_off",
    "input_datetime.set_datetime",
    "persistent_notification.create",
}
FALSE_CONTRACT_KEYS = {
    "command_topics_allowed",
    "control_affordances_allowed",
    "control_surfaces_allowed",
    "host_network",
    "machine_control",
    "privileged",
    "safety_alarm_claim_allowed",
    "safety_controller_allowed",
    "safety_function",
    "write_functions_allowed",
    "write_nodes_allowed",
}


def fail(path, message):
    raise SystemExit(f"{path}: {message}")


def scalar_path(path):
    return ".".join(str(part) for part in path)


def check_node(node, file_path, path=()):
    if isinstance(node, dict):
        for key, value in node.items():
            key_text = str(key)
            current_path = path + (key_text,)

            if len(path) == 0 and key_text in BANNED_TOP_LEVEL_DOMAINS:
                fail(file_path, f"machine/control domain is forbidden: {key_text}")

            if key_text == "service" and isinstance(value, str):
                service = value.strip()
                service_domain = service.split(".", 1)[0]
                if service not in ALLOWED_SERVICES and service_domain in BANNED_SERVICE_DOMAINS:
                    fail(file_path, f"machine/control service is forbidden: {service}")

            if key_text in FALSE_CONTRACT_KEYS and value is True:
                fail(file_path, f"safety boundary flag must not be true: {scalar_path(current_path)}")

            if key_text == "allowed_function_codes" and isinstance(value, list):
                forbidden = [code for code in value if code not in (3, 4)]
                if forbidden:
                    fail(file_path, f"Modbus write/control function codes are forbidden: {forbidden}")

            if key_text == "type" and isinstance(value, str) and value in {
                "button",
                "custom:button-card",
                "alarm-panel",
                "thermostat",
                "humidifier",
                "media-control",
            }:
                fail(file_path, f"control-style Lovelace card is forbidden: {value}")

            check_node(value, file_path, current_path)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            check_node(value, file_path, path + (index,))


for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.is_file():
        fail(path, "YAML file not found")
    try:
        data = yaml.load(path.read_text(encoding="utf-8"), Loader=Loader)
    except yaml.YAMLError as exc:
        fail(path, f"YAML parse failed: {exc}")
    check_node(data, path)

print("safety boundary verification passed")
PY
