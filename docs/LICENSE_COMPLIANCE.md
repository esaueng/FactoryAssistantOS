# License & Notice Compliance

Factory Assistant is a derivative of Home Assistant and ships a Linux system
image full of third-party software. This document is the standing policy for
staying compliant. It is engineering guidance, not legal advice; have counsel
review before commercial distribution.

## 1. License inventory (verify at fork time)

| Component | Upstream | License |
|---|---|---|
| Home Assistant Core | `home-assistant/core` | Apache-2.0 |
| Home Assistant Supervisor | `home-assistant/supervisor` | Apache-2.0 |
| Home Assistant frontend | `home-assistant/frontend` | Apache-2.0 |
| Home Assistant OS (build tree) | `home-assistant/operating-system` | Apache-2.0 |
| os-agent, builder, add-ons repos | `home-assistant/*` | Apache-2.0 (some add-ons MIT — check per add-on) |
| Buildroot (build system) | buildroot.org fork | GPL-2.0-or-later (build tool; its license does not extend to the images it produces) |
| Linux kernel | kernel.org | GPL-2.0 (with syscall exception) |
| systemd | freedesktop | LGPL-2.1-or-later |
| Docker Engine (moby) | moby project | Apache-2.0 |
| RAUC | rauc.io | LGPL-2.1 |
| BusyBox, GNU userland pieces | various | GPL-2.0 / LGPL |
| Python + Core's dependency set | PyPI | PSF + many (generate per-release report) |
| **Home Assistant brand assets** | `home-assistant/brands` | **Not licensed for our use — never copy (see §5)** |

Policy: re-verify each repo's `LICENSE`/`NOTICE` at the moment of forking and
at every upstream version bump; record surprises here.

## 2. Apache-2.0 obligations (the four main repos)

For every fork we distribute (source or image), Apache License 2.0 §4
requires us to:

1. **Ship the license** — keep upstream `LICENSE` files in place; this repo
   carries its own copy at the root.
2. **Mark modified files** — files we change carry a prominent change notice.
   Convention: a short header line
   `# Modified by Factory Assistant contributors — <year>; see git log.`
   plus honest git history. New first-party files use the standard Apache-2.0
   header with `Copyright <year> Factory Assistant contributors`.
3. **Retain notices** — never delete or rewrite upstream copyright, patent,
   trademark, or attribution notices in source files we keep.
4. **Carry NOTICE forward** — upstream repos that include a `NOTICE` file
   keep it; our own [`NOTICE`](../NOTICE) adds Factory Assistant's
   attribution (including the canonical sentence “Factory Assistant is based
   on Home Assistant.”) and must be included in derivative distributions.

## 3. Copyleft components in the OS image

The flashable image aggregates GPL/LGPL components (kernel, BusyBox, glibc
or musl, systemd, RAUC, …). Aggregation alongside Apache-2.0 code is fine;
the obligation is **source availability** for the copyleft components as
built:

- Run Buildroot **`make legal-info`** for every release configuration. It
  emits license texts, source archives, and a manifest for everything in the
  image.
- Publish the `legal-info` output (or at minimum the manifest + license
  texts plus a written source offer) alongside each release, and archive it
  with the release artifacts.
- Kernel/bootloader modifications (patches in the build tree) are part of
  the published sources automatically — keep them in-tree, never binary-only.

## 4. Container & Python/JS dependency notices

- Core/Supervisor/add-on container images embed OS packages (Alpine/Debian
  bases) and language dependencies. Upstream base images already aggregate
  their notices; when we rebuild under the FA registry we inherit that — keep
  base-image provenance unchanged and regenerate dependency license reports
  (e.g., `pip-licenses` for Core's venv, the frontend's bundled license
  output) per release.
- Add a "Open source licenses" page/link in the frontend fork's About dialog
  pointing at the per-release bundle (Phase 3).

## 5. Trademarks and branding compliance

Apache-2.0 §6 grants **no trademark rights**. Concretely:

- "Home Assistant", its logo, and assets in `home-assistant/brands` are
  trademarks of their respective owners (Home Assistant project / Open Home
  Foundation). **Never** use them as Factory Assistant branding: not in the
  UI, boot splash, docs headers, app icons, or marketing.
- The upstream name appears **only** in factual attribution, canonically:
  “Factory Assistant is based on Home Assistant.” — plus the non-affiliation
  statement (see [`NOTICE`](../NOTICE) and `docs/BRANDING.md`).
- Do not register or use confusingly similar marks/domains; do not imply
  endorsement or compatibility certification.
- All Factory Assistant logos/assets must be original work
  (`docs/BRANDING.md` §Assets).

## 6. Release checklist (every release)

- [ ] `LICENSE` and `NOTICE` present and current in every distributed repo.
- [ ] Modified upstream files carry change notices (§2.2 convention).
- [ ] Buildroot `make legal-info` run; output archived and published with
      the release.
- [ ] Dependency license reports regenerated for rebuilt container images.
- [ ] No `home-assistant/brands` assets or upstream logos anywhere in
      shipped artifacts (grep the frontend bundle for upstream asset names).
- [ ] Attribution + non-affiliation statement intact in README/NOTICE/UI.
- [ ] No private keys/certs in artifacts or git history.
