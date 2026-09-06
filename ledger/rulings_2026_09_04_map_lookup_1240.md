# Ruling record — #1240 map key lookup: no-format compare landed; the hash index is a carrier question (2026-09-04)

Issue: #1240 (enhancement, area:cx-lang, prio:medium, perf). Carrier: `vcx/cx/map_carrier.v` (RULED: RP-3).

## What landed without a ruling (representation unchanged)

- `MapEntry.key_image_is(k)`: the (kind, image) identity every lookup spelled as `e.key_str() == k`,
  without formatting the stored key — a string key compares its payload; an int key compares
  numerically after a canonical-image check on `k` (the int image is unique, so this IS the textual
  compare); other kinds fall back to the formatted image. Applied at all 20 sites (evaluator field
  read `map_member_step`, matcher map patterns, meta merge, stdlib).
- `[$map:get]` / `[$map:contains]` walk the carrier's own entries instead of building a normalized
  `MapNativeEntry` copy of the WHOLE map per probe (which formatted, NFC-normalized and re-coerced
  every key, three allocations per entry per probe). `cx_nfc_name` scans the string in place.
- Measured, flag-matched `-O0` binaries, 3,000-entry map, 20,000 probes (user seconds):
  int keys 41.0 → 11.7 (3.5×); string keys 12.3 → 4.8 (2.6×); `put`-built map unchanged.
- Byte-identity: `[$map:get]` on int / string / '3'-vs-3 / negative / zero / decimal / absent keys,
  `[= {1: x} {'1': x}]`, pattern rest-binds — identical to the baseline; code fixtures + numerics +
  xap + real_services lanes green.

## Question 1240-Q1 — a hash index for wide maps (OPEN, owner ruling)

Lookup is still O(n). The issue's step 2 is a `(key_type, payload)` → index alongside the ordered
`entries`. `MapNode` is heap-allocated behind a pointer in `Node` (`mk_map_node` stores `&v`) and a
published map is shared across threads (par_eval, workers), so a LAZY index built on first probe
is a data race unless published atomically; an EAGER index costs memory at parse for every wide
object whether or not it is ever probed, which `bench/repr` (RP-5) would see.

- **(a) recommended — eager index above a threshold, built in `mk_map` when `entries.len >= 64`,
  rebuilt by `map_set`/`[$map:put]` (both already O(n) clones).** Immutable once published, so no
  synchronization; small maps (every JSON record in the audit corpora) pay nothing, so the
  `bench/repr` ratchet is byte-identical. Cost: ~n × 16 B for maps of ≥ 64 keys. DELETES: nothing
  observable — order, `nodes_equal`, canonical bytes unchanged; the index is a lookup cache.
- (b) lazy index with atomic publication (`C.atomic_store`/`load` on a `&MapIndex` field; a losing
  builder discards its copy). Pays only when probed, but adds an unsafe publication protocol to a
  Ring-0 carrier and a mutable field to a value the rest of the tree treats as immutable.
- (c) close #1240 on the no-format compare alone. Wide-map probes stay linear; nothing today probes
  a wide map in a hot loop that the measurement can name.

Not ruled here: it changes the RP-3 carrier, so it is the owner's call. Recommendation (a).

## 1240-Q1 — RULED (a) 2026-09-05: an EAGER index above a 64-entry threshold

Accepted under the standing letter rule (the recommendation above, unchanged).

- Built in `mk_map` when `entries.len >= map_index_threshold` (64), rebuilt by
  `map_set` / `[$map:put]` — both already O(n) clones, so the rebuild is free in
  asymptotics. Immutable once published, so no synchronization and no unsafe
  publication protocol reaches the Ring-0 carrier.
- Key is `(key_type, payload)`; the probe falls back to the ordered scan for any
  key kind the index does not cover, so `key_image_is` stays the single identity.
- Maps below the threshold — every JSON record in the audit corpora — pay nothing,
  so `bench/repr` stays byte-identical and RP-5's re-based bar
  (`ledger/rulings_2026_09_05_rp5_bar_1226.md`) is untouched.
- **DELETES:** nothing observable. Insertion order (cxdm §2.6), `nodes_equal`,
  canonical bytes and iteration order are unchanged; the index is a lookup cache
  and `runtime_representation.md` §2's transparency rule covers it.
- (b) lazy + atomic publication and (c) close on the no-format compare alone stay
  rejected for the reasons recorded above.

Exit: a probe microbench on a 10k int-keyed and a 10k string-keyed map before/after;
`bench/repr` ratchet byte-identical; map fixtures and canonical bytes unchanged.

### Implementation record — 2026-09-05, and one trap worth the ink

Two indexes, not one, and both behind ONE pointer.

**TWO indexes, because the language has two identities and both must be exact.**
`Node.map_get(key)` compares the key IMAGE (`key_image_is`, kind-agnostic);
`[$map:get]` / `[$map:contains]` are kind-STRICT — `[$map:get {1: a, '1': b} '1']`
answers `b`, because `map_native_key_is` compares `(kind, image)`. One index cannot
serve both without guessing. So `MapIndexes` carries `by_image` and `by_kind`
(`<kind>\0<normalized image>`), built in one pass, FIRST position wins in both, so an
index hit names exactly the entry the ordered scan would have found — including the
`{1: a, '1': b}` collision. `cx.map_index_key` is the one place the qualified key is
spelled and `map_native_norm_image` delegates to it, so the probe and the index cannot
drift.

**Built in `mk_map_node`, not `mk_map`** — that is the single funnel every map value
passes through (the carrier constructors, the JSON/XML/binary/lossless readers, and
every `MapNode{ ...m, entries: … }` respin). Building there is what makes a
PARSER-built wide object indexed, which is where wide maps actually come from, and it
makes a stale index impossible: the field is always assigned, never carried over from
the value that was copied.

**THE TRAP — an inline `map[string]int` field is not free when empty.** The first
implementation put both indexes inline on `MapNode` and assigned `map[string]int{}`
below the threshold. `bench/repr` went RED at **22.5× live against a pinned 7.95×** —
≈900 B per map over the audit corpora's 32,000 FOUR-entry records, none of which is
anywhere near the 64-entry threshold. The cost was the two V maps' own allocation, paid
by every map in the tree whether indexed or not. Behind one `&MapIndexes` pointer
(nil below the threshold) a small map pays 8 bytes and allocates nothing; repr-guard is
green at json 7.570 / xml 7.941 / cx 7.580 / cxel 7.600, i.e. the pre-change figures.
A "lookup cache costs nothing when unused" claim has to be MEASURED on the corpus that
has the small values, not reasoned about from the threshold.

**Measured** — flag-matched `-O0` dev binaries, 10k-entry map parsed from JSON, 20k
probes, user seconds. Baseline taken with `map_index_threshold` raised out of range and
the binary rebuilt, so the two runs differ only in the index:

| lane | before | after | ratio |
|---|---|---|---|
| string keys (`k1`…`k10000`) | 5.14 | **0.69** | **7.4×** |
| numeric-image keys (`1`…`10000`) | 4.88 | **0.67** | **7.3×** |
