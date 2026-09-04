# Rulings 2026-09-03 — #1161 what an instance's `of=` pins: the archetype document or the package

**Status: PROPOSED 2026-09-03 — awaiting the owner's letter on Q1.**

## The finding

Two approved xap specs, and one spec against itself, disagree on what `[instance of=…]` pins:

| source | `of=` pins |
|---|---|
| xap_grammar_composition.md §4.3 item 1 ("the pin is load-bearing") | the archetype **document**'s Tier-1 content address |
| xap_schemas/instance.cxs header | the archetype **document** |
| xap_grammar_composition.md §4.3 closing paragraph | "a sealed feature **package** whose Tier-1 hash is exactly the `of=` pin" |
| xap_feature_distribution_market.md §1 (line 62) | "a sealed feature **package** whose Tier-1 hash is exactly the `of=` pin" |
| the binary (`[$xap:instantiate]`, CXER4879, vcx/platform/stdlib_xap.v) | the **document** — `store_doc_hash` of the presented `[feature …]` |

A package's Tier-1 hash is the subtree root over the whole directory — the feature document PLUS the
implementation module (`<feature>.cx`), fixtures and assets — so it can never equal the document's hash.
An adopter following the distribution spec computes a pin `instantiate` always refuses. Admitted to the
adoption campaign as AD-8 (2026-09-01) as "a pure spec ruling"; the ruling was never made (re-verified
open 2026-09-03 on v0.17.0). The stake the last report names: an instance that pins the document
"composes, renders and admits acts" but cannot be SERVED where a module is required unless a host can
find the archetype's implementation from the pin.

## Q1 — what `of=` pins (RECOMMENDED: a)

- **(a) RECOMMENDED — the archetype DOCUMENT, and the package is located THROUGH it.** Keep the
  implementation and §4.3 item 1 as they are: instantiation stays a pure function of two documents
  (archetype document, binding) — the same pair yields the same effective document everywhere,
  forever, with no package fetched. Correct the two package sentences (composition §4.3 closing,
  distribution §1) to state the actual relation: an archetype travels as a sealed feature package
  whose `[feature …]` document's Tier-1 address is the `of=` pin; a host that must SERVE an instance
  resolves the archetype's implementation by that document address (a package's feature-document
  address is a derived fact of the package, so a catalog indexes package ← document address). What
  it DELETES: the claim that the package hash equals the pin. What it KEEPS: every existing instance
  binding, CXER4879's message, the pure-function property, and the serving door (#1162/AD-10 stands:
  the instance's implementation IS the archetype's module, reached through the pin).
- (b) the PACKAGE: change `[$xap:instantiate]` / CXER4879 to compare the package subtree hash.
  Rejected: instantiation then requires the package to be present and identical everywhere — the
  same (archetype, binding) pair no longer yields the same effective document without a fetch, and
  every instance binding written so far is invalidated by a hash it never named.
- (c) BOTH — `of=` stays the document and a second attribute pins the package. Rejected: two pins that
  must agree is a new consistency obligation on every binding for a relation the catalog can derive.

## Execution notes (for the wave, once ruled)

- Two sentences: composition §4.3 closing paragraph; distribution §1 line 62. Refer by section title.
- instance.cxs header already says the document; unchanged. CXER4879 unchanged.
- A conformance fixture that pins the document and one that pins the package (refuses CXER4879, message
  names the document address) already exist or are added — the refusal message is the spec's word.
- The "serving door" sentence is the one addition of substance: a host resolves an instance's
  implementation by the archetype document address; the catalog's index from package to feature-document
  address is the distribution spec's obligation (one sentence there).
