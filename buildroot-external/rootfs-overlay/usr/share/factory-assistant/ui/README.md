# Frontend experience contract

`frontend_contract.yaml` is the OS-shipped handoff for the Factory Assistant
frontend fork. It turns the UI design spec into a small contract for the
native plant experience: default Plant overview route, trimmed navigation,
`fa-machine-card`, andon view, and kiosk wallboard behavior.

The contract is deliberately monitoring-only. Machine tiles open detail views
instead of controls, the wallboard is view-only, and the andon acknowledge flow
is bookkeeping only. Factory Assistant is a monitoring tool, not a safety device.
