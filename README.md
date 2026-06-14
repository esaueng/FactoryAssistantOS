# Factory Assistant OS

**Factory Assistant OS** is an embedded, appliance-style operating system for
**factory and manufacturing machine monitoring**: sensors, PLC gateways, MQTT,
Modbus, and an OPC UA-ready integration structure, served through local
dashboards on the plant network.

Factory Assistant is based on Home Assistant.

It follows the same proven architecture as Home Assistant OS — a minimal,
read-only, A/B-updated Linux host that runs a Supervisor, a Core application,
a web frontend, and add-ons as containers — re-targeted at industrial
*monitoring* workloads with industrial defaults.

> ⚠️ **Safety boundary — read first.**
> Factory Assistant is a **monitoring and visualization** system. It is **not**
> a safety device and must never implement or replace emergency stops,
> interlocks, safety PLCs, or any safety-rated function. See
> [`docs/SAFETY_BOUNDARY.md`](docs/SAFETY_BOUNDARY.md).

## Status

P0 foundations and P1 buildable/bootable image work are complete. The
generic x86-64 image has been produced and boot-verified as Factory Assistant
OS 17.3, with release image, RAUC bundle, and checksum artifacts.

P2 is nearly complete: esaueng-owned component forks, GHCR image wiring,
channel validation, branded landing page/CLI images, mirrored plugins, and
scheduled upstream release/security tracking are in place; trusted OTA remains
the P2 blocker until real external Factory Assistant RAUC keys, device
keyring, repository secrets, signed release bundles, and final release
verification are configured.

P3 industrial product experience is partial. The OS image ships industrial
defaults, a Plant overview dashboard, andon/wallboard templates, network/NTP
posture handoffs, onboarding contracts, and industrial add-on catalog
contracts. The frontend fork has the visible product rebrand, About panel
contract, branded landing/onboarding links, and local-first onboarding bridge;
the frontend/Core/Supervisor fork work still needs to complete the native
industrial onboarding wizard and native factory UI experience.

## Quick start (build an x86-64 image)

On a Linux x86-64 host with `git`, `rsync`, and Docker installed:

```sh
make bootstrap   # clone pinned upstream Home Assistant OS sources into upstream/
make overlay     # apply the Factory Assistant rebrand + config overlay
make os          # build the generic-x86-64 image inside the build container
```

Artifacts land under `upstream/operating-system/output/images/` as
`faos_generic-x86-64-<version>.img.xz`. Flashing, first boot, and VM options
are covered in [`docs/OS_BUILD.md`](docs/OS_BUILD.md); cutting a published
release (CI or local host) is in [`RELEASE.md`](RELEASE.md).

> The overlay/rebrand step is verified against the pinned upstream (17.3); the
> full Buildroot compile must run on CI or a Linux host with ~50 GB disk and
> open network — see [`RELEASE.md`](RELEASE.md).

## Repository layout

| Path | Purpose |
|---|---|
| `AGENTS.md` | Working rules for human and AI contributors |
| `RELEASE.md` | Runbook for cutting a flashable release image (CI or local host) |
| `.github/workflows/build-os-image.yml` | CI pipeline that builds the x86-64 image and publishes a Release |
| `.github/workflows/lint.yml` | Fast CI: validates scripts, overlay YAML, channel JSON/schema, doc links (`make lint`) |
| `docs/ARCHITECTURE.md` | Full stack: OS layer, Supervisor, Core, frontend, add-ons, updates, first boot |
| `docs/UI_DESIGN.md` | Factory/manufacturing UI design: personas, machine tiles, screens, tokens, wallboard mode |
| `docs/OS_BUILD.md` | How to build, flash, and boot the x86-64 image; fork strategy |
| `docs/LICENSE_COMPLIANCE.md` | Apache 2.0 / third-party license and notice obligations |
| `docs/SAFETY_BOUNDARY.md` | What Factory Assistant must never do |
| `docs/BRANDING.md` | Initial branding plan (names, IDs, assets, trademark rules) |
| `docs/INDUSTRIAL_DEFAULTS.md` | Industrial default configuration and conventions |
| `buildroot-external/` | Factory Assistant delta files overlaid onto the upstream Buildroot external tree |
| `branding/identity.env` | Single source of truth for product identity values |
| `upstream.env` | Pinned upstream repositories and tags |
| `scripts/` | `bootstrap.sh`, `apply-overlay.sh`, `build.sh`, `lint.sh` (+ `lint_yaml.py`, `lint_links.py`) |
| `version-service/` | Update-channel JSON: example, `schema/channel.schema.json`, and `generate-channel.sh` |

## Scope (first target)

- Generic x86-64 image (industrial PC / NUC-class hardware, UEFI), local
  network deployment — no cloud dependency.
- Monitoring and dashboards first: machine states, sensor telemetry, energy,
  alarms-as-notifications. Machine *control* is deliberately out of scope for
  v1 (see the roadmap gating in `docs/SAFETY_BOUNDARY.md`).
- Protocols: MQTT and Modbus TCP out of the box (Core integrations), OPC UA
  via a planned bridge add-on. Structure is OPC UA-ready from day one
  (topic/entity conventions in `docs/INDUSTRIAL_DEFAULTS.md`).

## Attribution and trademarks

Factory Assistant is based on Home Assistant. Home Assistant source code is
licensed under the Apache License 2.0; all upstream license and notice files
are preserved (see [`docs/LICENSE_COMPLIANCE.md`](docs/LICENSE_COMPLIANCE.md)
and [`NOTICE`](NOTICE)).

"Home Assistant" and the Home Assistant logo are trademarks of their
respective owners (the Home Assistant project / Open Home Foundation).
Factory Assistant is an independent project, **not affiliated with or endorsed
by** the Home Assistant project, the Open Home Foundation, or Nabu Casa, Inc.
Home Assistant branding is never used as Factory Assistant branding; the name
appears only in factual attribution like the sentence above
(see [`docs/BRANDING.md`](docs/BRANDING.md)).

## License

Apache License 2.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
