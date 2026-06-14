# Supervisor seed contract

`defaults_seed_contract.yaml` is the OS-shipped handoff for the Factory
Assistant Supervisor fork. It describes the robust first-boot hook that should
copy `/usr/share/factory-assistant` into the Supervisor-owned `/config` volume.

The Supervisor first-boot hook must run inside the Supervisor config-provisioning
flow, never overwrite an existing `configuration.yaml`, and never depend on the
host-side `/mnt/data/supervisor/homeassistant` implementation path. The existing
host unit remains a best-effort scaffold for early images and exits cleanly when
that path is unavailable.

This contract is monitoring-only. It copies templates and handoff files; it
does not write machine state, create control paths, or claim safety-function
behavior.
