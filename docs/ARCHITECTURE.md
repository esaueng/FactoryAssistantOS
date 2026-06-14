# Factory Assistant — Architecture

Factory Assistant mirrors the Home Assistant architecture (Factory Assistant
is based on Home Assistant) and re-targets it at factory/manufacturing
machine monitoring. This document covers every layer: the OS, the
Supervisor, Core, the frontend, add-ons, the update mechanism, first boot,
and the industrial data flows the system exists to serve.

## 1. System overview

```
┌─────────────────────────── Factory floor network (OT) ───────────────────────────┐
│   sensors / ESPHome nodes        PLCs & gateways            OPC UA servers       │
└──────────────┬───────────────────────────┬──────────────────────────┬────────────┘
               │ MQTT                      │ Modbus TCP               │ OPC UA
┌──────────────▼───────────────────────────▼──────────────────────────▼────────────┐
│                  Factory Assistant OS appliance (generic x86-64)                  │
│                                                                                   │
│   Containers (managed by the Supervisor, run by Docker Engine):                   │
│   ┌───────────────────────────────────────────────────────────────────────────┐  │
│   │ Add-ons: Mosquitto broker · OPC UA→MQTT bridge* · Node-RED* · SSH/editor  │  │
│   │ FA Core — entities, automations, recorder        (* = planned)            │  │
│   │ FA frontend — dashboards, served by Core on :8123                         │  │
│   │ FA Supervisor — lifecycle, add-ons, backups, updates                      │  │
│   │ Plugins: dns · audio · cli · multicast · observer                         │  │
│   └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
│   Host OS: Linux (Buildroot) · systemd · NetworkManager · Docker · RAUC ·         │
│            os-agent (D-Bus)                                                       │
│   Storage: A/B read-only system partitions · overlay · data partition             │
└───────────────────────────────────────────────────────────────────────────────────┘
                               │
                  Plant clients (browsers, wallboard/kiosk displays)
                  http://factory-assistant.local:8123 — local network only
```

Design stance: **monitoring and dashboards first.** The appliance observes
machines and visualizes/alerts; it does not control them in v1, and it never
implements safety functions at any phase (`docs/SAFETY_BOUNDARY.md`).

## 2. Repository map (fork/mirror plan)

Factory Assistant follows the upstream multi-repo layout. "Fork strategy"
states how far each fork diverges; the standing rule is **minimal delta,
track upstream tags** (AGENTS.md invariant 4).

| Factory Assistant repo | Upstream | Role | Fork strategy |
|---|---|---|---|
| `operating-system` (this repo) | `home-assistant/operating-system` | Buildroot-based appliance OS image | Phase 1: overlay onto pinned upstream (working today). Phase 2: true fork with periodic tag merges |
| `supervisor` | `home-assistant/supervisor` | Container/lifecycle manager | Fork; deltas limited to registry namespace, update channel URL, product strings, OS identity acceptance |
| `core` | `home-assistant/core` | Application runtime, integrations (MQTT, Modbus, …) | Fork; near-zero delta, track upstream releases for integration/security fixes |
| `frontend` | `home-assistant/frontend` | Web UI | Fork; branding strings/assets, industrial default dashboard, onboarding wording |
| `addons` | `home-assistant/addons` | Official add-ons (Mosquitto, SSH, …) | Fork; keep upstream add-ons, add industrial ones |
| `addons-industrial` | — (new) | OPC UA bridge, PLC gateway helpers, historian | New repo, Apache 2.0 |
| `os-agent` | `home-assistant/os-agent` | Host D-Bus agent for the Supervisor | Mirror, initially unmodified |
| `plugins` (dns/audio/cli/multicast/observer) | `home-assistant/plugin-*` | Supervisor system plugins | Mirror; rebuild under FA registry, CLI banner rebrand |
| `landingpage` | `home-assistant/landingpage` | First-boot "preparing" page | Fork; branding only |
| `builder` | `home-assistant/builder` | Container image build tooling | Mirror, config pointed at FA registry |
| `version` → `version-service/` here | `home-assistant/version` | Update channel JSON | Re-implemented for FA endpoints (see `version-service/`) |

Mirroring is plain git: `git clone --mirror <upstream>` then push to the
Factory Assistant org; development forks add `upstream` as a remote and merge
release tags on a cadence (see `docs/OS_BUILD.md` §Fork strategy).

## 3. OS layer

The host OS is a minimal, fixed-purpose Linux built with **Buildroot**
(upstream maintains a Buildroot fork as a git submodule, plus a
`BR2_EXTERNAL` tree — `buildroot-external/` — with board configs, packages,
kernel/bootloader configs, and a rootfs overlay).

Key properties inherited from upstream and kept by Factory Assistant:

- **Read-only system**: the rootfs is an immutable compressed image
  (SquashFS/EROFS depending on release); `/etc` customization goes through an
  overlay partition; all mutable state lives on the **data partition**
  (`/mnt/data`), which holds Docker storage, Core config, add-on data, and
  backups.
- **A/B updates with RAUC**: GPT disk with paired kernel/system slots
  (boot/EFI, kernel A+B, system A+B, bootstate, overlay, data). An OS update
  installs a signed RAUC bundle into the inactive slot and reboots into it;
  a failed boot falls back automatically to the previous slot. This is the
  right model for an unattended box on a factory floor.
- **Boot chain (x86-64)**: UEFI → GRUB2 (reads A/B boot state) → kernel →
  systemd → NetworkManager (DHCP by default, static-friendly) → Docker
  Engine → Supervisor service.
- **os-agent**: a small Go daemon exposing host operations (data-disk move,
  system info, reboot/shutdown) to the Supervisor over D-Bus.
- **Console**: a getty with the Factory Assistant banner; day-2 host access
  is intentionally limited — administration happens through the web UI and
  the CLI plugin.

Industrial notes: target hardware is fanless industrial PC / NUC-class
x86-64 with UEFI; hardware watchdog support where available; time sync via
NTP is part of the industrial defaults (`docs/INDUSTRIAL_DEFAULTS.md`).

## 4. Supervisor layer

The Supervisor is the appliance's brain: a long-running container that
manages everything else.

- Starts and supervises **Core**, the **plugins** (dns: CoreDNS; audio:
  PulseAudio; cli; multicast: mDNS reflection; observer: out-of-band status
  page), and **add-ons**.
- **Add-on model**: an add-on is a Docker image plus a `config.yaml`
  manifest (ports, volumes, privileges, ingress into the UI). Add-on
  *repositories* are git repos with a defined layout. Factory Assistant keeps
  this contract unchanged, so existing community add-ons remain installable —
  a deliberate compatibility decision.
- **Backups**: full/partial snapshots (Core config, add-on data) to the data
  partition or network targets; essential for plant maintenance windows.
- **Updates**: polls the Factory Assistant channel JSON and orchestrates OS
  (via RAUC/os-agent), Supervisor, plugin, Core, and add-on updates
  (§7).
- **Health/support checks**: the Supervisor flags unsupported/unhealthy
  states. Some checks inspect OS identity (`/etc/os-release`); the fork must
  accept Factory Assistant OS identity — tracked in the rebrand checklist
  (`docs/OS_BUILD.md`).

## 5. Core layer

Factory Assistant Core is a minimally-patched Home Assistant Core: the
entity/state model, automation engine, recorder (SQLite by default), auth,
and the integration ecosystem. The industrial-relevant built-ins:

- **MQTT** integration (+ Mosquitto broker add-on) — primary transport for
  sensors and machine gateways, including MQTT discovery.
- **Modbus** integration — native Modbus TCP polling of PLC gateways and
  meters; configured read-only per the safety boundary.
- **ESPHome** — practical path for retrofit sensing (temperature, vibration,
  current clamps, stack lights) on commodity microcontrollers.
- Automations/alerts: threshold and state-change alerts as *informational*
  notifications (not safety alarms — see `docs/SAFETY_BOUNDARY.md`).

OPC UA is **not** a Core built-in; it enters through the bridge add-on (§8).
Long-term historian storage (InfluxDB/TimescaleDB add-on) is a planned
add-on; the recorder keeps a bounded local window
(`docs/INDUSTRIAL_DEFAULTS.md`).

## 6. Frontend layer

The UI is designed for the plant floor, not the home — the full specification
(personas, status-first principles, machine-state vocabulary and tile
grammar, screen inventory, design tokens, wallboard/kiosk mode, and the
no-control-affordances rule) lives in **`docs/UI_DESIGN.md`**. Shipping today
inside the OS image: the `factory-assistant` theme (dark default), the "Plant
overview" dashboard template, and the `ui/frontend_contract.yaml` frontend
experience contract under `/usr/share/factory-assistant/`. Stock dashboards
run on an unmodified Core now; the frontend fork consumes the contract for
the deeper P3 changes — `fa-machine-card` tile, trimmed navigation, native
andon board, kiosk toggle, industrial terminology and onboarding — while
carrying the visible product identity (`docs/BRANDING.md`). It stays
API-compatible with Core, served on port **8123** (kept for ecosystem
compatibility).

## 7. Update mechanism

Three planes, all anchored on the channel JSON (`version-service/`):

| Plane | Artifact | Transport | Integrity |
|---|---|---|---|
| OS | RAUC bundle (`faos_<board>-<ver>.raucb`) | Downloaded by Supervisor, installed via RAUC to inactive A/B slot, reboot, auto-rollback on boot failure | **Factory Assistant** X.509 signature; device keyring baked into image (never upstream's keys, never dev keys in shipped images) |
| Supervisor & plugins | Container images | Pulled from FA registry on channel bump | Registry TLS + image digests |
| Core / frontend / add-ons | Container images | Supervisor-orchestrated pull, user-confirmed or scheduled | Registry TLS + image digests |

Plant-floor policy: updates are **pull-based and operator-scheduled** (no
forced updates mid-shift); A/B rollback bounds the blast radius; offline
plants can sideload OS bundles and images via the CLI. Keeping FA versions
aligned with upstream MAJOR.MINOR (e.g., FA OS 16.2 ≙ upstream 16.2 + delta)
keeps security patch provenance obvious.

## 8. Add-ons (industrial integration plan)

Initial set, in priority order:

1. **Mosquitto MQTT broker** (upstream add-on, kept) — the data backbone.
2. **OPC UA → MQTT bridge** (new, `addons-industrial`) — subscribes to OPC UA
   server nodes **read-only** and republishes on the FA topic convention;
   this is the "OPC UA-ready structure": entities arrive via MQTT discovery
   without Core changes.
3. **File editor / SSH terminal** (upstream add-ons) — commissioning tools.
4. **Node-RED** (community, optional) — protocol glue for odd gateways.
5. **Historian (InfluxDB or TimescaleDB)** (planned) — long-term telemetry.
6. **ESPHome dashboard** (upstream add-on) — retrofit sensor fleet management.

The OS image ships an industrial add-on catalog at
`/usr/share/factory-assistant/addons/industrial_addons.catalog.yaml`. It is a
contract for the separate `addons-industrial` repository, not executable add-on
code: OPC UA, PLC gateway helper, and historian entries are local-first,
monitoring-only, and explicitly disallow machine control or safety functions.

## 9. First boot and onboarding

1. Flash image → boot: system expands the data partition on first start.
2. Supervisor starts; the **landing page** ("Preparing Factory Assistant…",
   FA-branded) is served on :8123 while the Core image is fetched or
   activated.
3. Core's **onboarding wizard** runs at first UI access: create the admin
   account, set site name/location/time zone/units.
4. **Industrial onboarding (Phase 3 fork work)**: replace home-centric steps
   with site/line/cell area setup using the OS-shipped
   `onboarding/site_model.example.yaml` scaffold and
   `onboarding/wizard_steps.yaml` industrial onboarding wizard contract, NTP
   check, static-IP guidance, Mosquitto add-on offer, seed the default config template
   (`buildroot-external/rootfs-overlay/usr/share/factory-assistant/configuration.yaml`),
   and default analytics/cloud features to **off** (local network deployment
   is the product posture).

## 10. Network architecture

- Appliance on the plant LAN; discovery via mDNS (`factory-assistant.local`);
  DHCP default, static IP supported via NetworkManager (CLI plugin or UI).
- Recommended placement: a **monitoring VLAN/DMZ** between OT and IT —
  read-only southbound toward PLCs/gateways (Modbus/OPC UA/MQTT), HTTPS/UI
  northbound to plant clients. Never on a safety network
  (`docs/SAFETY_BOUNDARY.md` §Deployment).
- No cloud dependency: no remote-access tunnel, no external accounts; IEC
  62443-style zoning is the deployer's reference model for segmentation.

## 11. Phasing

| Phase | Deliverable | Status |
|---|---|---|
| P0 | This repo: architecture, build path, licensing, branding, safety boundary | complete |
| P1 | Verified x86-64 image build via overlay; boots to onboarding on real hardware/VM | complete for generic x86-64 17.3 release |
| P2 | True forks, FA registry, version service, branded landingpage, RAUC keys, CI release pipeline | partial: registry/channel/release wiring, branded landingpage image, and upstream release/security tracker exist; trusted OTA requires real external RAUC keys/secrets and final release verification |
| P3 | Industrial onboarding, config seeding, OPC UA bridge add-on, frontend fork implementing the factory UI (`docs/UI_DESIGN.md`) | partial: seed config, Plant overview default dashboard, examples, site/line/cell onboarding scaffold, industrial onboarding wizard contract, frontend experience contract, industrial add-on catalog, wallboard, theme, OS-level network/time posture helper, and local-first Core defaults exist; cloud/analytics defaults are off in the shipped template; add-ons/frontend fork remain |
| P4 | Limited **non-safety** machine control behind an explicit gate (see `docs/SAFETY_BOUNDARY.md` §Control roadmap gate) | gated |
