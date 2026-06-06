# DRAFT — upstream issue for vlang/v (review before posting)

Target: https://github.com/vlang/v/issues  · Labels: GC, performance, concurrency

---

**Title:** `-gc boehm`: allocation throughput degrades with thread count (bundled libgc serializes on a global alloc lock) — repro + data

**Body:**

### Summary

With `-gc boehm` (the default), multi-threaded **allocation throughput gets
*worse* as you add threads**, because the bundled Boehm GC funnels every
allocation's free-list refill through a single global mutex. On an allocation-heavy
multithreaded V program (web server, parallel data processing — anything that
allocates per work item across `spawn`ed threads), this caps the whole program at
roughly one core's worth of allocation and adds heavy lock/`futex` traffic.

This is reproducible in **pure C against V's own bundled libgc** (no V code
involved), so it should be straightforward for the GC layer to act on.

### Measurements (12-core Apple M-series, `-gc boehm` bundled libgc, 64-byte objects)

Allocate-and-free in a tight loop, N threads, 20M allocs/thread:

| allocator | 1 thread | 2 | 4 | 8 |
|---|--:|--:|--:|--:|
| **Boehm `GC_MALLOC`** (0 collections) | 77.5 | 34.8 | 12.2 | **15.8 M/s** |
| system `malloc`/`free` (control) | 50.8 | 81.4 | 157.7 | **252.1 M/s** |

The system allocator **scales ~5×** on the same hardware; Boehm **anti-scales**
(aggregate 77→16, per-thread 77→2). It is isolated to allocation, not collection:
the rows above do **zero** collections (verified `GC_get_gc_no()==1` via free-each
and a 4 GB initial heap), and the collapse is identical.

### Root cause

Boehm uses one global allocator mutex; thread-local allocation only *batches* it
(≈1 acquisition per heap block), and at interpreter/server allocation rates across
many cores even that contends fatally. Boehm's own docs note this
(<https://www.hboehm.info/gc/scale.html>: *"a single lock is used for all
allocation-related activity … this inherently limits performance of multi-threaded
applications on multiprocessors"*).

Two aggravators we found on macOS specifically:
1. **The bundled amalgamation is configured `--enable-thread-local-alloc=no`**
   (`thirdparty/libgc/amalgamation.txt`), so thread-local allocation — the one
   mitigation — is compiled OUT on the source-compile path. (The macOS prebuilt
   `tcc/lib/libgc.dylib` has it on by default, and *still* anti-scales as above.)
2. **Parallel-mark starves application threads on macOS.** libgc spawns one mark
   helper per core; on macOS each stop-the-world collection then wakes N-1 helpers
   that contend via `mach thread_suspend`/`resume`, stalling the `spawn`ed worker
   threads. Capping to a single marker (`GC_set_markers_count(1)` before
   `GC_INIT()`) gave us ~2.6× on a real server workload. (Happy to share a patch.)

### Impact

Any V program that allocates inside `spawn`ed threads is bounded to ~1 core of
allocation throughput and pays escalating lock traffic. We hit this building a
multi-threaded HTTP server and a parallel interpreter; a tree-walking workload
*degraded* 52→27→18→15 evals/s going 1→2→4→8 threads.

### Questions for the team

1. Is multi-core GC allocation scaling tracked anywhere / on the roadmap?
2. Would V consider shipping the bundled libgc with `--enable-thread-local-alloc=yes`
   (and, on macOS, defaulting markers to 1)? Even with TLA on we see the ceiling,
   so a longer-term direction (per-thread arenas, a scalable allocator under the
   GC, or `autofree` maturation) would also be valuable to know about.
3. Is `autofree` the intended answer for allocation-heavy multithreaded code, and
   is it considered production-ready for that?

### Repro

Minimal C benchmarks (Boehm vs system malloc vs a per-thread arena), buildable
against the bundled libgc, available on request — can attach `cbench.c` /
`malloc_ctl.c` / a `run.sh`. Output above is from those.

---

*(Drafted from cx's parallel-scaling investigation; the full harness lives in
`bench/parallel-alloc/`. Trim the macOS-specific aggravators if filing as a
general issue; they may warrant a separate macOS-tagged report.)*
