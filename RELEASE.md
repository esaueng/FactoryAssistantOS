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
running the tag build:

- `FAOS_RAUC_KEYRING_PEM` — Factory Assistant OTA root CA certificate.
- `FAOS_RAUC_CERT_PEM` — Factory Assistant OTA signing certificate.
- `FAOS_RAUC_KEY_PEM` — Factory Assistant OTA signing private key.

If none are present, the workflow produces a flash-only build with a public
self-signed development certificate. If only some are present, the workflow
fails rather than publishing a misleading OTA bundle.

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
  --keyring /secure/faos-ca.crt \
  --cert /secure/faos-ota.crt \
  --key /secure/faos-ota.key
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

- [ ] Factory Assistant RAUC keys are configured with
      `scripts/configure-rauc-signing.sh` or the three GitHub Actions secrets
      (`docs/OS_BUILD.md` §Signing). Without that, the image is **flash-only**
      and OTA is untrusted with the self-signed cert.
- [ ] Review the current "Upstream release/security tracking" issue maintained
      by `.github/workflows/upstream-tracker.yml`; resolve any pinned upstream
      drift or security-review checklist items before publishing.
- [ ] Re-walk the rebrand checklist (`docs/OS_BUILD.md` §4). Applied today:
      product name/ID, hostname, console banner (`etc/issue` + `etc/motd`),
      branded landing page image, and branded CLI plugin image; GRUB is N/A on
      x86-64. Still Phase 2/P3: running Supervisor update-channel URL and
      frontend branding/default experience.
- [ ] Verify the Supervisor accepts the `faos` os-release identity on first
      boot (`docs/OS_BUILD.md` §4 — os-release ID verification).
- [ ] Resolve the `branding/identity.env` go-live placeholders (org, registry,
      version host, OTA host) before any published or OTA release.
- [ ] Publish the license bundle with the artifact
      (`docs/LICENSE_COMPLIANCE.md` §6).
- [ ] Boot-test on real hardware/VM (milestone P1, `docs/ARCHITECTURE.md` §11).
