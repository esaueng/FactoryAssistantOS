# Cutting a Factory Assistant OS release image

This is the operational runbook for producing a **flashable** Factory
Assistant OS image for `generic-x86-64`. For *how the build works* and
flashing details, see [`docs/OS_BUILD.md`](docs/OS_BUILD.md).

> A full from-source build needs **~50 GB free disk** and **broad outbound
> network** (GitHub + the Buildroot submodule + hundreds of package source
> hosts + the Docker CDN for the builder image). It does **not** run in small
> or network-restricted sandboxes — use CI or a real Linux host.

## Status of the build pipeline

| Stage | Verified | How |
|---|---|---|
| Upstream pin resolves (17.3) | ✅ | cloned tag `17.3` |
| `scripts/apply-overlay.sh` against real 17.3 | ✅ | identity rewritten to `Factory Assistant OS`/`faos`, 5 overlay files placed, defconfig fragment appended, idempotent |
| Trusted RAUC signing input wiring | ✅ | `tests/test_configure_rauc_signing.sh` validates external CA/cert/key installation into the HAOS 17.3 build paths |
| Builder image + full Buildroot compile | ⛔ not run here | blocked in this environment by disk (<50 GB) and a network policy that 403s the Docker CDN — run on CI or a Linux host (below) |

So the rebrand/overlay is proven against the actual pinned upstream; the
heavy compile must run where resources allow.

## Path 1 — GitHub Actions (recommended, repeatable)

Workflow: [`.github/workflows/build-os-image.yml`](.github/workflows/build-os-image.yml).
It frees runner disk, runs `bootstrap` + `apply-overlay`, builds inside the
upstream builder container, then uploads the image (and on a tag, publishes a
Release with checksums + license bundle).

For a trusted OTA release, configure all three repository secrets before
running the tag build. Generate the external inputs with
`scripts/generate-rauc-signing-material.sh --out-dir /secure/faos-rauc`, then
copy the PEM contents into the matching secrets:

- `FAOS_RAUC_KEYRING_PEM` — Factory Assistant OTA root CA certificate.
- `FAOS_RAUC_CERT_PEM` — Factory Assistant OTA signing certificate.
- `FAOS_RAUC_KEY_PEM` — Factory Assistant OTA signing private key.

Tag builds require all three RAUC secrets and fail without them. Manual
`workflow_dispatch` builds may still produce flash-only development artifacts
with a public self-signed development certificate when no RAUC secrets are
present. If only some are present, the workflow fails rather than publishing a
misleading OTA bundle.

- **Ad-hoc build**: Actions → *Build Factory Assistant OS image* → *Run
  workflow*. Download the `faos-generic-x86-64` artifact when it finishes.
- **Tagged release**:

  ```sh
  git tag v17.3-fa.1      # FA build .1 on upstream base 17.3 (docs/OS_BUILD.md §6)
  git push origin v17.3-fa.1
  ```

  The run attaches `faos_generic-x86-64-<ver>.img.xz`, its `.raucb`,
  `SHA256SUMS`, and the legal-info bundle to a GitHub Release.

Requires GitHub-hosted (or self-hosted) Actions with internet access. On a
private mirror without Actions, use Path 2.

## Path 2 — build on your own x86-64 Linux host (works today)

On a Linux x86-64 machine with Docker, git, rsync, ~50 GB free:

```sh
git clone <this-repo> && cd FactoryAssistant
make bootstrap        # clone upstream 17.3 + Buildroot submodule
make overlay          # apply the Factory Assistant overlay  (verified)
# Trusted OTA build: install external FA RAUC inputs into the gitignored
# upstream checkout. Omit this and use upstream's generate-signing-key.sh only
# for explicit flash-only development images.
scripts/configure-rauc-signing.sh \
  --keyring /secure/faos-rauc/faos-rauc-ca.crt \
  --cert /secure/faos-rauc/faos-rauc-signing.crt \
  --key /secure/faos-rauc/faos-rauc-signing.key
make os               # full build (hours); or: cd upstream/operating-system && scripts/enter.sh make generic_x86_64
```

Result: `upstream/operating-system/output/images/faos_generic-x86-64-<ver>.img.xz`.
`scripts/enter.sh` must run as a **non-root** user with passwordless sudo
(an upstream requirement).

## Flash and try

```sh
xz -d faos_generic-x86-64-<ver>.img.xz
sudo dd if=faos_generic-x86-64-<ver>.img of=/dev/sdX bs=8M status=progress conv=fsync   # verify /dev/sdX!
```

Boot the x86-64 target (UEFI), then open `http://factory-assistant.local:8123`
and complete onboarding. Full flashing/VM notes: `docs/OS_BUILD.md` §3.

## Before calling a build a real "release"

- [ ] Run the local trusted-release preflight with the external RAUC inputs:

      ```sh
      scripts/verify-release-readiness.sh \
        --channel version-service/stable.json \
        --keyring /secure/faos-rauc/faos-rauc-ca.crt \
        --cert /secure/faos-rauc/faos-rauc-signing.crt \
        --key /secure/faos-rauc/faos-rauc-signing.key
      ```

      This validates the Factory Assistant RAUC chain/key match, runs
      `scripts/verify-shipped-branding.sh`,
      `scripts/verify-safety-boundary.sh`, and
      `scripts/verify-identity-go-live.sh`, and confirms the channel points at
      esaueng-owned images and OTA URLs before a tag is cut.
- [ ] If releasing through GitHub Actions, confirm the repository has all
      trusted RAUC secrets configured:

      ```sh
      scripts/configure-github-rauc-secrets.sh \
        --repo esaueng/FactoryAssistantOS \
        --keyring /secure/faos-rauc/faos-rauc-ca.crt \
        --cert /secure/faos-rauc/faos-rauc-signing.crt \
        --key /secure/faos-rauc/faos-rauc-signing.key

      scripts/verify-github-rauc-secrets.sh --repo esaueng/FactoryAssistantOS
      ```

      The installer validates the external RAUC certificate/key relationship
      and streams the three PEM values to GitHub without printing them. The
      verifier checks secret names only (`FAOS_RAUC_KEYRING_PEM`,
      `FAOS_RAUC_CERT_PEM`, `FAOS_RAUC_KEY_PEM`); it does not read or print
      secret values.
- [ ] Verify component fork ownership and exact channel image tags before
      trusting the channel:

      ```sh
      scripts/verify-component-ownership.sh \
        --channel version-service/stable.json \
        --owner esaueng
      ```

      This uses authenticated `gh` access to confirm required component repos
      are reachable under `esaueng`, confirms the channel image map points only
      at `ghcr.io/esaueng`, and verifies every exact channel image tag is
      anonymously pullable from GHCR. It also verifies the published
      industrial add-on manifests in `factory-assistant-addons` against the
      OS-shipped add-on catalog, verifies the published industrial add-on image tags
      referenced by those manifests are anonymously pullable from GHCR, then runs
      `scripts/verify-supervisor-channel-patch.sh` to confirm the Supervisor
      fork's `URL_HASSIO_VERSION` points at the Factory Assistant channel, not
      `version.home-assistant.io`. The tag workflow runs the same check with
      `GH_COMPONENT_READ_TOKEN` when that secret is set, falling back to the
      workflow token.
- [ ] Verify the published channel is live and matches the local stable
      document before cutting a release tag:

      ```sh
      scripts/verify-published-channel.sh \
        --local version-service/stable.json \
        --url https://esaueng.github.io/FactoryAssistantOS/stable.json
      ```

      This catches GitHub Pages drift and rejects any upstream or placeholder
      artifact references in the channel.
- [ ] Verify each RAUC bundle signature against the Factory Assistant OTA CA
      keyring before publishing:

      ```sh
      scripts/verify-rauc-bundle-signature.sh \
        --release-dir release \
        --board generic-x86-64 \
        --keyring /secure/faos-rauc/faos-rauc-ca.crt
      ```

      This runs `rauc info --keyring` for the release bundle and fails if the
      bundle is not trusted by the configured device keyring.
- [ ] After the build produces `release/`, verify the upload set before
      publishing:

      ```sh
      scripts/verify-release-artifacts.sh \
        --release-dir release \
        --board generic-x86-64 \
        --trusted
      ```

      This checks the flash image, RAUC bundle, license archive, checksums,
      `RAUC_TRUST.json` public certificate manifest, trusted release notes,
      and rejects accidental publication of signing material.
- [ ] Confirm the channel OTA template resolves to the exact RAUC bundle in
      the release directory:

      ```sh
      scripts/verify-ota-channel-artifact.sh \
        --channel version-service/stable.json \
        --board generic-x86-64 \
        --release-dir release
      ```

      This verifies the bundle filename devices will request and its
      `SHA256SUMS` coverage before publishing or promoting the channel.
- [ ] Run the shipped safety-boundary verifier:

      ```sh
      scripts/verify-safety-boundary.sh
      ```

      This rejects accidental machine-control domains, forbidden services, or
      safety contract flags in the OS-shipped Factory Assistant defaults.
- [ ] Factory Assistant RAUC keys are configured with
      `scripts/configure-rauc-signing.sh` or the three GitHub Actions secrets
      (`docs/OS_BUILD.md` §Signing). Without that, the image is **flash-only**
      and OTA is untrusted with the self-signed cert.
- [ ] Review the current "Upstream release/security tracking" issue maintained
      by `.github/workflows/upstream-tracker.yml`; resolve any pinned upstream
      drift or security-review checklist items before publishing.
- [ ] Re-walk the rebrand checklist (`docs/OS_BUILD.md` §4). Applied today:
      product name/ID, hostname, console banner (`etc/issue` + `etc/motd`),
      branded landing page image, branded CLI plugin image, running Supervisor update-channel URL preflight,
      Plant overview default dashboard, and the frontend product/About/local-first onboarding bridge;
      GRUB is N/A on x86-64. The frontend fork now has native plant navigation
      plus the native read-only `fa-machine-card`, `fa-andon-view`, and
      `factory-wallboard-kiosk`; still P3: dashboard wiring and industrial
      onboarding wizard integration.
- [ ] Verify the Supervisor accepts the `faos` os-release identity on first
      boot (`docs/OS_BUILD.md` §4 — os-release ID verification).
- [ ] Verify the settled `branding/identity.env` go-live values before any
      published or OTA release:

      ```sh
      scripts/verify-identity-go-live.sh --identity branding/identity.env
      ```

      This rejects stale `REPLACE-*` / `.example` values and verifies the
      `esaueng` GHCR registry, GitHub Pages channel URL, and GitHub Releases
      OTA template.
- [ ] Publish the license bundle with the artifact
      (`docs/LICENSE_COMPLIANCE.md` §6).
- [ ] Boot-test on real hardware/VM (milestone P1, `docs/ARCHITECTURE.md` §11).
