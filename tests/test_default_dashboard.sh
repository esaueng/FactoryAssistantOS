#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/configuration.yaml"
ui_doc="$ROOT/docs/UI_DESIGN.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
os_doc="$ROOT/docs/OS_BUILD.md"
release_doc="$ROOT/RELEASE.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

python3 - "$config" <<'PY'
import sys
import yaml

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

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.load(fh, Loader=Loader)

lovelace = data.get("lovelace") or {}
if lovelace.get("mode") != "yaml":
    raise SystemExit("lovelace.mode must be yaml so Plant overview is the first-boot default dashboard")
if lovelace.get("filename") != "dashboards/factory-overview.yaml":
    raise SystemExit("default Lovelace filename must be dashboards/factory-overview.yaml")

dashboards = lovelace.get("dashboards") or {}
if "factory-overview" in dashboards:
    raise SystemExit("Plant overview must not be a secondary dashboard; it is the default dashboard")
if dashboards.get("andon", {}).get("filename") != "dashboards/andon.yaml":
    raise SystemExit("andon YAML dashboard is missing")
if dashboards.get("wallboard", {}).get("filename") != "dashboards/wallboard.yaml":
    raise SystemExit("wallboard YAML dashboard is missing")
if dashboards.get("wallboard", {}).get("show_in_sidebar") is not False:
    raise SystemExit("wallboard must stay off the sidebar for kiosk/direct URL use")
PY

if grep -q 'mode: storage' "$config"; then
    fail "configuration.yaml still leaves the first-boot default dashboard in storage mode"
fi
grep -q 'Plant overview is the default Lovelace dashboard' "$config" \
    || fail "configuration.yaml does not document the default dashboard behavior"
grep -q 'Plant overview.*default landing.*now' "$ui_doc" \
    || fail "UI design doc does not mark Plant overview as the current default landing"
grep -q 'Plant overview is seeded as the default dashboard' "$defaults_doc" \
    || fail "industrial defaults doc does not document the seeded default dashboard"
grep -q 'Plant overview default dashboard' "$arch_doc" \
    || fail "architecture status does not mention the default Plant overview dashboard"
grep -q 'Plant overview default dashboard' "$os_doc" \
    || fail "OS build checklist does not mark the default dashboard as shipped"
if grep -Eq 'default factory dashboard.*P3|frontend branding/default experience' "$os_doc" "$release_doc"; then
    fail "status docs still list the shipped default dashboard as unresolved frontend work"
fi

echo "ok  Plant overview is the shipped default dashboard"
