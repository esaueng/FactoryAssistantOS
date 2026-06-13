# Safety Boundary

**Factory Assistant is a monitoring, visualization, and alerting system. It
is not a safety device, and it must never be designed, marketed, configured,
or relied upon as one.** This document is normative for the whole project:
code, add-ons, docs, defaults, and marketing copy.

## 1. What Factory Assistant is for

- Observing machines and processes: sensor telemetry, machine states,
  counters, energy, environmental data.
- Dashboards and wallboards on the local plant network.
- **Informational** notifications: thresholds, state changes, maintenance
  reminders.

## 2. What Factory Assistant must never do

Factory Assistant — including any add-on shipped or endorsed by the project —
must not implement, emulate, participate in, or interfere with:

- **Emergency stop (e-stop) functions** of any kind.
- **Safety interlocks** (guard doors, light curtains, two-hand controls,
  muting, zone protection).
- **Safety PLC / safety relay logic** or communication on safety protocols
  (e.g., PROFIsafe, CIP Safety, FSoE).
- **Safety-rated alarming or shutdown** (anything where failure to act, or a
  delayed/false action, could contribute to injury).
- **Real-time or closed-loop process control**, motion control, or any
  function with hard deadlines.
- Writing to PLC registers, OPC UA nodes, or fieldbus outputs in v1 — all
  shipped industrial protocol defaults are **read-only** (see §4).

These are the domain of dedicated, certified safety systems engineered to
IEC 61508 / ISO 13849-1 / IEC 62061 by qualified personnel. Factory Assistant
holds **no** SIL, PL, or any other safety rating, runs on a general-purpose,
non-deterministic OS stack, reboots for updates, and is a single node — it is
structurally unfit for safety functions, by design and on purpose.

## 3. Why this boundary is structural (not just policy)

- **No determinism**: Linux + containers + Python provide no bounded
  response time; network polling (MQTT/Modbus/OPC UA) can stall silently.
- **Availability model**: A/B updates reboot the appliance; a monitoring gap
  is acceptable, a safety gap never is.
- **No certification**: no part of the stack has been assessed for
  functional safety, and the project will not claim otherwise.

## 4. Engineering enforcement inside the product

- **Read-only defaults**: the shipped configuration template
  (`buildroot-external/rootfs-overlay/usr/share/factory-assistant/configuration.yaml`)
  contains only read paths; the OPC UA bridge add-on ships in read-only mode;
  Modbus examples use read calls only. Documentation never shows write
  examples against production machines.
- **Review gate**: any PR that adds a machine-write/control path, in any
  repo, is rejected unless the P4 roadmap gate (§6) has been explicitly
  opened and this document updated first (see `AGENTS.md` invariant 3).
- **Vocabulary ban**: features, entities, add-ons, or docs named or styled
  as "e-stop", "emergency stop", "interlock", "safety PLC", "safety alarm",
  or similar are rejected outright — including "soft" or "virtual" variants.
- **UI posture**: alerts are presented as notifications, not annunciators;
  default dashboards contain no control affordances for machinery.

## 5. Deployment guidance (for integrators and plants)

- Keep all safety functions in dedicated safety systems, designed and
  validated by qualified safety engineers per the applicable standards and
  local regulations. Factory Assistant must not be wired into e-stop chains,
  interlock circuits, or safety I/O — not even "just to monitor" them
  electrically; observe machine state via non-safety data interfaces instead
  (e.g., status registers on the standard PLC program, gateways, sensors).
- **Network segregation**: deploy on a monitoring VLAN/zone (IEC 62443-style
  zoning); never on a safety network. Prefer read-only southbound flows
  toward PLCs/gateways; see `docs/ARCHITECTURE.md` §10.
- **Alarms**: Factory Assistant notifications are informational and do not
  constitute an alarm management system (no IEC 62682 claim) — dashboards and
  notifications must never be the sole means of detecting a hazardous
  condition. Plan for the appliance being offline (updates, hardware
  failure): nothing safety- or process-critical may depend on it.
- Personnel hazards revealed by monitoring data (e.g., abnormal vibration on
  a press) must be handled through the plant's own hazard procedures.

## 6. Control roadmap gate (Phase 4, non-safety only)

Machine *control* (e.g., remotely toggling a conveyor in commissioning, or
writing a recipe setpoint) is excluded from v1. If ever introduced, it:

1. is limited to **non-safety convenience functions** — §2 remains absolute;
2. requires opening an explicit, documented roadmap gate: risk review,
   updated version of this document, opt-in (off by default), per-write
   authentication and audit logging;
3. never bypasses the plant's control hierarchy: writes go to the standard
   (non-safety) PLC program or gateway, which retains its own validation.

## 7. Disclaimer

Factory Assistant is distributed under the Apache License 2.0 **without
warranties or conditions of any kind** (License §7–8). Use in or around
machinery is at the deployer's sole risk and responsibility, within the
boundary defined here. This document must remain prominently linked from the
README and, from Phase 3, from the product UI (About page) and onboarding.
