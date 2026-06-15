FROM ghcr.io/home-assistant/generic-x86-64-homeassistant:landingpage AS server

FROM scratch

WORKDIR /
COPY --from=server /usr/bin/landingpage /usr/bin/landingpage
COPY rootfs /

ENTRYPOINT ["/usr/bin/landingpage"]

# io.hass.version MUST be "landingpage": the Supervisor compares the running
# image's io.hass.version label against the LANDINGPAGE sentinel
# (AwesomeVersion("landingpage"), supervisor/homeassistant/const.py) to recognize
# the first-boot preparing page. This final stage is FROM scratch, so no upstream
# label is inherited; without this the label is absent, DockerInterface.version
# returns None, and HomeAssistantCore.load() raises
# AwesomeVersionCompareException("Not a valid AwesomeVersion object").
LABEL \
    io.hass.type="landingpage" \
    io.hass.version="landingpage" \
    org.opencontainers.image.title="Factory Assistant OS landing page" \
    org.opencontainers.image.description="First-boot preparing page for Factory Assistant OS"
