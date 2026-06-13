# package/ — Factory Assistant host-OS packages

Reserved for Buildroot packages specific to Factory Assistant (each in its
own directory with `Config.in` and `<name>.mk`, wired into the external
tree's `Config.in`/`external.mk` at fork time).

Seed approach: first-boot seeding of the industrial default Core
configuration from `/usr/share/factory-assistant/` into the Home Assistant
config directory ships **today** as a rootfs-overlay scaffold — a
`fa-seed-config.service` oneshot plus `/usr/libexec/fa-seed-config`, enabled
via a `multi-user.target.wants` symlink. It copies the template tree only when
no `configuration.yaml` exists yet and never overwrites existing config. The
mechanism and its honest limitation (the config dir is a Supervisor-managed
volume, so robust seeding ultimately needs a Supervisor-fork hook) are
documented in `docs/INDUSTRIAL_DEFAULTS.md` §"Config seeding mechanism".

Planned packages:

- `fa-defaults` — a Buildroot package that may later re-home the seed script
  and unit with proper `Config.in`/`fa-defaults.mk` wiring. Same mechanism as
  the overlay scaffold; nothing additional is required for the scaffold to
  work, since `scripts/apply-overlay.sh` already mirrors overlay files into the
  upstream tree.

Upstream packages such as `hassio` (Supervisor bring-up) and `os-agent` keep
their upstream names and structure; Factory Assistant changes to them are
limited to configuration values (container registry, update channel URL —
Phase 2 rebrand checklist in `docs/OS_BUILD.md`).
