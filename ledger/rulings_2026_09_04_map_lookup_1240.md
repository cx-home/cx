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
