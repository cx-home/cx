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
- **W7 EXECUTED 2026-08-13 — the §9 pair family + the ruled audit
  additions (L92; Q3a/Q4a/Q6a). Session note: ran on Fable 5 (the
  session's launched model; capability ⊇ the Opus-5 policy tier; no
  mid-session switch) — which put the exit audit inside its ruled
  model boundary.**
  **W7.1 (#806 CLOSED-READY, fixture-FIRST):** the three AF-1
  divergences pinned as refusal-IDENTITY parity fixtures (same
  refusal MESSAGE, compared; zero bytes precede it; commit counter
  unmoved) — @nosuch at attr AND [ref @nosuch] body position;
  duplicate Unicode '#émile' → CXER0208; rooted /meta + //src in the
  yield body (buffered SUCCEEDS — streamed must match, never
  commit-then-CXER0001). Verified red in the exact audited modes,
  then green. Gate closures (streamed_input.v): '@' scanned like '#'
  (both ride document-global resolve_ids); the name predicate is the
  PARSER's ([L10a] byte arm + utf8_cp_at/is_name_start_cp decode;
  invalid UTF-8 = conservative decline); rooted-path spellings at
  expression position decline ('/x', '//x', '/@a', '/*' — the '/ '
  operator head stays engaged). Gate-15's bench shape carries no new
  decline trigger (engagement witness green).
  **W7.2 (#807 heads, ruled Q4a):** (a) out-of-range integer cells
  REFUSE loudly at encode on BOTH binary lanes — check_int_cell_range
  at encode_typed_cell (0x60) + encode_strict_cell (0x63), all signed
  + unsigned widths incl. negative-into-unsigned, column name in the
  refusal; the plain encode chain is FALLIBLE end-to-end
  (emit_data_bin ![]u8; codec-registry emit_bytes fallible w/ an
  ast_bin adapter; cabi err_out; Table.to_data_bin ![]u8; CLI loud).
  BISECT EVIDENCE: 40197669 (W3a) introduced the width-keeping casts;
  the pre-W3a encoder emitted per-cell VALUE tags (70000 rode int32 —
  type drift, value intact) — the audit's regression hypothesis
  CONFIRMED from history. Dead pre-W3a encode_table_cell REMOVED.
  (f) cx:serialize emits the canonical trailing LF — serialize∘parse
  ≡ canonical is BYTE-true; cx-121 pins it with NO mask; the
  cx-010/011/012 '[$concat … "\n"]' masks REMOVED (they asserted the
  buggy identity — the audit's masking finding); 10 serialize render
  pins re-derived from the oracle.
  **W7.3 (the family):** conformance/table_transparency.cxd (17
  cases) + runner lanes: [repr-pair] drives 0x60+0x63 against the
  SAME out-cx/out-json/out-hash the direct lane grades;
  from_chunked-never-serialized witnessed BYTE-level on every chunked
  pair (plain re-encode after chunked decode == direct plain encode);
  positive decode vectors pin the DECODER against blessed bytes
  (nullable/dict/mixed); [out-data-bin-plain-hex] pins the 0x62
  atom-dictionary bytes (the dict ENGAGEMENT witness) and the
  corrupt-dictionary-index vector is its negative; per-case gate=
  honored by conformance_run (advisory failures reported, never
  blocking — the gates.cxd model). Eval rows in code.cxd: row-vs-
  column lanes agree over one input (d22-012); EV-PULL effect-count
  probes over TABLE sources (ev-pull-004 take-over-map pulls exactly
  2; ev-pull-005 filter pulls until satisfied, 3 of 4). AF-2(b)
  FIXED fixture-first (ttp-006/007/008 + ttp-020 red → green): the
  0x80 inner code is the DECLARED/probed base (u16-with-nulls never
  widens; all-null n::int never falls to string) and the decode
  REFINES the rendered type from the inner (column_inner_code
  REMOVED). LANE (d) COMPLETE: the table name rides ArrowSchema.name
  both directions (reader surfaces the 0x50-wrapper name; export
  stamps the root schema; import re-emits the wrapper via named
  table-writer constructors) — [repr-pair-arrow] asserts FULL render
  identity; foreign producers without a schema name keep bare-0x63
  behavior. ADVISORY-RED pins (the ruled flip-gate — these ride
  #807's remainder, each ruling-bearing): ttp-009 header alias drift
  (f64→float + ::string drop — one wire code per column), ttp-010
  datetime-offset RENDER (the deliberate UTC wire pin; the Tier-1
  hash ALREADY agrees — canonical normalizes the same way), ttp-012
  f16 quantization render, ttp-013 0x81 declared-kind drop. **The
  columnar lanes' advisory→enforced FLIP is NOT executed — gated on
  family green per the Q4a ruling; the named landing for the flip +
  the four advisory classes is #807's remainder.** The u*/f16/f32
  widths are NOT in the Arrow bridge's format map (honest bridge
  limitation, named in the suite doc; ttp-002 rides lanes a/b/c).
  **W7.4 (witnesses + floor):** the pushdown honest-reporting flag
  asserted at the LIVE [$store:status] verb in BOTH directions
  (decline added; engage pre-existed); ev-budget-001-exactly-at-floor
  (rule=EV-BUDGET) pins the code.md ≥1,000,000-pull floor as a core
  row (~0.1s — the W1 bounded open-range arm).
  **Edit-map residue sweep:** code.md §6.7 EV-PULL cross-ref present;
  table-api iter_cols + lattice text present; cx_partition §9 / abi
  bit 41 / cxstore_columnar_backend §6 landed W6. A data-bin §3.10.3
  sentence stating the encode refusal normatively is NOT authorized
  by the ruling (behavior ruled, no spec-edit named) — recorded as a
  candidate for the #807-remainder landing, not silently written.
  **Gotchas:** V multi-return threading beats out-param refits for
  the (b) fix (column_effective_code → (eff, base)); a new runner
  lane's guard must name EVERY section it needs (the decode-vector
  lane briefly intercepted the schema-driven negatives — caught by
  the suite sweep, guard tightened to require out-cx); devbox's gate
  script is `test`, not `make`.
- **W7 gate record:** gate 1 `/tmp/s17_w7_gate.log` MISFIRE — ran the
  devbox `make` script (build-only; zero tests) — a runner mistake,
  not a red; discarded. Gate 2 `s17_w7_gate2.log` GATE-RC=2 — the
  FIRST full gate over the tabled audit report: the two spec-hygiene
  checkers (release-literal consistency; archived-record citation)
  tripped on the report's OWN historical prose (the reshape-era
  story's release literals; a quoted archived gate-table row). Fix
  @ e33a20ca: the report allowlisted in both checkers under their
  documented historical-record categories (the earlier audit-report
  precedent) — the tabled report's bytes UNTOUCHED. (This paragraph
  is worded token-clean on purpose: the checkers scan the working
  tree, and a ledger that NAMES the tripping tokens re-trips them —
  gate 4 proved it.) Gate 3 `s17_w7_gate3.log` GATE-RC=2: fabric/http
  = the classified #572 compile pair (in-gate cache-free retries
  GREEN); the one enforced red = the cxparse differential's COUNTED
  baseline (its designed movement contract): the family's +16 in-cx
  rows moved 779/612 → 795/628 with ALL SIXTEEN in the agree class
  and every divergence bucket unchanged — reviewed + updated
  deliberately @ 04d2669a (corpus growth only; both engines parse
  every new input identically). Gate 4 `s17_w7_gate4.log` GATE-RC=2
  at the early checks: THIS ledger's own gate-2 narration named the
  tripping tokens — reworded token-clean (both checkers verified OK
  directly over the working tree). **Gate 5 `s17_w7_gate5.log`
  GATE-RC=0** — the EXIT gate: PRE/POST HEAD = 04d2669a, dirty=4 =
  spec-only (the parallel session's PLAN.md hunk + this ledger/
  packet paperwork, committed immediately after); fabric/http = the
  classified #572 compile pair, cache-free retries GREEN in-gate.

## Closure evidence (#689 / #710) — stream exit

- **#689 (the stream):** W1 EV-PULL demand-driven engine (acceptance
  flip executed); W2 batch [?for] over tables; W3a-c the full §3.10
  lattice (0x62 dict, 0x80 nullable + real Arrow validity, 0x81
  mixed, secret-never-columnar); W4 vectorized pushdown (verdict-once
  = the shipped grammar's vectorized evaluation, disposition
  recorded); W5 parser_streaming WIRED as the gate-15 fast path (raw
  lane removed) + #806 refusal-identity closed in W7; W6 PathNode
  graft + the ruled drift repairs + honest perf-gate repairs
  (#802/#803/#804 filed → #805); W7 the §9 pair family + ruled audit
  additions. CLOSE at merge.
- **#710 items:** 1+4 pre-stream (impl/defects-714); 2 = W4; 3 =
  W3a-c; 5 = W5; 6 = W1; 7 = W2. CLOSE at merge.
- **#806:** closed with W7.1 (evidence above). **#807:** heads (a)
  + (f) + class (b) fixed; REMAINDER stays open — classes (c)/(d)/
  (e) + the 0x81 declared-kind drop, each ruling-bearing, pinned
  ADVISORY-RED by ttp-009/010/012/013; the columnar lanes'
  advisory→enforced flip GATED on that family green (the Q4a
  ruling); the data-bin §3.10.3 encode-refusal sentence rides the
  same remainder (behavior ruled; spec edit unauthorized).
- **Named landings standing:** stream 14 register row unchanged (the
  full per-combinator pull matrix + M5 witness families); #805 =
  gate-truth batch (#802/#803/#804) next after this exit per Q7a.

## Exit audit (in-session; Fable 5 — the ruled model boundary)

Adversarial pass over W7's own claims, method = the I5 audit's
(engagement witnesses, refusal parity, no-truing):
1. Every W7 fix landed fixture-FIRST with the red verified in the
   audited failure mode (W7.1 three modes; W7.2 wrap values; W7.3
   ttp-006/007/008/020) — no fix preceded its pin.
2. No threshold or expectation was trued to a shortfall: the four
   render-parity divergences the family surfaced are ADVISORY-RED
   with named rulings required, not rewritten expectations; the
   serialize-mask REMOVAL is the inverse of truing (the masks
   asserted the bug).
3. Engagement is witnessed at every seam W7 touched: streamed-input
   commit counter (still engages post-gate-tightening), the 0x62
   byte pin + corrupt-index negative, the pushdown flag at the LIVE
   verb both directions, repr-pair lanes graded against shared
   truths, from_chunked byte-witness on every chunked pair.
4. Honest residue, named: gate 15/30.5 stay true reds (#804/#803 →
   #805); the Arrow bridge lacks u*/f16/f32 formats (suite doc);
   date-year and f32-overflow encode arms remain best-effort
   (pre-existing, outside the ruled integer-wrap class — noted, not
   silently blessed); the wire bytes of nullable narrow-width
   columns changed (inner = declared base) — a CODEC change under
   ruling 19 (tags not identity-affecting), no blessed pin moved
   (full data-bin suite sweep green), old buffers still decode
   (inner read dynamically).
5. Scope check: every AUDIT-RULED W7 addition (Q3a/Q4a/Q6a) has a
   landing above; nothing deferred without a named landing (#807
   remainder, #805 batch).

## #807 remainder landing (post-exit; packet §10 arc-2/arc-3, 2026-08-14)

**Rulings-before-edits.** The owner's next-arc record (exit packet §10,
2026-08-14) governs this landing: **arc-2** (the remainder's
identity-adjacent choice — the long-term-best reading decides,
fixture-first; adopt when existing Tier-1 addresses are preserved;
address movement is a STOP-POINT) and **arc-3** (f16: refuse-or-widen —
a value that does not round-trip exactly widens to full precision or
refuses loudly; never silently approximates; extends Q4a). The
data-bin normative sentences named below ride these rulings (the
§3.10.3 encode-refusal sentence was recorded at exit as a candidate
for exactly this landing).

**The stop-point check (arc-2) — resolved to ADOPT, zero movement:**
Tier-1 hashing of binary inputs goes through canonical TEXT
(`cx_data_bin_hash` decodes and hashes `cx_canonical_doc_text` — the
CXCol wire bytes are not a hash basis anywhere in the tree), and this
landing changes no text canonicalization. The alternative branch for
class (c) — canonicalizing type-alias spellings in TEXT — would move
every `::f64`-spelling document's address AND erase declared-width
vocabulary; rejected on both counts. Wire-byte goldens (ch-*) are
deliberate re-pin fixtures by their own G5 charter ("show exactly
which wire bytes moved"), not addresses.

**The design (lossless-transport wire; strict stays strict):**
`canonical.md` §2.6 already defines the two tiers — LOSSLESS canonical
preserves offsets and source spellings; STRICT canonical (the hash
basis) normalizes. The CXCol transport writer aligns with the lossless
tier; strict canonicalization of binary inputs remains decode→strict-
text (unchanged):

- **Class (c) + the 0x81 declared-kind drop (ttp-009/013):** the
  col-spec gains a declared-type-name annotation — `0x82
  <string(declared-name)> <col-type>` in the col-type position,
  emitted IFF the declared spelling differs from the code's default
  render (minimal-annotation determinism; `v::float` col-specs are
  byte-identical to before). The reader applies the annotation as the
  rendered type name (it wins over 0x80 inner refinement); unknown
  declared types on the 0x81 escape round-trip their names. All
  col-spec readers rise: plain/dict/chunked (V), the streaming lane's
  two readers, chunked_group_row_counts, and the three native binding
  decoders (python/rust/go).
- **Class (d) datetime-offset render (ttp-010):** the wire's §3.6.1
  12-byte form ALREADY carries `offset_minutes`; the transport
  encoders (scalar 0x32, 0x60/0x62 column cells, 0x63 strict cells)
  stop hard-zeroing it and carry the parsed offset; `unix_nanos`
  stays UTC-normalized; decoders already applied the offset. The
  strict-canonical CONSTRAINT (offset 0) is untouched and continues
  to govern strict canonicalization (which runs through text). The
  Tier-1 hash already agreed on this class; only render/json parity
  moves. ch-007 re-pins deliberately (its ns-normalization spirit
  holds; the offset bytes now ride).
- **Class (e) f16 (ttp-012, arc-3):** encode REFUSES a cell whose
  value does not round-trip exactly through the declared float width
  (never silently approximates; the shortest-round-trip renderer was
  considered and REJECTED — it masks the approximation behind the
  original spelling). Applied to BOTH reduced float widths (f16 AND
  f32 — arc-3's wording is width-agnostic and the f32 lane is the
  same defect class); both binary lanes; the refusal names the value,
  the width, and the exact representable alternative. ttp-012
  re-pins to the ruled contract: exact-value pair rows (green) + the
  non-representable refusal pinned in the width-refusal V family
  beside the Q4a integer contracts. Widen-vs-refuse: refuse, matching
  Q4a's "never silently widen" (a declared width is a contract;
  widening would drift the wire type exactly like the axis class (a)
  closed).

**Authorized spec edits riding arc-2/arc-3 (data-bin.md):** the
§3.10.1 col-spec annotation grammar + its §3.10.3 registry row and
strict-minimality constraint; the §3.10.3 encode-refusal sentence
(integer ranges per Q4a + float-width exactness per arc-3); a §3.6.1
transport-vs-strict sentence naming the already-specified offset
field's transport role. No other spec text moves.

**Flip:** ttp-009/010/012/013 advisory→enforced on family green (the
Q4a gate), completing the columnar lanes' enforcement.

**LANDED (2026-08-14, fix/807-render-parity):** the whole remainder in
three commits (ledger a27cc668 → V-side 021d133f → bindings+spec
c71dbee4). ttp-009/010/013 GREEN and ENFORCED; ttp-012 re-pinned to
the arc-3 contract (exact-pair green; the non-representable refusal
pinned beside the Q4a integer contracts in the width-refusal V
family, f16 AND f32); the ch-001..013 goldens re-derived with every
delta verified byte-exact to the annotation/offset mechanism (ch-007
re-scoped to offset-rides-transport); the three binding decoders
risen with live witnesses (go/python vectors, rust through libcx's
encoder). table_transparency 17/17 enforced, data_bin_chunked 13/13,
umbrella suite green, binding suites green, verify-doc-blocks +
check-code-spec-consistency + spec-freeze-gate green. The columnar
lanes' advisory→enforced flip is EXECUTED — Q4a discharged.
**Observed adjacent (filed separately, not silently fixed):** the Go
binding's SCALAR 0x32 arm still speaks a pre-§3.6.1 placeholder form
(10 reserved bytes + u16-length source string, writer and reader
both) — internally consistent but below spec; the COLUMN 0x32 arm is
spec-true. The events-layer col_spec (§1.1, u32-prefixed) is its own
protocol surface and does not carry the annotation by design.

**Exit-gate record (2026-08-14):** union run 1 GATE-RC=2 — the R4.1
freeze gate refused the bindings+spec commit's prose-only arc citation
(the token form is `RULED: <id>`); the unpushed commit reworded to
carry `RULED: arc-2/arc-3` (verified against the packet §10 store);
freeze gate solo GATE-RC=0. Union run 2 GATE-RC=2 — two reds: (i) the
numerics-umbrella chunked-datetime pin still asserted the pre-ruling
hard-zeroed normalization (missed in the first sweep; re-derived to
the ruled offset carriage, RULED: arc-2, solo-green), (ii)
ev-async-006[bin] under the 12-way load = the pinned #814 signature
(profile gate solo GATE-RC=0, same tree — fresh classification
evidence on the issue's terms). Union run 3 **GATE-RC=0 — every lane
green, no classification needed** (807_union3.log).
