# CX Release & Publish Process

**Status:** Current.

This document specifies how a CX release is cut and published. It is a
**process/governance** specification. The release **gate** is normative in
[`core/code.md §11.6/§11.7`](https://github.com/cx-home/cx-core-code/blob/main/spec/03-approved/core/code.md); the **versioning**
axes are normative in [`process/governance.md §9`](governance.md);
this document is the authoritative end-to-end *procedure* that ties them together.

---

## 1 — One command

A release is cut with a single command from a clean `release/X.Y.0` (#666:
the version bump becomes the branch's final commit and the tag lands on that
bump commit, so the branch tip, the tag, the VERSION file, and the artifact
all name **one commit**; the flow merges to `main` itself, which then
contains the tag as the merge's second parent — `vX.Y.Z` patch releases cut
from the same `release/X.Y.0` branch):

```sh
make release-flow TAG=vX.Y.Z MODE=dry   # preview every step, zero writes
make release-flow TAG=vX.Y.Z            # cut + publish
```

`make release-flow` runs `flows/release.flow.cx`, the flow document that
replaced `scripts/release.sh` (RULED: RFLOW-1 L103). The procedure is
**sound** (gate-first, fail-fast) and **resilient**: pre-flight checks every
prerequisite before any irreversible step; `MODE=dry` previews the whole flow;
`PUBLISH=no` stops after the GitHub release; and the local phases before the
push are undone in reverse when a later one refuses. It **composes** the
existing building blocks rather than duplicating them.

## 2 — Phases

| # | Phase | What it does | Building block |
|---|---|---|---|
| 0 | Pre-flight | on the line branch, clean tree, `RELEASE_NOTES_<tag>.md` present, tag free, **the pins in sync** (`make deps-check` — RS-7's "a release cut ships whatever is pinned", and a cut that ships a stale pin ships a binary nobody can rebuild), `devbox`/`gh` ready — else abort (no `cx-v` clone to check for since D81a: see §3) | `release.flow.cx` |
| 1 | Gate | `make test` (the full version-agnostic `TEST_TARGETS`) + `make verify-doc-links` — **MUST** be green or the release aborts (no bump, no tag, no publish) | `tag_release.sh` under `devbox` |
| 1b | Perf ratchet | `make perf-ratchet` — `bench-json` then `bench-compare STRICT=1` against the committed `bench/baseline.json`; any benchmark more than 10 % slower than the previous cut (or a `_mbps` throughput more than 10 % lower) **aborts the cut** like a red gate; on green the fresh `bench/current.json` becomes `bench/baseline.json` in the bump commit, so each cut re-pins the floor to its own measurement on the maintainer machine (#1249, RULED: 1249-Q1a) | `tag_release.sh` → `make perf-ratchet` |
| 2 | Bump | `VERSION` + all manifests stamped, `check-version-consistency` verified, **bump committed before the build** so the artifact's stamped commit is the tag commit; the built binary's self-reported version+commit are then asserted clean (`-dirty` marks any tree that doesn't reproduce its stamp — #666) | `bump_version.sh` / `tag_release.sh` |
| 3 | Build + package | `-prod` `cx`/`libcx`/`cx.h` for the maintainer platform → `cx-<tag>-<target>.tar.gz` + `cx-conformance-<tag>.zip` + `SHA256SUMS.txt`, and the four §4 profile tarballs, **each built from the pins**: `make deps-sync` fetches every `[dep]` row into `deps/`, and a module whose repository has left is embedded from that checkout, so the four builds are the pinned set and nothing else | `release.flow.cx` |
| 4 | Tag + merge + push | annotated tag **on the release branch's bump commit**, then the flow merges the branch to `main` (`--no-ff`) and pushes `main` + the branch + the tag together (#666) | `tag_release.sh` / `release.flow.cx` |
| 5 | GitHub release | `gh release create <tag>` with `RELEASE_NOTES_<tag>.md` and **every** artifact — the version-named tarballs, the conformance bundle, and the flat stable-named set the quickstart's `releases/latest/download/cx-<plat>.tar.gz` resolves to, with ONE `SHA256SUMS.txt` over both sets (the installer verifies against it) | `release.flow.cx` |
| 6 | The org page | sync the organisation profile README (the `cx-v` mirror retired at the cut, RULED: D81a) | `make release-all` → `publish_org.sh` |

The gate (phase 1) is the **single source of release confidence**: because
`release.flow.cx` refuses to proceed on a red gate, a published tag is gate-green by
construction (the `code.md §11.6` evidence contract).

## 3 — One repository, one release (RULED: RS-11)

There used to be an allowlist mirror: `cx-home/cx-private` was the source and
the public `cx-home/cx` was generated from it by `scripts/publish.sh`, a
default-deny copy of curated paths, with its own GitHub releases carrying the
flat stable-named assets. RS-11 retires it — *"Public or private is a setting
per repository. The allowlist mirror (`scripts/publish.sh`, `.publishignore*`,
the guard) retires with the split; `cx-private` becomes `cx` when it is no
longer private."*

So there is **one** repository and **one** release. Phase 5 attaches both asset
sets to it: the version-named tarballs and the conformance bundle from `dist/`,
and the flat stable-named set and the four profile tarballs from `dist/public/`
— a directory whose name says what those assets *are*, flat and stable, not
where they go. The site files the mirror used to install (`CNAME`, the
quickstart `install` script) live in `docs/`, the site root itself.

`cx-home/cx-v` retires at the cut (RULED: D81a). The V fork is
`cx-home/v`, branch `cx-patches-0.18`, pinned by every V repository's
`deps.cxd` `v-fork=` — one fork, one pin, no second copy to drift; its
distribution is [`v-dependency-management.md`](v-dependency-management.md)'s
subject. `cx-home/cx-v` is archived at the cut with a README pointing at
`cx-home/v` and takes no further pushes or tags.

## 3.1 — What a cut ships is what is pinned

RS-7: *"A release cut ships whatever is pinned."* `deps.cxd` names every
repository `cx` builds on at a sha; `make deps-sync` fetches each into `deps/`,
and a module whose repository has left this tree is embedded from that checkout
([`repository-dependency-pins.md`](repository-dependency-pins.md) §6); the four
§4 profile builds then read exactly that set. A stale pin or a drifted
`deps/` checkout **aborts the cut in phase 0** — it never warns, and it is
never resolved to "whatever is newest". What a release was built from is the
`deps.cxd` of its tag commit, and the conformance bundle carries that file.

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

Until then, `make release-flow` is the complete release path — local, gate-first,
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

- [`core/code.md §11.3–§11.7`](https://github.com/cx-home/cx-core-code/blob/main/spec/03-approved/core/code.md) — the normative release gates + evidence/sign-off.
- [`process/governance.md §9`](governance.md) — the versioning axes.
- [`process/v-dependency-management.md`](v-dependency-management.md) — the patched-V fork the build depends on.
- `flows/release.flow.cx` — the executable procedure (§1/§2), its header the usage.
