# buildroot-external/ — Factory Assistant overlay tree

This directory holds **only the Factory Assistant delta files**, mirrored at
the same relative paths as the upstream Home Assistant OS
`buildroot-external/` (Buildroot `BR2_EXTERNAL`) tree.
`scripts/apply-overlay.sh` rsyncs it over the upstream checkout: files at
existing paths replace the upstream file, new paths are added.

Rules (see `AGENTS.md`):

- Do not vendor unmodified upstream files here — keep the delta minimal.
- Keep internal identifiers upstream-compatible (`HASSOS_*` variables, the
  `hassio` package, `BR2_EXTERNAL_HASSOS_PATH`, board names). Rebrand
  user-visible values only. The upstream `external.desc` is intentionally
  **not** overlaid, because the `BR2_EXTERNAL_<NAME>_PATH` variable derived
  from it is referenced throughout upstream configs.
- When the upstream pin in `upstream.env` is bumped, re-verify each file here
  against the new tag — upstream layout moves between releases.

Contents:

| Path | Purpose |
|---|---|
| `configs/factory-assistant.config` | Defconfig fragment appended to upstream `generic_x86_64_defconfig` |
| `rootfs-overlay/etc/hostname` | Default hostname → `factory-assistant` (mDNS: `factory-assistant.local`) |
| `rootfs-overlay/etc/issue` | Console pre-login banner with factual attribution |
| `rootfs-overlay/usr/share/factory-assistant/` | Industrial default templates and handoffs: Core `configuration.yaml`, `factory-assistant` UI theme (`themes/`), "Plant overview" dashboard (`dashboards/`), network identity contract (`network/network_identity_contract.yaml`), frontend contract (`ui/frontend_contract.yaml`), Supervisor seed contract (`supervisor/defaults_seed_contract.yaml`) — see `docs/INDUSTRIAL_DEFAULTS.md` and `docs/UI_DESIGN.md` |
| `package/` | Reserved for Factory Assistant host-OS packages (see its README) |

Identity values that live in upstream files (`buildroot-external/meta`) are
rewritten in place by `scripts/apply-overlay.sh` rather than replaced
wholesale, so upstream additions to those files are never silently dropped.
