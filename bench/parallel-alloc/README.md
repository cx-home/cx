# Parallel-allocation scaling — findings + reproducible harness

**Question (1.0-blocking):** can cx run allocation-heavy work in parallel across
multiple processors? A tree-walking interpreter allocates a node per eval step,
so the allocator's multi-thread behaviour bounds *all* parallel cx workloads.

**Answer:** not on the stock Boehm GC — its single global allocation mutex
serializes and *degrades* under threads. The hardware is fine; the substrate is
the wall. A per-thread bump arena over Boehm fixes it (validated below) without
forking V or switching languages.

Run `./run.sh` (macOS arm64; uses the patched libgc in `third_party/v`).

## Measured (12-core M-series, markers=1, 64-byte objects, 20M allocs/thread)

| allocator | 1T | 2T | 4T | 8T | per-thread 1T→8T |
|---|--:|--:|--:|--:|---|
| **Boehm `GC_MALLOC`** (free-each, 0 collections) | 77.5 | 34.8 | 12.2 | 15.8 M/s | 77 → 2 (**39× worse**) |
| **Boehm** (drop, 4 GB heap, 0 collections) | 67.9 | 41.0 | 24.7 | 27.9 M/s | anti-scales |
| **System `malloc`/`free`** (control) | 50.8 | 81.4 | 157.7 | 252.1 M/s | scales ~5× aggregate |
| **Per-thread arena over Boehm** (the fix) | 199.6 | 379.6 | 281.9 | 281.9 M/s | scales; **18× Boehm @ 8T** |

## What this isolates

- **It is the Boehm allocation lock**, not GC collection: the free-each and
  4 GB-heap rows do **zero** collections (`gc_no=1`) and still collapse.
- **It is not the hardware/OS**: the system allocator scales 5× on the same box.
- **It is not fixable by Boehm config**: a rebuilt bdwgc with thread-local-alloc
  on, parallel-mark off, and `--enable-large-config` collapses identically. The
  single `GC_allocate_ml` mutex is fundamental to Boehm's design; macOS's
  `psynch` mutex makes the contention catastrophic. (cx already caps Boehm
  parallel-mark to one marker on macOS — see `cmain.v` in the fork — which is a
  separate, real fix for stop-the-world coordination, not this alloc-lock issue.)
- **Boehm's thread-local-alloc is active but insufficient**: it batches the lock
  to ~1 acquisition per heap block (~64 objects of 64 B), but at interpreter
  allocation rates across many cores even that contends fatally.

## The fix: per-thread bump arena

`arena.c` grabs one large block from Boehm per ~65k allocations and bump-allocates
within it. The block is ordinary GC memory, so Boehm still traces it (pointers
stay valid; whole blocks collect when unreachable) — **no manual free, no escape
analysis, no fork**. It hits the global lock ~1000× less often and therefore
scales. cx's real allocation rate sits far inside the scaling region, so routing
transient `cx.Node` allocation through such an arena (reset at request / eval-scope
boundaries) removes allocation as a parallel-scaling constraint.

The arena's residual plateau (~282 M/s at 4–8T) is the block-refill still touching
Boehm + tracing the big blocks; refilling from raw `mmap`/`malloc` would push it
higher, but 282 M/s already dwarfs any cx workload's allocation demand.

## At the cx level (vcx/tests/runners/parallel_eval_bench.v)

The substrate finding manifests directly in cx evaluation. N threads each run an
allocation-heavy, I/O-free program (`range→map→sum`, 20k) via `code.eval_code`
(fresh env per call — no shared cx state; the GC is the only shared resource):

| threads | aggregate evals/s | per-thread |
|--:|--:|--:|
| 1 | 52 | 52 |
| 2 | **27** | 14 |
| 4 | **18** | 4 |
| 8 | **15** | 2 |

Parallel cx eval doesn't merely fail to scale — it *degrades* (2 threads is half
of 1; per-thread collapses 26×). This is the 1.0 blocker, quantified.

## Negative result: a transparent bump-arena does NOT work

Routing V's scanned `malloc` through a per-thread bump arena (gated `-d cx_arena`,
now reverted) was prototyped and **ruled out**. Decisive isolation, 1 thread,
arena build: **GC disabled → 79 evals/s** (faster than baseline); **GC enabled →
2 evals/s (40× slower)**. The transparent arena trades the alloc-lock contention
for a catastrophic **conservative-scan tax**: Boehm is a *conservative* collector,
so it scans every word of the large pointer-bearing arena blocks on each GC and
false-retains (integer fields look like pointers), ballooning the heap. A block is
also pinned until its *last* object dies, so retained eval objects keep big blocks
scanned. The microbench arena (`arena.c`) scaled only because it retained nothing.

**Conclusion.** Boehm is a conservative + stop-the-world + single-global-lock
collector — a trifecta hostile to parallel allocation-heavy interpreters. Fixing
the lock alone (arena) hits the conservative-scan wall. A viable in-process fix
must keep transient memory **out of the scanned heap and bulk-freed at scope
boundaries** (scope-aware regions reset per request/eval), or replace the
collector. The robust near-term parallelism story is **multiple processes**
(separate heaps → separate locks → linear scaling), which is how the server leg
can scale today without touching the allocator.

## Validated fix mechanism: scope-aware regions (`region.c`)

The scope-aware region — the thing the transparent arena was NOT — works. Each
thread owns ONE raw (non-GC) block, registered as a GC root **once** via
`GC_add_roots` (the correct, supported use of roots: pointers from region objects
to GC objects stay traced), reused across scopes (scope end = reset offset to 0;
a real impl deep-copies the small result to the GC heap first). Transient
bump-allocations never touch the GC heap, so there is no per-alloc global lock and
no conservative-scan tax (the region stays small + is reset):

| threads | aggregate | per-thread | shared GC obj survived 50 forced GCs |
|--:|--:|--:|:--:|
| 1 | 962 M/s | 962 | yes |
| 2 | 820 | 410 | yes |
| 4 | 1010 | 252 | yes |
| 8 | **1285 M/s** | 160 | yes |

Aggregate **scales up** (≈80× Boehm's 8-thread throughput) and stays GC-correct.
The remaining work is the cx-eval *integration*: route transient `cx.Node`
allocation into a thread-local current region (set at `[?worker]`/`[?async]`/
request scope entry), deep-copy the result out to the GC heap, reset at scope
exit — with escape-safety the careful part. This is the v0.8.0 in-process
parallelism fix; the substrate mechanism above de-risks it.

## Files

- `cbench.c` — Boehm `GC_MALLOC` scaling (`./cbench THREADS PER FREE`).
- `malloc_ctl.c` — system-allocator control (built with `-fno-builtin-*` so the
  alloc/free pair is not elided).
- `arena.c` — per-thread bump arena over Boehm (the validated fix shape).
