# CX Roadmap

This is CX's public roadmap: what is integrating now, what is queued,
and what is deliberately *not* planned. It is forward-looking only —
what has actually shipped lives in [`CHANGELOG.md`](CHANGELOG.md) and
the per-release `RELEASE_NOTES_v*.md` files, and the current release
is the version badge in [`README.md`](README.md).

Two standing rules for reading this document:

- **Priorities are set by the project owner.** Items below are derived
  from the open issue tracker; ordering and inclusion can change at the
  owner's discretion, and nothing here is a delivery commitment.
- **The tracker is the live queue.** The
  [issue tracker](https://github.com/cx-home/cx/issues) is always more
  current than this file.

## Stability boundary

**v0.8.0 was the API/format-stability boundary:** from v0.8.0 onward
through 1.0, no breaking changes to the public surface (C ABI, binding
APIs, wire formats, spec-normative grammar) without a documented
migration in the release notes.

---

## Now — the `release/0.16.0` partition line

The release in progress (see the *Unreleased* section of
[`CHANGELOG.md`](CHANGELOG.md) for the authoritative running list). Its
headline is architectural rather than a feature list:

- **The four-ring partition** — CX is separated into four rings with a
  one-directional import contract: **Ring 0 Data** (the format: values,
  identity, surfaces, schema), **Ring 1 Code** (execution: programs,
  capabilities, computation identity), **Ring 2 Platform** (store,
  history, wire, services, operations) and **Ring 3 Ecosystem**
  (distribution, registry, marketplace, bindings). A ring may depend
  only inward. This is what makes "adopt the data format without
  adopting the runtime" a supported position rather than an accident,
  and it is enforced by gates (ring-tag, ring-import, per-profile
  extraction) rather than asserted in prose.
- **Build profiles** — the partition made buildable: per-ring artifacts
  with verified installer assets, so a consumer takes only the ring they
  need.
- **Seven concept specs graduated** — the semantic value model,
  computation identity, bitemporal time, commands and effects, the
  consistency vocabulary, schema and event evolution, and runtime
  representation moved to approved status, and each becomes a taught
  guide arc in this release rather than a spec link.
- **A reference application** — an in-family XAP (`reference/shop`) with
  a committed cascade, a composed feature, real packaging through the
  distribution engine, a separate web client, and `cx xap init`
  scaffolding a project that already composes.
- **The ux projection capability, specified** — the third projection:
  the same command/query definitions that serve the wire and the
  agent-tools face project forms, tables, and live regions through a
  closed semantic vocabulary with web and terminal faces
  (`spec/03-approved/xap/ux.md`; the `cx-x/ux` module tier).
- **Prebuilt downloads** — per-profile darwin-arm64 tarballs
  (`platform` / `cli` / `embed` / `data`) published per release with a
  hosted installer (`curl -sSL https://cxhome.org/install | sh`,
  `CX_PROFILE=` selects the lean builds), checksums, and a Downloads
  page in the guide. Editor tooling joins the release motion: the
  Neovim plugin is consumable as a plugin root, and the VS Code
  extension packages/publishes from the release script.
- **Streaming throughput** — the data parser and evaluator reworked
  around lazy record nodes: `[?for]` over a streamed document moved from
  14.7 MB/s to roughly 200, and `[?map]` from 12.7 to 129 (16 MiB rung,
  the gate's five-trial configuration). The §11.4.4 gate is not green
  yet; the remaining criterion is throughput on the `[?map]` shape.
- **Documentation restructured on the rings — and trued** — the guide
  reorganized so the architecture is visible to a reader who has never
  seen the tracker, redesigned as a coherent visual system, and put
  through a full verification audit: every checkable claim tested
  against the live binary, with several hundred stale or fictional
  claims corrected to the engine's real surface.

## Next — queued in the tracker

Derived from the open issues at the time of writing; see the tracker
for live state.

- **Consumability** — a browser playground over Ring 0 wasm with
  shareable content-addressed snippets, `cx schema infer`, a
  model-facing docs pack, and package-manager distribution of the Ring 0
  bindings (pip/npm/brew/cargo). These four are what turn "you may adopt
  Ring 0 alone" from true into easy.
- **Analytics to parity-or-beyond** — aggregate coverage, generalized
  pushdown, a typed value-range index, and distributed query execution
  over composed stores.
- **Platform tracks in design** — ETL/iPaaS components, a native
  extension SDK, foreign-runtime engines, a REPL/notebook surface, CX in
  the browser as a native TypeScript client, and CX as CI/CD and as IaC.
  Each needs an approved spec before implementation.
- **HTTP/2 on the serve path** — the liveness contract (one SSE feed
  per page, pages never poll) structurally wants a multiplexing
  transport; the platform already carries a tested RFC-7540 codec, so
  the work is TLS+ALPN integration and stream mapping, not protocol
  implementation.
- **Test-suite duration relief** — tiered lanes and per-ring gates, so
  the partition pays back in build time as well as in architecture.
- **Deferred smaller items** — ftps:// end-to-end verification on Linux,
  a spreadsheet-writer module, the XSD→CX schema catalog, and a Windows
  investigation (investigation only, no port commitment).

## Toward 1.0

- **External security audit** — third-party review of the V core
  parser, C ABI, and binding FFI shims. Anchors the format/API
  stability claim ([`SECURITY.md`](SECURITY.md) tracks the interim
  posture).
- **Multi-core performance** — completing the scaling work the README
  status disclaimer names.

---

## Released history

Compact record; each release's full surface is in its notes file, and
binaries/tags live on the
[GitHub releases page](https://github.com/cx-home/cx/releases).

| Release | Date | Theme |
|---|---|---|
| [v0.15.0](RELEASE_NOTES_v0.15.0.md) | 2026-08-03 | Toolchain: vendored V moves to upstream 0.5.2, carrying the fork's memory-management series — deliberately thin — [release](https://github.com/cx-home/cx/releases/tag/v0.15.0) |
| [v0.14.0](RELEASE_NOTES_v0.14.0.md) | 2026-08-02 | Eventing + endurance: `cx fabric` graduates to a served tier (consumer groups, failover, DLQ, request–reply, backpressure) — [release](https://github.com/cx-home/cx/releases/tag/v0.14.0) |
| [v0.13.0](RELEASE_NOTES_v0.13.0.md) | 2026-07-16 | Platform + consumption: the store becomes a production component under a service tier; XAP features become a full distribution unit — [release](https://github.com/cx-home/cx/releases/tag/v0.13.0) |
| [v0.12.0](RELEASE_NOTES_v0.12.0.md) | 2026-06-22 | Reliability: sound concurrency + memory (TCO, cooperative-safepoint GC, reactor/streaming hardening) — [release](https://github.com/cx-home/cx/releases/tag/v0.12.0) |
| [v0.11.0](RELEASE_NOTES_v0.11.0.md) | 2026-06-18 | Agentic substrate: `cx-x/` tier (MCP, A2A, LLM), did/vc/jsonrpc/jsonschema stdlib, XAP advances — [release](https://github.com/cx-home/cx/releases/tag/v0.11.0) |
| [v0.10.1](RELEASE_NOTES_v0.10.1.md) | 2026-06-15 | Version-hygiene patch; VERSION file becomes the single source of truth — [release](https://github.com/cx-home/cx/releases/tag/v0.10.1) |
| [v0.10.0](RELEASE_NOTES_v0.10.0.md) | 2026-06-14 | `-gc e` hardening + performance under concurrency — [release](https://github.com/cx-home/cx/releases/tag/v0.10.0) |
| [v0.9.0](RELEASE_NOTES_v0.9.0.md) | 2026-06-13 | Memory model: Perceus-style RC front line + precise STW backstop (`-gc e`) |
| [v0.8.0](RELEASE_NOTES_v0.8.0.md) | 2026-06-09 | Data+code unification: CXPath value kind, `[?match]` / `[?modify]`, module system, bundled stdlib; API/format-stability boundary |
| v0.7.x | 2026-05 | Proof-of-concept line (superseded); the cxpath/cxquery surface was retired and replaced by CX code in v0.8.0 — see [`RELEASE_NOTES_v0.7.0.md`](RELEASE_NOTES_v0.7.0.md) |
| [v0.6.0](RELEASE_NOTES_v0.6.0.md) | 2026-05 | Production-hardening: schema language, namespaces, ID/IDREF, delimited formats, release-hygiene docs — [release](https://github.com/cx-home/cx/releases/tag/v0.6.0) |

---

## Deliberate non-features

These are *not* on the roadmap. They are decisions, not gaps.

- **External entity references** (XML's `&foo;` resolved against DTD
  declarations or external resources). This is the attack surface
  behind XXE and billion-laughs; CX's `[?cx include=...]` covers the
  legitimate use case (file inclusion) without the attack vectors.
- **`xml:space="preserve"` equivalent.** Token context in CX is
  unambiguous — quoted strings preserve, unquoted bodies normalize,
  raw-text blocks (`[# ... #]`) preserve verbatim. A per-element
  override would create three ways to do the same thing.
- **Multiple character encodings.** CX is UTF-8 only; the cost of
  multi-encoding parsers is large and the benefit for greenfield
  deployments is approximately zero.
- **MessagePack / CBOR / Protobuf as import-export targets.** The CX
  binary wire formats already cover the compact-wire need; adding more
  binary formats explodes the conversion matrix. Third parties can
  write codecs against the C ABI if they want them.
- **DOCTYPE as active declaration.** CX parses DOCTYPE for XML
  round-trip only; DTD-driven validation is XML's legacy — schema
  validation (`.cxs`) is the supported path.

---

## Updating this document

- When a "Now"/"Next" item ships, remove it here; the record moves to
  `CHANGELOG.md` and the release notes.
- Derive "Next" from the open tracker, never from aspiration; the
  owner decides priority.
- When a capability is rejected, add it under "Deliberate
  non-features" with the rationale.

Keep it honest; keep it short.
