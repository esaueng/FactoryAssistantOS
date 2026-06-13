# Industrial Defaults

What makes a Factory Assistant appliance behave like plant equipment instead
of a smart-home hub: the shipped defaults, the conventions, and where each is
implemented. The Core-side templates live under
`buildroot-external/rootfs-overlay/usr/share/factory-assistant/` —
`configuration.yaml`, the `factory-assistant` UI theme (`themes/`), the
dashboards (`dashboards/`: Plant overview, andon board, wallboard), and the
industrial example packages (`packages/`: plant KPIs, OEE, energy,
maintenance reminders, andon acknowledge), and the read-only protocol examples
(`examples/`: MQTT and Modbus, with `examples/README.md` as the naming/topic
quick reference); the UI is specified in `docs/UI_DESIGN.md`.

## 1. Defaults table

| Area | Default | Rationale | Where / phase |
|---|---|---|---|
| Hostname / discovery | `factory-assistant` (mDNS `.local`) | predictable commissioning on plant LANs | overlay — done |
| Network | DHCP out of the box; static IP first-class via NetworkManager | plants standardize on static addressing | OS (upstream capability); onboarding guidance P3 |
| Time | NTP required step in onboarding; UTC recorder timestamps, local-time display | trustworthy telemetry timelines | P3 |
| Cloud/remote access | none; analytics **off** by default | local network deployment posture | P3 (onboarding default) |
| Units | metric (`unit_system: metric`) | industrial norm; switchable per site | template — done |
| Recorder retention | `purge_keep_days: 30`, `commit_interval: 5` | bounded local history; long-term data → historian add-on | template — done |
| Terminology | "site" not "home"; areas model **line → cell → station** | matches plant mental model | template now; onboarding/frontend P3 |
| Alerting | informational notifications only | safety boundary §4 | policy — done |
| Industrial protocols | read-only (Modbus reads, OPC UA subscribe-only) | safety boundary §4 | template + add-on defaults |
| Default dashboard | "Plant overview": KPI strip + machine tiles by line, alerts, energy, maintenance views | the product's purpose | YAML template — done; native `fa-machine-card` in frontend fork P3 (`docs/UI_DESIGN.md`) |
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

## 4. Config seeding mechanism (Phase 3 work item)

The templates ship read-only in the image. Planned seeding: a small
`fa-defaults` host package (see `buildroot-external/package/README.md`) or
Supervisor hook copies the **whole `/usr/share/factory-assistant/` tree**
(`configuration.yaml`, `themes/`, `dashboards/`) into `/config` **only when
no configuration exists** (true first boot), so user changes and restores are
never overwritten. Until implemented, commissioning copies it manually — the
template headers say exactly that.

## 5. Site repo pattern (recommended practice, not shipped)

Treat each plant's `/config` as a git repo: configuration, dashboards,
register maps, and automations reviewed like code, backed up via the
Supervisor backup system before updates. This keeps fleet rollouts
reproducible across appliances.
