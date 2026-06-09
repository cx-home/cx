# CXStore — Internal Design Index

**INTERNAL — DO NOT PUBLISH. DO NOT MIRROR TO `cx-home/cx`. DO NOT REFERENCE FROM `docs-src/content/`, `spec/`, OR `spec/decisions/`.**

This directory captures the in-flight design of CXStore — a content-addressed store and query engine for CX data, to be developed on top of the v0.8.0 baseline. The design is not yet locked, not yet ratified by ADR, and not yet announced. Treat everything here as commercial-shape strategy: hold inside `cx-home/private` only.

## Org layout (for context)

- `cx-home/private` — this monorepo. CXStore design + future implementation live here through Phase 1.
- `cx-home/cx` — public language mirror. Built from `docs-src/content/` + selected `spec/`; nothing in `docs-src/canonical/` reaches it.
- `cx-home/cx-v` — extracted pure-V CX reference implementation. Establishes the precedent for spinning subsystems into their own repos when they outgrow the monorepo.

## Files

- [`plan.md`](plan.md) — TL;DR plan, two-tier design (embedded + service), backend-orthogonal-to-tier framing, phase estimates (0.5 / 0.7 / 1 / 2 / 3), decision gates, prerequisites.
- [`embedded.md`](embedded.md) — Phase 0.5 spec: the URL-dispatched Embedded Store. Store interface + backends (LocalFiles / Memory / HTTP / HTTP-WebDAV / S3 / FTP / SFTP). Day-of-v0.8.0-shippable, BaseX-class feature set minus indexed-perf, forward-compatible with pack backend.
- [`pack_format.md`](pack_format.md) — Phase 1 sub-deliverable: pack file binary layout (the eventual indexed-perf backend within the Embedded tier).
- [`performance.md`](performance.md) — performance expectations + competitive positioning. Two Mermaid quadrant charts (ingest × query throughput; scale × cost-efficiency), per-workload estimates, scale envelopes, tail-latency honesty, slots for measured numbers as Phase 0.5+ ships.

## Publishing posture

- `docs-src/canonical/` is **not** consumed by `scripts/gen_docs/build.cx`; the docs pipeline only walks `docs-src/content/`.
- `make docs-publish` cannot reach these files.
- Do not promote any content here into `spec/`, `spec/decisions/`, or `docs-src/content/` until the design is explicitly approved for public ratification (ADR or doc-page).
- When that promotion eventually happens, scrub commercial/competitive framing first; keep the design content, drop the positioning.

## When to escalate to a normative spec change

CXStore is currently a *product strategy*, not a *language change*. Normative CX surface changes live in the spec (`spec/core/*.md`). Promoting CXStore into the spec is justified only if:

1. The product ships under the `cx` brand (vs. a separate name), AND
2. Layer-1 binding API additions are needed for store operations beyond the existing 16 methods, AND
3. Those additions are normative across all four Tier-1 bindings.

Until then, CXStore stays in canonical/.

## Spin-out triggers

The current commitment is **keep in `cx-home/private` through Phase 1** ([`plan.md`](plan.md)). Revisit the spin-out decision when any of the following becomes true:

| # | Trigger | Action |
|---|---|---|
| 1 | Phase 1 decision gate = "ship publicly" | Spin out **before** any public announcement |
| 2 | Different license desired for CXStore (BUSL / AGPL / source-available) than CX's permissive license | Spin out **before** any non-permissive code lands |
| 3 | External contributors want to commit to CXStore | Spin out **before** accepting the first external PR |
| 4 | CXStore needs heavy deps that bloat `cx-home/private`'s CI (FoundationDB, S3 SDKs, Tantivy, K8s integration) | Spin out at the point dependency creep starts |
| 5 | CXStore reaches a public 0.1 release | Spin out for public release artifacts |
| 6 | Any commercial / proprietary surface area is added | Spin out — never mix commercial with the open-source language repo |

**Spin-out target:** `cx-home/cxstore` (private until announcement). Pattern matches `cx-home/cx-v`: subsystem extracted from the monorepo into its own repo with a published-binding-only coupling back to CX.

**Cleanest moment to spin out:** end of Phase 1, just before public announcement. By then ast_bin v7's wire format is locked, Layer-1's API is locked, the embedded product is real, and CXStore can stand on the normative Layer-1 contract rather than on `cx-home/private` internals.
