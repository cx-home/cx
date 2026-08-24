# Semantic value model — E1–E4 (stream 1)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 1 of the #651/#516 campaign, issue #673).
Implements the ruled §10 verdict (L1a–L4a): content-only identity; three
attachment lanes normative; E1 expression identity = Tier-1 of the quoted
tree; E2 type identity = (element name, schema content-hash); E3 version =
ref-history position with the CAS trio unified; E4 = the consolidating
Ring-0 contract document. Normative once approved; hash-affecting outcomes
(E2's hash basis, the Lane-1 fix) join the I1 cutover manifest.

**Evidence basis (2026-08-05):** full sweep of the identity substrate, the
three lanes, quasiquotation, schema references, and the ref/CAS machinery —
with live probes. Five divergences filed #708; the two sharpest: **`[?meta]`
changes `cx:hash`/`cx:equal`** (the internal `__cx_meta__` marker leaks
through serialization — Lane 1 is identity-participating today, the exact
failure L1a rejects), and **a quoted tree has no reachable Tier-1 address
at all** (the `cx:`-namespaced quote image dies on re-parse with E210, so
`quote → hash` fails; so does `quote → serialize → parse`).

**Worked example (M5 commerce):** one `[order id="o-5521" …]` value carried
through all seven modes of the invariant — stored (store-key), transmitted
(same address across substrates), queried (the CXPath's own §2.12.7
address + the result address), executed (E1: the quoted pricing expression
`[?quote [total-due [$sum [$map $lines [?fn ($l) [* $l@qty
$l@unit-price]]]] [tax-for $region]]]` has ONE address wherever authored),
replicated, rendered, agent-handled (lane-2 provenance attesting approval;
lane-3 journal entry recording who advanced the ref). Negative half:
`[?meta {pii: true} …]` MUST NOT change the address (fails today, #708);
CRLF/offset/map-order variants MUST NOT either (S0 families). Type: a 3PL
and a merchant exchange `("order", sha2-256:<hash of order.cxs>)`
out-of-band — nominal typing with zero registry. Version: "v17" = the 17th
advance of ref `order:o-5521`; two agents race the advance; the loser gets
ONE conflict vocabulary.

## §1. The three attachment lanes (normative, closed — L85)

Lane 1 inert side-band (`[?meta]`/`meta-of` — rides with the value,
excluded from identity); Lane 2 detached hash-keyed claims (provenance,
VCs, signed manifests — first-class values ABOUT a Tier-1 address, suite
slot per stream 19); Lane 3 event envelopes (journal `[entry]` wraps
payloads verbatim; attribution lives in the hashed envelope). **The list
is closed** — a MUST, not a description: no fourth lane, and no intrinsic
envelope under any name (the L1a rejection made permanent). Lane 1's
identity-exclusion becomes true in the implementation at I1 (#708: the
lowering chokepoint must unwrap `__cx_meta__`; per code.md §4.2 this is a
bug fix, and the digests of meta-annotated values re-bless in the epoch).

## §2. E1 — expression identity (L77–L81)

- **The identified tree (L77):** the post-hole-substitution CXDM value —
  what `[?quote]` returns (§6.4.3.1's determinism promise made normative).
  Template (pre-substitution) identity is named as a possible future
  ADDITIONAL tier, not ruled.
- **Acquiring canonical bytes (L78):** the quote image must become
  authorable canonical text. Ruling shape: quoted trees LOWER to plain CX
  source surface form — program forms are data (homoiconicity is the
  partition's own §2 argument) — with type annotations retained exactly
  where the bare spelling would re-type differently (the stream-11
  ruling-45 precedent), and a spec'd authorable form for variable holes.
  The `cx:` lift remains an emitter-internal projection, never the
  identity substrate; E210 stays intact. One identity substrate:
  canonical text (S0 L19a).
  **Hole-surface collision MUST (AMENDED 2026-08-05, audit C4 — the
  original deferral carried no collision requirement, and today
  `cx:hash "[total $x]"` equals `cx:hash "[total '$x']"` — a program
  expression and a string-valued data document sharing ONE Tier-1
  address, on the exact path that feeds address-bound approvals in
  propose mode):** the authorable hole form MUST be specified BEFORE
  the I1 epoch, and its canonical spelling MUST NOT collide with any
  string-valued data spelling — `[total $x]` (a hole) and
  `[total '$x']` (a four-character string) MUST canonicalize to
  different bytes and therefore different addresses. The corpus
  handoff's pair set gains the `$x` vs `'$x'` pair — the one pair that
  would have caught this (the existing set pinned only `$x` vs `$y`
  name-distinctness).
- **Name sensitivity (L79):** E1 is name-sensitive BY DESIGN (`$x` vs
  `$y` differ); alpha-normalized expression identity is a future
  additional tier, never a redefinition — stated normatively so the
  layering the verdict promised is not foreclosed.
- **The operator-head surface (L80; DIAGNOSIS CORRECTED 2026-08-05,
  audit C4):** `[* $x 2]` is unhashable in the data lane today (probe)
  — but the original claim that `+ - / = <` heads "parse" was wrong in
  class: those heads **silently stringify** (`[+ $x 2]` emits as the
  JSON string `"+ $x 2"`; root cause in the data-mode lexer), and `>`
  errors like `*`. Consequence the manifest must book in full: the I1
  lexer fix changes the MEANING and the ADDRESS of every stored
  document with any of the seven operator heads (`+ - * / = < >`) —
  not just the `*`-head class the manifest originally listed. This is
  a hash-affecting change to existing documents (now-or-never,
  enumerated in the I1 manifest); fixture-before-fix pairs pin the
  current stringify/error behavior per head so the epoch's re-bless
  shows every flip. (Stream-13 coordination; grammar repair batch
  already open.)
- **Address form (L81):** a plain Tier-1 tagged address
  (`sha2-256:<hex>`) — expression identity IS Tier-1 of the quoted tree;
  no new namespace prefix.
- CXPath expressions already carry the §2.12.7 identity guarantee; E1
  extends the same promise to all expressions.
- **Totality exceptions (ADDED 2026-08-05, audit C4 — E1's identity
  promise fails on three shipped value classes, and each needed a
  ruling before the epoch):** identity acquisition **refuses with a
  typed error** for all three — no silent fallback, no coercion:
  1. **Closures** — already refuse (shipped `CXER4101`); now normative
     rather than incidental. A closure captures an environment; no
     canonical text can carry it, and inventing one would fork the
     substrate.
  2. **Unbounded iterators** — currently FORCE-MATERIALIZED by the
     hash path (a hang on an infinite source, and an identity that
     depends on consumption state). At I1 this becomes the same typed
     refusal (a behavior fix booked in the manifest's re-bless
     column, not an address move: no sound address ever existed).
  3. **`::secret` values** — the redaction-vs-identity question is
     RESOLVED BY REFUSAL: a secret-bearing value has NO Tier-1
     address. Hashing the plaintext would make every address a
     secret-confirmation oracle (the same adversary class the
     erasure stream's nonce defense exists for); hashing the redacted
     form would give two different secrets one address — an identity
     lie. Refusal is fail-closed, keeps secrets out of address-bound
     approvals BY CONSTRUCTION, and preserves both future directions
     as additive options where a frozen wrong choice could never be
     unwound. (Consistent with stream 17's "secret never columnar".)
  Exact refusal codes come from the module-cx band (`4100–4119`,
  its own table) at I1; the corpus gains one refusal fixture per
  class.

## §3. E2 — type identity (L82–L83)

- **Hash basis (L82 — forced by S0 L19a):** the schema's identity is the
  Tier-1 hash of its canonical TEXT bytes. schema.md §13.1 /
  data-bin.md's CXCol-encoding hash basis is superseded; existing
  `0x10`/`0x12` digests re-bless at I1; the reserved `0x13` multihash tag
  (stream 19) carries the tagged form on the wire.
- **The pair (L83; REOPENED by audit M39 and RULED (c) by the owner
  2026-08-05 with the full option ladder on the decision-log record):**
  type identity = `(element name, schema content-hash)`,
  **whole-schema** at v1, **and one-type-per-schema-document is
  NORMATIVE for identity-bearing schemas** — a schema document that
  anchors a type identity (feeds a `[type-binding]` claim, a pair
  exchange, or any address-bound adoption) MUST declare exactly one
  type; multi-type schema documents remain legal for validation but
  CANNOT anchor type identity. This closes the audit's trap
  structurally: no cross-type identity churn is possible (editing one
  type's schema can never move another type's identity, because they
  never share a hashed document), with zero new hashing machinery in
  the I1 epoch. Per-type-declaration subtree hashing remains an
  additive refinement — with the caveat stated at ruling time: if ever
  adopted for multi-type anchoring, it arrives as a SECOND basis for
  those new documents; existing one-type pairs keep the whole-schema
  basis. The pair is primarily
  **recoverable-by-computation** (name from the value, hash from the
  schema in force — zero bytes, cannot desync; "two parties adopt a type
  by exchanging a hash" is a protocol statement); the assertable form is
  a Lane-2 `[type-binding [subject hash=…] [name order] [schema
  sha2-256:…]]` claim — never intrinsic fields. Asserting a type
  identity at a trust boundary obliges fail-closed validation (the #702
  posture). Resolution (`CX_SCHEMA_STORE`, `cx schema` verbs) is stream
  16's ruled deliverable (L63) — cross-bound, not duplicated.
  `schema-mode` rides in the hash as document bytes and is never a
  separate policy input. Schema REVISIONS are distinct E2 identities —
  the inter-revision link is the Lane-2 `[schema-lineage]` claim with
  unique-path load enforcement (stream 21,
  `schema_event_evolution.md` L149; journal.md §3.9 `lineage-path`) —
  never a field on either schema, never an identity perturbation.

## §4. E3 — version identity (L84)

- **Lineage substrate:** version history is journal-backed — a per-ref
  lineage stream where `seq` IS the position (dense, gap-free,
  `prev-hash`-chained, retention-ruled — every property E3 needs is
  already normative in journal.md). The store's alias plane records
  advances durably through this lane; today's manifest `A` records are
  compaction-transient with no read API, and `store:log` reports
  doc-insertion order against its own spec sentence (#708) — `log` is
  fixed to per-ref advance order.
- **Position semantics:** "v17" = the 17th advance of the named ref,
  dense and gap-free; `branch-force` advances APPEAR in the history
  (an invisible force-move hollows the audit story); re-pointing a ref
  at its current target is an advance (it was an act).
- **One CAS vocabulary:** CXER1114 survives as THE conflict code
  (already the wire-mapped survivor) with two expectation encodings —
  explicit prior value (`expect=<address>`, `""` = must-not-exist,
  validate-then-apply all-or-nothing) and position (`expect-pos=N`);
  CXER4604/CXER1704 retire with governance §9.6 registry updates (a
  public-surface compatibility event, pre-freeze).
- **No version fields on values** — restated normatively; a document
  carrying `version=17` as authored data is domain data, never the
  value's version. **Ref scope is a closed list at v1:** store
  aliases/branches and journal streams (XAP/fabric state and `pkg:` pins
  are named non-members; extension is additive).

## §5. E4 — the contract (L85; AUTHORED I5 stream 1 W4)

E4 is a **binding contract, not a restatement**. This section IS the
contract; the document graduates as the Ring-0 contract artifact
(G3 owner-gated).

**The invariant (normative, universal):** *a CX value has the same
identity and meaning whether stored, transmitted, queried, executed,
replicated, rendered, or handled by an agent.* Identity is the Tier-1
content address of the value's strict canonical text (canonical §1.2
/ §1.4); meaning is the CXDM value those bytes denote. No surface,
substrate, protocol, or representation may present a different
address or a different value for the same canonical bytes — a surface
that cannot honor the invariant for a value class MUST refuse loudly
(the E1 totality posture), never re-key, re-canonicalize privately,
or coerce. The invariant is stated universally so later streams
inherit it as a CONSTRAINT — never a scoped-down promise.

**Bound by reference (one source of truth, zero copied normative
text):** canonical §1.2/§1.4 (the identity substrate and the two-tier
non-conflation guarantee) and §11.4 (round-trip closure, extended
over lowered quote results); cxdm §4/§5 (document identity and
equality semantics); code.md §4.2 (Lane-1 identity exclusion) and
§6.4.3 (quoted-tree determinism + the hole spelling); code-identity.md
(Tier-2 as an ADDITIONAL tier); schema.md §13.1 (E2 type identity +
the header-as-body-data resolution); store.md §6 + journal.md §3.2
(E3 lineage and the ONE CAS vocabulary); the three attachment lanes
(§1 above, the closed list).

**Terminology (the four senses of "identity" — the glossary that
closes the reader trap; each keeps its name, this table is the
disambiguation):**

| Sense | Where | What it is |
|---|---|---|
| **Document ID / IDREF** | cxdm §4 (`#name`, `[ref @name]`) | Intra-document naming — authored data, participates in canonical bytes, is NOT a content address |
| **Content address (Tier-1)** | canonical §1.2/§1.4, `cx:hash` | THE identity of this contract: `sha2-256:<hex>` over strict canonical text; Tier-2 (`code:`) and plan addresses (`plan:`) are ADDITIONAL tiers above it, never substitutes |
| **`cx:equal`** | modules/cx.md §2.1, cxdm §5 | Canonical-aware equality of two values — `true` iff canonical bytes agree; a predicate, not an address |
| **CXDM set-equality** | cxdm §5.2 | Collection-comparison semantics inside the value model (order/dedup rules per kind); never an identity claim about documents |

A specification that says "identity" without qualification means the
content address. The other three senses MUST be named by their row.

## §6. I1 manifest additions

This stream ADDS to the identity-epoch cutover manifest (which names
streams 11/12/19/13/15 today): E2's schema hash basis; the Lane-1
`__cx_meta__` fix; the `*`-head data-mode parse fix; E1's quoted-tree
lowering (new canonical surface for quote results). One epoch, one
re-bless — unchanged.

## §7. Corpus handoff (stream 14)

`identity_hash.cxd` (closes G1 — zero Tier-1 hash fixtures today) with
M5 substrate: `out-hash` singles; pair-cases (same expression, different
spelling ⇒ same digest; `$x` vs `$y` ⇒ different — pinning L79);
meta-does-not-participate pairs (the #708 regression); quoted-tree
round-trip (`parse ∘ canonicalize` closure over quote results — §11.4
extended); type-identity pairs (same schema text reformatted ⇒ same
type; one facet changed ⇒ different); ref-history fixtures (advance
positions incl. a force-move; the unified CAS error in both expectation
encodings, local and over the wire — today the wire remaps codes).

## §8. Rulings ledger — RULED

Letters 77–85 **all ruled (a) by the owner 2026-08-05** ("all
recommendations accepted if they are the best long term for cx"):
E1 = post-substitution quoted value (77), lowered to authorable
canonical CX — one identity substrate, E210 intact (78), name-sensitive
by design with alpha-normalization as a future ADDITIONAL tier (79),
`*`-head data-mode gap fixed at I1 (80), plain Tier-1 tagged address
(81); E2 hash basis = canonical text bytes, 0x10/0x12 re-bless at I1
(82), whole-schema pair at v1 — recoverable-by-computation + Lane-2
claim, fail-closed at trust boundaries, per-type named additive (83);
E3 journal-backed per-ref lineage, ONE CAS code = CXER1114 with
address/position encodings, no version fields, closed ref scope (84);
E4 binding contract document, closed three-lane list, universal
invariant, terminology glossary, Lane-1 fix at I1 (85). Recorded in the
campaign decision log. Spec-edit map:
new `semantic_value_model.md` graduates as the Ring-0 contract; cxdm
(terminology, lanes), canonical §1.4/§11.4 (quoted trees), code.md
§4.2/§6.4.3 (identity promises normative), code-identity.md (layering
statement), schema.md §13 + data-bin §3.13 (hash basis), store.md
§6.2/§6.3/§11/§13 + journal.md §3.2 + remote-protocol §3.14 + grpc
mapping + governance §9.6 (CAS unification), cx_partition.md §2,
modules/cx.md + cli.md (hash over program values).
