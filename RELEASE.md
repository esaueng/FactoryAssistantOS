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
| Builder image + full Buildroot compile | ⛔ not run here | blocked in this environment by disk (<50 GB) and a network policy that 403s the Docker CDN — run on CI or a Linux host (below) |

So the rebrand/overlay is proven against the actual pinned upstream; the
heavy compile must run where resources allow.

## Path 1 — GitHub Actions (recommended, repeatable)

Workflow: [`.github/workflows/build-os-image.yml`](.github/workflows/build-os-image.yml).
It frees runner disk, runs `bootstrap` + `apply-overlay`, builds inside the
upstream builder container, then uploads the image (and on a tag, publishes a
Release with checksums + license bundle).

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
# self-signed dev cert -> flash-only image (FA RAUC keys are Phase 2)
( cd upstream/operating-system && buildroot-external/scripts/generate-signing-key.sh cert.pem key.pem )
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

- [ ] This is a **flash-only** image unless Factory Assistant RAUC keys are
      configured (`docs/OS_BUILD.md` §Signing) — OTA is untrusted with the
      self-signed cert.
- [ ] Re-walk the rebrand checklist (`docs/OS_BUILD.md` §4) — Phase 2 items
      (registry, update channel, landing page/CLI banner) are not yet applied.
- [ ] Publish the license bundle with the artifact
      (`docs/LICENSE_COMPLIANCE.md` §6).
- [ ] Boot-test on real hardware/VM (milestone P1, `docs/ARCHITECTURE.md` §11).
