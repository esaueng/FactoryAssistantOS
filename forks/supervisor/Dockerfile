# Factory Assistant Supervisor — a single-constant overlay of the upstream
# Home Assistant Supervisor image.
#
# The ONLY change vs upstream is the hardcoded update-channel URL in
# supervisor/const.py (URL_HASSIO_VERSION). The running Supervisor uses that URL
# to discover component versions + image names; upstream hardcodes
# https://version.home-assistant.io/{channel}.json with no override, so without
# this change a running esaueng Supervisor would ignore the Factory Assistant
# channel and pull Core + plugins from ghcr.io/home-assistant. We repoint it to
# the Factory Assistant version service. URL_HASSIO_APPARMOR is deliberately
# left on upstream (unbranded, public). See docs/forks/supervisor/README.md.
#
# Why an image overlay rather than a source fork: this one URL is the entire
# Phase-1 delta. An overlay is reproducible, builds in seconds, and is trivially
# re-pinned to a new upstream tag — without re-implementing the Supervisor's
# multi-stage build. A full source fork is the eventual path (P2) when we also
# rebrand Supervisor product strings.
#
# License: this is upstream's Home Assistant Supervisor image (Apache-2.0) with
# a one-line modification; upstream LICENSE/NOTICE are retained from the base
# image (docs/LICENSE_COMPLIANCE.md §2). Factory Assistant is based on Home
# Assistant; this project is not affiliated with or endorsed by it.
ARG SUPERVISOR_VERSION
FROM ghcr.io/home-assistant/amd64-hassio-supervisor:${SUPERVISOR_VERSION}

# Repoint the update-channel constant, then drop bytecode so the patched source
# is (re)compiled at runtime. Asserts the upstream line exists first, so a build
# fails loudly if upstream moves the constant at a future tag.
# hadolint ignore=DL3059,SC2016
RUN set -eux; \
    f="$(python3 -c 'import supervisor.const as c; print(c.__file__)' 2>/dev/null \
        || find / -type f -path '*/supervisor/const.py' 2>/dev/null | head -1)"; \
    test -n "$f"; \
    grep -q 'https://version.home-assistant.io/{channel}.json' "$f"; \
    sed -i 's#https://version.home-assistant.io/{channel}.json#https://esaueng.github.io/FactoryAssistant/{channel}.json#' "$f"; \
    grep 'URL_HASSIO_VERSION' "$f"; \
    find "$(dirname "$f")" -depth -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

LABEL org.opencontainers.image.title="Factory Assistant Supervisor"
LABEL org.opencontainers.image.description="Upstream Home Assistant Supervisor with the update-channel URL repointed to the Factory Assistant version service (esaueng.github.io/FactoryAssistant). Based on Home Assistant; Apache-2.0; upstream LICENSE/NOTICE retained from the base image."
LABEL org.opencontainers.image.source="https://github.com/esaueng/FactoryAssistant"
