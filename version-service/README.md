# version-service/ — Factory Assistant update channels

The Supervisor decides what to update by polling a **channel JSON** document
(upstream: `https://version.home-assistant.io/{stable,beta,dev}.json`,
maintained in the `home-assistant/version` repository). Factory Assistant
runs its own equivalent so that appliances in the field update to Factory
Assistant builds, never to upstream Home Assistant builds.

How it fits together (details in `docs/ARCHITECTURE.md` §Updates):

1. **OS** — the channel JSON names the current OS version per board; the
   Supervisor downloads the corresponding signed RAUC bundle (`.raucb`) from
   the Factory Assistant OS release URL and installs it to the inactive A/B
   slot.
2. **Supervisor / plugins / Core** — the channel JSON names container image
   versions; they are pulled from the Factory Assistant container registry.

`stable.json.example` shows the shape of the document. It is **illustrative**:
the authoritative schema is whatever the pinned Supervisor version parses —
derive the real file from the upstream `version` repository at fork time
(Phase 2), and validate it against the Supervisor's updater before publishing.

Operational requirements (Phase 2):

- Static hosting with TLS is sufficient (object storage / pages hosting).
- The OS image must be built pointing at this channel URL and at the Factory
  Assistant RAUC keyring — see `docs/OS_BUILD.md` §Signing and §Rebrand
  checklist. Never publish a channel that mixes Factory Assistant and
  upstream artifact URLs.
- Channels: start with `stable` only; add `beta`/`dev` when CI produces them.
