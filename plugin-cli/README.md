# Factory Assistant CLI plugin

This build context produces the Supervisor CLI system plugin published as
`ghcr.io/esaueng/amd64-hassio-cli`.

The image inherits the pinned upstream-compatible CLI plugin image and replaces
only `/usr/bin/cli.sh`, the visible interactive wrapper. The internal `ha`
command, Supervisor plugin type label, and image naming contract remain
upstream-compatible so the unmodified Supervisor can continue to pull and run
the plugin.

Visible shell startup copy is Factory Assistant branded, keeps the required
factual attribution, and states the monitoring-only safety posture:
"Factory Assistant is based on Home Assistant."
