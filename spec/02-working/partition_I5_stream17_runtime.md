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
- **W1 EXECUTED 2026-08-13 — EV-PULL, the demand-driven engine (#710
  item 6; the stream-22 acceptance FLIP executed red→green).** The
  pull core (iter_pull.v): lazy construction at map/filter/take/drop;
  per-kind incremental arms incl. the BOUNDED open-range
  (take-over-INFINITE works — the spec's motivating case);
  IterClosureEntry{cl, scope, closures-alias} parks transforms at
  construction and invokes against their OWN frame world (partials'
  inner sentinels resolve; EV-CLOSURE-CAP-faithful); the env-free
  consumer problem solved by the g_iter_pull_state hook (iterate()
  forces through a minimal state-built env — no 51-site sweep); §9.2
  err short-circuits surface at the FORCE point (err-terminal
  collapse; bare unwrap at the result boundary — force_lazy_result in
  eval_code all paths + BOTH runners + the profile-gate runner);
  statically-infinite unbounded forcing keeps the immediate classic
  refusal; EV-BUDGET exactly-at-floor succeeds; [par] map eager BY
  REQUEST (documented). ev-pull-001/003 ENFORCED (the acceptance);
  ev-pull-002 + all program-iterator-* + program-err-010 +
  program-pfa-004 green. **Gotchas:** V maps alias on assignment
  (entry closures = cheap COW-protected alias); error()-carried codes
  double-prefix through mk_err — strip before wrapping; the -prod
  lane refuses unused vars the dev build tolerates; EVERY runner is
  a result boundary (three of them).
- **W1 gate record:** gate 1 `s17_w1_gate.log` RC=2 (the unused
  filter binding under -prod; the profile-gate runner missing the
  boundary force) → **W1.1**. Gate 2 `s17_w1_gate2.log` GATE-RC=0,
  PRE/POST HEAD = 13116a8b, dirty=0 (fabric/http = the classified
  #572 pair, green on retries). W2 next: batch [?for] over tables
  (#710 item 7).
- **W2 EXECUTED 2026-08-13 — batch [?for] over tables (#710 item 7).**
  The [?for] table walk streams rows one at a time (table_row_map_at
  builds a single row's D22 view only when its iteration runs; a
  :take/:where short-circuit stops construction — the up-front
  N(1+2M) boxing is dead on the hot path); the row SHAPE is
  byte-identical (table_row_maps delegates to the same per-row
  builder). **Gotcha:** the for-source tail keeps plain iterate()
  (the EV-PULL state hook forces combinator chains; an iterate_env
  swap there regressed the statically-infinite refusal shape).
- **W2 gate record:** `s17_w2_gate.log` GATE-RC=0, PRE/POST HEAD =
  98d8ef79, dirty=0 (fabric/http = the classified #572 pair, green
  on retries; the first gate run died with the session — re-run
  clean). W3 next: the columnar lattice rise (#710 item 3, L89).
- **W3a EXECUTED 2026-08-13 — the §3.10.3 lattice rise (#710 item 3
  core).** column_type_code RISEN (unsigned + f16/f32 widths KEPT;
  decimal/bigint codes reachable; bool = 0x01 bit-packed §3.10.4;
  atom = 0x70; unknown = 0x81 honest mixed); the plain 0x60 form
  emits TYPED per-column payloads (per-cell tags die — the omit-tag
  optimization IS the encoding); undeclared columns probe cells;
  nulls wrap 0x80 (bitmap + packed non-nulls); collection columns →
  0x81. Full V decoder mirror incl. IEEE-754 binary16 both ways.
  CHUNKED rises w/ the shared mapper (bool bit-packs column-level;
  u*/f32/f16/decimal/bigint/atom strict cells). ARROW bool = direct
  bit-copy both directions. ch-009 wire hex RE-BLESSED deliberately.
  **Gate-found ×2 (W3a.1/W3a.2): EVERY language binding carries an
  INDEPENDENT CXCol decoder — python, rust, AND go (go's red hidden
  behind its test cache) all read the retired per-cell-tagged form;
  all three risen to §3.10.3 (typed payloads, 0x80, 0x81, bit-packed
  bool; rust parses bigint/decimal native; canonical UTC datetime
  renderers).** Lattice round-trip fixture family landed. Remaining
  for W3b: 0x62 dictionary + atom-by-construction + Arrow validity
  bitmaps + secret-force-node (the store-columnar side).
- **W3a gate record:** gates 1-2 caught the binding decoders
  (`s17_w3a_gate.log`/`gate2`); gate 3 `s17_w3a_gate3.log` GATE-RC=0,
  PRE/POST HEAD = c3335716, dirty=0 (fails all classified).
- **W3b EXECUTED 2026-08-13 — 0x62 dictionary + secret-never-columnar
  (#710 item 3 cont.).** The §3.10.2 form (atoms BY CONSTRUCTION;
  strings by the byte-savings rule; per-column 0x00/0x01 flags; FULL
  tagged dict values; range-checked indexes); SECRET NEVER COLUMNAR
  pinned structurally (__cx_secret__ = marker elements — promotion
  can't lift them; the force-node negative fixture). #794 filed
  (canonical quotes atom cells — the #791 family; the dict fixture
  asserts round-trip == direct render instead). **W3b.2 — the fabric
  flake ROOT-CAUSED:** the credited-transient-push read was NEVER a
  deadline problem (two raises masked it — 5s→30s stream-10, an
  attempted 30s→90s here still expired): the credit rides obsc, the
  next emit rides pubc — no cross-socket ordering; under load the
  emit beat the credit and the push was LOST (inherent drop, window=1).
  Fix = a request/response BARRIER on obsc after the credit (in-order
  per connection; the observer's DENIED reply is the side-effect-free
  barrier shape). Reproduced deterministically 3rd-consecutive-run
  pre-fix; 4× green post-fix; the in-gate retry ran green at gate 4.
  Deadline reverted to 30s. **Batch mapping (ruled 1a):** #795 = the
  canonical-forms batch (#790/#791/#794, owner-reviewed as one
  family, post-I5 own lane); #796 = the post-gate defect batch
  (#788/#792/#793, rides the #695 wave slot); campaign plan updated.
- **W3b gate record:** gates 1–3 red on the fabric race (classified
  wrongly as wall-clock twice before the root-cause); gate 4
  `s17_w3b_gate4.log` GATE-RC=0, PRE/POST HEAD = d9fb6286, dirty=0
  (fabric/http = the #572 compile pair, retries GREEN). W3c next:
  Arrow validity bitmaps + chunked nullable.
- **W3c EXECUTED 2026-08-13 — chunked nullable + REAL Arrow validity
  (#710 item 3 COMPLETE).** Chunked §3.10.5 (0x80 in the col-spec —
  whole-table decision; every group emits the wrapper; type names
  refine from the inner; exact null positions across group
  boundaries); the streaming lane's silent null-coercion → LOUD
  refusal; Arrow export derives layout from WIRE codes
  (codes_snapshot + a one-group peek resolves inner types at schema
  time; expanded buffers + validity bitmaps + ARROW_FLAG_NULLABLE —
  Parquet refuses undeclared nulls, gate-found); Arrow import emits
  §3.10.5 from validity (the '?' type-name prefix rides the ast_bin
  col-spec carrier — a raw byte form corrupted it, gate-found).
  End-to-end acceptance: CX → parquet (real validity) → back, the
  null lands as NullValue at the right row. All data-bin lanes +
  columnar + codecs/table umbrellas green.
- **W3c gate record:** `s17_w3c_gate.log` GATE-RC=0 first run,
  PRE/POST HEAD = 9b8b487a, dirty=0 (fabric/http = the #572 compile
  pair; retries green — the W3b.2 barrier holding). W4 next:
  vectorized pushdown (#710 item 2).
- **W4 EXECUTED 2026-08-13 — vectorized pushdown (#710 item 2;
  L86+L91).** The pushdown path materializes nothing it does not
  answer with: `parse_data_bin_projected` decodes ONLY the wanted
  columns (every other §3.10.3 payload cursor-skips — bool bitpack,
  f16, decimal/bigint varlen, atom/string dictionary, 0x80 nullable —
  witnessed by the LAST column decoding correctly across every
  skipped representation); the store executor consumes it for
  [projected col + `__cx_key`], killing the filed
  parse-everything-then-loop. Final-step PREDICATES lower: a
  promoted+exact column's candidates are shape-invariant BY PROMOTION
  (scalar leaves — no attrs, no element children, one name), so the
  row scan's own `store_elem_matches_predicates` evaluates ONCE and
  decides every row — parity by construction (the identical
  fail-closed engine, never a re-implementation); the attribute axis
  answers provably-empty. The executor runs `store_query_plan` FIRST
  — a path the row lane would CXER1709-refuse is never answered from
  columns. **Disposition (recorded):** §6's min/max row-group pruning
  + per-cell vectorized compare stay unconsumed BY THE PREDICATE
  GRAMMAR — no shipped predicate form reads cell values (attrs / name
  / position only), so building them now would be a dead seam
  (seam-needs-live-consumer); the verdict-once form IS the vectorized
  evaluation for the shipped universe. The moment the grammar grows a
  value-comparison form, the pushdown extends over the projected
  buffer. **Gotcha:** infix `[@x='1']` is RETIRED in CXPath — the
  prefix form `[= $_@x '1']` is the shipped spelling.
- **W4 gate record:** `s17_w4_gate.log` GATE-RC=0, PRE/POST HEAD =
  c00c2e38; POST dirty=1 is a PARALLEL SESSION's uncommitted
  `partition_campaign_PLAN.md` edit (the #800 analytics-campaign
  paragraph — spec-only, no build input; left untouched per the
  shared-checkout rule), not gate residue (fabric/http = the #572
  pair; in-gate retries green). W5 next: parser_streaming
  disposition (#710 item 5).
- **W5 EXECUTED 2026-08-13 — parser_streaming disposition (#710
  item 5; L91): WIRED as the gate-15 input fast path; the raw lane
  REMOVED.** The Element lane rose to a PULL reader
  (cx.open_top_level_children / CXChildStream.next — the root head
  validated by a REAL cx.parse of its slice; strict ws-only tail;
  every child through the real parser) consumed by
  code/streamed_input.v inside eval_code_streaming for the canonical
  `[?for [in $u $doc/user] [yield $u]]` shape (1–2 plain child
  steps). Equivalence machinery: per-match ns+lang resolution under
  the root context (lexical + downward ⇒ whole-doc-equivalent;
  validate_reserved_ns_bindings per child); conservative declines
  ($doc/$input spelled exactly once in the program text; no `..`; no
  `&`/`#name` input bytes — resolve_ids is doc-global); DEFERRED
  COMMIT (buffer to the 2nd match; 0/1-match walks decline
  pre-emission so the materializing path owns the single-match
  field-read shape, the #21 lone-collection unwrap, the __cx_slot
  fallback); TWO-PASS walk (the validation pass parses+resolves all
  and verifies the tail BEFORE any output — an input the
  materializing path refuses ALWAYS declines pre-emission and
  reproduces the exact refusal; the multi-doc fixture caught the
  single-pass emit-then-error live). Engagement WITNESSED
  (streamed_input_commits — the dead-seam guard). REMOVED:
  scan_top_level_children_raw + render_flat_record_to +
  StreamCtx.emit_raw_bytes + ptr helpers (a caller-less PARALLEL
  RENDERER of identity-bearing canonical text — the #563-565 class)
  + the false headers (claimed consumer; a resolve_languages pass
  that does not exist — lang rides resolve_namespaces). **Measured
  @20MiB:** peak RSS 290MB streamed vs 1283MB materialized (4.4×),
  wall ~20% faster; throughput 2.1 MB/s on BOTH paths — the 200 MB/s
  gate-15 threshold is an engine-wide per-item eval gap, NOT an
  input-path gap; gate 15 now RUNS honestly and measures a true red
  (W6 evidence item). **Gotchas:** cx.parse REFUSES multi-doc
  (`---`) input outright — parse_input_doc never sees a second doc;
  `ref` is a reserved element name (fixtures must not use it).
- **W5 gate record:** `s17_w5_gate.log` GATE-RC=0, PRE/POST HEAD =
  2acded26 (fabric/http = the #572 pair, retries green; dirty=1 both
  ends = the same parallel-session PLAN.md paragraph). W6 next:
  PathNode graft + drift repairs.
- **W6 EXECUTED 2026-08-13 — PathNode graft + drift repairs (#710
  items 1+4 residue; the stream-16 residual; L87+L91+L92).** GRAFT:
  PathNode joined the Node sum type; the `::path` kind test became a
  REAL check (the accept-always arm validated ANY value —
  program-sap-O1-10b pins the refusal); wire arms complete capability
  bit 36's three-kinds promise (0x13 encode/decode dispatch +
  node_is_v8; emitters follow the MatchNode conventions). RULED SPEC
  EDITS (the L91 edit map): table-api §8.1/§8.2 (bindings are
  row-major boxed; compactness is a WIRE guarantee; one-allocation
  aliasing = fixed-width lanes only); cx_partition §9 dual lean
  restored (L87 — the owner's BOTH correction); abi.md bit 41 claimed
  + cx_features SET (0x203df7fffff); cxstore_columnar_backend §6
  timing note (verdict-once IS the vectorized evaluation for the
  shipped predicate grammar). PERF-GATE REPAIRS (L92): gate 14
  (retired [?for PATTERN :yield] spelling → [?match] case-pattern
  form) PASS p99 0.3ms/1ms; gate 16 (retired [?service]/postfix-pipe
  spellings → [?http-service]/[?pipe]) PASS 15.7K rps, p99
  0.2ms/10ms; gate 30.5 runs honestly — sharing-ratio TRUE red
  (32,648 B/match vs 29 B subtree avg; identity PASS) → **#803**;
  gate 15 runs honestly — ~2 MB/s vs 200, an engine-wide per-item
  eval gap (identical on both input paths) → **#804**;
  _gate_evidence/gate_{14,15,16,30.5}.log refreshed on disk (the .log
  family is gitignored by design). FOUND IN PASSING: cx_features
  under-advertises bits 23/29/34-40 → **#802**. Y6: streaming_bench.v
  repaired off retired spellings (streaming 1.78× buffered);
  streaming_bench_json.v REMOVED (unwired, parse-dead, rode the
  retired interpolation form).
- **W6 gate record:** `s17_w6_gate.log` GATE-RC=0, PRE/POST HEAD =
  1f8214bc (fabric/http = the #572 pair, retries green; dirty=1 both
  ends = the parallel-session PLAN.md paragraph).
- **MARCH PAUSED (owner order, 2026-08-13, post-W6):** an ADVERSARIAL
  AUDIT of I5 runs before W7 or any further stream — the owner's read:
  the campaign is generating bugs faster than it fixes them (#790-#794,
  #802-#804 filed across three streams while headline issues close;
  #803/#804 are TRUE reds in shipped engine behavior surfaced by the
  W6 gate repairs). W7 (§9 transparency family + closure evidence +
  exit) does NOT start until the audit's findings are dispositioned.
  #802/#803/#804 need a post-gate batch mapping ruling (the 1a
  mapping predates them).
- **AUDIT RULED (owner, 2026-08-13: "1a-7a"; report
  spec/02-working/partition_I5_audit.md; rulings record §3 of
  partition_I5_exit_review_packet.md).** Mapping: #802/#803/#804 → the
  GATE-TRUTH batch #805 (after s17 exit, before stream 18); #781/#782 →
  #796. Relabels applied (#803 high, #793/#794 medium). **W7 SCOPE
  ADDITIONS (Q3a/Q4a/Q6a — part of W7 acceptance):** (1) #806 fixed
  fixture-first — refusal-IDENTITY parity lane (same refusal, compared)
  + the three gate closures (@ scan; Unicode name predicate; yield-body
  path validation or rooted-form decline); (2) #807 head items — u16
  out-of-range cells REFUSE loudly at encode (ruled; never wrap, never
  silently widen) + cx:serialize emits the canonical trailing LF, with
  a byte-level fixture; the full AF-2 family pinned by the §9 pair
  fixtures, and the advisory→enforced flip is GATED on that family
  green; (3) engagement witnesses — a 0x62 hex pin (an ::atom column in
  an out-data-bin-hex fixture), a corrupt-dictionary-index negative, a
  verb-level pushdown witness (honest-reporting flag asserted at the
  live verb, both engage and decline directions); (4) the EV-BUDGET
  exactly-at-floor probe (code.md §"MUST accept ≥ 1,000,000"). Model:
  W7 implementation = Opus 5 per the standing policy; #803-class
  vgc/GC descent, new lettered rulings, and any canonical re-bless
  escalate out.
