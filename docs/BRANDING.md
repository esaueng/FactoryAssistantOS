# Branding Plan (initial)

The rules and the initial decisions for Factory Assistant's identity.
Trademark/legal rationale lives in `docs/LICENSE_COMPLIANCE.md` §5; this
document is the practical plan. Two absolutes up front:

1. Home Assistant branding (name as a brand, logo, `home-assistant/brands`
   assets) is **never** used as Factory Assistant branding.
2. The upstream name appears only as factual attribution, canonically:
   **“Factory Assistant is based on Home Assistant.”**, accompanied where
   appropriate by the non-affiliation statement (see [`NOTICE`](../NOTICE)).

## 1. Names

| Thing | Name | Short |
|---|---|---|
| Product / OS image | **Factory Assistant OS** | FA OS |
| Application runtime | **Factory Assistant Core** | FA Core |
| Lifecycle manager | **Factory Assistant Supervisor** | FA Supervisor |
| Web UI | **Factory Assistant frontend** | — |
| Add-on ecosystem | **Factory Assistant add-ons** | — |

Writing rules: "Factory Assistant" is two words, title case; never "FactoryAssistant"
in prose (repo slugs excepted); never abbreviate to "FA" in user-facing UI.

## 2. Identifiers

| Identifier | Value | Notes |
|---|---|---|
| OS ID / artifact prefix | `faos` | image: `faos_generic-x86-64-<ver>.img.xz`, bundles: `faos_<board>-<ver>.raucb` |
| Default hostname / mDNS | `factory-assistant` → `factory-assistant.local` | set via overlay |
| Web UI port | `8123` (unchanged) | deliberate ecosystem compatibility |
| Org/repo slugs | `factory-assistant/<component>` pattern; `REPLACE-ORG` placeholder until the org exists | mirrors upstream repo names |
| Container registry | `ghcr.io/REPLACE-ORG` | placeholder in `branding/identity.env` |
| Update/version host | `version.factory-assistant.example` | `.example` until a real domain is secured |
| Internal symbols | **unchanged from upstream** (`HASSOS_*`, `hassio`, D-Bus names, API paths) | AGENTS.md invariant 4 — branding is user-visible only |

Before any real release/OTA, replace every `REPLACE-ORG` / `.example`
placeholder; the four-item go-live checklist lives in `branding/identity.env`.

Versioning: FA OS tracks upstream MAJOR.MINOR (`docs/OS_BUILD.md` §6); Core/
Supervisor forks keep upstream version numbers with the FA registry namespace.

## 3. Assets (logo, theme)

- Master logo: the refined original mark is
  [`branding/assets/logo.svg`](../branding/assets/logo.svg), with a 16 px-tuned
  app/favicon variant [`branding/assets/icon.svg`](../branding/assets/icon.svg).
  The mark is a deliberate **industrial gauge** (open scaled arc) crossed by a
  **live monitoring pulse** — the motif pinned by the spec.
- Logo/icon: **original artwork required**; must not derive from, trace, or
  resemble the Home Assistant logo or any `home-assistant/brands` asset. The
  master is **original work** — hand-authored vector, not derived from any
  Home Assistant / `home-assistant/brands` asset (provenance:
  [`branding/assets/README.md`](../branding/assets/README.md) §5). It honours
  the direction — industrial gauge/pulse motif — and is **legible at 16 px**
  favicon size and on dark wallboards (verified by rasterising at 16 px and
  512 px with `rsvg-convert`).
- Palette: specified as design tokens in `docs/UI_DESIGN.md` §8 — graphite
  neutrals, amber `#F5A623` brand accent, distinct informational state colors
  — and implemented in the shipped `factory-assistant` theme (dark default,
  light mode included). The master mark is drawn in the single brand amber
  `#F5A623` (matching the theme's `primary-color` / `accent-color`), so it
  never reads as a state colour; the informational **state colors stay fixed**.
- State colors are **informational only** (the andon/stack-light convention,
  for operator familiarity); they carry **no ISO 3864 / ANSI Z535 safety-color
  meaning** and make no safety claim (`docs/UI_DESIGN.md` §2 principle 5, §10).
  No brand asset is named, styled, or arranged as an e-stop, interlock, safety
  alarm, or stack-light, and none depicts or invites machine control —
  Factory Assistant is **monitoring, read-only**.
- Asset inventory still to produce in Phase 2/3 (frontend follow-up): raster
  favicon set, PWA icons, landing page art, boot console text (no splash needed
  for v1), About-dialog logo, documentation header — generated from the SVG
  masters above.
- All assets live in a `factory-assistant/brands`-equivalent directory in the
  frontend fork, Apache-2.0 like the code, with provenance recorded. The
  authoritative asset spec (inventory, sizes, the original-artwork mandate, and
  the state-color disclaimer) is [`branding/assets/README.md`](../branding/assets/README.md).

## 4. Where branding lives, per repo (string inventory plan)

| Surface | Repo | Phase |
|---|---|---|
| Image name, os-release, hostname, console banner | this repo (overlay) | done |
| Landing page text/art | `landingpage` fork | P2 |
| CLI banner/MOTD | `plugin-cli` fork | P2 |
| UI product name, logo, About dialog, onboarding wording | `frontend` fork | P3 |
| Default dashboard ("Factory overview") | `frontend` fork | P3 |
| Supervisor product strings/log prefixes | `supervisor` fork | P2 |
| Core: keep delta near zero; visible naming comes from the frontend | `core` fork | P3 |

Rule of thumb when renaming strings: if a user sees it → rebrand; if code,
another repo, or the ecosystem depends on it → keep upstream.

## 5. Attribution placement

The canonical sentence (plus non-affiliation where space allows) appears in:
`README.md`, `NOTICE`, the console `/etc/issue`, the frontend About dialog
(P3), and release notes. It is not decorated, reworded into endorsement, or
accompanied by upstream logos.

## 6. Compatibility notes (not branding, but adjacent)

- Existing community add-ons and the add-on repository format keep working —
  that compatibility is a feature, not co-branding.
- Third-party clients that speak the (unchanged) API may connect at the
  user's choice; Factory Assistant does not bundle, rebrand, or imply
  endorsement of upstream's companion apps.
