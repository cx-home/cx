# CX Release & Publish Process

**Status:** Current.

This document specifies how a CX release is cut and published. It is a
**process/governance** specification. The release **gate** is normative in
[`core/code.md §11.6/§11.7`](../core/code.md); the **versioning**
axes are normative in [`process/governance.md §9`](governance.md);
this document is the authoritative end-to-end *procedure* that ties them together.

---

## 1 — One command

A release is cut with a single command from a clean `release/X.Y.0` (#666:
the version bump becomes the branch's final commit and the tag lands on that
bump commit, so the branch tip, the tag, the VERSION file, and the artifact
all name **one commit**; the script merges to `main` itself, which then
contains the tag as the merge's second parent — `vX.Y.Z` patch releases cut
from the same `release/X.Y.0` branch):

```sh
make cut-release ARGS='--dry-run vX.Y.Z'   # preview every step, zero writes
make cut-release ARGS='vX.Y.Z'             # cut + publish
```

`make cut-release` runs `scripts/release.sh` (`scripts/release.sh --help`). The
script is **sound** (gate-first, fail-fast) and **resilient** (pre-flight checks
every prerequisite before any irreversible step; `--dry-run` previews the whole
flow; `--no-publish` stops after the GitHub release). It **composes** the
existing building blocks rather than duplicating them.

## 2 — Phases

| # | Phase | What it does | Building block |
|---|---|---|---|
| 0 | Pre-flight | on `main`, clean tree, `RELEASE_NOTES_<tag>.md` present, tag free, `devbox`/`gh`/public-repo clones ready — else abort | `release.sh` |
| 1 | Gate | `make test` (the full version-agnostic `TEST_TARGETS`) + `make verify-doc-links` — **MUST** be green or the release aborts (no bump, no tag, no publish) | `tag_release.sh` under `devbox` |
| 2 | Bump | `VERSION` + all manifests stamped, `check-version-consistency` verified, **bump committed before the build** so the artifact's stamped commit is the tag commit; the built binary's self-reported version+commit are then asserted clean (`-dirty` marks any tree that doesn't reproduce its stamp — #666) | `bump_version.sh` / `tag_release.sh` |
| 3 | Build + package | `-prod` `cx`/`libcx`/`cx.h` for the maintainer platform → `cx-<tag>-<target>.tar.gz` + `cx-conformance-<tag>.zip` + `SHA256SUMS.txt` | `release.sh` |
| 4 | Tag + merge + push | annotated tag **on the release branch's bump commit**, then `release.sh` merges the branch to `main` (`--no-ff`) and pushes `main` + the branch + the tag together (#666) | `tag_release.sh` / `release.sh` |
| 5 | GitHub release | `gh release create <tag>` with `RELEASE_NOTES_<tag>.md` + the artifacts | `release.sh` |
| 6 | Mirror publish | publish the public `cx` + `cx-v` mirrors (allowlist copy), the org page, and the public tags | `make release-all` → `publish*.sh` |

The gate (phase 1) is the **single source of release confidence**: because
`release.sh` refuses to proceed on a red gate, a published tag is gate-green by
construction (the `code.md §11.6` evidence contract).

## 3 — The public mirrors

`cx-home/cx-private` is the **source**; the public `cx-home/cx` and
`cx-home/cx-v` repositories are **generated** by `scripts/publish*.sh` (a
default-deny allowlist copy — only curated paths are published; the spec process
tree, gate evidence, and internal scratch stay private by construction). Phase 6
stages, commits, pushes, and tags the mirrors. They are mirrors, never edited
directly. Clones are expected at `$PUBLIC_ROOT` (default `~/git-repos/cx/cx`) and
`$PUBLIC_V_ROOT` (default `~/git-repos/cx/cx-v`).

## 4 — CI status and the automatic path

> **Releases are cut locally** (§1). CI-based release is currently **unavailable**:
> GitHub Actions cannot allocate runners for the `cx-home` org — every workflow
> fails at startup (no runner; an org billing/runner-allocation constraint, not a
> workflow defect). All workflows under `.github/workflows/` are therefore
> `workflow_dispatch`-only so they do not fail on every push.

The CI release path is **ready** for when runners return: `.github/workflows/release.yml`
builds the patched V fork + RE2 on hosted runners, derives per-tag notes, and
publishes — it only lacks its `push: tags: ['v*.*.*']` trigger (removed while
runners are unavailable). To re-enable fully automatic, tag-push releases **without
paying for hosted minutes**, register a **self-hosted runner** (any machine you
control; no GitHub-minutes cost), switch the workflows' `runs-on:` to
`self-hosted`, and re-add the removed `push`/`tags`/`schedule` triggers. Verify
with `gh workflow run release.yml -f tag=vX.Y.Z` before re-arming the trigger.

Until then, `make cut-release` is the complete release path — local, gate-first,
zero-cost.

## 5 — Versioning (cross-reference)

The repo-root `VERSION` file is the single source of truth (see
[`governance.md §9`](governance.md)); code derives it via
the `cx_version` build define, manifests + README badges are stamped by
`bump_version.sh`, and drift is a red build via `check-version-consistency`
(wired into `TEST_TARGETS`). Per-release detail lives in `CHANGELOG.md` +
`RELEASE_NOTES_v*.md`; the latter is the authoritative release surface and is
also the body of the GitHub release (phase 5).

## 6 — Companion documents

- [`core/code.md §11.3–§11.7`](../core/code.md) — the normative release gates + evidence/sign-off.
- [`process/governance.md §9`](governance.md) — the versioning axes.
- [`process/v-dependency-management.md`](v-dependency-management.md) — the patched-V fork the build depends on.
- `scripts/release.sh --help` — the executable procedure (§1/§2).
