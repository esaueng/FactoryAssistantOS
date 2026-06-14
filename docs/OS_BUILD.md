# Building Factory Assistant OS

How to produce a bootable Factory Assistant OS image for **generic x86-64**,
and how the build is structured. Two paths share the same overlay:

- **Path A — overlay build** (works now): build on top of the *pinned
  upstream* Home Assistant OS source tree with the Factory Assistant overlay
  applied at build time. No fork maintenance; ideal until Phase 2.
- **Path B — true fork** (Phase 2): this repository becomes a real fork of
  `home-assistant/operating-system` with the overlay merged in and upstream
  tags merged on a cadence.

> Honest status: the pipeline below is defined and scripted but has not yet
> been CI-verified end to end. First verification on real hardware/VM is
> milestone P1 (`docs/ARCHITECTURE.md` §11). If an upstream invocation
> differs at your pinned tag, the upstream build guide inside the checkout —
> `upstream/operating-system/Documentation/` — is authoritative.

## 1. Prerequisites

- Linux x86-64 build host (bare metal or VM), Docker installed and usable by
  your user (the build runs inside upstream's build container via
  `scripts/enter.sh`; `sudo` may be required).
- `git`, `rsync`, GNU make.
- ~50 GB free disk, 8+ GB RAM; first build takes several hours (full
  Buildroot toolchain + system compile). Subsequent builds are incremental.
- Network access to GitHub and the distro mirrors Buildroot fetches from.

## 2. Path A — overlay build (current)

```sh
make bootstrap   # clones upstream OS repo at the tag pinned in upstream.env
                 # (incl. the Buildroot submodule — large) into upstream/
make overlay     # applies the Factory Assistant delta (see below)
make os          # runs the containerized build: scripts/enter.sh make generic_x86_64
```

`make overlay` (= `scripts/apply-overlay.sh`) does three idempotent things:

1. rsyncs `buildroot-external/` over the upstream tree (same relative
   paths): hostname, console banner, the industrial config template.
2. rewrites product identity in upstream's `buildroot-external/meta`
   (`HASSOS_NAME` → "Factory Assistant OS", `HASSOS_ID` → `faos`), keeping
   upstream variable *names* so upstream scripts keep working.
3. appends `buildroot-external/configs/factory-assistant.config` to the
   upstream `generic_x86_64_defconfig` (last kconfig assignment wins).

### Output

Build artifacts land under `upstream/operating-system/output/images/`
(release scripts may also populate `release/`). The flashable image is:

```
faos_generic-x86-64-<version>.img.xz
```

The `faos` prefix comes from the rebranded `HASSOS_ID`; `<version>` follows
the upstream `meta` version at the pinned tag (versioning policy: §6).
A RAUC update bundle (`.raucb`) for the same version is produced alongside.

### Other targets

`TARGET=<board> make os` selects another upstream defconfig (e.g. `ova` for
the virtual appliance). Only `generic_x86_64` carries the FA overlay today;
extend `scripts/apply-overlay.sh` per board when adding targets.

## 3. Flash and first boot

**Physical x86-64 box** (industrial PC / NUC-class, UEFI boot enabled):

```sh
xz -d faos_generic-x86-64-<version>.img.xz
# DANGER: double-check the device node — this destroys the target disk.
sudo dd if=faos_generic-x86-64-<version>.img of=/dev/sdX bs=8M status=progress conv=fsync
```

(or use a GUI flasher like balenaEtcher; writing to a USB stick and booting
from it also works for evaluation — the data partition grows to fill the disk
on first boot.)

**VM evaluation** (QEMU/KVM with UEFI firmware, illustrative):

```sh
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive file=faos_generic-x86-64-<version>.img,format=raw,if=virtio \
  -nic bridged-or-user-networking-of-your-choice
```

**First boot**: the appliance gets a DHCP lease, announces itself via mDNS,
and serves the landing page while Core comes up. Open
`http://factory-assistant.local:8123` (or `http://<ip>:8123`) and complete
onboarding. Console shows the Factory Assistant banner with this URL.

## 4. Rebrand override checklist

Status legend: **A** = covered by the overlay today · **P2/P3** = phased work
· every row must be **re-verified whenever `upstream.env` is bumped** (file
paths move between upstream releases).

| Item | Where | Status |
|---|---|---|
| Product name / OS ID (`HASSOS_NAME`, `HASSOS_ID`) → image filename, os-release | `buildroot-external/meta` (sed by overlay) | A |
| Hostname `factory-assistant` (mDNS name) | rootfs overlay `etc/hostname` + defconfig fragment | A |
| Console banner with attribution | rootfs overlay `etc/issue` + defconfig fragment | A |
| Industrial default Core config template | rootfs overlay `usr/share/factory-assistant/` | A (seeding: P3) |
| os-release **CPE product** vs **unmodified** Supervisor OS-detection (allowlist `{hassos, haos}`) | `scripts/apply-overlay.sh` rewrites the `post-build.sh` CPE product to `haos` (keeps `ID=faos` + branded `NAME`); the product is an internal OS-family id (invariant 4) | A |
| Supervisor/Core/plugin container registry + image names | Supervisor image: rootfs overlay `hassos-supervisor` (`SUPERVISOR_IMAGE`, cold boot). Core + 5 plugins: channel `images` map (`version-service/stable.json`), which the **running** Supervisor reads only after the `const.py` patch | supervisor img: A · core+plugins: P2 verified by component preflight |
| Update channel URL → FA version service | cold boot: rootfs overlay `hassos-supervisor` fallback. **Running Supervisor: hardcoded `const.py` `URL_HASSIO_VERSION`** → see `docs/forks/supervisor/` | overlay: A · running fork: P2 verified by Supervisor channel patch preflight |
| **RAUC signing keys + device keyring + OTA URL** | `scripts/configure-rauc-signing.sh`, build workflow secrets, `version-service/` | P2 implementation path exists; production OTA requires real external keys/secrets |
| Host login banner (MOTD) | rootfs overlay `etc/motd` (replaces upstream's HA MOTD) | A |
| GRUB menu title / boot splash | generic-x86-64 `board/pc/grub.cfg` is a functional A/B slot menu with **no product branding** — nothing to rebrand for this board (the separate `ova` image's `home-assistant.ovf` would need it if that target is built) | N/A (x86-64) |
| Landing page text/art | `landingpage/` image context + `.github/workflows/mirror-fa-plugins.yml` | A (workflow-built branded image) |
| Containerized CLI-plugin banner | `plugin-cli/` image context + `.github/workflows/mirror-fa-plugins.yml` | A (workflow-built branded image) |
| Plant overview default dashboard | rootfs overlay `usr/share/factory-assistant/configuration.yaml` + `dashboards/factory-overview.yaml` | A |
| Frontend product branding, About dialog, and local-first onboarding bridge | `frontend` fork | P3 bridge implemented in fork |
| Native read-only machine card | `frontend` fork (`custom:fa-machine-card`) | P3 implemented in fork |
| Native read-only andon view | `frontend` fork (`custom:fa-andon-view`) | P3 implemented in fork |
| Native read-only wallboard kiosk | `frontend` fork (`custom:factory-wallboard-kiosk`) | P3 implemented in fork |
| Native plant navigation | `frontend` fork (`ha-sidebar`) | P3 implemented in fork |
| Dashboard wiring and full industrial onboarding wizard | `frontend` fork | P3 |

**Component ownership preflight.** Before cutting a trusted tag, run
`scripts/verify-component-ownership.sh --channel version-service/stable.json
--owner esaueng` with authenticated `gh` access. It checks the required
component forks, rejects channel images outside `ghcr.io/esaueng`, and verifies
every exact channel image tag is anonymously pullable from GHCR. It also runs
the published industrial add-on manifests check for
`factory-assistant-addons` so the installable add-on repository stays aligned
with the OS-shipped catalog, verifies the published industrial add-on image tags
referenced by those manifests are anonymously pullable from GHCR, plus
`scripts/verify-supervisor-channel-patch.sh` so the running Supervisor fork
is proven to read the Factory Assistant version channel. The tag build
workflow runs the same check with `GH_COMPONENT_READ_TOKEN` when that secret
is set, falling back to the workflow token.

**os-release ID verification (P1).** After first boot, confirm the Supervisor
accepts the `faos` OS identity: Settings → About reports "Factory Assistant
OS"; `ha os info` and `ha supervisor info` succeed with no "unsupported OS"
health warning; OS updates and backups are offered; the observer page
(`:4357`) is healthy. If any of these degrade, keep the functional os-release
ID fields upstream-compatible unless a documented Supervisor fork decision
supports a different value — do **not** change `HASSOS_ID` away from `faos`
without that decision (AGENTS.md invariant 4). Record the result in
`RELEASE.md`.

## 5. Signing (RAUC) — Phase 2, blocking for OTA

RAUC update bundles (`.raucb`) are signed with a Factory Assistant key and
verified on-device against a keyring baked into the image at build time. A
device must only ever trust Factory Assistant certificates — never upstream's,
and never development certificates in shipped images. Until this is wired,
images are flash-only (no OTA), which is acceptable for P1.

> **Private keys are NEVER committed.** `.gitignore` refuses `*.pem`, `*.key`,
> and `*.crt` repo-wide (confirm with `git check-ignore faos-ota.key`). The CA
> private key and the signing private key live on offline/HSM-backed storage,
> not on the build host's working tree and not in CI secrets that land on disk.

### 5.1 Generate the CA and signing certificate (offline, one time)

Do this on an air-gapped machine. The CA private key signs the signing cert
and is then locked away; day-to-day bundle signing uses only the signing key.
Use the repository helper so the certificate extensions and file names match
the release workflow:

```sh
scripts/generate-rauc-signing-material.sh --out-dir /secure/faos-rauc
```

The helper writes:

- `/secure/faos-rauc/faos-rauc-ca.key` — root CA private key; keep offline.
- `/secure/faos-rauc/faos-rauc-ca.crt` — public root CA/device keyring.
- `/secure/faos-rauc/faos-rauc-signing.key` — bundle-signing private key.
- `/secure/faos-rauc/faos-rauc-signing.csr` — signing CSR.
- `/secure/faos-rauc/faos-rauc-signing.crt` — code-signing certificate.

Keep the two `*.key` files offline. Only the **public**
`faos-rauc-ca.crt` is the device keyring input, and even that is referenced
from outside the repo — `*.crt` remains gitignored.

### 5.2 Wire the device keyring at build time

RAUC on the device verifies bundles against `/etc/rauc/keyring.pem`, which
upstream installs from the `BR2_EXTERNAL` tree. Point that keyring at the
Factory Assistant CA certificate so a flashed device trusts FA bundles only.
After `make bootstrap && make overlay`, run:

```sh
scripts/configure-rauc-signing.sh \
  --keyring /secure/faos-rauc/faos-rauc-ca.crt \
  --cert /secure/faos-rauc/faos-rauc-signing.crt \
  --key /secure/faos-rauc/faos-rauc-signing.key
```

The script validates that the signing certificate verifies against the supplied
CA, that the private key matches the signing certificate, and that all three
source files live outside this repository. It then copies the inputs into the
gitignored upstream checkout at the locations HAOS 17.3 uses during build:

- `upstream/operating-system/buildroot-external/ota/rel-ca.pem`
- `upstream/operating-system/buildroot-external/ota/dev-ca.pem`
- `upstream/operating-system/cert.pem`
- `upstream/operating-system/key.pem`

Both `rel-ca.pem` and `dev-ca.pem` are replaced with the Factory Assistant CA
so a production build never bakes upstream or development CA trust into the
device keyring. Verify the baked keyring after a build: `rauc info
--keyring=… <bundle>` must validate FA-signed bundles and reject upstream or
development-signed ones.

### 5.3 Sign release bundles

HAOS signs the `.raucb` during image assembly with `/build/cert.pem` and
`/build/key.pem`. Because the build container mounts
`upstream/operating-system` at `/build`, running
`scripts/configure-rauc-signing.sh` before `make os` signs the release bundle
with the Factory Assistant signing key:

```sh
make bootstrap
make overlay
scripts/configure-rauc-signing.sh \
  --keyring /secure/faos-rauc/faos-rauc-ca.crt \
  --cert /secure/faos-rauc/faos-rauc-signing.crt \
  --key /secure/faos-rauc/faos-rauc-signing.key
make os
```

Run signing where the signing key is available (ideally an offline/HSM-backed
release host). In GitHub Actions, set all three repository secrets together:

- `FAOS_RAUC_KEYRING_PEM`
- `FAOS_RAUC_CERT_PEM`
- `FAOS_RAUC_KEY_PEM`

Before cutting a tag through Actions, verify the secret names are present:

```sh
scripts/configure-github-rauc-secrets.sh \
  --repo esaueng/FactoryAssistantOS \
  --keyring /secure/faos-rauc/faos-rauc-ca.crt \
  --cert /secure/faos-rauc/faos-rauc-signing.crt \
  --key /secure/faos-rauc/faos-rauc-signing.key

scripts/verify-github-rauc-secrets.sh --repo esaueng/FactoryAssistantOS
```

The installer validates that the signing certificate chains to the supplied
Factory Assistant CA, verifies that the signing private key matches the
certificate, rejects source files from inside this repository, and streams the
three PEM values to GitHub without printing them. The verifier uses
`gh secret list` and checks names only; GitHub does not expose secret values.

If all three are present, `.github/workflows/build-os-image.yml` installs them
with `scripts/configure-rauc-signing.sh` and the generated `.raucb` is trusted
by images from that run. The tag release workflow refuses to publish without
all three RAUC secrets, so GitHub Releases cannot accidentally ship a
self-signed OTA bundle. Manual `workflow_dispatch` builds with no RAUC secrets
may still use a public self-signed development certificate and are labeled
flash-only. A partial secret configuration fails the build. After the release
steps, CI scrubs the temporary RAUC PEM files and upstream build-tree signing
inputs from the runner workspace.

### 5.4 Publish

Publish signed bundles at the OTA URL template in `branding/identity.env`
(`FAOS_OTA_URL_TEMPLATE`) and reference them from the channel JSON under
`version-service/` (validated by `version-service/schema/channel.schema.json`).

Before cutting a `v*` tag, run the local release preflight with the same
external RAUC inputs:

```sh
scripts/verify-release-readiness.sh \
  --channel version-service/stable.json \
  --keyring /secure/faos-rauc/faos-rauc-ca.crt \
  --cert /secure/faos-rauc/faos-rauc-signing.crt \
  --key /secure/faos-rauc/faos-rauc-signing.key
```

The preflight validates the CA/signing certificate/private key relationship,
refuses signing material from inside the repository, and checks that the
channel document points at the Factory Assistant registry and OTA template.

## 6. Versioning policy

Factory Assistant OS versions **track upstream MAJOR.MINOR** (FA OS 16.2 =
upstream 16.2 + FA delta); rebuilds of the same upstream base append a patch
suffix per upstream's scheme. This keeps security provenance and the
Supervisor's OS-version expectations simple.

## 7. Path B — true fork (Phase 2)

1. Create the org fork: `git clone --mirror` upstream → push to
   `REPLACE-ORG/operating-system`; this repo's history merges in (overlay
   files land at their final paths; `scripts/apply-overlay.sh` retires).
2. Add `upstream` as a git remote; merge upstream **release tags** (not
   `main`) on a cadence — at minimum for upstream security releases.
   `.github/workflows/upstream-tracker.yml` maintains a weekly tracking issue
   with current upstream release/tag state, the latest published repository
   security advisory found through GitHub's advisory API, and the manual
   security-review checklist that must be cleared before bumping pins.
3. Conflict policy: branding/identity files → ours; everything else →
   take upstream and re-apply the minimal delta; every merge re-walks the §4
   checklist. Any divergence of internal identifiers (`HASSOS_*`, `hassio`,
   board names, port 8123) still requires a documented decision (AGENTS.md
   invariant 4) — the fork does not relax that.
4. CI: adapt upstream's GitHub Actions build workflows to build
   `generic_x86_64` on PR (artifact upload) and signed release bundles on
   tags.

## 8. License bundle per release

Every published image/release must ship its third-party license texts:
Buildroot's `make legal-info` (run inside the build container against the
same config) collects licenses/sources for the host OS; container-layer
notices are handled per `docs/LICENSE_COMPLIANCE.md` §Release checklist.

## 9. Troubleshooting

- **Submodule fetch slow/fails**: re-run `make bootstrap` (idempotent);
  the Buildroot submodule is large.
- **`enter.sh` permission errors**: the build container needs Docker
  privileges; try `sudo make os`, or add your user to the `docker` group.
- **Disk full mid-build**: Buildroot needs tens of GB; `make clean` removes
  output but keeps downloaded sources (`dl/` cache) for the next run.
- **Defconfig fragment didn't take**: confirm the marker block at the end of
  `upstream/operating-system/buildroot-external/configs/generic_x86_64_defconfig`
  and re-run `make overlay`.
- **Image boots but UI never appears**: first boot downloads/activates the
  Core container — give it time on slow links; check the observer page on
  port 4357, or the console.
