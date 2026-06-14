FROM ghcr.io/home-assistant/generic-x86-64-homeassistant:landingpage AS server

FROM scratch

WORKDIR /
COPY --from=server /usr/bin/landingpage /usr/bin/landingpage
COPY rootfs /

ENTRYPOINT ["/usr/bin/landingpage"]

LABEL \
    io.hass.type="landingpage" \
    org.opencontainers.image.title="Factory Assistant OS landing page" \
    org.opencontainers.image.description="First-boot preparing page for Factory Assistant OS"
