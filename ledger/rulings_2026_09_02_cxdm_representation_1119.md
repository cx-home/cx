# Rulings 2026-09-02 — #1119 CXDM in-memory representation (RP-1..RP-6)

**Status: RULED (a) on RP-1..RP-6 under the standing letter-acceptance
ruling (2026-08-05), each verified against the long-term-best bar; flagged
for owner review like every agent-authored adjudication.** Recorded BEFORE
any implementation, per the #832 process rule. No behavior has changed.
The design these rulings authorize is `spec/02-working/cxdm_representation.md`
(WORKING, not graduated; G3 is owner-only).

Issue: #1119 (umbrella, `representation campaign`). Session scope pinned
2026-08-30 in `ledger/rulings_2026_08_30_codec_ring_layering.md` item 10:
Fable, design-first; Opus implements only against a ruled design.

Prior rulings honored, not re-derived: **TF-5** (streaming direction),
**TF-10** (priority), **L86–L92** (`runtime_representation.md` —
transparency normative, representation QoI, boundary rule, dual lean),
**#1176** (no compiler; the representation is the work; reopen trigger),
**#1077** (full option space per item), **#804 leg 2** (LazyRecord's
dual-build differential), the vgc lineage (#57/#58/#63/#973 — no
GC-soundness regressions).

## RP-0 — the streaming direction is ALREADY RULED; it stands (TF-5 = a)

The session brief posed "does the 32-event vocabulary reach the codec
surface, or is NDJSON the ceiling?" as the ruling that must come before the
code. It was ruled on 2026-08-30: **TF-5 = a** — the 32-event model IS the
one streaming mechanism and is meant to reach the codec surface (read-side
pull events from non-CX input, json and xml first), NDJSON is a lane and
not the ceiling, implementation is demand-triggered by the first consumer
whose documents break the whole-document model, and no per-format
streaming hack may land meanwhile. TF-5 also recorded the split this
session executes: the multiplier is representation overhead, and no event
API fixes the in-program tree a feature navigates.

Not re-posed (a settled owner decision is never re-litigated). What this
session ADDS to TF-5's record is the measurement that proves the split:
the live tree costs 10–18× input bytes with the input string long gone
(§"What was measured"), so a streaming reader would leave every consumer
that does more than stream-and-forget exactly where it is.

## What was measured (the design attacks this, not a guess)

Binary `vcx/target/cx` @ 21c2da416 (macOS arm64, vgc default). Corpora
generated in-session, same logical data in three surfaces, 300k flat
records × 4 fields (`id` int, `name` string, `active` bool, `score` float):
JSON array of objects 19.0 MB; XML `<rec …/>` attribute records 19.9 MB; the
CX text the JSON converts to (an array of map literals) 19.0 MB. Peak RSS by
`/usr/bin/time -l` on `--from=X --to=X`; live bytes by a V harness over the
`cx` module that parses, walks and counts, then `gc_collect()`s with the
tree still reachable and reads vgc's `marked` (input string subtracted).

| lane | peak RSS | RSS× | live after collect | live× | RSS ÷ live |
|---|---|---|---|---|---|
| JSON (`__cx_map__` envelope carrier) | 1,938 MB | 102× | 345 MB | 18.1× | 3.3 |
| XML (Element + Attribute) | 1,162 MB | 58× | 290 MB | 14.6× | 4.0 |
| CX map literals (`MapNode` carrier) | 887 MB | 47× | 195 MB | 10.3× | 4.5 |

Read across the rows: **the representation is 10–18× on its own; the rest
of the multiplier (×3.3–4.5) is collector policy** — the pacer's goal is
2× marked (`gc_percent` 100) plus span pool and emit-time transients. The
audit's 112×/50× (F14) and these 102×/58× are the same phenomenon on
corpora of slightly different shape; nothing here depends on matching them
exactly.

Per-node accounting (sizes by `sizeof`, counts by the walker):

- `Node` is 16 bytes: a pointer + tag. **Every variant's payload is a
  separate heap object** (V sum types box). A `ScalarNode` is 24 B holding a
  `ScalarValue` (16 B, itself a boxed sum type) — so ONE integer costs the
  16-byte slot + a 24-byte box + an 8-byte box: three objects, two
  allocations, for eight bytes of information.
- **JSON, per field** (1.2M fields): envelope `Element{name: key, items:
  [v]}` = 96 B box + a 16 B block for the EMPTY `attrs` array (vgc keeps a
  real block for zero-cap arrays, #657) + a 16 B `items` block + the key
  string copied per occurrence (1.5M `substr` copies for 6 distinct names;
  8.1 MB of name bytes) + the scalar's two boxes. ≈190–210 B for ≈15 input
  bytes. The record itself adds another Element and a 64 B items block.
- **XML, per attribute** (1.2M): 48 B inline `Attribute` + the value's boxed
  `ScalarValue` payload + the name copy, **plus a 112-byte `AttributeMeta`
  on 900k of them** — allocated by `set_data_type` solely to carry the
  autotyped kind's NAME (`xml_parser.v` typing pass). 100 MB — five times
  the input — spent recording that an attribute is an int.
- **CX map literals, per entry**: 56 B inline `MapEntry` + boxed key
  `ScalarValue` + the value's two boxes. Same data as the JSON lane at 57%
  of its live bytes — **the carrier shape alone is a 1.75× difference,
  measured, with scalar boxing held constant.**

Two dominators, therefore, for two workload classes: for record DATA the
carrier shape (an Element per field) dominates; for EVALUATION (Stage-0
profile: alloc+GC 42–79%, `fib` model 780 ms → 38 ms compact) the
per-value boxing dominates. A design that fixes only one leaves the other
multiplier standing. RP-1 takes the boxing; RP-3 takes the carrier; RP-4
takes the two parser-side leaks the accounting exposed.

## RP-1 — the value carrier: a compact inline tagged Node (RULED: RP-1 = a)

- (a) **TAKEN — `Node` becomes a 24-byte tagged struct: an 8-byte header
  (node kind, scalar kind, flags) and a 16-byte union {`i64`, `f64`,
  `bool`, `string`, pointer-to-payload}.** Every scalar kind and every
  single-string kind (Text, Alias, Hole, EntityRef, PEReference, RawText,
  Interpolation) is carried INLINE — zero allocations per value. Compound
  kinds (Element, Map, Array, Sequence, Iterator, Document, Comment, PI,
  XMLDecl, CXDirective, EvalDirective, BlockContent, the DTD family,
  Path/Match/Modify, LazyRecord, Doctype) stay heap structs reached by
  pointer — the SAME aliasing semantics as today's boxed variant, so
  sharing, spine-copy, and IteratorNode's identity-by-address are
  unchanged. `ScalarValue` becomes the same shape minus the node kind (an
  inline compact scalar), so `Attribute.value` and `MapEntry.key_value`
  lose their boxes too. Verified in-session: V unions compile with a
  `string` and a pointer member (`sizeof` 24 as designed); the compiler's
  `contains_ptr` sees through the union, so `[]Node` is allocated
  SCANNABLE (never `_noscan`); vgc's precise per-span pointer-map scan is
  REMOVED in the fork (the cgen comment says so and the conservative-mark
  backstop scans every scannable span), so a union payload is found the
  way every pointer is found today. Soundness rules the spec makes
  normative for the implementation: compound pointers live in a
  POINTER-TYPED union member, never an integer word; union access is
  confined to the `ast.v` accessor bodies; `Node` is never allocated
  noscan.
- (b) Keep the V sum type; inline only `ScalarValue` inside `ScalarNode` —
  rejected: removes one of the scalar's two boxes and none of the Node
  box, touches the same ~1,800 `ScalarValue` sites, and leaves the
  evaluator's per-intermediate allocation in place — half the win for the
  same migration class.
- (c) NaN-boxing / low-bit pointer tagging into 8 bytes — rejected on the
  GC invariant: an encoded pointer is not an interior pointer; the
  conservative word scan would not find it and the object would be swept
  live. The vgc lineage is a non-negotiable invariant of this campaign.
- (d) Arena / pooled storage per document — rejected as the general
  answer: subtrees escape their document (stores, closures, `[?modify]`
  spine-copy, iterator memos); the V memory-management spec already found
  arenas workload-shaped (§1.3). Not revisited.

## RP-2 — migration mechanics: API-fication first, then ONE flip (RULED: RP-2 = a)

Touch surface measured: 187 `.v` files in `vcx/` (cx 60, code 76, platform
83, tests 27, cmd 7, cxstore 4, cli 2) plus 7 under `lang/v`; 8,648 lines
naming a variant; 1,732 `is Element`, 573 `as Element`, 516 `is
ScalarNode`, 1,995 `Node(…)` casts, ~1,800 `ScalarValue` mentions.

- (a) **TAKEN — a behavior-free pre-pass converts every `is`/`as`/`match`/
  `Node(…)` site to a kind-and-accessor API (`n.kind()`, `n.is_element()`,
  `n.el()`, `mk_int(v)`, …) IMPLEMENTED OVER THE CURRENT SUM TYPE, landing
  per directory with the full gate green each time; then the
  representation flips in ONE commit confined to `ast.v`, the accessor
  bodies, and the parsers' constructors.** This is not dual-accept: one
  representation exists at every commit; the API is the permanent access
  discipline that makes L86 ("representation is QoI") true in the code
  — the next layout change becomes local instead of tree-wide.
- (b) One big-bang flip across 187 files — rejected: unreviewable,
  ungateable mid-way, and `make -j` masks later lanes after the first
  failure (the 2026-09-01 lesson) — defects would surface one per run.
- (c) Two coexisting `Node` types with conversions at module seams —
  rejected: dual-accept (absolute), and it doubles allocation during the
  transition — the opposite of the campaign.

## RP-3 — the map / array / sequence carriers: one representation, the element envelopes retire (RULED: RP-3 = a)

The runtime carries maps TWO ways: `cx.MapNode` (parsed map literals,
`[?to-map]` results) and the in-pipeline `__cx_map__`-marker Element
whose entries are `Element{name: key, items: [value]}` (every JSON/YAML/
TOML parse, and eval's lane), bridged by `map_node_view` (#618). The
marker appears in approved spec exactly ONCE, descriptively (the
`runtime_representation.md` worked example); `cxdm.md` §2.6 makes Map a
first-class Item; ast-bin already carries `0x11 MapNode`. The envelope is
implementation, QoI under L86.

- (a) **TAKEN — unify on `MapNode` / `ArrayNode` / `SequenceNode`. Entries
  are inline `MapEntry{key (compact scalar), value (compact Node), kind}`
  ≈ 48 B, one allocation per map; the JSON/YAML/TOML parsers build them
  directly; the evaluator's lane carries them; `map_node_view`, the marker
  names, and `jnode_seq/arr/map`'s element wrapping are deleted;
  `key_kind` / `decl_kind` already live on `MapEntry`.** Measured basis:
  same data, envelope 18.1× vs MapNode 10.3× with boxing held constant,
  and the envelope's ~130 B of pure carrier per 15-byte field. Fidelity is
  the risk and the corpus is the arbiter: every marker-matching site (38
  in code, 24 in platform, 6 in cx) gains a MapNode arm; canonical bytes
  cannot move (identity is text; emitters already render `MapNode` as
  `{k: v}`); the extraction gate's byte-identical transcript and the
  ~2,700-case corpus must stay green. Own wave, fixtures first.
- (b) Keep the envelope and diet the entry Element — rejected: an Element
  per field is the cost, not the Element's width.
- (c) Shape-shared record maps now — deferred to RP-6 with a trigger.

## RP-4 — names interned per parse; kinds inline on attributes; exact-size arrays (RULED: RP-4 = a)

- (a) **TAKEN.** (i) Parsers intern element names, attribute names, and
  map keys through a PER-PARSE hash table — O(1), and explicitly NOT the
  #1178 linear-scan pool that was just removed; strings are immutable so
  sharing is safe and a per-parse table has no cross-thread state. (ii)
  `Attribute` carries its scalar kind INLINE (the compact scalar of RP-1
  already does); `AttributeMeta` is allocated only for storage-precision
  names (`u16`, `f32`, …) that the kind byte cannot express — the 900k
  112-byte blocks in the XML lane vanish. (iii) Where a count is known
  (JSON object/array, XML attribute list) the parser builds exact-size
  arrays, and Element construction stops paying two 16-byte blocks for
  empty `attrs`/`items`.
- (b) A process-global intern table — rejected: shared mutable state
  across parser threads (the #973 class) for no gain over per-parse.

## RP-5 — the exit bar and the guard (RULED: RP-5 = a)

- (a) **TAKEN — two-part bar.** (i) **Campaign exit:** peak RSS ≤ 8× input
  on the audit corpora (JSON records, XML attribute records; `--from=X
  --to=X`, default pacing) — the owner's proposed number, kept: admission
  is RSS. (ii) **Regression guard, committed and in `make test`:** a
  `bench/repr` lane (V driver over `cx` + a runner script) asserting the
  LIVE multiplier (bytes marked after a forced collect ÷ input bytes) per
  lane against a bound — a RATIO, so it holds on any machine; a ~2 MB
  corpus so it costs well under a second (#700's register is respected).
  The bounds are a **ratchet**: pinned at W1 to today's multipliers with
  headroom (so any wave that makes it worse fails), re-pinned downward at
  each wave's exit. The model puts RP-1+RP-3+RP-4 at ≈4.4× live on the
  JSON records, i.e. ≈9–10× RSS under the 2× pacer — at the bar. If the
  RSS half misses after W7, the gap is ATTRIBUTED BY MEASUREMENT to pacer
  vs representation: the pacer half is a V-runtime item (own issue,
  `upstream` mirror), the representation half is RP-6's trigger.
- (b) Live-only bar — rejected: the product-limiting quantity is RSS.
- (c) RSS-only bar — rejected: RSS is pacer- and platform-dependent; not a
  deterministic gate.

## RP-6 — shape-shared record maps and columnar/lazy record arrays: ruled in principle, trigger-bound (RULED: RP-6 = a)

- (a) **TAKEN — NOT in #1119's exit; ruled in principle as QoI
  refinements under `runtime_representation.md` §2/§4 (transparent;
  boundary rule; the D22 table seam), each designed as its own letter when
  triggered.** Trigger: RP-5's RSS bar missed on the representation half
  after W7, OR the first record-feed consumer above ~100 MB. Cost model:
  shape-shared maps (one interned key vector per homogeneous shape,
  values-only array per record) ≈150 B/record → ≈2.4× live on the JSON
  corpus; columnar tables ≈0.5×.
- (b) Do them inside this campaign — rejected: RP-1..RP-4 already deliver
  the 3–5× data win and the ~20× scalar win; stacking a second semantic
  seam onto the flip wave raises risk for a gain the bar may not need.
- (c) Never — rejected: the S-0 premise (SaaS on CX, enterprise feeds)
  will need it.

## Execution constraints (not letters)

1. **#1176's reopen trigger executes in W8:** re-run the Stage-0 profile
   after the flip and record it; AOT re-costing only then.
2. **No approved-spec edit now** — L86 makes this QoI. `runtime_representation.md`
   §1 finding 1 ("one uniformly boxed representation … 27-variant") goes
   STALE at the flip and is trued in W5 with `RULED: RP-1`. `streaming.md`
   is untouched (TF-5).
3. **Invariants, stated so the gates can check them:** canonical identity
   unchanged in BOTH tiers (identity is text); `semantic_value_model.md`
   E4 intact; the frozen libcx ABI untouched (it exposes zero node
   pointers — `runtime_representation.md` §1.5); the extraction gate's
   transcript byte-identical over the Ring-0 corpus; EV-* evaluation order
   unchanged; `nodes_equal` semantics unchanged (Iterator identity by
   address survives — the pointer moves from a box to the union);
   LazyRecord's `-d cx_no_lazy_record` differential stays byte-identical;
   ast-bin / data-bin wire untouched; no vgc-soundness regression
   (concurrency soundness gate green at every wave exit).
4. Exit gate for every wave: full `make test`, verdict from the log.

## Wave plan (member issues filed 2026-09-02; #1119 is the scoreboard)

- **W1 (#1200)** — `bench/repr` guard + harness committed; today's multipliers
  pinned as the ratchet baseline. Small; unblocks measurement of every
  later wave.
- **W2 / W3 / W4 (#1201 / #1202 / #1203)** — API-fication (RP-2) of `vcx/cx`, `vcx/code`, and
  `vcx/platform` + `cxstore` + `cmd` + `cli` + `tests` + `lang/v`
  respectively. Independent of each other (parallel sessions in
  worktrees per the shared-checkout rule); each gate-green; zero behavior
  change.
- **W5 (#1204)** — the flip (RP-1): compact `Node` + compact scalar; accessor
  bodies; parser constructors; `runtime_representation.md` §1 truing
  (`RULED: RP-1`); measure.
- **W6 (#1205)** — RP-4: per-parse interning, inline attribute kind, exact-size
  arrays; measure.
- **W7 (#1206)** — RP-3: carrier unification, fixtures first; measure.
- **W8 (#1207)** — exit: RP-5 measurement on the audit corpora, Stage-0 profile
  re-run (#1176 trigger), ratchet re-pinned, RP-6 trigger evaluated,
  campaign closed on #1119.
