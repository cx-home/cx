# Runtime representation (stream 17)

**Status:** Approved (G3 graduation, owner ruling exit-1a, 2026-08-14; stream 17 of the #651/#516 campaign, issue #689).
The ruled direction (#37 reframing): nodes stay the logical/homoiconic
surface; typed columnar/unboxed representation for bulk data-in-flight;
lazy node materialization when code or inspection touches it. Constrains
the C ABI and Ring 1 internals; cheap to decide pre-bindings, brutal after.
Normative once approved.

**Evidence basis (2026-08-05):** full sweep of the value model, the
columnar machinery end-to-end, the hot paths, the C ABI surface, and the
bench record — including the owner-level correction in the #37 session
brief that the execution lean is **"BOTH: a fast general execution core
(unbox/specialize) for scalar/control/irregular work AND
columnar/vectorized for bulk data movement — not either/or."**
Divergences filed #710.

**Worked example (M5 commerce):** a million-line order ledger arrives as
a chunked CXCol table. Today: column-major wire bytes → row-major boxed
cells → per-row `__cx_map__` + 2-per-cell wrapper boxes on every `[?for]`
pass (N(1+2M) allocations from data that was already columnar), while the
100 MiB parse path caps at ~30 MB/s against a 200 MB/s gate. Under this
spec: the ledger flows column-major through filter/aggregate; the
fulfillment code that inspects one order gets a node view lazily; the
ledger's Tier-1 address is computed over canonical text bytes exactly as
if every row had been a node — byte-identical, pinned by pair-fixtures.

## §1. Findings

1. **One uniformly boxed representation:** every value is a 27-variant
   sum-type node; five physical scalar carriers serve thirteen type
   labels. The parser allocates ~1.1M element boxes on a 100 MiB corpus;
   GC pressure caps throughput at ~30 MB/s vs the ≥200 MB/s gate.
2. **The wire is columnar; memory never is.** CXCol encodes untagged
   column-major cells; decode transposes into row-major boxed cells
   through THREE representation hops. The store's "columnar pushdown"
   materializes every row then filters (the spec'd vectorized evaluation
   is unimplemented); streaming re-encodes columnar from re-boxed rows.
   The only node-free columnar code in the tree is the Arrow bridge.
3. **The mechanism for lazy materialization was built and never wired:**
   `parser_streaming.v` ships a complete shape-gated
   never-materialize-a-node pipeline (byte-slice scanning, direct
   canonical rendering, fall-back-to-nodes on shape mismatch) with ZERO
   callers.
4. **Iterators are lazy in the model, eager in the engine:**
   `mk_eager_iterator` materializes every combinator — which stream 22's
   EV-PULL ruling (exact demand-driven pull counts) already outlaws; the
   laziness fix is EV-PULL implementation work, observable via
   effect-count fixtures.
5. **The C ABI exposes zero node pointers** — text, framed bytes,
   booleans, and opaque handles only. Columnar-in-flight is invisible to
   every frozen symbol by construction; capability bits 41–63 are free.
6. **Six approved-spec claims contradict the implementation** (#710):
   table-api's "column-major internal layout"; the vectorized pushdown;
   the wide column-kind lattice (impl supports 9 codes and silently
   degrades decimal/bigint/atom to string, widens unsigned/f16/f32);
   `iter_cols` with no in-core analogue; dictionary/nullable/mixed
   columns unimplemented; lazy-combinator claims vs eager reality.
7. **The perf gates that would measure any of this are red for build
   reasons** (gate 15/30.5 logs end in V→C build failures) — repaired as
   a prerequisite, not a follow-up (#710).

## §2. The central ruling (L86) — transparency normative, internals QoI

**Representation-transparency is normative; the representation itself is
quality-of-implementation.** Observable semantics — results, canonical
bytes, Tier-1/Tier-2 addresses, error codes, evaluation order (per the
stream-22 EV-* register), EBV, equality — MUST be identical whichever
internal path executes. The spec does NOT mandate that any operation
take a columnar path. Grounds: S0 ruling 19 (identity over canonical
text only — no internal representation can be identity-bearing); the
corpus-as-contract is output-shaped and cannot police internals; frozen
internals convert every optimization into a spec amendment; and the
`[?view]` precedent already made exactly this ruling once
("observationally identical to a copy; true zero-copy walking is a
future runtime optimisation").

Four things ARE normative because they are observable: the boundary rule
(§4), the columnar type lattice (§5 — wire- and ABI-visible, frozen by
§8 of the partition spec), the table-mutation contract (§6), and the
**honest-reporting obligation** (§7).

## §3. The direction as recorded (L87)

The direction this spec carries is the owner-corrected **dual lean**: a
fast general execution core (unboxing/specialization) for
scalar/control/irregular work AND columnar/vectorized movement for bulk
data — not either/or. The issue text's columnar-only framing was the
pre-correction narrow reading. Both halves live below the §2
transparency line; neither moves ring seams; the artifact boundaries
already accommodate them.

## §4. The boundary rule (L88) — when node form is observable

Node form MUST be semantically available (materialized or
indistinguishably emulated) at: **identity and hashing** (always via
canonical text bytes; a direct batch→canonical-bytes emitter is
admitted PROVIDED byte-identical output, pinned by pair-fixtures — the
ruling constrains the substrate, not the code path); **inspection
surfaces** (emitters, AST projections, diagram, LSP, debug);
**CXPath navigation into the value**; **`[?match]` patterns**;
**quasiquotation**; **`[?meta]` reflection**. Iterator host-boundary
forcing (cxdm §2.9) is unchanged. **The ruled non-boundary:** table rows
are not CXDM children (D22 — `$t//row` is `()`); that carve-out is the
columnar seam, and it already ships.

## §5. The columnar type lattice (L89)

data-bin §3.10.3's lattice IS the lattice — the implementation rises to
the spec, never the reverse:

- `0x18` bigint and `0x28` decimal columns implemented (the stream-11
  "columnar variants follow" mandate); **narrowest-tag-WITHIN-KIND
  extends to columns** — a decimal column with integral values never
  becomes an int column; the `else → tag_string` degradation dies.
- Unsigned and `f16`/`f32` columns keep their declared width (silent
  widening ends).
- `0x80` nullable wrapper implemented (validity bitmap + packed
  non-nulls) — nullability is per-column via the wrapper, the Arrow
  bridge gains real validity bitmaps.
- `0x62` dictionary columns implemented; **atom columns are
  dictionary-encoded by construction** (tag-shaped values, the natural
  fit).
- `0x81` mixed implemented as the totality escape for irregular columns
  (per-row tagged), honestly reported (§7).
- **`secret` never gets a raw columnar cell** — redaction semantics
  (cxdm §12) cannot be bypassed by a bulk buffer; secret-bearing shapes
  force the node path. A security rule, not a performance one.

Timing: column tags are NOT identity-affecting (ruling 19 — data-bin is
a codec), so the lattice lands at I5 with this stream, not I1.

## §6. Table mutation (L90)

**Tables are not `[?modify]` targets** — rows are not CXDM children
(D22), so no CXPath focus can address them; nothing today defines
modify-into-table and this spec declines to invent it without a
consumer. Cell-level update surfaces (slice-assignment or table verbs)
are named as additive future work behind a live consumer. Values are
immutable, so batch mutability is a non-question at the semantic level;
**column-level copy-on-write is recorded as the QoI implementation
guidance** (the columnar analogue of spine-copy, O(one column) per cell
change) for whoever builds the update path later.

## §7. Honest reporting (normative)

Extending the shipped `columnar_pushdown` precedent ("no silent
full-scan masquerading as pushdown"): wherever a representation choice
is invisible in results, it MUST be visible in introspection — engines
report which path executed (batch/node, pushdown/scan, dictionary/
plain) through their status surfaces, so adopters can reason about
performance without reading engine internals.

## §8. Contradiction repairs (L91; #710)

table-api's "column-major internal layout" claim is amended NOW to the
§2 transparency language (a false normative claim cannot stand until
I5 makes it true); the vectorized-pushdown promise stays spec'd and is
implemented at I5; the column-kind lattice per §5 at I5; an in-core
`iter_cols` analogue lands with the lattice; eager combinators become
demand-driven per stream 22's EV-PULL (I5, effect-count fixtures);
the dead `parser_streaming.v` pipeline is either wired as the gate-15
fast path at I5 (its shape-gated fallback is the §4 pattern) or removed
— it does not stay dead; its documented semantic gaps (skipped
namespace/id/language resolution on the fast path) are closed before
wiring (transparency requires identical results INCLUDING resolution).

## §9. Fixtures and gates (L92; stream 14 handoff)

**Pair-case representation-transparency family** (M5 ledger substrate):
the same table as (a) CX text, (b) `0x60` data-bin, (c) `0x63` chunked,
(d) Arrow round-trip — identical `out-cx`, `out-json`, and `out-hash`
across all four; the `from_chunked` provenance flag pinned as
never-serialized; row-iteration vs column-iteration lanes over one
input (the table-api fixture skeleton already defines both); nullable/
dictionary/mixed column decode vectors; secret-column force-node
negative; EV-PULL effect-count probes over table sources. Columnar
lanes land `gate=advisory` and flip to `enforced` at I5. **Perf gates
14–16/30.5 are repaired first** (#710) — allocation/throughput budgets
are gate territory, not corpus territory, and the gates must run before
any acceptance criterion leans on them.

## §10. Rulings ledger — RULED

Letters 86–92 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar): transparency
normative / internals QoI with four observable exceptions (86); the
dual lean recorded — the owner's "BOTH" correction, not columnar-only
(87); the boundary rule with the D22 table seam (88); the wire lattice
implemented in full, within-kind narrowing, dictionary atoms, secret
excluded (89); tables not modify-targets, COW as QoI guidance (90);
contradiction repairs incl. table-api amended now and the dead
streaming pipeline wired-or-removed (91); transparency pair-fixtures +
gate repair as prerequisite (92). Recorded in the campaign decision
log. Spec-edit map: cx_partition.md §9 (dual lean wording), table-api
§(layout claim, lattice, iter_cols), data-bin §3.10 (impl rises),
cxstore_columnar_backend (pushdown timing), code.md §6.7 (EV-PULL
cross-ref), abi.md (capability bit for the engine at I5, bits 41–63),
conformance families per §9.
