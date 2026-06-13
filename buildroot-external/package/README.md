# package/ — Factory Assistant host-OS packages

Reserved for Buildroot packages specific to Factory Assistant (each in its
own directory with `Config.in` and `<name>.mk`, wired into the external
tree's `Config.in`/`external.mk` at fork time).

Planned packages:

- `fa-defaults` — first-boot seeding of the industrial default Core
  configuration from `/usr/share/factory-assistant/` into the data partition
  (Phase 3; mechanism documented in `docs/INDUSTRIAL_DEFAULTS.md`).

Upstream packages such as `hassio` (Supervisor bring-up) and `os-agent` keep
their upstream names and structure; Factory Assistant changes to them are
limited to configuration values (container registry, update channel URL —
Phase 2 rebrand checklist in `docs/OS_BUILD.md`).
