# vgc tiny-allocator free bug — map corruption under -gc vgc / -gc e (2026-06-12)

V-runtime only, CX-agnostic. CX merely surfaced it; the repro and fix are CX-free.

## Symptom
`vlib/builtin/map_test.v` fails under `-gc vgc` and `-gc e`, passes under `-gc none` / `-gc boehm`:
- `test_delete_in_for_in` (:318): a string key reads back as garbage (` `, len 1) instead of e.g. "501".
- `test_delete_and_set_in_for_in` (:357): `m.len` drifts (1001 vs 1000).

Both are `map[string]string` mutated **while iterating** under GC pressure. (The earlier breadcrumb's "map[int]int" was stale.)

## Root cause — it is the ALLOCATOR, not the collector
The breadcrumb framed this as a collector "handles map buffers across grow/realloc"
bug. That was wrong. Bisection on the live allocator (clone `v2`, all toggles
reverted afterward):

- Disabling **sweep** → still corrupts.
- `-d vgc_never_collect` (collection never runs at all) → still corrupts ⇒ NOT the
  collector / mark / sweep.
- Disabling **`vgc_free`** → passes ⇒ it is eager slot reuse on explicit free.

A free/alloc tracer showed `vgc_free` called on **unaligned interior pointers**
(`0x..b4`, `..b8`, `..bc`, 4 bytes apart) all resolving to **one 16-byte slot**,
which was then reused.

The **tiny allocator** (`vgc_malloc_noscan_opts`, Go-style) packs several
independently-allocated sub-`vgc_tiny_size` noscan objects — e.g. the short map-key
char buffers "498","499","500","501" — into a single span slot. But `vgc_free(ptr)`
computes `obj_idx = (ptr - base) / elem_size` and clears the **whole slot's** alloc
bit. When a map's `delete` → `free_fn` (`map_free_string`) frees ONE key's char
buffer, the live sibling keys packed in the same tiny block are marked free and
reused → their bytes overwritten → map corruption.

(Tiny blocks are elem_size **16 or 24**: sizes 9–15 round to class 3; the size-class
lookup leaves class-1/8B unused, so the minimum is 16. So the bug is not limited to
16-byte slots.)

`none`/`boehm` pass because libc `free` is precise and boehm `free` is a conservative
no-op — neither reuses a still-referenced sibling.

## Fix (vgc-tiny-free-fix.patch, 5 hunks in vlib/builtin/vgc_d_vgc.c.v)
Per-span `is_tiny` flag on `VGC_Span`:
- set `true` when the tiny allocator carves a packed block,
- reset `false` in `vgc_span_init` (recycle) and `vgc_alloc_large`,
- `vgc_free` returns early (no eager reclaim) for `is_tiny` spans.

Like Go, tiny blocks are reclaimed **only by the tracing collector**, and only once
NONE of the packed sub-objects is reachable (the slot stays marked while any sibling
is live). Skipping the eager-free hint for tiny slots is always sound — free is only
a hint; the collector is the backstop.

## Validation
- `map_test` 318/357 PASS under `-gc vgc` AND `-gc e`; `map_test` fully GREEN under vgc.
- array_test / string_test / map_delete_reclaim_test / map_of_floats_test green vgc+e.
- g_churn 100 1 30 / 200 1 50 / 100 2 40 PASS under `-gc e`.
- Corpora none==e byte-identical (perceus / deep_free_hazard / uref / p2_reuse).
- **Gate**: `map_churn_corpus.v` (this dir) — closes the gap that let the bug through
  (g_churn only ever allocated linked-list Nodes, never a hashmap). Has teeth: under
  `-gc vgc`/`-gc e` it reports `CORRUPT failures=25` (exit 1) WITHOUT the fix, `OK`
  WITH it. Byte-identical + exit 0 across none/boehm/vgc/e with the fix.

## SEPARATE 2nd bug found (NOT this fix, NOT the collector) — Perceus drop, -gc e only
`test_large_map` (:184) fails **only** under `-gc e` (passes none/boehm/vgc). It is a
**Perceus front-line drop-placement** bug, pre-existing (A/B-confirmed it failed with
the old free behavior too) and independent of the tiny-free fix. Generated C for
`key := i.str(); m[key] = v`:

```c
string key = builtin__int_literal_str(i);
builtin__string_free(&key);                       // freed BEFORE its use
builtin__map_set(&nums, &(string[]){key}, &(int[]){ i });
```

`key` is freed, then a shallow struct-copy sharing `key.str` is passed to `map_set`,
which clones from freed/reused memory → stored keys corrupt, map collapses (len=2
after 30000 inserts; lookups miss). Fails with BOTH free and collection disabled ⇒
pure codegen: Perceus's last-use analysis does not treat the address-of-temp-array
map-set argument as a use of `key` (class = the banked "interproc escape /
buffer-fresh" sharpen items). Non-tiny keys fail too, so it is not the tiny bug.
Distinct subsystem (perceus.v / autofree.v / fn.v drop emission) — deferred to a
focused follow-up (soundness first).

## State
Fix is in the clone working tree (canonical, alongside the E tree) and folded into
`E-canonical.patch`; standalone CX-free delta is `vgc-tiny-free-fix.patch`. NOT yet
forward-ported to the fork / committed there / cx-re-gated (the integration step).
