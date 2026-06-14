# Factory Assistant OS landing page

This build context produces the temporary first-boot page shown while the
Supervisor downloads and starts Factory Assistant Core.

The image keeps the upstream-compatible landingpage server contract:

- listens on port `8123`,
- redirects port `80` to `8123`,
- proxies the same selected Supervisor and Observer endpoints,
- advertises the same landingpage mDNS service shape,
- keeps the `io.hass.type="landingpage"` container label.

Only the shipped static web root is replaced. The visible page uses Factory
Assistant text, the original Factory Assistant mark from `branding/assets/`,
and the required factual attribution: "Factory Assistant is based on Home
Assistant." It does not ship upstream Home Assistant or OHF logos/assets.
