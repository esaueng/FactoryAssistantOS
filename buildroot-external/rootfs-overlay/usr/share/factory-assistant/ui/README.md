# Frontend experience contract

`frontend_contract.yaml` is the OS-shipped handoff for the Factory Assistant
frontend fork. It turns the UI design spec into a small contract for the
native plant experience: default Plant overview route, trimmed navigation,
`fa-machine-card`, andon view, `factory-wallboard-kiosk`, and the About panel.
Its terminology contract keeps product labels aligned across frontend
translations, onboarding copy, network handoffs, and CLI notes: `Plant
overview` for the default landing view, site -> line or cell taxonomy for the
factory model, and `Factory Assistant CLI` for the upstream-compatible `ha`
command.

The contract is deliberately monitoring-only. Machine tiles open detail views
instead of controls, the wallboard is view-only, and the andon acknowledge flow
is bookkeeping only. Factory Assistant is a monitoring tool, not a safety device.

The frontend fork now implements native plant navigation plus the contract's
read-only `fa-machine-card`, `fa-andon-view`, and `factory-wallboard-kiosk`.
Dashboard wiring is implemented in the shipped YAML templates with
`custom:fa-machine-card`, `custom:fa-andon-view`, and
`custom:factory-wallboard-kiosk`; the full industrial onboarding wizard remains
P3 frontend work.

The About panel contract keeps the product identity honest: it carries the
canonical upstream attribution, requires the non-affiliation notice, links the
Safety boundary, and exposes Open source licenses from the per-release
`legal-info` bundle.
