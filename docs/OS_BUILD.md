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
| os-release `ID` change vs **unmodified** Supervisor OS-detection checks | verify on first boot; if OS update/management features degrade, keep functional ID fields compatible until the Supervisor fork lands | P1 verify |
| Supervisor/Core container registry + machine image names | upstream `hassio` package config + Supervisor fork constants | P2 |
| Update channel URL → FA version service | `hassio` package config / Supervisor fork | P2 |
| **RAUC signing keys + device keyring + OTA URL** | build config + `version-service/` | **P2 — required before any OTA** |
| GRUB menu title, boot splash | `buildroot-external/bootloader` & board files | P2 |
| Landing page, CLI plugin banner (MOTD) | `landingpage` / `plugin-cli` forks | P2 |
| Frontend branding, default factory dashboard, onboarding wording | `frontend` fork | P3 |

## 5. Signing (RAUC) — Phase 2, blocking for OTA

Until done, images are flash-only (no OTA), which is acceptable for P1.

1. Generate a Factory Assistant CA + signing certificate (offline key
   storage; never in git — `.gitignore` already refuses `*.pem/*.key/*.crt`):
   `openssl req -x509 -newkey rsa:4096 -keyout faos-ota.key -out faos-ota.crt -days 3650 -nodes -subj "/CN=Factory Assistant OS OTA"`
2. Configure the build so the **device keyring trusts the FA certificate**
   (upstream wires the keyring through the `BR2_EXTERNAL` tree — follow the
   OTA/RAUC section of upstream `Documentation/` at the pinned tag) and sign
   release bundles with the FA key.
3. Publish bundles at the OTA URL template in `branding/identity.env`, and
   reference them from the channel JSON (`version-service/`).

Rule: a device must only ever trust Factory Assistant certificates — never
upstream's, and never development certificates in shipped images.

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
3. Conflict policy: branding/identity files → ours; everything else →
   take upstream and re-apply the minimal delta; every merge re-walks the §4
   checklist.
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
