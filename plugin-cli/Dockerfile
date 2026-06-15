ARG CLI_SOURCE_TAG=2026.05.0
FROM ghcr.io/home-assistant/amd64-hassio-cli:${CLI_SOURCE_TAG}

# FA release version this image is published under. The Supervisor reads the
# io.hass.version label (const.LABEL_VERSION) to learn a plugin's installed
# version, then references ghcr.io/esaueng/<arch>-hassio-cli:<that-version>.
# It MUST equal the published tag and the update channel's "cli" version, or the
# Supervisor pulls a tag that was never published and the plugin never starts.
ARG FA_VERSION=2026.6.0

COPY rootfs /

LABEL \
    io.hass.type="cli" \
    io.hass.version="${FA_VERSION}" \
    org.opencontainers.image.version="${FA_VERSION}" \
    org.opencontainers.image.title="Factory Assistant CLI Plugin" \
    org.opencontainers.image.description="Factory Assistant Supervisor plugin for CLI" \
    org.opencontainers.image.authors="esaueng" \
    org.opencontainers.image.url="https://github.com/esaueng/FactoryAssistantOS" \
    org.opencontainers.image.documentation="https://github.com/esaueng/FactoryAssistantOS/tree/main/docs" \
    org.opencontainers.image.source="https://github.com/esaueng/FactoryAssistantOS" \
    org.opencontainers.image.licenses="Apache-2.0"
