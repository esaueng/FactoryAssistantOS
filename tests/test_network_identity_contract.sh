#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/network/network_identity_contract.yaml"
readme="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/network/README.md"
identity="$ROOT/branding/identity.env"
hostname_file="$ROOT/buildroot-external/rootfs-overlay/etc/hostname"
issue="$ROOT/buildroot-external/rootfs-overlay/etc/issue"
motd="$ROOT/buildroot-external/rootfs-overlay/etc/motd"
core_config="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/configuration.yaml"
site_model="$ROOT/buildroot-external/rootfs-overlay/usr/share/factory-assistant/onboarding/site_model.example.yaml"
helper="$ROOT/buildroot-external/rootfs-overlay/usr/bin/fa-network-posture"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
branding_doc="$ROOT/docs/BRANDING.md"
overlay_doc="$ROOT/buildroot-external/README.md"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$contract" ] || fail "network identity contract is missing"
[ -f "$readme" ] || fail "network identity README is missing"

expected_hostname="$(sed -n 's/^FAOS_HOSTNAME="\([^"]*\)"/\1/p' "$identity")"
[ -n "$expected_hostname" ] || fail "FAOS_HOSTNAME missing from identity.env"
expected_mdns="${expected_hostname}.local"
expected_url="http://${expected_mdns}:8123"

python3 - "$contract" "$expected_hostname" "$expected_mdns" "$expected_url" <<'PY'
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh)

expected_hostname = sys.argv[2]
expected_mdns = sys.argv[3]
expected_url = sys.argv[4]

if not isinstance(data, dict):
    raise SystemExit("network identity contract must be a mapping")

contract = data.get("contract") or {}
if contract.get("id") != "factory_assistant_network_identity":
    raise SystemExit("network identity contract id drifted")
if contract.get("version") != 1:
    raise SystemExit("network identity contract version must be 1")
if contract.get("status") != "os_shipped_handoff":
    raise SystemExit("network identity contract status must identify OS handoff")

identity = data.get("identity") or {}
if identity.get("hostname") != expected_hostname:
    raise SystemExit("network identity hostname must match identity.env")
if identity.get("mdns_name") != expected_mdns:
    raise SystemExit("network identity mDNS name must match hostname.local")
if identity.get("web_ui_url") != expected_url:
    raise SystemExit("network identity web UI URL must use the mDNS name on port 8123")
if identity.get("port") != 8123:
    raise SystemExit("network identity must preserve the upstream-compatible UI port")
if identity.get("product_name") != "Factory Assistant":
    raise SystemExit("network identity product name drifted")
if identity.get("core_display_name") != "Factory Assistant":
    raise SystemExit("Core display name must remain Factory Assistant")
if identity.get("local_network_only") is not True:
    raise SystemExit("network identity must be local-network only")
if identity.get("zeroconf_enabled") is not True:
    raise SystemExit("network identity must require zeroconf")

commissioning = data.get("commissioning") or {}
if commissioning.get("dhcp_default") is not True:
    raise SystemExit("network identity must keep DHCP as the default")
if commissioning.get("static_ip_guidance") is not True:
    raise SystemExit("network identity must keep static-IP guidance")
if commissioning.get("posture_helper") != "fa-network-posture":
    raise SystemExit("network identity must point at fa-network-posture")
if commissioning.get("ntp_required") is not True:
    raise SystemExit("network identity must require NTP review")
if commissioning.get("mosquitto_offer") is not True:
    raise SystemExit("network identity must keep the Mosquitto offer")

safety = data.get("safety") or {}
if safety.get("monitoring_only") is not True:
    raise SystemExit("network identity must be monitoring-only")
if safety.get("safety_network_allowed") is not False:
    raise SystemExit("network identity must forbid safety-network placement")
if safety.get("machine_control") is not False:
    raise SystemExit("network identity must not allow machine control")
PY

[ "$(tr -d '\r\n' < "$hostname_file")" = "$expected_hostname" ] \
    || fail "rootfs hostname does not match identity.env"
grep -q "$expected_url" "$issue" \
    || fail "console issue does not show the canonical web UI URL"
grep -q "$expected_url" "$motd" \
    || fail "MOTD does not show the canonical web UI URL"
grep -q 'zeroconf:' "$core_config" \
    || fail "Core template must enable zeroconf"
grep -q 'name: "Factory Assistant"' "$core_config" \
    || fail "Core template display name is not Factory Assistant"
grep -q "commissioning_host: $expected_mdns" "$site_model" \
    || fail "site model commissioning host does not match the mDNS name"
grep -q "$expected_mdns" "$helper" \
    || fail "network posture helper does not report the mDNS name"

for expected in \
    "$expected_mdns" \
    'local-network only' \
    'static IP' \
    'fa-network-posture' \
    'zeroconf'; do
    grep -q "$expected" "$readme" \
        || fail "network identity README is missing expected text: $expected"
done

grep -q 'network/network_identity_contract.yaml' "$defaults_doc" \
    || fail "industrial defaults doc does not mention the network identity contract"
grep -q 'network identity contract' "$arch_doc" \
    || fail "architecture phase status does not mention the network identity contract"
grep -q 'network_identity_contract.yaml' "$branding_doc" \
    || fail "branding doc does not mention the network identity contract"
grep -q 'network_identity_contract.yaml' "$overlay_doc" \
    || fail "buildroot-external README does not mention the network identity contract"

echo "ok  network identity contract keeps hostname, mDNS, and commissioning URLs aligned"
