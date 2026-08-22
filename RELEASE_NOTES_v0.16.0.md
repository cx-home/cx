# CX v0.16.0 — Release Notes

**Date:** 2026-08-19
**Tag:** `v0.16.0`

The **partition** release. v0.13.0 made CX consumable and v0.14.0 made a
deployment survive its own success; this release states what CX *is*: **four
rings with a one-directional import contract** — Ring 0 Data, Ring 1 Code,
Ring 2 Platform, Ring 3 Ecosystem — enforced by gates, buildable per ring,
taught by the guide, and demonstrated end to end by a reference storefront
with zero view code.

**No breaking changes to the public surface.** The partition is a separation
of what already existed, not a redefinition of it. One behavioral change to
know before upgrading programs is the error-propagation tightening below.

## Headlines

- **The four-ring partition, gated.** A ring answers one question — how much
  of CX you take on. Ring 0 is a data format that cannot execute anything;
  Ring 1 adds execution behind deny-by-default capabilities; Ring 2 is the
  platform you reach over a network; Ring 3 is the ecosystem around it. The
  import contract (inward only) is machine-checked — ring tags, import
  gates, and a per-profile extraction gate that verifies the ring artifacts
  byte-for-byte against the monolith — and the installer now resolves
  per-ring artifacts via `CX_PROFILE=data|embed|cli` (the default asset
  stays the full platform profile).
- **Seven concept specs graduated and taught.** The semantic value model,
  computation identity, bitemporal time, commands & effects, the
  consistency vocabulary, schema & event evolution, and runtime
  representation each moved to approved status — and each is a written
  guide arc, not a spec link. The guide's navigation *is* the ring model.
- **Features as building blocks, ruled end to end.** The composition track
  closes its three open questions: a derived noun is computed by a
  **declared deriver-as-actor** (attributable derived state; derived nouns
  are deriver-reserved, enforced at compose and at run assembly); an
  **archetype** instantiates per tenant under a refinement contract that
  admits rename/add/tighten/select and refuses repurpose and loosen — the
  mechanism for third-party feature catalogs without forks; and
  **granularity is computable** — a cohesion instrument reports a feature's
  connected components under a declared-edge set, two components are two
  features wearing one name, and graduation takes two genuinely different
  compositions.
- **ORIEL, the reference storefront.** 1,004 products, six departments,
  facets, baskets, four-step checkout, subscriptions, returns, reviews —
  rendered in a browser, a terminal, and a serial voice-style renderer,
  from declarations, with **zero view code** (a diff instrument computes
  that claim). Promoted in-repo to `spec/03-approved/xap/demos/oriel/` with
  its six instruments as a CI lane, a developer guide
  (`docs/dev/oriel-guide.md`), and a live derived `product.rating`.
- **The evaluator got dramatically faster where it was quietly slow.**
  `[?match]` arm attempts no longer deep-copy the accumulated closure
  table — tree-walk dispatch had scaled with closure fatness. ORIEL
  category pages went from ~3.6s to ~0.13s; renders now beat the campaign's
  recorded baselines; the conformance corpus's own runtime halved.
- **The ux projection capability, specified.** The third projection joins
  the wire and the agent-tools face as a spec
  (`spec/03-approved/xap/ux.md`): the same definitions project forms,
  tables, and live regions through a closed, gate-enforced semantic
  vocabulary with web and terminal faces — what is shown is what is
  allowed, every state is a URL, and the terminal face is the
  keyboard-reachability fixture.
- **Prebuilt downloads, and a guide worth reading.** Per-profile
  darwin-arm64 tarballs publish with the release behind the hosted
  installer (`CX_PROFILE=data|embed|cli`), with a Downloads page
  presenting the profile matrix as the ring ladder. The guide itself was
  redesigned as one visual system (drawing-office chrome, the ring model
  drawn as an annotated figure) and put through a full verification
  audit — every checkable claim tested against the live binary, several
  hundred stale or fictional claims corrected. Editor tooling joins the
  release motion: the Neovim plugin installs as a plugin root; the VS
  Code extension packages and publishes from the release script.

## Changed (behavioral)

- **Error propagation is position-based and total.** A computed `[err]` in
  an element-child position propagates instead of being adopted as data, a
  top-level `err` exits 1, and a refusal can no longer come to rest inside
  a document. Source-literal `[err …]` stays data — the discriminator is
  position, not value.
- **`[par]` reassembles source order, always.** Unordered output was
  unspecified; `[ordered]` is now a documented no-op. `pure ⇒
  deterministic` is normative, which is what makes computation addresses
  and the pure result cache sound.

- **Map literals refuse instead of inventing (#917, MSS).** A map value is
  one expression-shaped item in both readers — unquoted prose, spaced
  `::` annotations, unknown type tags, and unparseable entries are loud
  errors now, never silently absorbed as text or coerced into invented
  values (`{x: prose ::bool}` used to yield `false` at exit 0). Entries
  separate by whitespace as well as commas (the shipped form, now spec).
  New capability: the declaration-only entry `{k: ::T}` — a typed field
  with its value ABSENT (not null) — carried by cx/XML/ast_bin, refused
  by lossy targets.

## Migration

- Programs that embedded a *captured* err as document data must rebuild it
  from parts (`[report [code $e@code] [message $e@message]]`) or collect
  outcomes in a paren sequence — element construction now propagates.
- Map literals: quote prose values (`{note: 'two words'}`), quote bare
  `::`/`:`-carrying text values (`{a: 'std::vector'}`,
  `{u: 'http://x'}`). Well-formed maps — including the whitespace-
  separated entry form the stdlib always used — parse unchanged; the
  zero-movement corpus differential (829 inputs) is the receipt.
- Nothing else: cx source, schemas, stored documents, and wire formats are
  unchanged; the partition did not move any address.

## Known state, stated honestly

- The §11.4.4 streaming perf gate is **red on one criterion** ([?map]
  throughput); the threshold was not relaxed to meet the implementation,
  and the numbers re-measure on the perf campaign now that the match-clone
  fix moved the floor.
- Linux artifacts do not ship at this cut (darwin-only, as v0.14/v0.15);
  the dockerized Linux release lane lands separately.

## Toolchain

- Vendored V remains the 0.5.2-based cx fork; this cycle adds the
  `-usecache` type-table validation (a cached-layer type-pun class closed
  at the linker) and the waiter-declaration fix underneath it.
