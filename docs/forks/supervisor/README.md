# Fork: `esaueng/supervisor` — point the update channel at Factory Assistant

This is the **keystone** of the app-layer rebrand (Phase 1). Without it, a
running Factory Assistant appliance does **not** use the Factory Assistant
update channel at all.

## Why a source fork is required (it can't be done from this repo)

The Supervisor's version-channel URL is a **hardcoded constant** with no env or
config override (`supervisor/const.py`, verified at tag `2026.06.0`):

```python
URL_HASSIO_APPARMOR = "https://version.home-assistant.io/apparmor_{channel}.txt"
URL_HASSIO_VERSION  = "https://version.home-assistant.io/{channel}.json"
```

`supervisor/updater.py` `fetch_data()` formats `URL_HASSIO_VERSION` and reads
the whole `data["images"]` map (core, supervisor, and the 5 plugins) plus `ota`
from whatever that URL returns. So once the running Supervisor container starts,
it fetches versions **and image names from `version.home-assistant.io`** and
pulls Core + plugins from `ghcr.io/home-assistant`, **ignoring**
`esaueng.github.io/FactoryAssistant/stable.json` entirely.

The OS rootfs overlay (`usr/sbin/hassos-supervisor`) only governs the *cold-boot
bootstrap* pull of the Supervisor image — not steady state. Therefore the
esaueng channel JSON (and all its `images` overrides) is only honored once the
**shipped Supervisor image itself** carries the patched constant.

## The patch (one line)

In the fork, change only `URL_HASSIO_VERSION`:

```diff
- URL_HASSIO_VERSION  = "https://version.home-assistant.io/{channel}.json"
+ URL_HASSIO_VERSION  = "https://esaueng.github.io/FactoryAssistant/{channel}.json"
```

Robust, line-number-independent application:

```sh
sed -i \
  's#^URL_HASSIO_VERSION\( *\)= "https://version.home-assistant.io/{channel}.json"#URL_HASSIO_VERSION\1= "https://esaueng.github.io/FactoryAssistant/{channel}.json"#' \
  supervisor/const.py
grep -n 'URL_HASSIO_VERSION' supervisor/const.py   # verify it now reads esaueng.github.io
```

### Deliberately NOT changed in Phase 1

- **`URL_HASSIO_APPARMOR`** stays on `version.home-assistant.io`. The AppArmor
  profile is unbranded, public, and functional; leaving it upstream avoids
  having to serve `apparmor_{channel}.txt` from Pages. Follow-up (optional):
  serve `apparmor_stable.txt` on the Pages site and patch this constant too.
- **`os/manager.py` OS-supported allowlist** is **not** patched. We keep the
  OS's CPE *product* field = `haos` via `scripts/apply-overlay.sh` (see
  `docs/OS_BUILD.md §4`), so the unmodified allowlist `{hassos, haos}` already
  accepts the appliance. Patching the allowlist to add `faos` would be a second,
  higher-maintenance fork delta — avoided.
- **Cosmetic strings** (`SERVER_SOFTWARE`, log lines like "Detect Home Assistant
  Operating System") are not user-facing in the appliance UI and are out of
  scope for the keystone; rebrand them in a later supervisor-polish pass.

## Channel coupling (must be true before this ships)

`URL_HASSIO_VERSION` uses `{channel}` → for the default `stable` channel it
fetches `https://esaueng.github.io/FactoryAssistant/stable.json` (already
served). The Supervisor reads that document's **`images`** map (plural) — which
this repo's `version-service/stable.json` now provides for all 7 components.
If you ever switch a device to `beta`/`dev`, you must also publish
`beta.json`/`dev.json`, or pin the channel to `stable`.

## Build & publish the forked Supervisor image

1. **Fork** `home-assistant/supervisor` into the **`esaueng` org** at the pinned
   tag (so the version baked into the appliance matches the channel). Apply the
   patch on a branch; keep `LICENSE`+`NOTICE`, add the "based on Home Assistant"
   attribution, mark `const.py` as modified (`docs/LICENSE_COMPLIANCE.md §2`).
2. **Build** via the repo's own `.github/workflows/builder.yml`. Its image name
   comes from `prepare-multi-arch-matrix` as `${REGISTRY_PREFIX}/${arch}-hassio-supervisor`
   with `REGISTRY_PREFIX` defaulting to `ghcr.io/${{ github.repository_owner }}`
   — because the fork owner is `esaueng`, it auto-publishes to
   `ghcr.io/esaueng/amd64-hassio-supervisor` with **no workflow edit**. Flip any
   `if: github.repository_owner == 'home-assistant'` guards, and use the
   "build local wheels" path (the publish path needs HA's `WHEELS_KEY`, which
   you don't have). For `generic-x86-64` you only need `amd64`.
3. **Tag** the GitHub Release so the image tag **byte-matches** the `supervisor`
   field in `version-service/stable.json`. ⚠️ CALVER punctuation matters:
   upstream Supervisor uses a **zero-padded** month (e.g. `2026.06.1`); the
   channel currently says `2026.6.0`. Pick the real published tag and make the
   channel field equal it exactly, or the cold-boot/self-update pull 404s.
4. **Make the package PUBLIC** (the appliance pulls anonymously). `GITHUB_TOKEN`
   cannot change package visibility — flip it once in org Package settings, or
   script it with an org PAT. Verify anonymously:
   `docker pull ghcr.io/esaueng/amd64-hassio-supervisor:<tag>` with no creds.

## Verify on a running appliance

```sh
# The running Supervisor now reads the FA channel (not version.home-assistant.io):
ha supervisor logs | grep -i 'esaueng.github.io/FactoryAssistant'   # NOT version.home-assistant.io
# Core + every plugin resolve to esaueng:
docker ps --format '{{.Image}}'        # all ghcr.io/esaueng/*, none ghcr.io/home-assistant/*
cat /mnt/data/supervisor/updater.json  # .image map entries all esaueng
# OS reported supported (CPE product = haos):
ha resolution info                     # no "unsupported OS" issue
busctl get-property org.freedesktop.hostname1 /org/freedesktop/hostname1 \
  org.freedesktop.hostname1 OperatingSystemCPEName   # ...:haos:...
```

> Re-verify the `const.py` line and the builder image-name templating at the
> **exact** Supervisor tag you fork (paths/line numbers move between releases).
> Sources and the full mechanism are in the Phase-2 research notes referenced by
> `docs/OS_BUILD.md §4` / `docs/ARCHITECTURE.md §2`.
