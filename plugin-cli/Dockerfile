ARG CLI_SOURCE_TAG=2026.05.0
FROM ghcr.io/home-assistant/amd64-hassio-cli:${CLI_SOURCE_TAG}

COPY rootfs /

LABEL \
    io.hass.type="cli" \
    org.opencontainers.image.title="Factory Assistant CLI Plugin" \
    org.opencontainers.image.description="Factory Assistant Supervisor plugin for CLI" \
    org.opencontainers.image.authors="esaueng" \
    org.opencontainers.image.url="https://github.com/esaueng/FactoryAssistantOS" \
    org.opencontainers.image.documentation="https://github.com/esaueng/FactoryAssistantOS/tree/main/docs" \
    org.opencontainers.image.source="https://github.com/esaueng/FactoryAssistantOS" \
    org.opencontainers.image.licenses="Apache-2.0"
