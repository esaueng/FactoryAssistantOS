# Working agreements

Complete the requested work. Infer scope from context, make reasonable
implementation choices, and continue until finished or genuinely blocked.
Keep investigation-only requests read-only.

An explicit request or prior approval authorizes that action. Do not ask
again. Ask only when consequential ambiguity remains or an additional action
falls outside the authorized scope. Complete independent work while waiting.

Follow repository conventions. Keep changes focused. Preserve units,
tolerances, defaults, formats, and public contracts unless changes are
required. Label approximations and flag breaking changes or new dependencies.

Run required checks and tests proportional to the change. Add regression
coverage for bug fixes. Do not weaken assertions or bypass protections.
Attempt routine recovery from missing tools or Git refs before reporting a
blocker. Distinguish local validation from production verification.

Keep secrets, private instructions, and identifying information out of shared
artifacts. Inspect staged content and metadata before committing. Use the
approved repository Git identity.

## Delivery

- Use a branch and a ready-for-review pull request for repository changes.
- A merge request authorizes the identified pull request’s merge and its
  existing automatic deployment. Mention that consequence and proceed
  without another confirmation.
- Before merging, verify the current head, mergeability, reviews, and required
  checks. Wait for pending checks. Existing approval remains valid for the
  authorized change.
- Bypassing CI requires explicit authorization for the specific pull request.
  Disclose affected checks and risks; preserve review requirements.
- Standalone production deployments and manual migrations require
  authorization. An explicit request to perform them is sufficient.
- Resolve the target repository, environment, and account from configuration
  and context. Ask only if the target remains ambiguous.

Report the outcome briefly, followed by verification, actual blockers, and
relevant links. Never claim an unverified result passed.

---

# AGENTS.md — working in this repository

Guidance for contributors and coding agents. Read this before changing
anything; the four invariants below are hard requirements for every change.

## What this repository is

The OS build repository for **Factory Assistant OS**, an industrial monitoring
appliance derived from Home Assistant OS. It contains:

- documentation of the whole multi-repo architecture (`docs/`),
- the Factory Assistant delta/overlay applied on top of the upstream
  `home-assistant/operating-system` Buildroot tree (`buildroot-external/`),
- build automation (`scripts/`, `Makefile`),
- identity and upstream pins (`branding/identity.env`, `upstream.env`).

The Core, Supervisor, frontend, and add-ons live in their own forked
repositories (see the repo map in `docs/ARCHITECTURE.md`). This repo is the
root of the system and the place where the appliance image is built.

## The four invariants

1. **Licensing** — Never remove or alter upstream license headers, `LICENSE`
   files, or `NOTICE` content. New first-party files are Apache 2.0. Every
   released image must ship its third-party license bundle
   (`make legal-info`). Details: `docs/LICENSE_COMPLIANCE.md`.
2. **Branding** — Home Assistant names, logos, or assets (including anything
   from the `home-assistant/brands` repository) must never appear as Factory
   Assistant branding. The only permitted use of the upstream name is factual
   attribution, canonically: “Factory Assistant is based on Home Assistant.”
   Details: `docs/BRANDING.md`.
3. **Safety boundary** — Do not add, scaffold, or document features that
   implement safety functions: emergency stops, interlocks, safety PLC logic,
   safety-rated alarms, or real-time control loops. Industrial protocol
   defaults stay read-only. Any change that adds a *write/control* path to
   machines requires an explicit roadmap gate and an update to
   `docs/SAFETY_BOUNDARY.md` first. Details: `docs/SAFETY_BOUNDARY.md`.
4. **Upstream compatibility** — Keep the delta against upstream minimal and
   mergeable. Rebrand *user-visible* strings and values only; keep *internal*
   identifiers (variable names like `HASSOS_*`, package names like `hassio`,
   machine names like `generic-x86-64`, D-Bus names, API paths, port 8123)
   upstream-compatible unless a documented Phase 2 decision says otherwise.

## Repo map

| Path | What it is | Rules |
|---|---|---|
| `docs/*.md` | Canonical project documentation | Keep cross-links valid; these are deliverables |
| `buildroot-external/` | Overlay files mirrored at the same relative paths as upstream's `buildroot-external/` | Only delta files; never vendor whole upstream files unless modified |
| `buildroot-external/configs/factory-assistant.config` | Defconfig fragment appended to the upstream x86-64 defconfig | Keep values in sync with `branding/identity.env` |
| `branding/identity.env` | Product identity (name, ID, hostname, registry/URL placeholders) | Single source of truth; scripts read it |
| `upstream.env` | Pinned upstream repos and tags | Bump deliberately; record the bump in the commit message |
| `scripts/` | POSIX-ish bash, `set -euo pipefail` | Must stay idempotent; check with `bash -n` (and `shellcheck` if available) |
| `version-service/` | Update-channel JSON example + docs | Illustrative until Phase 2 |
| `upstream/`, `output/`, `release/` | Build-time clones and artifacts | **Never commit** (gitignored) |

## Common tasks

- **Build the image**: `make bootstrap && make overlay && make os`
  (Linux + Docker required; see `docs/OS_BUILD.md` for prerequisites,
  flashing, and troubleshooting).
- **Add or change a rebrand item**: put the file under `buildroot-external/`
  at the upstream-relative path, or extend `scripts/apply-overlay.sh` if it
  must be a targeted edit (like the `meta` sed). Then update the rebrand
  checklist table in `docs/OS_BUILD.md`.
- **Bump upstream**: edit `upstream.env`, run a fresh
  `make distclean bootstrap overlay`, re-verify every row of the rebrand
  checklist against the new tag (upstream layout moves), and note the bump in
  the commit message.
- **Convert to a true fork (Phase 2)**: follow the Path B procedure in
  `docs/OS_BUILD.md` §7 — overlay files land at their final paths,
  `scripts/apply-overlay.sh` retires, and upstream release tags merge on a
  cadence (branding/identity → ours; internal identifiers stay upstream-compatible).
- **Add documentation**: put it in `docs/`, link it from `README.md`'s table.
  Upstream merges may later introduce a `Documentation/` directory; `docs/`
  stays canonical for Factory Assistant.

## Validation before committing

There is no compiled OS code here, but the overlay templates, the update
channel document, and the docs are validated without a full build:

```sh
make lint            # scripts (bash -n + shellcheck), YAML parse + yamllint,
                     # channel JSON + schema, Markdown cross-links
git status --short   # no upstream/ or artifacts staged
```

`make lint` runs `scripts/lint.sh`; it degrades gracefully when optional tools
(`shellcheck`, `yamllint`, `check-jsonschema`) are absent locally and runs them
strictly in CI (`.github/workflows/lint.yml`). Lint config lives in
`.shellcheckrc` and `.yamllint`. The same checks run on every push/PR, so keep
the tree green — a renamed doc with a dangling cross-link or a malformed
template fails the lint, not just review.

## Things you must not do

- Don't commit `upstream/`, `output/`, `release/`, images, or RAUC bundles.
- Don't commit private keys or certificates (RAUC signing material lives
  outside the repo; see `docs/OS_BUILD.md` §Signing).
- Don't copy Home Assistant logos/icons or `home-assistant/brands` assets.
- Don't rename internal upstream symbols for cosmetic reasons.
- Don't add safety-function code, configs, or docs (invariant 3).
- Don't invent version numbers or URLs as if they were live — placeholders use
  `.example` domains or `REPLACE-ORG` and are flagged as such.

## Commit conventions

Imperative subject line, body explaining *why*, one logical change per commit.
Reference the doc updated when behavior or policy changes (docs and scripts
must not drift apart).
