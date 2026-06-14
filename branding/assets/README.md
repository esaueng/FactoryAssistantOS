# branding/assets/ — Factory Assistant brand assets (spec + holding dir)

This directory is the home for Factory Assistant's **original brand artwork**
(logo/icon, favicon set, PWA icons, landing-page and About-dialog art,
documentation header). Until those assets are produced and reviewed it holds
only this README, which doubles as the directory marker. The file is the
**authoritative asset specification**; the practical branding plan it
implements is `docs/BRANDING.md` §3, and the colour tokens it pins are
`docs/UI_DESIGN.md` §8.

Work item: **FA-P2-11** (Phase 2). This is specs only — no artwork is created
or described here, and nothing in this repo derives from, traces, or resembles
any Home Assistant asset (see the absolute rule below).

## 1. The absolute rule (read first)

All Factory Assistant artwork must be **original work**. No asset may derive
from, trace, recolour, or resemble the Home Assistant logo or any asset in the
`home-assistant/brands` repository, in whole or in part. This holds for every
surface: UI, favicon, PWA/app icons, landing page, About dialog, docs headers,
and any marketing material (`docs/BRANDING.md` §1, §3; `docs/LICENSE_COMPLIANCE.md`
§5).

Apache-2.0 grants **no trademark rights** (§6 of the licence). "Home
Assistant", its logo, and the `home-assistant/brands` assets are trademarks of
their respective owners and are **never** used as Factory Assistant branding.
The only permitted reference to the upstream name is the factual attribution,
canonically: **"Factory Assistant is based on Home Assistant."** — accompanied
by the non-affiliation statement where space allows (see [`NOTICE`](../../NOTICE)).
Attribution is text; it is never rendered with, or alongside, an upstream logo.

Direction for the original mark: an industrial motif (e.g. an abstract
machine / gauge / pulse mark) that reads as a monitoring appliance, **legible
at 16 px favicon size and on dark wallboards viewed at 3–8 m**
(`docs/UI_DESIGN.md` §1, §2). The mark must work within the design tokens of
§3 below; the brand accent may be tuned when the logo lands, but the
informational state colours stay fixed.

## 2. Required original assets

The inventory to produce in Phase 2/3 (`docs/BRANDING.md` §3). All entries are
original artwork; sizes are targets, refined when the mark is designed.

| Asset | Target sizes / formats | Notes |
|---|---|---|
| Primary logo / wordmark | scalable SVG master + raster exports | App header, About dialog, docs; works on dark (default) and light |
| App icon / mark | scalable SVG master; **must stay legible at 16 px** | The mark reduced to the favicon and PWA icon; must read on dark wallboards |
| Favicon set | 16, 32, 48 px PNG + multi-size `.ico`; SVG favicon | 16 px legibility is the hard constraint |
| PWA / maskable icons | 192, 512 px PNG; maskable safe-zone variant | Web-app install / home-screen |
| Landing-page art | SVG/PNG sized to the `landingpage` fork (P2) | Restyled to the §3 tokens |
| About-dialog logo | logo export at dialog scale (light + dark) | Sits beside the attribution + disclaimer text (P3) |
| Documentation header | banner/wordmark for docs sites | Text attribution only; no upstream logo |

Boot console branding needs **no splash/image for v1** — it is the text banner
in `/etc/issue` (`docs/BRANDING.md` §3), out of scope for this directory.

## 3. Palette and tokens (from `docs/UI_DESIGN.md` §8)

Artwork is built within the shipped `factory-assistant` theme tokens. The
brand accent may be tuned when the logo lands; the **state colours are fixed**.

| Token | Dark | Light | Used for |
|---|---|---|---|
| Accent (brand) | `#F5A623` amber | `#B07300` on light | selection, focus, sidebar-active |
| Background | `#111418` | `#F2F4F7` | app background |
| Surface / card | `#1E242C` | `#FFFFFF` | cards, tiles |
| Text primary / secondary | `#E8EAED` / `#9AA0A6` | `#1F2933` / `#52606D` | content |

Informational state colours (the andon/stack-light convention — see §4):

| State | Colour | Token |
|---|---|---|
| Success / running | `#43A047` green | `--fa-state-running` |
| Warning / blocked | `#FFB300` amber | `--fa-state-blocked` |
| Error / down | `#E53935` red | `--fa-state-down` |
| Info / maintenance | `#1E88E5` blue | `--fa-state-maint` |
| Idle | `#78909C` slate | `--fa-state-idle` |
| Offline (no data) | `#546E7A` gray + hatched band | `--fa-state-offline` |

The amber `#F5A623` accent is the brand colour; do **not** use a state colour
as the brand mark's primary colour, and do not let the mark read as a single
state. Typography keeps the upstream font stack — no new font licensing
(`docs/UI_DESIGN.md` §8).

## 4. State colours are informational only (critical)

The state colours above follow common **andon / stack-light conventions for
operator familiarity**. They are **informational only**. They carry **no
ISO 3864 / ANSI Z535 safety-colour meaning** and make no safety-colour claim
(`docs/UI_DESIGN.md` §2 principle 5, §10).

Consequently, for assets in this directory:

- **No asset may be named, labelled, or styled as e-stop, interlock, or safety
  alarm**, or as any safety device (`docs/UI_DESIGN.md` §10).
- Red/amber/green in any mark or icon are decorative/informational, never a
  safety signal; do not arrange them to imply a safety stack-light function.
- Factory Assistant is a **monitoring, read-only** appliance — no asset may
  depict, imply, or invite machine control or actuation.

## 5. Licensing and provenance

Brand assets are licensed **like the code** — Apache-2.0, per `docs/BRANDING.md`
§3 — and live in this `factory-assistant/brands`-equivalent directory in the
frontend fork's asset tree. For each asset, record its **provenance**
(originating designer/tool, source files, and confirmation it is original
work) so the release checklist can verify no upstream asset is present
(`docs/LICENSE_COMPLIANCE.md` §5, §6: "No `home-assistant/brands` assets or
upstream logos anywhere in shipped artifacts"). The Apache-2.0 grant of no
trademark rights (§1 above) means original authorship is mandatory, not
optional.

### Provenance — master mark

| Asset | Provenance |
|---|---|
| [`logo.svg`](logo.svg) | **Original work.** Hand-authored vector (plain SVG, no embedded raster, fonts, or external refs). Composed from first principles for Factory Assistant; **not derived from, tracing, recolouring, or resembling the Home Assistant logo or any `home-assistant/brands` asset.** Licensed Apache-2.0. |
| [`icon.svg`](icon.svg) | **Original work.** A reduction of `logo.svg` (hexagon + one bold pulse) tuned for the favicon/app-icon and verified legible at 16 px. Same originality and licence as the master. |

Design of the master mark (`logo.svg`): a deliberate **industrial hexagon**
(the modular/industrial **enclosure**) — crossed at its centre by a **live
monitoring pulse** waveform (the **signal**). It is drawn in a single FA amber
`#F5A623` so it reads as one mark, never as a state colour. The master is tuned
for the product-default **graphite** surfaces (`#111418` / `#1E242C`, ≥7.7:1
contrast); on light backgrounds the mark is recoloured to the darker amber
`#B07300`, the same accent the theme uses in light mode (`#F5A623` on `#F2F4F7`
is too low-contrast for a fill). The hexagon + pulse motif is the
direction pinned in §1; the abstract hexagon/pulse depicts observation only and
**invites no machine control or actuation** (§4). The mark is **not** a
safety stack-light and makes **no ISO 3864 / ANSI Z535 safety-colour claim**
(§4). It rasterises cleanly at 16 px (favicon) and 512 px (PWA / About-dialog),
verified with `rsvg-convert` (see §6).

## 6. Status

**Master mark landed.** The refined original master logo — [`logo.svg`](logo.svg)
— and its 16 px-tuned app/favicon variant — [`icon.svg`](icon.svg) — are in
place, with provenance recorded in §5. They honour §1 (original hexagon/pulse
motif, amber on graphite, legible at 16 px) and §4 (informational, monitoring-
only, no safety claim). For light surfaces, recolour the amber to `#B07300`
(§5). Both rasterise cleanly at 16 px and 512 px; verify with:

```sh
rsvg-convert -w 16  -h 16  branding/assets/logo.svg -o /tmp/l16.png
rsvg-convert -w 512 -h 512 branding/assets/logo.svg -o /tmp/l512.png
rsvg-convert -w 16  -h 16  branding/assets/icon.svg -o /tmp/i16.png
```

The brand-accent token in the shipped theme
(`buildroot-external/rootfs-overlay/usr/share/factory-assistant/themes/factory-assistant.yaml`)
uses the same amber `#F5A623`; the informational state colours stay fixed (§3).

Still to produce per the §2 inventory (Phase 2/3 frontend follow-up, separate
repo): the raster favicon set / `.ico`, the PWA / maskable icons, landing-page
art, the About-dialog export, and the documentation header. The raster icon set
is generated from these SVG masters, not hand-drawn. This README remains the
spec that governs all of them.
