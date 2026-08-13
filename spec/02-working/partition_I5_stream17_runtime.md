# I5 stream 17 — runtime representation (implementation ledger)

**Branch** `impl/I5-stream17-runtime` off `design/651-516-partition`
(opened 2026-08-13 @ 3667027a, the stream-22 exit merge). **Governing
spec** `runtime_representation.md` (letters 86–92 ruled (a)
2026-08-05: transparency normative/internals QoI w/ four observable
exceptions; the DUAL lean — the owner's "BOTH" correction; the D22
boundary rule; the wire lattice in full; tables-not-modify-targets;
contradiction repairs; pair-fixtures + gate repair prerequisite).
**Issues:** #689 (the stream), #710 items 2/3/5/6/7 (items 1+4 landed
pre-stream on impl/defects-714). **Inbound handoffs:** stream 22's
EV-PULL rule + the advisory pair (flip = acceptance); stream 16's
PathNode residual (#689 comment).

## Shipped-state map (evidence sweep 2026-08-13, at 3667027a)

Spec-complete, implementation-zero. Item 6: mk_eager_iterator
(eval.v:13567) pre-fills memo/exhausted at 16 combinator sites; the
closure-bearing kinds (map/filter/scan/partition/group-by/cycle/
reduce) dead-end at pull_iterator_to_end:14126 ("env/closure table is
not threaded"); the seams that already exist: the Ring2IterWalk
registry (ring_registry.v:57 — carries mut env + ForLimitState),
iter_open_range_walk (eval.v:13589 — the one-item-at-a-time reference
walker), single_use/D25 discipline, and ev-pull-002 pinning
no-over-pull under either engine. Item 7: table_row_maps
(eval.v:2951) allocates N(1+2M) boxes; 4 hot call sites (5545/5573/
11998/13505). Item 3: column_type_code (data_bin.v:926) still
degrades unsigned→i64, f16/f32→f64, bool→sentinel, else→string;
0x62/0x80/0x81 spec'd (data-bin §3.10.3, 24-row table) w/ ZERO
implementation; per-cell tags still emitted (the omit-tag
optimization reserved); Arrow validity bitmaps hardcoded NULL
(arrow.v:34); secret never columnar = neither enforced nor violated
(nothing forces the node path). Item 2: store_columnar_query_matches
(platform/store_columnar_d_cxstore_columnar.v:939) materializes
framed→parse→row loop; honest-reporting flag ships. Item 5:
parser_streaming.v (634 lines) ZERO callers; header FALSELY claims
eval_code_streaming uses it; self-documented gaps (namespace/id/
language resolution skipped; root #id refused). DRIFT found: table-api
§8.1 still carries the false column-major claim (:339/:352 — the L91
edit hit §2 only); gates 14/16 still end in build failures + the
in-tree _gate_evidence logs for 15/30.5 are stale (show pre-repair
reds); cx_partition.md §9 dual-lean wording NOT applied; abi.md
41-63 reserved (no engine capability bit claimed). The §9
representation-transparency pair family is entirely UNAUTHORED
(conformance/table/ does not exist). PathNode still outside the Node
sum type (ast.v:43); the accept-always arm at eval.v:2384.

## Wave plan

- **W1 — EV-PULL: the demand-driven engine (#710 item 6, the
  stream-22 acceptance):** thread env/closures through the pull
  machinery (the Ring2IterWalk shape generalized to combinator
  chains; per-pull closure invocation; take-over-infinite works;
  memoization + single_use preserved; EV-BUDGET floor respected);
  FLIP ev-pull-001/003 advisory→enforced (red→green = acceptance);
  ev-pull-002 + program-iterator-* stay green; the eval.v:3890 EBV
  comment becomes true.
- **W2 — batch [?for] over tables (#710 item 7):** the D22 row view
  without N(1+2M) boxing on the [?for] hot path; byte-identical
  results (transparency); a perf evidence note (gate-15/30.5 numbers
  move or the wave records why not).
- **W3 — the columnar lattice rise (#710 item 3, L89):** 0x18/0x28
  columns; unsigned + f16/f32 widths kept (narrowest-within-kind);
  0x80 nullable (bitmap + packed non-nulls) incl. real Arrow validity
  bitmaps both directions; 0x62 dictionary w/ atom columns
  dictionary-encoded BY CONSTRUCTION; 0x81 mixed as the honestly-
  reported totality escape; the columnar-omit-tag optimization
  (encode_table_cell's reserved _col_code input); SECRET NEVER
  COLUMNAR (force-node negative fixture); chunked 0x63 shares the
  risen mapper; decode vectors per §3.10.3.
- **W4 — vectorized pushdown (#710 item 2):** the predicate over
  column buffers (cxstore_columnar_backend §6) — no row
  materialization on the pushdown path; the honest-reporting flag
  stays truthful; equality-of-results fixtures vs the node path.
- **W5 — parser_streaming disposition (#710 item 5):** wire as the
  gate-15 fast path AFTER closing the resolution gaps (identical
  results incl. namespace/id/language resolution — transparency), or
  REMOVE ("it does not stay dead"); the false header dies either way.
- **W6 — PathNode graft (the stream-16 residual) + drift repairs:**
  PathNode joins the Node sum type; the 'path' accept-always arm
  becomes a real kind check (+ fixture); table-api §8.1/§8.2 false
  claims amended (RULED L91); gates 14/16 repaired to run honestly;
  _gate_evidence refreshed; cx_partition §9 dual-lean wording (the
  edit map); abi.md engine capability bit (41-63 band) claimed per
  the edit map.
- **W7 — hygiene + exit:** the §9 representation-transparency pair
  family AUTHORED (CX text / 0x60 / 0x63 / Arrow round-trip w/
  identical out-cx/out-json/out-hash; from_chunked never-serialized;
  row-vs-column lanes; nullable/dict/mixed decode vectors; the
  secret-column negative; EV-PULL effect-count probes over table
  sources) — columnar lanes flip advisory→enforced per L92; the
  edit-map sweep residue; #689 + #710 closure evidence; exit audit +
  exit gate → merge.

Named landings (ruled): the FULL per-combinator pull matrix + M5
witness families = stream 14 (§9 + the stream-22 handoff); XSD-era
items none. Items 1+4 = landed pre-stream (impl/defects-714).

## Wave record

- **W1 DESIGN (recorded before implementation).** The demand-driven
  core: (1) IteratorNode gains `consumed i64` (the source cursor —
  additive Ring-0 field; memo stays the yielded prefix, exhausted
  flips when the source ends). (2) eval.v gains `iter_pull(mut it,
  want, mut env) !` — extends memo to `want` items (want<0 = all):
  per-kind incremental arms for map/filter/take/drop/zip/enumerate/
  chunks/concat/cycle/scan (pull sources recursively via iter_pull
  when the source is an IteratorNode, index directly when
  materialized); partition/group-by remain FULL-FORCE with their
  lookahead DOCUMENTED in §6.7 (they must see the whole source —
  the spec's "except where a combinator documents it" seam);
  generator kinds (range_open/iterate/unfold) respect `want`; live
  kinds delegate to the Ring-2 walk registry unchanged. (3) The 16
  construction sites build LAZY nodes (no eager memo). (4) iterate()
  has NO env (why the W3c dead-end existed) — env-bearing callers
  move to a new `iterate_env(n, mut env)`; the program-RESULT
  boundary forces via a new `pub fn force_lazy_result(n, mut env)`
  called in api.v (all three variants) AND the conformance runner —
  laziness survives bindings, forcing happens only at consumers and
  the env-bearing result boundary. EBV keeps refusing to force
  (eval.v:3890 — now true). EV-BUDGET guards total pulls. Acceptance:
  ev-pull-001/003 flip advisory→enforced; ev-pull-002 +
  program-iterator-* + take-over-infinite ([$range 1 *]) green.
