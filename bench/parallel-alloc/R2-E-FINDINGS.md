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
