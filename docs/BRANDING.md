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

Versioning: FA OS tracks upstream MAJOR.MINOR (`docs/OS_BUILD.md` §6); Core/
Supervisor forks keep upstream version numbers with the FA registry namespace.

## 3. Assets (logo, theme) — to be created

- Logo/icon: **original artwork required**; must not derive from, trace, or
  resemble the Home Assistant logo or any `home-assistant/brands` asset.
  Direction: industrial motif (e.g., abstract machine/gauge/pulse mark),
  legible at 16 px favicon size and on dark wallboards.
- Palette direction (proposal, to be finalized with the logo): industrial
  amber/safety-orange accent on graphite/dark neutrals; high contrast for
  shop-floor displays. Default frontend theme ships dark with a light option.
- Asset inventory to produce in Phase 2/3: favicon set, PWA icons, landing
  page art, boot console text (no splash needed for v1), About-dialog logo,
  documentation header.
- All assets live in a `factory-assistant/brands`-equivalent directory in the
  frontend fork, Apache-2.0 like the code, with provenance recorded.

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
