# Planar query algebra (stream 2)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: working draft (stream 2 of the #651/#516 campaign, issue #674). Mandate: source-reference builtins; planar-fragment designation; formal equivalences; static dependency extraction (authorize-before-execute, identity-keyed caching, incremental maintenance); store-query accepts quoted planar comprehensions. **`[?for]` stays THE comprehension — no second query surface.** Normative once approved. Binding inputs: E1/E3 (semantic_value_model.md, ruled), the ONE-traversal contract (stream 16 L62a), honest reporting (stream 17 §7), EV-* determinism (stream 22).

**Evidence basis (2026-08-05):** full grammar/impl divergence table for
`[?for]`, the five (nine-plus) duplicate walkers, the shipped-but-informal
pushdown machinery (columnar projection + wire-level limit/offset/
aggregate), the err/absence semantics interaction, and the E1-vs-
equivalence tension. Defects filed #711.

**Worked example (M5 commerce):** revenue by region —
`[?for [in $o [$store:source $s /orders]] [in $l $o/line]
[= $r [* $l@qty $l@price]] [group-by $o/customer/@region]
[yield [row region=$key revenue=[$sum $group/r]]]` — inexpressible today
(`$group` is spec'd and unimplemented; COUNT is the only aggregate). Under
this spec it has: a plan address (cached across spelling variants), an
extracted source set (`/orders` slice → authorize-before-execute via the
purity theorem), an E3-versioned invalidation key, and a delta rule
(γ over monotone inserts) that stream 3's `[?materialize]` maintains
incrementally.

## §1. The algebra (normative core)

Operators over CXDM sequences (ordered): source scan (`[in …]` over a
source reference), σ (`[where]`, pure, EBV), π (`[yield]` /
`[yield-array]` / `[yield-map]` — three output shapes), extension
(`[= $y E]`), ⋈ (multiple generators + `[where]` — Cartesian semantics
already normative; no dedicated join clause, none needed), γ
(`[group-by]` + `$key`/`$count`/`$group`), τ (`[order-by]`, stable),
λ (`[limit]`/`[take]`/`[drop]`). Aggregates are the shipped pure set
(`sum/max/min/avg/count/distinct`) over `$group`.

**Absence and null:** absence = empty sequence, flows inertly; `null` is
a present value; the algebra states normatively that SQL NULL maps onto
TWO CX notions (adapters must say which); no three-valued logic exists
or is introduced.

## §2. Rulings

- **L93 — canonical plan form (the additional identity tier L79
  anticipated).** A normative plan normalization — canonical clause
  ordering, alpha-normalized binders, a confluent rewrite set, the
  §2.12.7-style equality⟺byte-identity contract — yielding the **plan
  address**. E1 (text, name-sensitive) remains the base identity;
  caching and computation identity key on the PLAN address, so
  equivalent spellings share. `limit`/`take` collapse to one canonical
  operator in the plan (both stay legal surface).
- **L94 — γ is hash-partition (SQL GROUP BY), normatively.** code.md
  §7.2's "consecutive items" wording is amended (the implementation
  already partitions; analytics and adapters expect it; run-grouping is
  windowing territory). Group output order = first appearance of the
  key, pinned. **`$group` is implemented** (the spec'd binding —
  currently the only-COUNT blocker) alongside `$key`.
- **L95 — planar-fragment membership (loud, never silent):** head ∈
  {for, for-array, for-map}; clause vocabulary closed to {generator,
  `where`, `=`, `order-by`, `group-by`, `limit`, `take`, `drop`};
  every generator source is a **source reference** (§3) or a nested
  planar comprehension — **the implicit ambient document and bare
  pattern-generators are non-planar** (a source set that cannot name
  its root is not a source set); every predicate, key, and yield is
  `pure` (the shipped §6.5 checker verbatim); no `[?eval]`, no
  `[?with-scope]`, no unbounded generator; `take-while`/`drop-while`/
  `$_position` excluded (order-observers, not relational); `[par]`/
  `[lazy]`/`[ordered]` are ERASED as execution hints (the lazy hint
  spelled `[stream]` until U1.1a / #763) — planar results
  are ordered per the algebra, and bare-`[par]`'s unspecified order
  cannot leak (transparency). Non-membership at a planar consumer is a
  typed error (the CXER1709 refuse-to-lie precedent), never a silent
  fallback. **Tightened 2026-08-10 (#770, ruled (a) with the cousin):
  λ clause counts join the purity enumeration (a free-name count stays
  a member — a §7.9 plan parameter; an impure count refuses), and the
  ambient-document exclusion covers ALL expression slots — a
  document-context CXPath read anywhere in a clause expression, λ
  count, computed generator source, or yield body is a non-member (the
  determinism guarantee "deterministic given the sources' contents"
  admits no slot-scoped carve-out).**
- **L96 — the equivalence set, with the err rule.** Normative rewrites:
  σ/σ commutation; σ-pushdown below τ (sound) and NEVER across λ
  (order-fixing barriers); π pruning; join reordering/placement over
  pure predicates. **The err rule:** because an err-valued predicate
  short-circuits the whole comprehension (§7.2, normative), σ-pushdown
  is admissible ONLY for predicates established total (purity + shape,
  via stream 16's inference); err-raising order is NOT declared
  unobservable — fail-loud fidelity outranks optimizer freedom. Every
  applied rewrite is reportable (the honest-reporting obligation).
- **L97 — source references + flat results.** `[$store:source $store
  PATH]` (new Ring-1 builtin surface, Ring-2 resolution) and
  journal-stream references are THE source forms — exactly E3's closed
  versionable-ref scope, so **cacheability ≡ all sources versionable**
  (part of the membership test). The planar result relation is FLAT
  with provenance attributes (doc address, source ref) — replacing the
  doc-keyed nesting divergence; the columnar and row execution paths
  MUST emit the identical shape (the #711 transparency probe).
- **L98 — windows are OUT of v1.** The `[59a]` head reservations die
  with stream 13's deletion; the future form is CLAUSES under `[?for]`
  (`[tumbling …]`), never new heads (single-surface rule), sequenced
  behind a live consumer (standing rule; not a scope cut — the fragment
  is designed so window clauses drop in additively as new plan
  operators).
- **L99 — shipped queries.** `[$store:query]` accepts a QUOTED planar
  comprehension (E1/plan-addressed); the executor is the shipped
  sandboxed `[?eval]`; execution runs under the narrowed capability
  set; **authorize-before-execute** = the authz `check` (pure,
  point-in-time, explainable) over the extracted slice set, and the
  §6.5.1 purity theorem guarantees the query needs authority for
  exactly its source set and nothing else. Host-capability gating
  (read/net at the handle) and authz slice gating are BOTH applied and
  named as distinct layers.
- **L100 — the ONE traversal contract** (discharging L62a's promise):
  the normative `[?for]` walk — clauses × (source, expr) + yield — is
  authored here as the single contract; extraction (which sources),
  shape inference (stream 16), purity, lint, LSP, Tier-2 emission all
  implement it; the nine-plus duplicate walkers retire onto it at I5.
- **L101 — the incremental sub-fragment + the ∂ vocabulary.** σ, π, ⋈,
  γ carry normative delta rules (σ/π trivially; ⋈ with opposite-side
  state; γ with group state over monotone deltas); τ and λ are NOT
  incrementally maintainable (recompute). **Incremental sub-fragment
  membership additionally requires ESTABLISHED TOTALITY of every
  predicate involved (added 2026-08-05, audit M6): under the
  ERR-TOTALITY rule a partial predicate makes recompute yield the
  whole-comprehension err while maintenance would yield
  state-then-err-frame — two different values at one cursor, which
  `maintained ≡ recompute` cannot survive; a partial predicate
  therefore excludes the fragment from maintenance (recompute-only),
  loudly.** The delta vocabulary (∂ —
  insert/retract/regroup) is authored HERE once and consumed by stream
  3 (`[?materialize]` refuses or recomputes outside the sub-fragment,
  loud) and stream 4 (the wire delta frames).

## §3. Consumers (normative hooks)

- **Caching:** key = (plan address, {(source-ref, E3 position)});
  invalidation = `expect-pos` comparison; composes into stream 5's
  computation identity with the plan address in the fn slot and the
  versioned source set in the inputs slot (co-authored, not
  duplicated).
- **Live modes (stream 3):** `[?observe]`/`[?materialize]`/
  `[?changes-since]` build on §2's ∂ rules + the journal `since`/
  `fold-value` substrate; the algebra owes them nothing further.
- **Adapters:** the SQL-adapter mapping notes (NULL duality; γ =
  GROUP BY; λ = LIMIT/OFFSET as shipped on the wire) live here so
  stream 18/I6 adapters project one algebra.

## §4. Corpus handoff (stream 14; M5 substrate)

Revenue-by-region and top-SKU fixtures (γ with `$group` aggregates —
the currently-inexpressible skeletons); plan-form pair-cases (two
spellings, one plan address; `$x`-vs-`$y` E1 distinction preserved
under the plan tier); pushdown equivalence pairs (rewritten vs naive
plans → identical results incl. err cases; total vs partial predicate
negative); order-barrier negatives (σ across λ rejected); planar
membership negatives (impure predicate, ambient-document generator,
`[?eval]` body → typed errors); flat-relation shape parity between
columnar and row paths; delta-rule fixtures (insert/retract streams →
maintained γ state equals recompute).

## §5. Rulings ledger — RULED

Letters 93–101 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar): canonical plan
form as the additional identity tier (93); γ = hash-partition + `$group`
implemented (94); the six-point loud membership test with ambient-doc
and order-observers excluded, hints erased (95); the equivalence set
with the err-totality rule and reportable rewrites (96); source refs =
E3's closed versionable scope, flat provenance-bearing results (97);
windows out of v1, future = clauses never heads (98); quoted-planar
store queries with dual-layer authorization on the purity theorem (99);
the ONE traversal contract authored here (100); the incremental
sub-fragment + ∂ vocabulary shared with streams 3/4 (101). Recorded in
the campaign decision log. Spec-edit map: code.md §7 (γ wording, $group,
plan-form section, membership test), grammar.ebnf (clause notes;
[fail-fast]/[on-error] repair rides #711), store.md (source/query
surface), authz.md (slice-set note), canonical.md §2.12.7 cross-ref,
journal.md (∂ cross-ref), LSP surfaces (#711).

## Identity-epoch membership (audit C9)

**ADDITIVE — this stream owns no I1 manifest row and joins no epoch.**
The plan form, planar-fragment designation, source-reference builtins,
and ∂ vocabulary are NEW surfaces; computation addresses over
comprehensions compose per stream 5's post-I1 definition. Nothing here
moves an existing Tier-1/Tier-2 address or canonical byte. **The loud
part:** the ONE-walk retirement re-implements identity-bearing
traversals — the nine-plus duplicate walkers retire onto the single
walk, and that walk includes the Tier-2 emitter's traversal. Fixtures
pin OUTPUTS, not addresses (W-22 is the standing proof that an emitter
re-implementation can move every hash while staying green), so this
stream's I5 exit gate carries the I2 byte-identity clause: Tier-1 and
Tier-2 addresses byte-identical over the FULL corpus, before and after
the retirement. No re-bless is available to this stream; a moved hash
is a defect, never a blessing.
