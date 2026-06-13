# Factory Assistant — example conventions reference

Quick reference for the naming and topic conventions the shipped templates
under `/usr/share/factory-assistant/` follow. This consolidates the rules;
the authoritative source is [`docs/INDUSTRIAL_DEFAULTS.md`](../../../../../../docs/INDUSTRIAL_DEFAULTS.md)
(§2 naming, §3 protocol guidance) — defer to it if anything here drifts.

Everything here is **monitoring / read-only**. No example introduces a
machine-control or write path (see `docs/SAFETY_BOUNDARY.md`).

> Factory Assistant is based on Home Assistant.

## Vocabulary

- **"site", not "home".** A deployment is a *site* (a plant). The
  `homeassistant: name:` placeholder is replaced with the site name during
  onboarding.
- **Area model: line → cell → station.** Areas mirror the physical hierarchy
  rather than rooms.

## Entity IDs

Lowercase snake_case, encoding the physical hierarchy
(`INDUSTRIAL_DEFAULTS.md` §2):

```
sensor.<area>_<machine>_<measurement>          e.g. sensor.line1_press03_motor_temp
binary_sensor.<area>_<machine>_running         e.g. binary_sensor.line1_press03_running
binary_sensor.<area>_<machine>_<fault>_alert   e.g. binary_sensor.line1_press03_overtemp_alert
```

The `_running` and `_alert` suffixes are load-bearing: plant KPI sensors count
machines by matching `*_running$` / `*_alert$`, and the OEE rollup matches
`*_oee$` (see `../configuration.yaml` and `../packages/oee_example.yaml`).

## MQTT topics

Gateways, the OPC UA bridge, and the ESPHome fleet all publish on
(`INDUSTRIAL_DEFAULTS.md` §2):

```
fa/<site>/<area>/<device>/<measurement>        e.g. fa/plant1/line1/press03/motor_temp
```

Retain slow-changing states; use availability topics (`…/status`) for
liveness; MQTT discovery is the preferred way for gateways to create entities.

## Protocols (read-only)

- **MQTT** — Mosquitto add-on as broker, per-device credentials, QoS 1.
- **Modbus TCP** — poll PLC gateways/meters, function codes 3/4 (reads) only,
  scan intervals ≥ 1 s. Never configure writes.
- **OPC UA** — via the bridge add-on (P3): subscribe-only, republished onto the
  `fa/…` topics above.
- **ESPHome** — retrofit path for unsensored legacy machines.

Worked read-only starting points live beside this file:
[`mqtt_example.yaml`](mqtt_example.yaml) (MQTT discovery + manual sensors) and
[`modbus_example.yaml`](modbus_example.yaml) (Modbus TCP, function codes 3/4
only; documentation host `192.0.2.x` — replace at commissioning).
[`../configuration.yaml`](../configuration.yaml) carries the matching setup
notes and points at both files.

## Example packages

Per-machine templates loaded via `packages: !include_dir_named packages`. They
render **unavailable** until mapped to real entities — copy a block per machine
at commissioning.

- [`../packages/kpi_example.yaml`](../packages/kpi_example.yaml) — the plant
  KPI-strip sensors `sensor.plant_machines_running` / `plant_active_alerts`
  (derived automatically from the `*_running` / `*_alert` convention) and the
  `plant_shift_output` placeholder.
- [`../packages/energy_example.yaml`](../packages/energy_example.yaml) —
  read-only power/energy metering: `sensor.plant_power_now` (incomer), a
  per-line power template, and shift/daily `utility_meter` kWh rollups.
- [`../packages/oee_example.yaml`](../packages/oee_example.yaml) — OEE
  (availability × performance × quality) plus the plant-wide `sensor.plant_oee`
  KPI rollup.
- [`../packages/maintenance_example.yaml`](../packages/maintenance_example.yaml)
  — runtime-hours service reminders (informational notification + `_service_due`
  alert).
- [`../packages/andon_example.yaml`](../packages/andon_example.yaml) — andon
  acknowledge bookkeeping (`_ack` helpers; ack never silences or clears a real
  alert condition).

The full plant KPI strip — `sensor.plant_machines_running`,
`plant_active_alerts`, `plant_shift_output` (KPI package), `plant_power_now`
(energy package), and `plant_oee` (OEE package) — is provided by the packages
above. The Energy *view* in `../dashboards/factory-overview.yaml` reuses Core's
native energy dashboard on top of `energy_example.yaml`'s meters.

## Placeholder IDs — remap at commissioning

The `<area>_<machine>` identifiers shipped in the templates and dashboards are
**placeholders illustrating the pattern**, not real machines. Remap them to the
site's actual entities (and the matching `fa/…` topics) during commissioning:

| Placeholder | Appears in |
|---|---|
| `line1_press03` | packages (OEE, maintenance, andon), dashboards |
| `line1_press01` | dashboards |
| `line1_pack01`  | dashboards |
| `line1_weld02`  | dashboards |
| `line2_extr01`  | andon package, dashboards |
| `line2_extr02`  | dashboards |
| `line2_pal01`   | dashboards |
| `line2_wind01`  | dashboards |

`line1_press03` is the worked example carried through every package, so it is
the cleanest one to copy when adding a real machine.

## Seeding

These files ship read-only in the OS image. Copying the
`/usr/share/factory-assistant/` tree into `/config` on first boot is a Phase 3
work item (`INDUSTRIAL_DEFAULTS.md` §4); until then, commissioning copies them
manually.
