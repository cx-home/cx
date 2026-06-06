# DRAFT — `-gc vgc` deadlocks / OOMs with multiple allocating threads

For the V team (post after the Discord check). A focused repro + root-cause read
of vgc's source. This is arguably the higher-leverage report than the Boehm
alloc-lock one: vgc is the *strategic* path (a pure-V, Go-style, per-thread-cache,
precise scan/noscan collector — the right architecture to scale), and this bug is
the thing blocking it from being a usable parallel GC.

## Summary

`-gc vgc` works single-threaded but, with two or more concurrently allocating
threads under GC pressure, a collection cycle's stop-the-world never completes.
Observed nondeterministically as **either**:
- `V panic: memory allocation failure`, or
- a **permanent hang** — the collecting thread spins at ~100–200% CPU
  indefinitely (we left one spinning for 37 minutes).

Both are the same root cause (below). The nondeterminism is the tell: it's a
concurrency race in the STW handshake.

## Environment

- macOS 14 / Apple M-series (arm64), `-gc vgc -prod`.
- V at the commit vendored in our tree; vgc files
  `vlib/builtin/vgc_{d_vgc,gc_d_vgc}.c.v`.

## Reproducer

`vgc_repro.v` (in this directory):

```
v -gc vgc -prod -o vgc_repro vgc_repro.v
./vgc_repro 1     # ok: 1 threads x 20000000 allocs
./vgc_repro 4     # panics OR hangs (collector spins ~200% CPU)
```

Each thread churns transient objects (a scanned `&Blob` + a noscan `[]u8` buffer
per iteration; the previous one is dropped so the collector must reclaim). Single
allocation per iteration / lower volume often survives; the crash needs enough GC
cycles + concurrent allocators, consistent with a race in the GC cycle.

## Root cause (from reading vgc source)

The stop-the-world handshake counts threads that can never reach a safepoint:

1. **STW target counts every thread that ever registered.**
   `vgc_gc_d_vgc.c.v`: `vgc_heap.gc_target_stops = ncaches - 1`. The collector
   then busy-waits: `for gc_stopped_count < gc_target_stops { fence }`.

2. **The only safepoint is the allocation path.** `vgc_d_vgc.c.v` `vgc_maybe_gc()`
   checks `gc_stop_flag` and calls `vgc_safepoint()` only from inside `malloc`.

3. **There is no thread deregistration.** `vgc_register_thread()` allocates a
   cache slot and bumps `ncaches`, but nothing releases it on thread exit. So a
   `spawn`ed worker that finishes and returns still counts toward
   `gc_target_stops` — and being dead, it will never hit the alloc-path safepoint
   to increment `gc_stopped_count`. The collector therefore waits **forever** →
   the ~200% CPU spin (collector + one stuck mutator).

4. **Same gap for live-but-not-allocating threads.** Any registered thread that
   is blocked in a syscall or running a long non-allocating stretch also never
   reaches the alloc-path safepoint, so STW can't complete there either.

5. **The OOM variant** is the other face of the same stall: while the collector
   is stuck (or before it can keep up), allocation keeps growing the heap; at the
   arena cap (`vgc_max_arenas` 64 × 64 MB = 4 GB) `vgc_os_alloc` returns null and
   V's `_memory_panic` fires — "memory allocation failure".

(Go avoids all of this with compiler-inserted safepoints + signal-based async
preemption, and a precise notion of "running mutators" tied to the scheduler.)

## Suggested direction

- **Thread lifecycle:** deregister on thread exit; compute `gc_target_stops` from
  *currently-live* mutators, not `ncaches`. (Fixes the deadlock in this repro.)
- **Safepoint coverage:** mutators must reach a safepoint promptly regardless of
  whether they're allocating — e.g. signal-based preemption of stopped threads,
  or compiler-inserted safepoint polls at back-edges/calls (the general fix).
- **A concurrency correctness battery** (thread churn + GC pressure, output
  byte-diffed against `-gc none`) — this class of bug needs it as a gate.

## Why it matters

vgc is the pure-V, Go-architecture collector that could give V world-class
multi-core allocation scaling (per-thread mcache → lock-free fast path; precise
scan/noscan → no conservative-scan tax). Getting STW correct under real thread
lifecycles is the gate between "experimental, single-thread-only" and "usable
default." Happy to help test — we have a parallel-interpreter workload that
hammers exactly this path.
