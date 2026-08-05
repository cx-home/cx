# #651 verdict drafts — pending owner letters

---

## §12 — "Generalize XSP into the native CX execution protocol"

**Draft verdict: ACCEPT the direction, REJECT the XSP/2 big-bang. XSP becomes
the native CX protocol by the additive path v1 already proved.**

### Evidence (protocol inventory, 2026-08-04)

- xsp.md §1 already anticipates this: the frame codec is generic; only the
  `type` enum + `principal` semantics are XAP's; the spec defers the split
  "until a second consumer appears." Fabric became that consumer and drove the
  whole §5 session layer (negotiation, heartbeat, credit, resume) — added with
  ZERO frame changes via §5.0 negotiated features.
- The doc's XSP/2 frame list is mostly shipped: OPEN/INVOKE/RESULT ≈
  request/reply; DELTA ≈ event; CREDIT/CANCEL/RESUME/ERROR all exist (§5.2,
  type 4, §5.3, type 7). Genuinely missing: content-by-hash transfer, semantic
  deltas as a spec'd vocabulary, expression invocation, transaction
  boundaries, schema negotiation — ALL carryable as payload vocabulary +
  negotiated feature tokens, none need a new frame format.
- Ruled earlier (campaign decision log): frames are CX vocabulary; binary
  framing is the encoding; no text wire form.

### The accepted work stream

1. Split the spec (not the wire): "XSP frame + session layer" (generic) vs
   "XAP frame semantics" (one profile of it). The store profile (§13) becomes
   the second semantics consumer that xsp.md §1 was waiting for.
2. New capabilities land as negotiated features + payload vocabulary:
   expression invocation (ships a quoted planar comprehension — the §3/§11
   additive path — identified by E1 expression identity), content-by-hash
   fetch, semantic delta events. Each gated on its live consumer.
3. SSE/web binding fidelity + conformance fixtures (divergences #7/#8 below).

### Ring assignment

Frame codec + `[frame]` vocabulary: Ring 1 stdlib with Ring 0-representable
vocabulary. Session layer + served tiers: Ring 2. Import gate: Ring 0 never
depends on xsp.

### Business value case

One authenticated session = one identity + authority context for everything a
client does — execute, subscribe, fetch, store — under a proven DID principal
with attenuable capabilities. For agent-principal symbiosis this is the
material claim: an agent holds ONE auditable channel where every frame is
attributed and capability-checked, vs. today's industry norm of one auth
story per protocol (REST token + DB credential + broker ACL + RPC mTLS = four
attack surfaces, four audit trails, no shared attenuation). Plus operational:
cancel, backpressure, resume for long-running queries — none of which
HTTP/1.1 request/response can express. Honest bar check: alone this is
infrastructure; it is material as the carrier of the §3/§11 query-shipping
chain and §14 computation identity — accepted as that enabler, sequenced
behind its consumers.

### Letter L5

(a) Additive path: keep the v1 frame, grow via negotiated features + payload
vocabulary, split spec into generic-frame vs XAP-profile when the store
profile lands (recommended — zero breakage, proven mechanism) /
(b) design XSP/2 now per the doc's frame list (new frame format, version
bump, re-do §5 — no capability the additive path can't deliver) /
(c) defer.

---

## §13 — "Fold CSRP into XSP"

**Draft verdict: ACCEPT the destination, REJECT the fold-as-restructure.
Amended direction: the store JOINS XSP (additively, when the query-shipping
stream needs it); CSRP remains the permanent HTTP edge adapter over the same
internal op layer. Nothing is demoted to "compatibility profile."**

### Evidence

- Zero code overlap today: no `store_*.v` file touches xsp. The layered
  composition already works (fabric mounts ride `cx-store://` as a client).
- The adapter seam already exists and is proven: gRPC serves 19 methods by
  synthesizing CSRP requests into the same routing/authz/limits pipeline
  (`store_csrp_route`) with normative parity tests. Store-over-XSP is a third
  synthesizer over the same seam — not a rewrite.
- Structural mismatches that make a literal fold wrong:
  - CSRP's unauthenticated bootstrap (`capabilities`, `health`, `ready`) must
    work pre-session; XSP negotiation is post-attach by design. Fabric itself
    solved probes with a separate plain-HTTP listener — the pattern is
    settled.
  - `/metrics` is Prometheus text over HTTP, period.
  - Error spaces differ structurally (numeric CXER17xx bound 1:1 to HTTP
    status vs symbolic CXER-XSP-*) — a fold needs a mapping table either way.
- What the store gains on XSP: cancel, heartbeat, credit backpressure on
  iter/query (today unbounded), resume, multiplexing — real, but incremental.
- What neither side has: a store change feed. Folding produces no
  subscription model by itself; `?observe-ref` (doc §13) is new machinery
  regardless of carrier — it belongs to the live-modes work stream (§4).

### Sequencing guard

Store-over-XSP is built only when its live consumer exists (shipped queries /
store subscriptions from the §3/§11 + §4 streams) — a transport seam with no
consumer is a partial impl (standing rule).

### Ring assignment

Internal store op layer + all three adapters (CSRP/HTTP, gRPC, XSP profile):
Ring 2. The op layer is the ring's inner seam; adapters are its edge.

### Business value case

Honest split: consolidation alone ("one fewer protocol") is incremental and
does NOT clear the bar — rejected as motivation. What clears it: the store
joining the execution substrate is the precondition for data-local query
execution (push a planar comprehension to the store, get rows + deltas back
on one capability-scoped session) and for store access under the same
attenuable authority chain agents use for everything else. Use cases: live
operational dashboards fed by store-side incremental queries instead of
poll-and-diff; field/edge clients that resume one session instead of
re-syncing three; agents granted read-this-slice-only store access with the
grant inspectable and revocable as a CX value. The value is the destination
(store on the native protocol), not the fold (retiring an adapter that costs
nothing to keep).

### Letter L6

(a) Amended direction: store joins XSP additively when query-shipping/live
modes demand it; CSRP stays the permanent HTTP adapter; probes, bootstrap,
metrics stay HTTP (recommended — proven adapter seam, no migration, no
consumer-facing breakage, honest sequencing) /
(b) doc-literal fold: XSP primary now, CSRP demoted to compatibility profile
(restructure cost now, no capability gained until the query streams land
anyway) /
(c) reject: store stays HTTP-only (closes the door on data-local execution
under session authority — conflicts with accepted §12).

---

## Spec/impl divergences surfaced by the protocol inventory (follow-ups at G-A)

1. cxstore-grpc.md .proto lists 8 RPCs; impl serves 19.
2. Object wire (objects-*/refs*) has no CSRP §3 endpoint section.
3. journal-over-CSRP (#644) has no spec section; journal.md never mentions CSRP.
4. `list` response shape differs text vs binary route; networked-backends §C
   forbids the `[sequence]` form the binary route uses.
5. Capabilities sample advertises zst default; daemon emits none.
6. Text route still accepts URL query params §2.1 retired.
7. xsp.md claims conformance-tested; no xsp.cxd fixture exists.
8. xsp.md §4.1 says SSE carries base64 XSP frames; xap host SSE writes plain CX.
9. fabric.md §11 capability table lists 3 actions; code has 4 (rotate).
10. gRPC parity suite misses Aliases/AliasesSet/Reload.
11. XAP-tier symbolic errors (CXER-XSP-*, :CXER-UNAUTHORIZED) have no numeric
    allocation in governance.md §9.6.

---

**Status:** DRAFT staging file. Each section here is a verdict analysis awaiting
owner letters; once ruled, the verdict posts to #651 as a tracker comment and
this file keeps only a pointer. Verdict template per `partition_campaign_PLAN.md`:
verdict + rationale + ring assignment + business value case (revolutionary bar,
CX-generic use cases, no downstream clients).

---

## §10 — RULED 2026-08-04 (L1a / L2a / L3a / L4a) and POSTED

Verdict: https://github.com/cx-home/cx-private/issues/651#issuecomment-5186712253
Draft retained below until Gate G-A, then this section collapses to the pointer.

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
