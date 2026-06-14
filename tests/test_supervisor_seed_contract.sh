#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/supervisor/defaults_seed_contract.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/supervisor/README.md"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
overlay_doc="$ROOT/buildroot-external/README.md"
package_doc="$ROOT/buildroot-external/package/README.md"
seed_script="$ROOT/buildroot-external/rootfs-overlay/usr/libexec/fa-seed-config"
seed_unit="$ROOT/buildroot-external/rootfs-overlay/usr/lib/systemd/system/fa-seed-config.service"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$contract" ] || fail "Supervisor seed contract is missing"
[ -f "$readme" ] || fail "Supervisor seed contract README is missing"

python3 - "$contract" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

if not isinstance(data, dict):
    raise SystemExit("Supervisor seed contract must be a mapping")

contract = data.get("contract") or {}
if contract.get("id") != "factory_assistant_supervisor_seed_defaults":
    raise SystemExit("Supervisor seed contract id drifted")
if contract.get("version") != 1:
    raise SystemExit("Supervisor seed contract version must be 1")
if contract.get("consumer") != "supervisor":
    raise SystemExit("Supervisor seed contract must target the Supervisor fork")
if contract.get("status") != "contract_for_supervisor_fork":
    raise SystemExit("Supervisor seed contract status must identify fork handoff")

seed = data.get("seed") or {}
if seed.get("source_tree") != "/usr/share/factory-assistant":
    raise SystemExit("Supervisor seed source must be the shipped template tree")
if seed.get("target_config_dir") != "/config":
    raise SystemExit("Supervisor seed target must be the Supervisor/Core config volume")
if seed.get("runs_inside_supervisor_first_boot") is not True:
    raise SystemExit("robust seeding must run inside Supervisor first-boot flow")
if seed.get("host_path_dependency_allowed") is not False:
    raise SystemExit("robust seeding must not depend on host implementation paths")
if seed.get("host_scaffold") != "/usr/libexec/fa-seed-config":
    raise SystemExit("contract must name the best-effort host scaffold")

first_boot = seed.get("first_boot_gate") or {}
if first_boot.get("missing_file") != "configuration.yaml":
    raise SystemExit("first-boot gate must be missing configuration.yaml")
if first_boot.get("overwrite_existing_config") is not False:
    raise SystemExit("Supervisor seed hook must never overwrite existing config")
if first_boot.get("create_stray_host_directory") is not False:
    raise SystemExit("Supervisor seed hook must not create host-side stray config directories")

expected_entries = [
    "configuration.yaml",
    "themes/",
    "dashboards/",
    "packages/",
    "examples/",
    "onboarding/",
    "addons/",
    "ui/",
    "supervisor/",
]
if seed.get("copy_entries") != expected_entries:
    raise SystemExit(f"Supervisor seed copy entries drifted: {seed.get('copy_entries')}")

safety = data.get("safety") or {}
if safety.get("monitoring_only") is not True:
    raise SystemExit("Supervisor seed contract must be monitoring-only")
if safety.get("machine_control") is not False:
    raise SystemExit("Supervisor seed contract must not allow machine control")
if safety.get("safety_function") is not False:
    raise SystemExit("Supervisor seed contract must not claim safety function behavior")
PY

for expected in \
    'Supervisor first-boot hook' \
    'never overwrite' \
    '/config' \
    '/mnt/data/supervisor/homeassistant' \
    'monitoring-only'; do
    grep -q "$expected" "$readme" \
        || fail "Supervisor seed README is missing expected text: $expected"
done

grep -q 'supervisor/defaults_seed_contract.yaml' "$seed_script" \
    || fail "seed script comments do not mention the Supervisor seed contract is copied"
grep -q 'defaults_seed_contract.yaml' "$seed_unit" \
    || fail "seed unit comments do not mention the Supervisor seed contract"
grep -q 'defaults_seed_contract.yaml' "$defaults_doc" \
    || fail "industrial defaults doc does not mention the Supervisor seed contract"
grep -q 'Supervisor seed contract' "$arch_doc" \
    || fail "architecture phase status does not mention the Supervisor seed contract"
grep -q 'defaults_seed_contract.yaml' "$overlay_doc" \
    || fail "buildroot-external README does not mention the Supervisor seed contract"
grep -q 'defaults_seed_contract.yaml' "$package_doc" \
    || fail "package README does not mention the Supervisor seed contract"

echo "ok  Supervisor seed contract is shipped for robust first-boot defaults"
