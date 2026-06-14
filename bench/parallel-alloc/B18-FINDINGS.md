# B18 — allocator per-thread/contention fixes: recovering `[par]` scaling
# under `-gc e` by removing global-lock contention from the alloc fast path

Goal (option (a), chosen 2026-06-14): make cx `[par]` under `-gc e` SCALE by
attacking the *dominant* serializer, which B18 measurement showed is **in-process
allocator lock contention**, NOT GC pacing and NOT memory bandwidth. All work is
V-only / CX-agnostic (fork `third_party/v`); cx is the microscope. Builds crash-free
(residual #4 closed @ fork 871dceda).

## TL;DR
1. **The B13 premise was stale.** B17 (COW closures) already eliminated the gross
   anti-scaling: on the current fork, E par-default ≈ **parity** with serial
   (1470 vs 1570 ms), not "1.72× slower."
2. **The real bottleneck is allocator global-lock contention** (proven, see
   "Decomposition"), specifically the single global `vgc_heap.lock` (new-span carve)
   and the per-class `central[].lock` (full-span return) — both spun on by all 8
   `[par]` workers. GC-STW is the *minority* cost; concurrent mark alone would not
   have fixed this.
3. **Two CX-free V fixes** (both in `vlib/builtin/vgc_d_vgc.c.v`, default-on):
   - **(slab) span-descriptor bump slab** — removes a per-carve `mmap()` syscall from
     the `vgc_heap.lock` hold. Side win: **RSS ~3× lower** (the per-span mmap wasted
     ~16 KB of page granularity on a ~400-byte descriptor).
   - **(drop-return) stop returning full spans to `central.full`** — the partial list
     was never reused (returns only ever land FULL spans on full; sweep relinks only
     fully-empty), so the per-fill return was pure `central[].lock` contention. Dropped
     spans stay in `allspans`, are swept normally, and reclaimed-when-empty via the
     existing `on_central==0` path. Reuse now flows through the `free_spans` pool
     (refilled by GC sweep) + the active span's own `free_index`.
4. **Result (best-of-5, `-prod -gc e`, 12-core M-series, all outputs `80000200000 ×8`):**
   par now scales 3–4× over serial once the GC trigger gives the (now contention-free)
   alloc path headroom — and the slab's 3× RSS cut makes that headroom affordable.

## Decomposition (why it's lock contention, not GC or bandwidth)
1-worker `[par]` = 240 ms; ideal 8-way ≈ 240 ms. Measured 8-way:
- default trigger: 1470 ms (6.1× the ideal).
- GC essentially off (16 GB trigger): 890 ms — still **3.7× the 1-worker time with
  ZERO GC** ⇒ the dominant cost is NOT GC.
- **8 SEPARATE processes** (independent heaps), each the 1-worker load, concurrent:
  ~400 ms total. The hardware runs 8× the work in 400 ms ⇒ NOT memory bandwidth.
  8 workers in ONE process, GC off: 900 ms ⇒ the 2.4× penalty is **in-process shared
  allocator state**.

`sample`-profiling the GC-off 8-worker run pinpointed it exactly: ~98% of the alloc
path is `cthread_yield` (lock spin) split between
`vgc_span_alloc → vgc_heap.lock` (new-span carve) and
`vgc_cache_get_span+340 → central[].lock` (full-span return). The carve storm exists
because Perceus-freed slots strand in `central.full`/dropped spans until a GC sweep,
so threads constantly carve fresh spans under the single global heap lock — whose hold
included a per-span `mmap()`.

## Numbers (cx, fork build `-prod -cc cc -gc e`, best-of-5)
| config                         | par time | RSS    | vs serial (1380 ms) |
|--------------------------------|----------|--------|---------------------|
| baseline (871dceda) par def    | 1490 ms  | 1.76GB | 1.07× (parity)      |
| baseline par 1GB floor         | 1080 ms  | 5.6 GB | 1.45×               |
| **+slab** par 1GB floor        | 580 ms   | 2.0 GB | 2.4×                |
| **+slab+drop-return** par 512  | 890 ms   | 0.9 GB | 1.55×               |
| **+slab+drop-return** par 1GB  | 590 ms   | 2.0 GB | 2.3×                |
| **+slab+drop-return** par 2GB  | 460 ms   | 2.3 GB | 3.0×                |
| **+slab+drop-return** par 4GB  | **360 ms** | 2.3 GB | **3.8×** ✅        |
| serial (slab; trigger-indep.)  | 1380 ms  | 0.6 GB | — (was 1550)        |

RSS plateaus ~2.3 GB even at a 4 GB trigger (the workload's true peak), so a generous
default floor costs no more than the working set needs here. At the 4 GB config the
`sample` profile top is `eval_reduce_directive` (real interpreter work) — **the
allocator lock-spin is gone from the hot path; the bottleneck is now computation.**

HTTP (guide_serve, wrk -t8 -c128, container): base 116.5K → b18 **122.3K req/s**
(+5%; HTTP is transport-bound so the alloc win is modest, but it does not regress).

## What this does NOT fix (the residual gap + next levers)
- **At the default 256 MB trigger, par stays ~1350 ms** (GC-frequency-bound) — the
  alloc win only shows once the trigger gives headroom. Realizing the par win *by
  default* needs a higher default trigger floor (now affordable: 4 GB trigger →
  2.3 GB RSS, vs baseline ~12 GB) and/or per-thread GC pacing. **User decision.**
- The remaining ~2× gap to the 1-worker ideal (170–240 ms × 8-way vs 360 ms) is now
  GC per-collection mark cost + the inherent compute/[par] overhead — the concurrent-
  mark / generational lever (#37), now worth pursuing because the allocator no longer
  wastes the headroom.

## Soundness gate (all GREEN)
- residual #4 white-box selftest (`vgc_residual4_test.v`, B+C teeth): PASS.
- cx V-impl gate `make test-vcx-v08`: **125/125** under `-gc e`.
- Local MP stress: 50/50 `[par]` runs across triggers, 0 corruption.
- **HTTP churn repro** (container, `wrk -t8 -c256 -d10s -H "Connection: close"` ×15
  rounds vs guide_serve.cx — the residual-#4 reproducer): **SURVIVED 15 rounds,
  niltrace=0.** drop-return is sound under MP churn.

## Why drop-return is sound (vs residual #4)
Residual #4 (Bug B) was a span reclaimed while STILL mcache-resident (held by a
suspended owner's local). A *dropped* span is no longer in any mcache
(`alloc[span_class]` is overwritten) nor held by a mutator local, so same-cycle
reclaim-when-empty is correct. While still referenced during the drop it is protected
by `vgc_protect_cached_spans`' sweep_gen stamp. Cross-thread frees still locate it via
`vgc_find_span` (it stays in `allspans`) and clear bits atomically.

## State
- Fork `third_party/v` @ 871dceda + UNCOMMITTED change: ONE file
  `vlib/builtin/vgc_d_vgc.c.v` (+46/-8): the slab (struct fields `span_meta_cur/end`,
  helper `vgc_alloc_span_meta`, call-site swap) + drop-return (in `vgc_cache_get_span`).
  `vgc_gc_d_vgc.c.v` is clean (the sweep-relink probe was tried, found ineffective —
  it only fires at GC, useless at high trigger — and reverted; no band-aid).
- NOT committed/pushed (push is user-gated). v0.9.0 tag unaffected.
- A tried-and-reverted dead end: sweep relinks `central.full→partial` on free slots —
  ineffective because at high trigger GC (hence sweep) rarely runs, and reuse needs to
  happen on the eager-free path, which drop-return + free_spans achieves instead.
