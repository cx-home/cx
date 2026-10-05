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

**v0.8.0 was the API/format-stability boundary:** from v0.8.0 onward <!-- version-literal-ok: the boundary is a fixed point in history -->
through 1.0, no breaking changes to the public surface (C ABI, binding
APIs, wire formats, spec-normative grammar) without a documented
migration in the release notes.

---

## Now — the `release/0.18` line

The release in progress (see the *Unreleased* section of
[`CHANGELOG.md`](CHANGELOG.md) for the authoritative running list). The
four rings that v0.16.0 drew and v0.17.0 settled become separate <!-- version-literal-ok -->
repositories:

- **The approved multi-repository shape** — this repository is the front
  door; the two frozen core repositories carry Ring 0
  (`cx-core-data`) and Ring 1 (`cx-core-code`); each platform product is a
  `cx-platform-*` repository, each language binding a `cx-binding-*`, and the
  editor surface `cx-tooling`. The front door pins every one of them by sha
  in `deps.cxd`, and `registry/repos.cxd` says what each owns and why.
- **CI and CD as cx flow** — the post-merge run, the pre-merge rounds and
  the release motion are flow documents run by `cx flow`, graded by steps
  that read their own load table.
- **The guide redone** — the documentation rewritten on cx's own terms,
  every example a conformance case, a phone-width pass, and a dark mode
  graded at WCAG AA in both modes.
- **The corpus gaps closed** — the language, stdlib and command gaps found
  porting real programs (the cx-examples letters) fixed whole, each with a
  failing case first.

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

<!-- version-literal-ok:begin — the shipped releases, history by design -->
| Release | Date | Theme |
|---|---|---|
| [v0.17.0](RELEASE_NOTES_v0.17.0.md) | 2026-08-27 | Settlement: the path/value model a total, measured, frozen matrix with a conformance pin per cell; a refusal can no longer leave a program as silent data at the effect boundary — [release](https://github.com/cx-home/cx/releases/tag/v0.17.0) |
| [v0.16.0](RELEASE_NOTES_v0.16.0.md) | 2026-08-20 | Partition: four rings (Data, Code, Platform, Ecosystem) with a one-directional import contract, enforced by gates, buildable per ring, taught by the guide, shown by a reference storefront — [release](https://github.com/cx-home/cx/releases/tag/v0.16.0) |
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
<!-- version-literal-ok:end -->

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
