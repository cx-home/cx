# R2 (alloc-heavy MP) under `-gc e` — E does NOT yet beat Boehm; two fixable causes

Forward-phase measurement (user-chosen): does the decoupled E mode (`-gc e` =
Perceus front line + vgc backstop) deliver R2 — monotonic-up alloc-heavy MP
scaling — the property Boehm anti-scales on (cx-private #14), and the core
justification for E? **Answer (2026-06-12): NO, not yet.** E currently anti-scales
like bare vgc; Boehm wins. The causes are implementation gaps, not fundamental.

## Measurements (12-core M-series, `-prod`, best of 2, 2M allocs/thread, Mops/s)

bench_mp.v `alloc` (Obj has a nested heap `pad []u8`):
| threads | boehm | vgc | **e** | 
|---|---|---|---|
| 1 | 32.8 | 20.4 | 26.0 |
| 2 | 33.6 | 11.7 | 9.7 |
| 4 | 30.3 | 6.7 | 6.0 |
| 8 | 27.1 | 4.7 | 4.0 |

bench_scalar.v (Obj is scalar-only — Perceus drop fully reclaims, no nested-heap leak):
| threads | boehm | **e** | vgc |
|---|---|---|---|
| 1 | 66.7 | 60.6 | 44.4 |
| 2 | 81.6 | 17.4 | 24.8 |
| 4 | 72.1 | 11.3 | 13.7 |
| 8 | 64.0 | 6.9 | 8.9 |

Boehm stays flat-to-up (per-thread TLA + marker-pin); E falls off a cliff at T1→T2.

## Cause analysis (Perceus IS working — verified in generated C)
Under `-gc e`, `alloc_worker`'s loop emits `o = HEAP_vgc(...); sink += o->a;
builtin___v_free(o);` — Perceus DOES drop `o` every iteration (→ `vgc_free`). So
the front line fires. Yet it anti-scales, for two reasons:

1. **Global `heap_live` atomic = shared-cacheline contention (dominant).** The vgc
   hot path does `vgc_atomic_add_u64(&vgc_heap.heap_live, sz)` on EVERY allocation
   (vgc_d_vgc.c.v:941/1089/1110) and `vgc_atomic_sub_u64(&vgc_heap.heap_live, sz)`
   on EVERY free (1230), against ONE global u64. Every thread's every alloc+free
   ping-pongs that cacheline → the T1→T2 cliff (60→17 in the scalar case, where GC
   never even fires because Perceus keeps heap_live near zero). This is pure
   allocator-accounting contention, NOT STW.

2. **Perceus nested-heap deep-free gap (compounds #1 in bench_mp).** The dropped
   `&Obj` is freed but its `pad []u8` (a separate vgc allocation) is NOT deep-freed
   → pad arrays leak every iteration → heap_live climbs → GC triggers → STW adds on
   top of the contention. (This is the banked A5 follow-on "deep-free of nested heap
   fields in a dropped `&Foo`".)

## Verdict / implication
E's R2 win is **achievable but unbuilt**. Neither cause is architectural:
- **Fix #1 — per-thread heap accounting.** Make `heap_live` a per-mcache counter
  aggregated lazily (à la Go's per-P heap accounting), so the alloc/free fast path
  touches no global atomic. This is the high-leverage fix and turns the per-thread
  mcache into a genuinely contention-free fast path. Real runtime work.
- **Fix #2 — Perceus deep-free.** Drop nested heap fields of a dropped `&Foo`
  (A5 coverage). Removes the GC pressure in nested-object workloads.

**Sequencing consequence:** the A7 fork forward-port would be PREMATURE before E
actually beats Boehm on the MP workload that motivates it. Recommend allocator
hardening (#1, then #2) on the clone first, re-measure R2, THEN forward-port a
proven-faster E. (Matches decision A5 = measurement-driven: this is the measurement,
and it points at per-thread accounting as the next work.)

Benches: bench_mp.v (committed), bench_scalar.v (committed). Re-run:
`./v2 -gc {boehm,e,vgc} -prod [-enable-globals] -o bm bench_mp.v && ./bm alloc <T> 2000000`.

---

## ✅ FIX #1 DONE 2026-06-12 — per-thread heap accounting → R2 MET & EXCEEDED
Made `heap_live`/`total_alloc` per-mcache (Go per-P style): the alloc/free fast
path bumps THREAD-PRIVATE `live_delta`/`alloc_delta` (in VGC_Cache), flushing into
the global atomics only every ~1 MB (`vgc_acct_flush`). Balanced alloc/free keeps
`live_delta` near zero, so the hot path never touches a shared cacheline. Helpers
`vgc_acct_alloc`/`vgc_acct_free` (vgc_d_vgc.c.v); the collector flushes+zeros all
deltas under STW at the `heap_live = marked` rebaseline; slot (re)registration and
thread-exit also reset/flush. In vgc-collector-linux.patch.

**Result — scalar-only alloc (no nested heap), Mops/s best-of-2:**
| threads | boehm | e (before) | **e (after)** |
|---|---|---|---|
| 1 | 76.9 | 60.6 | 76.9 |
| 2 | 60.6 | 17.4 | **173.9** |
| 4 | 61.5 | 11.3 | **333.3** |
| 8 | 64.3 | 6.9 | **516.1** |

E now scales near-LINEAR (6.7× T1→T8) and is **8× Boehm at T8**. The contention
WAS the whole anti-scale. R2 met and exceeded.

**bench_mp alloc (nested `pad` heap field — cause #2 still present):**
| threads | boehm | **e (after)** |
|---|---|---|
| 1 | 39.2 | 30.8 |
| 2 | 35.1 | 51.3 |
| 4 | 32.9 | 76.2 |
| 8 | 29.4 | 72.4 |
E scales up and beats Boehm 2.5× at T8 even with the deep-free gap; the T8 plateau
(76→72) is the residual pad-leak GC pressure → fix #2 (Perceus deep-free) closes it.

**Correctness preserved (the accounting feeds the GC trigger):** `-gc e` churn
g_churn 100 1 30 = 12/12; `-gc vgc` baseline 8/8 (unaffected); corpus G-DIFF
none==e 4/4.

**Status:** R2 delivered. Cause #2 (deep-free of nested heap fields, A5 coverage)
is the remaining nested-object optimization — E already beats Boehm with it open.

---

## ✅ FIX #2 DONE 2026-06-12 — sound Perceus deep-free of nested heap fields
A dropped `&Foo` now cascade-frees its nested heap fields (via the generated
`<Foo>_free`) before reclaiming the struct — but ONLY when proven sound. New
deep-drop analysis (perceus.v, in the exhaustive `pcs_scan_share` pass so it cannot
miss a use): a var is deep-droppable iff it is born from a fresh `&Foo{...}` whose
every heap field is freshly allocated (`pcs_struct_init_all_fields_fresh`), has no
conflicting non-fresh assignment, AND no heap field is ever selected through it
(`deep_field_exposed` — a `x := p.buf` read-alias or `p.buf = ext` reassign
disqualifies, since deep-freeing an aliased/borrowed field would UAF the real
owner). Emitted as `<Foo>_free(p); builtin___v_free(p)` only under `-gc e`; threaded
via `g.perceus_deep_drop`. In vgc-collector-linux.patch + the perceus.v mirror.

**bench_mp alloc (nested `pad`) AFTER deep-free, Mops/s best-of-2:**
| threads | boehm | e (before #2) | **e (after #2)** |
|---|---|---|---|
| 1 | 39.2 | 30.8 | 35.7 |
| 2 | 37.4 | 51.3 | 70.2 |
| 4 | 30.8 | 76.2 | 135.6 |
| 8 | 29.3 | 72.4 | **266.7** |
Deep-free closes the pad-leak GC pressure: the T8 plateau (72) becomes near-LINEAR
(266.7, 7.5×) — **E is now 9× Boehm at T8** on the nested-object workload too.

**Soundness proof (deep_free_hazard_corpus.v, loop form so drops FIRE under GC):**
none == e, rc=0 at 2M iters/case, AND the analysis is precise — `owned_loop`
deep-frees (1 `Box_free`), `aliased_loop` + `borrowed_loop` correctly do NOT (0) —
so no UAF on aliased/borrowed fields. Full gates: -gc e churn 12/12; corpus G-DIFF
none==e 5/5 (incl the deep-free hazards); flag-off byte-identical; `-autofree -d
perceus` intact; -gc vgc baseline 6/6.

**Both R2 causes now closed. E scales near-linearly and beats Boehm ~9× at T8 on
both scalar and nested-object alloc-heavy MP.** Remaining deep-free gap (not a
safety issue): nested `&Bar` pointer fields free Bar's fields but not the Bar
allocation (V's auto free-methods don't recurse pointer ownership) — a leak-tightness
follow-on, not unsound.
