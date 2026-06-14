# Industrial Defaults

What makes a Factory Assistant appliance behave like plant equipment instead
of a smart-home hub: the shipped defaults, the conventions, and where each is
implemented. The Core-side templates live under
`buildroot-external/rootfs-overlay/usr/share/factory-assistant/` —
`configuration.yaml`, the `factory-assistant` UI theme (`themes/`), the
dashboards (`dashboards/`: Plant overview, andon board, wallboard), the
industrial example packages (`packages/`: plant KPIs, OEE, energy,
maintenance reminders, andon acknowledge), the read-only protocol examples
(`examples/`: MQTT and Modbus, with `examples/README.md` as the naming/topic
quick reference), and the onboarding scaffold (`onboarding/`:
`site_model.example.yaml` and `wizard_steps.yaml`), plus the industrial add-on
contract (`addons/industrial_addons.catalog.yaml`) and frontend handoff
contract (`ui/frontend_contract.yaml`), plus the Supervisor seed handoff
(`supervisor/defaults_seed_contract.yaml`) and network identity contract
(`network/network_identity_contract.yaml`); the UI is specified in
`docs/UI_DESIGN.md`.

## 1. Defaults table

| Area | Default | Rationale | Where / phase |
|---|---|---|---|
| Hostname / discovery | `factory-assistant` (mDNS `.local`) | predictable commissioning on plant LANs | overlay + `network/network_identity_contract.yaml` — done |
| Config seeding | first-boot copy of the template tree into `/config` when none exists | reproducible appliance defaults without clobbering user config | overlay scaffold — done (§4); robust path needs Supervisor hook |
| Network | DHCP out of the box; static IP first-class via NetworkManager | plants standardize on static addressing | OS (upstream capability); manual guidance now (§5), onboarding step P3 |
| Time | NTP discipline for trustworthy timestamps; UTC recorder timestamps, local-time display | trustworthy telemetry timelines | host timesyncd now; manual guidance (§5); required onboarding step P3 |
| Cloud/remote access | none; analytics **off** by default | local network deployment posture | template — done; onboarding wording P3 |
| Units | metric (`unit_system: metric`) | industrial norm; switchable per site | template — done |
| Recorder retention | `purge_keep_days: 30`, `commit_interval: 5` | bounded local history; long-term data → historian add-on | template — done |
| Terminology | "site" not "home"; areas model **line → cell → station** | matches plant mental model | template now; onboarding/frontend P3 |
| Alerting | informational notifications only | safety boundary §4 | policy — done |
| Industrial protocols | read-only (Modbus reads, OPC UA subscribe-only) | safety boundary §4 | template + add-on defaults |
| Default dashboard | "Plant overview": KPI strip + machine tiles by line, alerts, energy, maintenance views | the product's purpose | Plant overview is seeded as the default dashboard; native `fa-machine-card` is implemented in the frontend fork, but the shipped YAML template still uses stock cards until the forked frontend/dashboard wiring is promoted (`docs/UI_DESIGN.md`) |
| UI theme | `factory-assistant` dark theme (light mode included), informational state colors | shop-floor glare, 24/7 wallboards, glanceability | theme template — done |
| Logging | persistent system journal where the data partition allows | post-incident diagnosis on appliances | verify at P1 against upstream behavior |

## 2. Naming conventions

**Entity IDs** encode the physical hierarchy, lowercase snake_case:

```
sensor.<area>_<machine>_<measurement>     e.g. sensor.line1_press03_motor_temp
binary_sensor.<area>_<machine>_running   e.g. binary_sensor.line1_press03_running
```

**MQTT topics** (the OPC UA bridge and ESPHome fleet follow the same shape):

```
fa/<site>/<area>/<device>/<measurement>   e.g. fa/plant1/line1/press03/motor_temp
```

Retained messages for slow-changing states; availability topics
(`…/status`) for device liveness. MQTT discovery is the preferred way for
gateways to create entities. (Sparkplug B awareness is on the radar for the
historian/bridge add-ons, not a v1 commitment.)

The onboarding scaffold at `onboarding/site_model.example.yaml` carries the
same site → line → cell → station → machine hierarchy as data. Copy it into the
site repository during commissioning, replace the placeholder machine IDs, and
keep its MQTT/entity IDs aligned with the dashboards and packages.

The companion `onboarding/wizard_steps.yaml` is the industrial onboarding
wizard contract for the frontend/Supervisor forks. It replaces the
home-centric setup path with safety acknowledgement, site identity, line/cell
hierarchy, network posture, NTP, Mosquitto offer, cloud/analytics-off defaults,
and the Plant overview/andon/wallboard default experience.

The companion `ui/frontend_contract.yaml` is the native frontend handoff for
the same default experience: trimmed plant navigation, `fa-machine-card`,
native andon view, kiosk wallboard mode, and the monitoring-only UI safety
rules that forbid control affordances. The frontend fork now implements the
read-only `fa-machine-card`; its `about_panel` section requires the Safety
boundary and Open source licenses links in the frontend fork's About surface.

## 3. Protocol guidance

- **MQTT**: Mosquitto add-on is the assumed broker; per-device credentials;
  QoS 1 for telemetry. Keep payloads numeric/JSON-flat for recorder
  friendliness. Worked read-only example: `examples/mqtt_example.yaml`.
- **Modbus TCP**: poll PLC *gateways*/meters, not safety controllers; scan
  intervals ≥ 1 s unless justified; register maps documented per machine in
  the site repo; reads only (function codes 3/4) — never writes. Worked
  read-only example: `examples/modbus_example.yaml`.
- **OPC UA**: via the bridge add-on (P3): subscribe to a curated node set,
  republish on the `fa/...` topic convention, read-only mode hard-default.
- **ESPHome**: the retrofit path for unsensored legacy machines (vibration,
  current clamps, temperatures, andon light states).

The shipped `addons/industrial_addons.catalog.yaml` records the planned
industrial add-on contract for the separate `factory-assistant-addons`
repository: OPC UA bridge, PLC gateway helper, and historian storage are
local-first, monitoring-only, and must not add machine write/control behavior.

## 3.1 Local-first Core defaults

In the shipped `configuration.yaml`, `default_config is deliberately not used`.
Home Assistant's upstream `default_config` meta integration currently includes
home/cloud-oriented services such as Cloud, Usage Prediction, Home Assistant
Alerts, and My Home Assistant. Factory Assistant replaces it with an explicit
local-first allowlist: `backup`, `config`, `dhcp`, `energy`, `history`,
`logbook`, `ssdp`, `system_health`, and `zeroconf`, plus the industrial
recorder/frontend/Lovelace sections below it.

This means cloud/analytics defaults are off in the shipped template. Operators
can still add integrations deliberately at a site, but no remote-access,
analytics, or upstream alerting defaults are loaded just because the appliance
booted.

## 4. Config seeding mechanism

The templates ship read-only in the image at `/usr/share/factory-assistant/`.

**What ships today (best-effort scaffold).** A systemd oneshot,
`fa-seed-config.service`, runs
`/usr/libexec/fa-seed-config` on boot. It copies the **whole
`/usr/share/factory-assistant/` tree** (`configuration.yaml`, `themes/`,
`dashboards/`, `packages/`, `examples/`, `onboarding/`, `addons/`, `ui/`,
`supervisor/`) into the
Home Assistant config directory **only on a true first boot** — that is, only
when no `configuration.yaml` exists in the target. It never overwrites existing
files (`cp -Rn`), so user edits, restores, and re-runs are all safe; running
the unit on every boot is harmless and idempotent. The unit is enabled in the
rootfs overlay via a
`multi-user.target.wants` symlink. The seed script and unit are part of the
overlay (`buildroot-external/rootfs-overlay/usr/...`) and are mirrored into the
upstream build tree by `scripts/apply-overlay.sh` like any other overlay file.

**Honest limitation.** In Home Assistant OS the Core config directory is a
**Supervisor-managed data volume**, not a stable host path. The host-side hook
targets the current upstream on-disk location
(`/mnt/data/supervisor/homeassistant`), but that path is an upstream
implementation detail, and the volume may not exist (or may not yet be the
mounted target) at the moment the unit runs. When the directory is absent the
script logs and exits cleanly — it deliberately does **not** create a stray
directory. So treat this as a **scaffold**: it works opportunistically, but
robust, ordering-correct seeding will ultimately need a **Supervisor-fork
hook** that runs inside the Supervisor's own first-boot/config-provisioning
flow (the Supervisor lives in its own repo — see `docs/ARCHITECTURE.md`). The
OS image now ships `supervisor/defaults_seed_contract.yaml` as the exact
machine-readable contract for that hook: copy `/usr/share/factory-assistant`
into `/config` only when `configuration.yaml` is absent, never overwrite
existing config, and never depend on the host-side
`/mnt/data/supervisor/homeassistant` path. The companion `fa-defaults` host
package noted in
`buildroot-external/package/README.md` may later package the same script with
its Buildroot wiring; the mechanism is identical.

Either way, commissioning can also copy the tree into `/config` manually — the
template headers say exactly that.

The seeded `configuration.yaml` sets the main Lovelace dashboard to YAML mode
and points it at `dashboards/factory-overview.yaml`, so first boot lands on
Plant overview at `/lovelace`. Andon remains a separate sidebar dashboard, and
Wallboard remains a direct-URL kiosk dashboard outside the sidebar.

## 5. Deployment guidance (NTP / static IP / Mosquitto)

These are the commissioning defaults the seeded `configuration.yaml` documents
in its header. The OS image now ships `fa-network-posture`, a read-only host
helper that reports NTP synchronization, hostname/mDNS, default route, global
addresses, NetworkManager active connection/static IP posture, and the
Mosquitto offer. It does not change time, routes, NetworkManager state, add-ons,
or machine state. Surfacing the same checks as guided **first-boot onboarding
steps** still requires backend changes in Core/Supervisor (and the frontend
onboarding flow), which live in other repos. See the §1 defaults table for the
phase markers.

The companion `network/network_identity_contract.yaml` keeps the OS hostname,
`factory-assistant.local` mDNS target, local web UI URL, Core display name,
`zeroconf` requirement, static-IP guidance, NTP review, and Mosquitto offer
aligned for those external fork consumers.

- **Time / NTP (required).** Trustworthy recorder and history timestamps
  depend on a disciplined clock. The host syncs time with
  `systemd-timesyncd`; point it at the plant's NTP source and set the time
  zone during onboarding (Settings -> System -> Date & Time). Recorder
  timestamps are stored in UTC and displayed in local time.
- **Static IP (recommended).** Plants standardize on static addressing.
  Configure it through Settings -> System -> Network, which drives
  NetworkManager — **not** in `configuration.yaml`. DHCP works out of the box
  for initial commissioning and discovery (`factory-assistant.local`).
- **Mosquitto / MQTT (offer).** For MQTT sensors, gateways, and the OPC UA
  bridge, install the **Mosquitto broker** add-on (Settings -> Add-ons), then
  add the MQTT integration (Settings -> Devices & Services). Follow the
  `fa/<site>/<area>/<device>/<measurement>` topic convention from §2.
  Monitoring only — no command/control topics.

Operators can run:

```sh
fa-network-posture
```

The output is advisory and read-only; use it as the commissioning checklist
before assigning the appliance to a line, wallboard, or historian feed. Future
onboarding/Supervisor/frontend consumers should use:

```sh
fa-network-posture --json
```

That mode emits schema version `1`, stable check IDs, monitoring-only safety
metadata, and the same commissioning reminders without requiring UI code to
parse terminal text.

## 6. Site repo pattern (recommended practice, not shipped)

Treat each plant's `/config` as a git repo: configuration, dashboards,
register maps, and automations reviewed like code, backed up via the
Supervisor backup system before updates. This keeps fleet rollouts
reproducible across appliances.
