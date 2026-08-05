# #651 verdict drafts — pending owner letters

**Status:** DRAFT staging file. Each section here is a verdict analysis awaiting
owner letters; once ruled, the verdict posts to #651 as a tracker comment and
this file keeps only a pointer. Verdict template per `partition_campaign_PLAN.md`:
verdict + rationale + ring assignment + business value case (revolutionary bar,
CX-generic use cases, no downstream clients).

---

## §10 — "Make the CX value the universal contract" (+ roadmap Milestone 1 "Semantic core")

**Draft verdict: ACCEPT — as a consolidation spec plus four targeted extensions —
with one first-principles amendment: identity stays content-only; the document's
intrinsic metadata envelope is REJECTED in favor of CX's three shipped
attachment lanes.**

### What the doc asks vs. what exists

Evidence: `partition_audit_spec_inventory.md`. Milestone 1's eleven line items,
mapped:

| Doc ask | Status |
|---|---|
| Canonical error values | **Shipped, exceeds ask** — `[err]` + four-channel outcome model + CXER registry |
| Schema identity | **Shipped** — content-hash schema refs, MUST-verify |
| Stable type identity | **Gap** (closed TypeName set; no value-level named types) |
| Universal value envelope | **Conflicts with settled rulings** as sketched (see amendment) |
| Version identity | **Gap at value level; machinery shipped at ref/journal level** (CAS trio CXER1114/4604/1704) |
| Expression identity | **Gap** — Tier-2 is def-only; strict-canonical hash of any tree mechanically available |
| Provenance | **Shipped** — detached, Tier-1-hash-keyed `[provenance]` grammar + journal attribution envelope |
| Temporal semantics | **Partially shipped** (kinds + `at-seq`/`as-of`); bitemporal NOT FOUND, no driving consumer |
| Effect declarations | Rides the §5–§6 verdict (purity barewords + caps shipped; per-def `[requires]` clauses are the open part) |
| Capability declarations | **Shipped** — authority artifacts are homoiconic CX values (authz §2; caps; xap §22) |
| Consistency declarations | Rides the §7 verdict (isolation vocabulary NOT FOUND anywhere — real gap, separate ruling) |

### The amendment (first principles)

The doc's runtime envelope (`[meta type=… version=17 origin=… authority=…]`
intrinsic to the value) would make identity context-dependent. CX has already
ruled this out once: the staged set-identity spec records that a content
address must depend on **content only, never content + policy**. And canonical
forms are identity-bearing (emit-quoting rulings). The invariant the doc
actually wants — *same identity and meaning wherever the value appears* — is
achieved BY content-only identity, not despite it.

CX's shipped answer is three attachment lanes, each preserving identity:

1. **Inert side-band** — `[?meta]` / `meta-of`: rides with the value, excluded
   from identity and equality.
2. **Detached hash-keyed claims** — `[provenance]`, VC attestations, signed
   manifests: first-class values *about* a Tier-1 hash; verifiable, storable,
   composable; never mutate the subject.
3. **Event envelopes** — journal `[entry]` wraps a payload verbatim and owns
   attribution/seq/ts in the hashed envelope, not in the payload.

The §10 spec should name these lanes normatively as *the* metadata model.

### The four extensions (the accepted work stream)

- **E1 — Expression identity.** Tier-1 hash of a quoted expression tree,
  spec'd as first-class identity (quasiquote §6.4.3 already guarantees
  deterministic canonicalization). Enables: shipped-query identity (§3/§11
  additive path), plan caching/audit, and §14's computation identity
  (`hash(fn, inputs, env)` composes Tier-2 + E1 + Tier-1). Ring 0.
- **E2 — Type identity = (element name, schema content-hash).** Nominal typing
  when wanted, with zero registry and zero coordination: two parties agree on
  a type by exchanging a hash. Extends schema.md §13.1 refs + validate;
  optionally surfaced via lane 1/2, never as intrinsic value fields. Ring 0.
- **E3 — Version identity = ref-history position.** Spec the projection: a
  value's lineage is the epoch-ordered ref/branch history (+ journal seq where
  applicable); expected-version stays the shipped CAS machinery, unified as
  one vocabulary (today CXER1114 / CXER4604 / CXER1704 are three dialects of
  one concept). No version fields on values. Ring 0 identity / Ring 2 refs.
- **E4 — The semantic value model spec.** One working spec consolidating
  CXDM + identity tiers + attachment lanes + E1–E3, stating the §10 invariant
  normatively: *a CX value has the same identity and meaning whether stored,
  transmitted, queried, executed, replicated, rendered, or handled by an
  agent.* This is Ring 0's contract document — effectively the partition
  spec's normative companion.

**Deferred, explicitly (not rejected):** bitemporal time axes (no driving
consumer; `at-seq`/`as-of` cover audit today); consistency vocabulary (§7
verdict); per-def effect/authority clauses (§5–§6 verdict).

### Ring assignment

E1/E2/E4 = Ring 0 (representation + identity are the data product's contract).
E3 spans Ring 0 (identity semantics) and Ring 2 (ref machinery). `meta-of`
reflection is a Ring 1 builtin; the `[?meta]` representation is Ring 0.

### Business value case (revolutionary bar)

**The outcome: one verifiable identity for data, code, queries, and
computation results — across storage, wire, and execution.** No incumbent
stack has this as a platform property: JSON has no practiced canonical form,
protobuf bytes are schema-dependent, SQL has no value identity at all.
Concrete CX-generic use cases:

- **Cross-organization exchange where the artifact proves itself.** Signed
  strict-canonical bytes + detached provenance: the receiver re-hashes and
  verifies with zero trust in the channel or sender infrastructure —
  supply-chain-grade data, regulatory submissions, inter-company
  reconciliation.
- **Audit-grade agent operations** (the north-star criterion made concrete).
  An agent's query (E1), the authority chain it acted under (authz values),
  and the result it produced are ALL content-addressed values: every agent
  action is reproducible and disputable after the fact. No mainstream agent
  stack can state that invariant.
- **Build-system semantics for data pipelines** (with §14): deterministic
  result caching, incremental recomputation, distributed memoization — keyed
  by computation identity, not by file mtimes or pipeline-run IDs.
- **Zero-coordination typing** (E2): partners adopt a type by exchanging a
  hash — no shared registry, no release-train coupling, no versioned-IDL
  ceremony.

**Honesty check against the material/revolutionary bar:** E4 alone
(consolidation) is incremental and would not clear the bar. The revolutionary
claim rests on the bundle — E1+E2 complete the identity chain from data
(shipped) through code (shipped) to queries and computations (new), which is
what makes the agent-audit and pipeline-memoization cases possible at all.
Accept as a bundle or defer as a bundle. Cost is moderate precisely because
the foundation shipped; leverage ratio is the highest of any §-verdict in
this review.

### Owner letters requested (L1–L4)

1. **L1 — envelope model:** (a) reject intrinsic envelope; normatively name
   the three attachment lanes (recommended — preserves content-only identity,
   zero migration) / (b) adopt the doc's intrinsic `[meta …]` envelope
   (rejected-by-analysis: context-dependent identity, moves every stored
   hash) / (c) defer.
2. **L2 — type identity:** (a) (element name, schema content-hash) binding
   (recommended — content-addressed nominal layer, no registry) / (b) nominal
   type system with a registry (central authority; contradicts
   content-addressing) / (c) defer.
3. **L3 — expression identity:** (a) E1 as Tier-1-of-quoted-tree
   (recommended — zero new normalization; ships on existing machinery) /
   (b) extend Tier-2 alpha-normalization to arbitrary expressions now
   (more dedup power, real cost; can layer over E1 later without breaking
   identity) / (c) defer.
4. **L4 — version identity:** (a) E3 ref-history projection, no value-level
   version fields (recommended — aligns with immutable store + shipped CAS) /
   (b) value-level version fields (identity-hostile; duplicates the ref
   layer) / (c) defer.
