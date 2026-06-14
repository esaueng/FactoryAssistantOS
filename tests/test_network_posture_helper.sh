#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$ROOT/buildroot-external/rootfs-overlay/usr/bin/fa-network-posture"
motd="$ROOT/buildroot-external/rootfs-overlay/etc/motd"
defaults_doc="$ROOT/docs/INDUSTRIAL_DEFAULTS.md"
arch_doc="$ROOT/docs/ARCHITECTURE.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -x "$helper" ] || fail "fa-network-posture helper is missing or not executable"

grep -q 'Monitoring only - not a safety device' "$helper" \
    || fail "posture helper must state the safety boundary"
grep -q 'Mosquitto broker add-on' "$helper" \
    || fail "posture helper must offer Mosquitto for MQTT commissioning"
grep -q 'static IP' "$helper" \
    || fail "posture helper must provide static-IP guidance"
if grep -q 'HA CLI' "$helper"; then
    fail "posture helper still uses upstream HA CLI wording"
fi

if grep -Eq 'nmcli[[:space:]]+connection[[:space:]]+(modify|up|down|delete)|ip[[:space:]]+addr[[:space:]]+add|timedatectl[[:space:]]+set-' "$helper"; then
    fail "posture helper must remain read-only and must not modify network/time state"
fi

cat > "$tmp/timedatectl" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "show" ] && [ "$2" = "-p" ] && [ "$3" = "NTPSynchronized" ]; then
    echo "yes"
elif [ "$1" = "show" ] && [ "$2" = "-p" ] && [ "$3" = "Timezone" ]; then
    echo "America/Detroit"
else
    exit 1
fi
EOF

cat > "$tmp/ip" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "route" ] && [ "$2" = "show" ] && [ "$3" = "default" ]; then
    echo "default via 192.0.2.1 dev eth0 proto dhcp"
elif [ "$1" = "-brief" ] && [ "$2" = "addr" ] && [ "$3" = "show" ] && [ "$4" = "scope" ] && [ "$5" = "global" ]; then
    echo "eth0             UP             192.0.2.10/24"
else
    exit 1
fi
EOF

cat > "$tmp/nmcli" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-t" ] && [ "$2" = "-f" ] && [ "$3" = "NAME,DEVICE,IP4.METHOD" ]; then
    echo "Plant LAN:eth0:manual"
else
    exit 1
fi
EOF

cat > "$tmp/hostname" <<'EOF'
#!/usr/bin/env bash
echo "factory-assistant"
EOF

chmod +x "$tmp/timedatectl" "$tmp/ip" "$tmp/nmcli" "$tmp/hostname"

FA_POSTURE_TIMEDATECTL="$tmp/timedatectl" \
FA_POSTURE_IP="$tmp/ip" \
FA_POSTURE_NMCLI="$tmp/nmcli" \
FA_POSTURE_HOSTNAME="$tmp/hostname" \
    "$helper" > "$tmp/posture.out"

FA_POSTURE_TIMEDATECTL="$tmp/timedatectl" \
FA_POSTURE_IP="$tmp/ip" \
FA_POSTURE_NMCLI="$tmp/nmcli" \
FA_POSTURE_HOSTNAME="$tmp/hostname" \
    "$helper" --json > "$tmp/posture.json"

grep -q 'Factory Assistant network/time posture' "$tmp/posture.out" \
    || fail "posture output is missing the title"
grep -q '\[OK\] NTP synchronized' "$tmp/posture.out" \
    || fail "posture output did not report synchronized NTP"
grep -q '\[OK\] Default route present' "$tmp/posture.out" \
    || fail "posture output did not report default route"
grep -q '\[INFO\] NetworkManager active connection: Plant LAN on eth0 uses manual IPv4' "$tmp/posture.out" \
    || fail "posture output did not report static IPv4 status"
grep -q 'Install the Mosquitto broker add-on' "$tmp/posture.out" \
    || fail "posture output did not offer Mosquitto"
grep -q 'Monitoring only - not a safety device' "$tmp/posture.out" \
    || fail "posture output did not include the safety posture"
if grep -q 'HA CLI' "$tmp/posture.out"; then
    fail "posture output still uses upstream HA CLI wording"
fi

python3 - "$tmp/posture.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

if data.get("schema_version") != 1:
    raise SystemExit("posture JSON schema_version must be 1")
if data.get("product") != "Factory Assistant":
    raise SystemExit("posture JSON product must be Factory Assistant")
if data.get("helper") != "fa-network-posture":
    raise SystemExit("posture JSON helper id drifted")
safety = data.get("safety") or {}
if safety.get("monitoring_only") is not True:
    raise SystemExit("posture JSON must state monitoring_only safety posture")
if safety.get("machine_control") is not False:
    raise SystemExit("posture JSON must state machine_control is false")

checks = {check.get("id"): check for check in data.get("checks") or []}
expected = {
    "ntp_synchronized": ("OK", "yes"),
    "time_zone": ("INFO", "America/Detroit"),
    "hostname_mdns": ("OK", "factory-assistant"),
    "default_route": ("OK", "default via 192.0.2.1 dev eth0 proto dhcp"),
    "global_address": ("INFO", "eth0             UP             192.0.2.10/24"),
    "networkmanager_ipv4_method": ("INFO", "manual"),
}
for check_id, (level, value) in expected.items():
    check = checks.get(check_id)
    if not check:
        raise SystemExit(f"posture JSON missing check: {check_id}")
    if check.get("level") != level:
        raise SystemExit(f"posture JSON {check_id} level drifted: {check.get('level')}")
    if check.get("value") != value:
        raise SystemExit(f"posture JSON {check_id} value drifted: {check.get('value')}")

reminders = "\n".join(data.get("reminders") or [])
for phrase in ("Static IP", "NTP", "Mosquitto", "Safety"):
    if phrase not in reminders:
        raise SystemExit(f"posture JSON reminders missing: {phrase}")
PY

grep -q 'fa-network-posture' "$motd" \
    || fail "MOTD does not tell operators about the posture helper"
grep -q 'fa-network-posture' "$defaults_doc" \
    || fail "industrial defaults doc does not document the posture helper"
grep -q -- '--json' "$defaults_doc" \
    || fail "industrial defaults doc does not document posture JSON output"
grep -q 'network/time posture helper' "$arch_doc" \
    || fail "architecture status does not mention the posture helper"

echo "ok  network/time posture helper is shipped and documented"
