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

## Files

| File | Purpose |
|---|---|
| `stable.json.example` | Illustrative `stable` channel document |
| `schema/channel.schema.json` | JSON Schema (draft 2020-12) for a channel document; validated in CI (`make lint`) |
| `generate-channel.sh` | Produce a channel document from `branding/identity.env` + version flags, validated against the schema |

## Generating a channel document

`generate-channel.sh` reads the registry and OTA URL from
`branding/identity.env` (the single source of truth) so the registry and OS
download host never drift between the image build and the channel:

```sh
./version-service/generate-channel.sh \
    --channel stable --supervisor 2026.05.0 --core 2026.5.0 \
    --os-board generic-x86-64 --os-version 17.3 --out stable.json
```

Plugin versions (`--dns/--audio/--cli/--multicast/--observer`) default to the
supervisor version. When `check-jsonschema` or `python3`+`jsonschema` is
available the output is validated against `schema/channel.schema.json` before
it is written (CI installs a validator); otherwise it is emitted with a
warning. The schema is **advisory** — it encodes the shape of the example, not
a guarantee about a future Supervisor. Always re-validate against the pinned
Supervisor's updater before publishing (next paragraph).

Operational requirements (Phase 2):

- Static hosting with TLS is sufficient (object storage / pages hosting).
- The OS image must be built pointing at this channel URL and at the Factory
  Assistant RAUC keyring — see `docs/OS_BUILD.md` §Signing and §Rebrand
  checklist. Never publish a channel that mixes Factory Assistant and
  upstream artifact URLs.
- Channels: start with `stable` only; add `beta`/`dev` when CI produces them.
