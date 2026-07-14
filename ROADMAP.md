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

## Now — the `release/0.13.0` integration line

The platform release in progress (see the *Unreleased* section of
[`CHANGELOG.md`](CHANGELOG.md) for the authoritative running list):

- **cx store** — a content-addressed multimodel store engine
  (mem / file / sqlite / s3 substrates, one canonical URI surface) and a
  single-node production **service tier** (daemon, auth, observability,
  CSRP/gRPC remote protocols).
- **XAP feature distribution** — the full author → seal → sign →
  publish → install pipeline for distributing features through
  git-repo registries.
- **Database access to external engines** — build-gated (`-d cx_db_*`)
  connectors.
- **Reliability hardening** across the serve plane, plus the
  fix waves from the 2026-07 release audits.

## Next — queued in the tracker

Derived from the open issues at the time of writing; see the tracker
for live state.

- **Release-audit repairs** — CLI surface honesty and conversion-lane
  fixes (`--lossless` wiring, `[table]` conversion loss, `cx diff`
  blind spot, `cx --help` / `cx demo` repair), guide/examples rebuild,
  and editor-tooling sync (VS Code, Neovim, completions).
- **XAP design work** — the identity model, session multiplicity /
  attach policy, client-platform strategy, and the marketplace /
  entitlement model. Design-stage; each needs an approved spec before
  implementation.
- **Deferred smaller items** — ftps:// end-to-end verification,
  spreadsheet-writer stdlib module, XSD→CX schema catalog, a
  runtime-architecture review.

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
