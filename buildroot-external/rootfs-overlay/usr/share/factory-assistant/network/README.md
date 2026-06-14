# Network identity contract

`network_identity_contract.yaml` is the OS-shipped source for the appliance
network identity used by onboarding, frontend, Supervisor, CLI, and docs.

The canonical host is `factory-assistant`, the mDNS target is
`factory-assistant.local`, and the local web UI URL is
`http://factory-assistant.local:8123`. This is a local-network only appliance
posture: DHCP works for initial commissioning, static IP setup is first-class
site guidance, `zeroconf` remains enabled for plant LAN discovery, and
`fa-network-posture` is the read-only checklist helper for NTP, hostname,
routes, static IP posture, and the Mosquitto offer. Onboarding, Supervisor,
frontend, and CLI consumers should call `fa-network-posture --json` when they
need stable check IDs instead of operator-facing text.
The terminology contract keeps this network copy aligned with the rest of the
product: use `Plant overview` for the default landing view, line or cell for
factory areas, and `Factory Assistant CLI` for operator-facing notes. Factory
Assistant is based on Home Assistant.

The contract is monitoring-only. It must not create machine-control paths,
claim safety-network placement, or change the upstream-compatible UI port 8123.
