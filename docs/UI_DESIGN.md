# UI Design — Factory / Manufacturing

The design specification for the Factory Assistant user interface. It governs
the frontend fork (Phase 3), the theme and dashboard templates that already
ship in the OS image, and any add-on UI. The upstream frontend is designed
around a home; this document redesigns the experience around a plant:
**status first, glanceable at distance, dense, dark, read-only.**

Related: `docs/ARCHITECTURE.md` §6 (frontend layer), `docs/BRANDING.md`
(identity), `docs/INDUSTRIAL_DEFAULTS.md` (entity/topic conventions),
`docs/SAFETY_BOUNDARY.md` (normative for everything below). The OS image also
ships `ui/frontend_contract.yaml`, a machine-readable handoff for the
frontend fork's native plant navigation, `fa-machine-card`, `fa-andon-view`,
`factory-wallboard-kiosk`, and About panel (`about_panel`) obligations.

## 1. Users and contexts

| Persona | Context | Primary need |
|---|---|---|
| Operator | At the line; panel PC or tablet, often gloved | Is my machine OK? What just changed? |
| Line lead | Walking the floor; tablet/phone | Line status, alert triage, shift output |
| Maintenance tech | At the machine; tablet | Machine detail, state history, trends before/after intervention |
| Plant / process engineer | Desk; full browser | Configuration, long trends, commissioning |
| Wallboard | Unattended display, viewed at 3–8 m | Plant/line status and active alerts, no interaction |

Design for the wallboard and the gloved operator first; the engineer can
always reach the full UI.

## 2. Design principles

1. **Status first, configuration last.** The default landing view is plant
   status, not a configuration surface. Settings exist but are de-emphasized
   for operator accounts.
2. **Glanceable.** A machine's state must be readable from across an aisle:
   color + icon + label, large numerals, no hover-dependent information.
   Legibility rule of thumb: character height ≥ viewing distance ÷ 250
   (5 m → ≥ 20 mm capitals on the wallboard).
3. **Dense and uniform.** Plants have many similar machines; one repeated
   tile grammar (§5) beats bespoke decorative cards. Density over whitespace.
4. **Dark by default.** Shop floors have glare, mixed lighting, and 24/7
   displays; ship a dark theme with a light mode (§8). Contrast ≥ 4.5:1,
   ≥ 7:1 for wallboard text.
5. **Color is never the only channel.** Every state pairs color with an icon
   and a text label (≈8 % of male users are red/green colorblind). State
   colors follow common andon/stack-light *conventions* for familiarity —
   they are **informational, with no ISO 3864 / ANSI Z535 safety-color claim**.
6. **Honest about freshness.** Every state/metric display carries a staleness
   indicator; an offline or stale machine is unmistakable (§5). A dashboard
   that silently shows old data as current is the worst failure mode of a
   monitoring product.
7. **Touch for gloves.** Targets ≥ 48 px, generous spacing, no long-press or
   hover requirements, swipe-free critical paths.
8. **Read-only by design.** Monitoring dashboards contain **no control
   affordances** — tapping a machine opens detail/history, never a toggle.
   This is the safety boundary expressed as UI (§10).
9. **No audio dependence.** Plants are loud; everything works silently.
   (Notifications can still reach phones/wallboards visually.)
10. **Local-first, no cruft.** No cloud nags, weather, media, or
    home-presence features in the default experience.

Anti-patterns (rejected in review): red/green-only state, decorative gauges
for discrete states, control toggles on monitoring views, values without
units or freshness, popups that hide active alerts, tiny sparklines without
numbers.

## 3. Information architecture

Physical hierarchy maps onto Core's native structures — no schema invention:

```
Site (the appliance)
└── Hall / building      → "floor" in Core
    └── Line → Cell → Station → "areas" (line1, line1_cell2, …)
        └── Machine          → device
            └── Signals      → entities (sensor.line1_press03_motor_temp, …)
```

Entity/topic naming follows `docs/INDUSTRIAL_DEFAULTS.md` §2; the UI sorts
and groups by area throughout.

**Navigation (frontend fork, P3).** Sidebar trimmed for plant use:
*Plant overview* (default) · *Alerts* · *Energy* · *History* · *Logbook* ·
*Maintenance* · Settings (admin only). Home-centric items (Media, Map, To-do)
are hidden by default. Until the fork lands, the shipped YAML dashboard
provides the same structure as views (§9).

## 4. Machine state vocabulary

One canonical, plant-wide state model; gateways/integrations map into it
(convention: `sensor.<area>_<machine>_state` enum + `binary_sensor.…_running`).

| State | Meaning | Color token | Icon |
|---|---|---|---|
| `running` | Producing | `--fa-state-running` green `#43A047` | `mdi:play-circle` |
| `idle` | Powered, no job | `--fa-state-idle` slate `#78909C` | `mdi:pause-circle` |
| `blocked` | Starved/blocked by up-/downstream | `--fa-state-blocked` amber `#FFB300` | `mdi:timer-sand` |
| `down` | Fault / unplanned stop | `--fa-state-down` red `#E53935` | `mdi:alert-octagon` |
| `maintenance` | Planned intervention | `--fa-state-maint` blue `#1E88E5` | `mdi:wrench` |
| `offline` | **No data** (stale/disconnected) | `--fa-state-offline` gray `#546E7A` + hatched band | `mdi:lan-disconnect` |

`offline` is a data-quality state, not a machine state — it always wins
visually, because unknown must never look like OK.

## 5. The machine tile (core UI unit)

Everything aggregates from one tile grammar. The frontend fork now ships the
read-only `fa-machine-card`; the stock Lovelace templates still approximate
it until the image consumes that forked frontend and the dashboard templates
switch to `type: custom:fa-machine-card`:

```
┌──────────────────────────────┐
│ ▶ PRESS 03          RUNNING  │  ← state band: color + icon + label
│ 412 parts/h      78.4 °C     │  ← ≤2 key metrics, tabular numerals, units
│ run 6.2 h   ⚠ 1   ⟳ 3 s ago │  ← runtime today · alert badge · freshness
└──────────────────────────────┘
```

Rules: state band spans the full width; metrics are chosen per machine class
(rate, temperature, current, pressure); freshness goes amber > 3× the
expected update interval and the tile degrades to `offline` beyond 10×; tap
opens machine detail — never an action.

## 6. Screen inventory

**Plant overview (default landing).**
KPI strip — machines running `14/17`, active alerts, shift output, plant
power now — followed by per-line sections of machine tiles:

```
│ Running 14/17 · Alerts 2 · Output 8 412 · 142 kW                │
├─ LINE 1 ────────────────────────────────────────────────────────┤
│ [PRESS 01][PRESS 03][WELD 02][CNC 04][PACK 01][PACK 02]         │
├─ LINE 2 ────────────────────────────────────────────────────────┤
│ [EXTR 01][EXTR 02][WIND 01][PAL 01]                             │
```

**Line / area detail.** Tiles for the line's machines, line throughput and
key-signal trend (8–12 h), recent state-change log (logbook filtered to the
area).

**Machine detail.** State timeline (history), the machine's gauges/trends,
active and recent alerts, runtime counters, and a commissioning notes /
register-map link block. This extends Core's device page rather than
replacing it.

**Alerts (andon board).** Active alerts sorted severity-then-age with
acknowledge state (`new → acknowledged → cleared`; ack is bookkeeping, alerts
stay visible until the condition clears). Severities: `info`, `warning`,
`critical` — **all informational**. The view footer carries the standing
disclaimer (§10). Wallboard variant: oversized rows, auto-contrast.

**Energy.** Core's energy dashboard re-purposed for plants: incomer +
per-line/per-machine consumption (CT clamps), shift and daily views.

**Maintenance.** Runtime-hours counters with thresholds (counter-based
reminders), machines recently `down`/`maintenance`, last backup status —
the pre-maintenance-window checklist lives here.

**History / trends.** Core history for the recorder window (30 d default);
long-range analysis defers to the historian add-on (P3+).

**Settings.** Upstream settings surface, unchanged, admin-only. Operators
and wallboards run as non-admin users (upstream supports admin/non-admin
only; finer roles are a known limitation, revisit in the fork).

**About panel.** The frontend fork implements `about_panel` from
`ui/frontend_contract.yaml`: Factory Assistant product identity, canonical
upstream attribution, non-affiliation notice, Safety boundary link, and an
Open source licenses link to the per-release `legal-info` bundle.

## 7. Wallboard / kiosk mode

- Dedicated **non-admin, view-only** user per display; browser in kiosk mode
  on a panel PC, or any HDMI box pointed at the appliance.
- Frontend fork implements the native `factory-wallboard-kiosk`: hides
  sidebar/header chrome, scales type ×1.6 (KPI numerals ≥ 64 px), disables
  dashboard interaction, and leaves optional view auto-cycling as a contract
  flag. The shipped YAML still provides a dedicated wallboard dashboard view
  that can be opened directly by kiosk browsers until dashboard wiring promotes
  the native card by default.
- Wallboards render the `factory-assistant` dark theme regardless of profile.

## 8. Design tokens (implemented in the shipped theme)

The `factory-assistant` theme ships in the image at
`/usr/share/factory-assistant/themes/factory-assistant.yaml` (dark default +
light mode). Final brand accent may be tuned when the logo lands
(`docs/BRANDING.md` §3) — state colors won't change.

| Token | Dark | Light | Used for |
|---|---|---|---|
| Accent (brand) | `#F5A623` amber | `#B07300` on light | selection, focus, sidebar-active |
| Background | `#111418` | `#F2F4F7` | app background |
| Surface / card | `#1E242C` | `#FFFFFF` | cards, tiles |
| Text primary / secondary | `#E8EAED` / `#9AA0A6` | `#1F2933` / `#52606D` | content |
| Success / running | `#43A047` | same | state band, success |
| Warning / blocked | `#FFB300` | same | state band, warnings |
| Error / down | `#E53935` | same | state band, faults |
| Info / maintenance | `#1E88E5` | same | state band, info |
| Card radius | `6px` | `6px` | squarer, equipment-like surfaces |

Typography: keep the upstream font stack (no new font licensing); tabular
numerals for all metrics; minimums — body 14 px, tile metric 24–32 px,
wallboard scale ×1.6.

## 9. What ships when

| Deliverable | Mechanism | Phase |
|---|---|---|
| `factory-assistant` theme (dark+light) | `themes/factory-assistant.yaml` template in the image | **now** |
| "Plant overview" dashboard (views: Overview, Line, Alerts, OEE, Energy, Maintenance) | `dashboards/factory-overview.yaml` template + `configuration.yaml` wiring | default landing now (adapted at commissioning) |
| Andon board (severity sections + ack indicators, stock-card approximation) | `dashboards/andon.yaml` + `packages/andon_example.yaml` (ack helpers) | **now** |
| Wallboard / kiosk board (full-screen status, view-only, browser kiosk flags) | `dashboards/wallboard.yaml` | **now** (stock dashboard; native kiosk component implemented in fork) |
| OEE (availability×performance×quality) + maintenance reminders | `packages/oee_example.yaml`, `packages/maintenance_example.yaml` (per-machine templates) | **now** |
| KPI template sensors | commented examples in `configuration.yaml` template | **now** |
| Landing page restyled to tokens | `landingpage/` image context | **now** |
| Visible product rebrand, About panel safety/license links, and local-first onboarding bridge | `frontend` fork consuming the shipped `ui/frontend_contract.yaml` and `onboarding/wizard_steps.yaml` contracts | implemented in fork |
| Native read-only `fa-machine-card` with status/OEE/job/maintenance freshness and detail-only tap behavior | `frontend` fork consuming the shipped `ui/frontend_contract.yaml` machine-card contract | implemented in fork |
| Native read-only `fa-andon-view` with severity grouping, ack bookkeeping status, and detail-only alert rows | `frontend` fork consuming the shipped `ui/frontend_contract.yaml` and `dashboards/andon.yaml` contract | implemented in fork |
| Native read-only `factory-wallboard-kiosk` with hidden chrome, ×1.6 wallboard type scale, and view-only dashboard interaction blocking | `frontend` fork consuming the shipped `ui/frontend_contract.yaml` kiosk contract and `dashboards/wallboard.yaml` source dashboard | implemented in fork |
| Trimmed navigation, terminology pass ("Home"→"Plant overview", areas as lines/cells), dashboard wiring, full industrial onboarding wizard | `frontend` fork consuming the shipped `ui/frontend_contract.yaml` and `onboarding/wizard_steps.yaml` contracts | P3 |
| Auto-generated area dashboards from the line/cell taxonomy | frontend fork consuming the shipped `onboarding/site_model.example.yaml` line/cell taxonomy scaffold | P3 |

Templates are deliberately stock-Lovelace (glance/entities/gauge/history
cards) so they work on an unmodified Core today and degrade gracefully.

## 10. Safety boundary in the UI (normative)

Restating `docs/SAFETY_BOUNDARY.md` as UI rules:

1. No control affordances on monitoring dashboards; default views render
   read-only entities and `tap → detail` only.
2. No UI element may be named or styled as e-stop, interlock, or safety
   alarm; the state colors of §4 carry no safety-color claim.
3. Alert acknowledge is informational bookkeeping — the UI never implies a
   machine was made safe.
4. Freshness indicators (§5) are mandatory wherever machine state is shown.
5. The disclaimer — *"Factory Assistant is a monitoring tool, not a safety
   device. Dashboards and notifications must never be the sole means of
   detecting a hazardous condition."* — appears in onboarding, the About
   dialog, and the Alerts view footer.
6. If the P4 control gate ever opens, control surfaces live on a separate,
   opt-in, per-user dashboard — never mixed into monitoring views.

## 11. Open questions (tracked, not blocking)

Shift calendar modeling (entities vs. add-on); OEE now ships as a stock-card
template package (`packages/oee_example.yaml`) — the open question is whether a
dedicated add-on should compute it from the state model at fleet scale;
Sparkplug B
namespace browsing in the bridge add-on UI, multi-appliance/multi-site
roll-up (out of scope for the single-appliance v1).
