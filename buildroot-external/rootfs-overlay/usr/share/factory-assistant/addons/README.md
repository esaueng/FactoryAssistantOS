# Industrial Add-on Catalog

Factory Assistant ships this catalog as a commissioning contract for the
industrial add-ons that live outside the OS repository. It is copied with the
rest of `/usr/share/factory-assistant` on first boot so site templates,
onboarding, and future add-on repositories refer to the same defaults.

The catalog covers three planned `addons-industrial` entries:

- **OPC UA to MQTT Bridge** — subscribes to curated OPC UA nodes in read-only
  mode, publishes MQTT discovery, and uses
  `fa/<site>/<area>/<device>/<measurement>` topics.
- **PLC Gateway Helper** — normalizes read-only data from PLC gateway devices,
  meters, and protocol converters. Modbus TCP is limited to function codes 3
  and 4; write functions are not allowed.
- **Historian Storage** — the historian stores long-term telemetry through
  local InfluxDB or TimescaleDB backends fed by MQTT or Core recorder exports.

Install the Mosquitto broker add-on before commissioning MQTT gateways or the
OPC UA bridge. The add-ons are local-first by default and do not require cloud
services.

Factory Assistant is a monitoring product, not a safety device. These add-ons
must not implement emergency stops, interlocks, safety PLC logic, safety-rated
alarms, real-time control loops, or any write/control path to machines.
