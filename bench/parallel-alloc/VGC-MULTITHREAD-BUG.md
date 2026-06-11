# DRAFT — `-gc vgc` deadlocks / OOMs with multiple allocating threads

> **CONFIRMED LIVE on upstream `vlang/v` master `a83aabb` (2026-06-11).** The
> STW handshake is unchanged: `vgc_gc_d_vgc.c.v:28` still
> `gc_target_stops = ncaches - 1`, lines 37–38 still `if wait_iters > 1000000 {
> break }` ("proceed with what we have"), and `vgc_register_thread`
> (`vgc_d_vgc.c.v`) still has **no deregistration**. The naive single-pattern
> repro (`vgc_repro.v`) can *pass* because the timeout-break silently proceeds
> instead of hanging. The adversarial battery `g_churn.v` (long-lived
> checksummed anchor + churn + waves of short-lived threads that grow `ncaches`
> with dead caches + a blocked thread) reproduces hard: **`-gc boehm` and
> `-gc none` oracles PASS with 0 corruptions; `-gc vgc` SEGFAULTs (signal 11 in
> a churn thread)** at `g_churn 20000 6 40`. Build all three with `-prod` on the
> upstream-built `./v`.

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

---

## Investigation update (2026-06-11, upstream master a83aabb)

We built the upstream `./v` and ran the `g_churn.v` battery (long-lived
checksummed anchor + churn + waves of short-lived threads + a blocked thread).
**Oracles `-gc boehm` and `-gc none` PASS; `-gc vgc` fails — a use-after-free**,
not (only) a hang. Under lldb the crash is deterministic:

```
EXC_BAD_ACCESS (address=0x8)  main__churn(...) at g_churn.v:104
  -> if last.id == 0xdeadbeef {     // `last` points to a SWEPT live Node
```

i.e. the collector frees an object that is still referenced by a live mutator
local. It reproduces under **thread create/exit churn** (the `waves`), not under
steady allocation (config `N N 0` passes). Bisected trigger = many short-lived
allocating threads concurrent with GC, **independent of the blocked thread**.

### We implemented and tested five fixes (patch: `vgc-stw-partial-fixes.patch`)

1. **Thread deregistration** via a pthread-key destructor + **cache-slot reuse**
   (fixes `caches[]` exhaustion / `caches[-1]` OOB once >64 threads have ever
   registered, and stops counting dead threads in STW).
2. **STW targets live mutators** (`live_threads`), recomputed each wait
   iteration, instead of `ncaches - 1`.
3. **Abort-not-corrupt**: on incomplete stop, abort the cycle (no sweep) instead
   of "proceed with what we have" — removes the silent-corruption-on-timeout.
4. **Full stop-the-world mark+sweep** (resume only after sweep) — removes the
   unsound concurrent-mark window (white objects allocated during mark with no
   alloc-black + no stack-write barrier).
5. **Register spilling at every root scan** (mutator safepoint AND the collector
   itself, via `setjmp` into a frame kept alive across the scan) — so a root
   that lives only in a callee-saved register (a hot `last`) is not missed; plus
   a **park-in-register barrier** so a thread cannot allocate white during STW.

**Result: the use-after-free persists** (same line-104 crash) under thread
churn, in both `-prod` and debug builds — including the debug build where `last`
provably lives on the stack. So beyond the five issues above, vgc's root
scanning still drops a live object under concurrent thread lifecycle. Remaining
suspects we did not chase to ground: parallel-mark helper threads registering
*during* the collection; span/cache-slot reuse races; conservative-scan span
lookup under concurrent arena growth.

### Takeaway

Making vgc sound under real multi-threaded lifecycles is **not a small fix** — it
needs OS-level suspend-the-world (mach/signals, à la Boehm) so blocked and
non-cooperating threads are stopped and their full register+stack state scanned,
plus a thread-registration barrier and a correct (or absent) concurrent-mark
path. That is effectively the multi-year STW engineering Go already did. The
five fixes here are necessary-but-insufficient groundwork. We're filing this so
the team can decide whether to invest in finishing vgc's STW or steer multi-core
scaling another way; happy to share the battery and patch.

Repro: `g_churn.v` (oracle + subject), build all three with `-prod` on the
upstream `./v`; `./g_churn_vgc 100 1 40` segfaults within seconds.
