# Factory Assistant onboarding scaffold

Factory Assistant is based on Home Assistant.

This directory is the OS-shipped bridge between today's manual commissioning
and the future industrial onboarding wizard. It gives operators and the
frontend/Supervisor forks one explicit shape for the plant hierarchy:

```text
site -> line -> cell -> station -> machine -> entities
```

Copy `site_model.example.yaml` into the site's configuration repository,
rename it for the plant, and replace the placeholder IDs with real lines,
cells, stations, and machines. The IDs should match the entity and MQTT topic
conventions used by the shipped dashboards and packages.

`wizard_steps.yaml` is the industrial onboarding wizard contract for the
frontend/Supervisor forks. It sequences safety acknowledgement, site identity,
line/cell hierarchy, NTP, static IP guidance, the Mosquitto broker add-on
offer, local-first privacy defaults, and the Plant overview/andon/wallboard
default experience. The network posture step consumes
`fa-network-posture --json` so the UI can show the same read-only checks
without parsing terminal text.

The build repo's area dashboard generator consumes this scaffold and emits
`dashboards/area-dashboards.example.yaml`: line-level dashboards with
`custom:fa-machine-card`, `custom:fa-andon-view`, and telemetry history cards.
The generated dashboards stay read-only and provide no machine-control path.

The frontend terminology contract keeps onboarding labels plant-floor specific:
`Plant overview` is the default landing view, the hierarchy is site -> line or
cell -> station -> machine, and operator-facing CLI notes say `Factory Assistant
CLI` even though the upstream-compatible command remains `ha`. Factory
Assistant is based on Home Assistant.

Required commissioning posture:

- Factory Assistant is a monitoring tool, not a safety device.
- Protocol mappings stay read-only.
- MQTT topics follow `fa/<site>/<area>/<device>/<measurement>`.
- Install or offer the Mosquitto broker add-on before onboarding MQTT
  gateways or the OPC UA bridge.
- Plant NTP and static-IP choices are documented here, but configured through
  the OS/Core UI or the Factory Assistant CLI.
- Local-first deployment: cloud and analytics remain off unless a site
  deliberately enables them later.

The scaffold intentionally does not create Home Assistant areas by itself and
does not configure a machine-control path. It is data for commissioning,
documentation, and future onboarding code.
