# Architecture E: a Perceus front-line + precise stop-the-world tracing backstop for V's C backend

> Draft PR description for vlang/v. Branch: `cx-home/v-cx-patches` (fork `cx-home/v`),
> based on upstream `a83aabb10f`. All changes are provider-neutral V-runtime / codegen
> work; a downstream language (CX, a tree-walking interpreter) was the workload that
> surfaced the bugs and motivated the optimizations, but nothing here is specific to it.

## Summary (TL;DR)

This adds a new opt-in memory-management mode for the C backend, **`-gc e`**, that pairs
a **Perceus-style reference-counting front line** (compiler-emitted, in-place reuse) with
a **precise, from-scratch stop-the-world tracing collector** (`vgc`) as the backstop —
plus the bug fixes and allocator optimizations that made the combination sound and fast
under heavy multi-threaded allocation. The front line reclaims the common, uniquely-owned
case with zero tracing; the backstop reclaims arbitrary aliased/cyclic graphs that RC
cannot. `vgc` alone is also usable (`-gc vgc`).

**Why**: Boehm (V's default conservative GC) anti-scales on alloc-heavy multicore
workloads (its parallel marker and alloc lock serialize mutators) and over-retains
(conservative). E targets *both* single-thread throughput (reuse-in-place avoids
allocation) and multicore scaling (per-thread allocation + accounting, no shared
alloc-path lock in the steady state).

**Status / honesty**: developed and gated against one large real consumer + a battery of
provider-neutral micro-benchmarks (included). The performance numbers below are
**measured on those workloads and should be independently verified** before any claim is
relied on. STW is the default collection strategy; concurrent mark is behind a separate
`-d vgc_concurrent` and is *not* proposed for default. The verification tooling
(mark-closure verifier, root-finder) is compiled out unless `-d vgc_verify`.

---

## Architecture & rationale

V today offers Boehm (conservative, default), `-autofree` (compiler-managed scope frees,
single-ownership assumption), and `-gc none`. None gives both *low allocation* and
*linear multicore scaling* for an allocation-heavy program with aliased/graph-shaped data.

**Architecture E = front line + backstop, decoupled from `-autofree`:**

1. **Perceus front line** (`vlib/v/gen/c/perceus.v`, new). A compile-time ownership/share
   analysis emits in-place **reuse** and **drop** for values it can prove uniquely owned,
   reclaiming the common case without touching the collector. Crucially it is **decoupled
   from `-autofree`**: `-autofree` restructures codegen assuming sole ownership and is
   incompatible with a backing collector (corrupts under *any* GC — demonstrated). E runs
   the drop analysis off its own `perceus` define, so Perceus drops are the sole frees and
   the analysis stays sound (it pins assignment-aliases, call-result aliases, and any
   value whose heap field is exposed → those fall through to the backstop).

2. **Precise STW tracing backstop** (`vlib/builtin/vgc_*.c.v`, new). A from-scratch
   mark/sweep collector with a **Go-`mcache`-style segregated allocator** (per-thread span
   caches, per-size-class central lists, arena-backed spans). It reclaims what RC can't
   (cycles, aliased graphs) and runs *rarely* because the front line absorbs most frees.
   Precise (type-driven) marking where sound; conservative stack/register scanning for
   roots. Mutators are stopped via OS-level suspend (mach / signal).

3. **The hybrid is the point.** RC alone leaks cycles; tracing alone pays full mark cost
   on every cycle. Perceus handles the dominant uniquely-owned case in-place; the tracing
   backstop is the correctness net for the rest. This mirrors Koka/Lean's Perceus + a
   collector, adapted to V (which lacks a uniform per-object header, so the backstop owns
   arbitrary-graph reclamation rather than a global RC header scheme).

**Isolation-for-scaling doctrine**: linear multicore scaling comes from *per-thread
isolation of the allocation path* (per-thread span caches + per-thread heap accounting),
not from a faster shared collector. The collector is the rare backstop; the steady-state
alloc/free fast path touches no shared cacheline or lock.

---

## Bugs fixed (correctness)

Each is provider-neutral and was reproduced under heavy concurrent alloc/free (a
multi-reactor HTTP server + churn micro-benchmarks). References are fork commits.

| # | Fix | Commit | Notes |
|---|-----|--------|-------|
| 1 | Collector self-scan anchored at the **real SP**, not the frame pointer | `50fde691` | `setjmp` spills callee-saved regs *below* the FP; an FP-anchored scan missed a live root held only in a spilled reg → reclaimed-while-live. |
| 2 | Advance `gc_cycle` + GC trigger **under STW**, before resuming the world | `8baa8db0` | A resumed mutator stamping a fresh span's `sweep_gen` with the old cycle let the next sweep recycle a still-in-flight span (UAF). TSan: 30→0 races. |
| 3 | Publish `narenas` with **release/acquire** | `c39ce23f` | Lock-free `vgc_find_span` read `narenas` while `span_alloc` wrote it under lock — publication race on the arena it gates. TSan-pinpointed. |
| 4 | Publish `page_span` slots with **release/acquire** | `46d2ae5a` | Spans carved from an existing arena don't bump `narenas`, so the page-map writes weren't published to the lock-free `find_span` reader → stale span. |
| 5 | mcache bitmap **atomic** `fetch_or`/`fetch_and` + atomic count | `46d2ae5a` | Unlocked RMW on `alloc_bits` (alloc fast path) raced a cross-thread `free`'s RMW under the central lock → one slot handed out twice. |
| 6 | `vgc_span_alloc_obj` two-pass scan **start-byte** coverage | `871dceda` | The free-index offset was applied in both passes, leaving `[0,start_bit)` of the start byte scanned in neither → a span with a free low slot reported "full" → `vgc_malloc` NULL → caller null-deref. |
| 7 | Don't reclaim **mcache-resident** spans in sweep | `871dceda` | A cached span that momentarily empties was recycled while still referenced by an mcache slot / a suspended owner's local (span descriptors live outside the GC arena, so the root scan can't protect them). Fix: stamp registered threads' cached spans' `sweep_gen` under STW. |
| 8 | **Conservative** backstop mark; drop the unsound per-span `ptrmap` | `004b02f2` | `ptrmap` was a per-*span* property set by the first typed alloc, but a size class packs many types → objects whose layout differed had live child pointers skipped → reclaimed-while-reachable. Conservative scanning over-retains, never under-retains. |
| 9 | Sound eager-drop for **aliased call results** + `?&T` free-method codegen + `vgc_free` central lock | `38607b2d` | (a) a heap value bound from a call may alias the callee's traversed sub-objects → pin it (backstop, don't deep-drop); (b) option-of-pointer free emitted a struct member-access on the `_option_*` wrapper (C compile error); (c) `vgc_free` now takes the per-class central lock (was a real MP soundness gap). |
| 10 | Option-aware free methods for `?SumType` / `?[]T` fields | `26ac2bbe` | `gen_free_for_sumtype`/`_array` emitted `it->_typ`/`it->len` on the `_option_*` wrapper → C error for any program freeing such a field under autofree/Perceus. |
| 11 | `contains_ptr` treats `?T` / `!T` as pointer-bearing | `d112d5c8` | `[]?int` was flagged noscan (the option strips to `.int`), but `_option_int` carries an `IError` pointer → a pointer-bearing object marked noscan. |
| 12 | Four `-gc e` correctness fixes: map tiny-free, Perceus drop, HEAP_vgc arity, overflow-thread panic | `a95aff916b` | Incl. the >`vgc_max_threads` case that indexed `caches[-1]` and recursed through malloc in the panic path. The HEAP_vgc-arity fix alone cleared 22 of 34 of V's own `-gc e` test failures. |
| 13 | Drop extraneous `)` when freeing an **option-pointer local** (`b := &?Foo{}`) | `3bcf843fb9` | The option branch closed the free call's paren and the shared tail closed it again → `free((Foo**)b.data));` C error. Fixes `option_init_ptr_test` under `-gc e`; boehm/none unaffected. |

---

## Optimizations (performance)

| # | Optimization | Commit | Claimed effect (verify) |
|---|--------------|--------|-------------------------|
| A | **Per-thread heap accounting** (Go per-P style): alloc/free bump thread-private `live_delta`/`alloc_delta`, flush to the global atomics only every ~1 MB | `677770dd` / `38607b2d` | Removes the global-atomic cacheline contention that made alloc-heavy MP anti-scale. Scalar-alloc T1→T8: ~6.7× (near-linear); ~8× Boehm at T8. |
| B | **Perceus deep-free** of nested heap fields of a dropped `&Foo`, gated by a sound deep-drop analysis | `677770dd` | Nested-object MP T1→T8 ~7.5× (near-linear); removes the GC pressure that compounded MP contention. |
| C | **In-place reuse**: direct indexed stores for reused map slots | `d7e9f5a1` | Avoids re-hashing on reuse-in-place. |
| D | **Dynamic span registry** (mmap-backed, lazily committed) + env-gated GC pacing | `72edb9e5` | Removes a fixed 262k-span cap; lets the trigger scale without a hard abort. |
| E | **Concurrent tri-color mark** behind `-d vgc_concurrent` (opt-in, STW stays default) | `d22ae0ee` | ~1.2–1.4× on a parallel alloc-heavy fold vs STW; *not* proposed for default (needs a sound GC-assist first). |
| F | **Alloc-path lock-contention removal** (B18): span-descriptor **bump slab** (drops a per-carve `mmap` from under the heap lock; ~3× lower RSS) + **drop full spans** instead of returning them to the central full-list (the never-reused per-fill central-lock traffic) + **per-thread GC pacing on by default** (adaptive — only when >1 mutator) | `82e39343` | Parallel alloc-heavy workload recovered from anti-scaling (≈parity) to ~3.8× its serial at a high trigger; ~3× lower RSS. |

Profile evidence: under parallel churn the alloc fast path was ~98% spin on two global
locks (`vgc_heap.lock` for span carving — whose hold included an `mmap` syscall — and the
per-class central lock for span return); 8 *separate processes* scaled but 8 in-process
workers did not, isolating the cost to in-process shared allocator state (not bandwidth).

---

## Soundness evidence

- **TSan** (Linux, clang `-fsanitize=thread`) found and confirmed fixes #2, #3, #5
  (race count → 0 after each).
- **Deterministic white-box self-check** for fixes #6/#7: `vlib/builtin/vgc_selftest_d_vgc.c.v`
  (driven by `bench/parallel-alloc/vgc_residual4_test.v`) — reverting either fix fails it.
- **Churn batteries** (provider-neutral, in `bench/parallel-alloc/`): `g_churn`
  (alloc/free/realloc storms, multi-thread), `bench_mp`/`bench_scalar` (MP alloc scaling),
  `par_live` (large concurrent live sets), `cm_stress` (concurrent-mark hazards),
  `cm_barrier_proto.c` (the write-barrier model with deterministic teeth).
- **Differential**: program output byte-identical across `-gc none` / `boehm` / `vgc` / `e`.
- Long multi-reactor HTTP soundness run: tens of millions of requests, crash-free.

## Scope / what to review carefully

- New GC backend is large; suggest reviewing `vgc_d_vgc.c.v` (allocator) and
  `vgc_gc_d_vgc.c.v` (collector) first, then `perceus.v` (analysis) and the codegen
  touch-points (`assign.v`, `auto_free_methods.v`, `autofree.v`, `cgen.v`, `fn.v`).
- **Not for default upstream**: `-d vgc_concurrent` (needs a sound GC-assist),
  `vgc_verify` tooling (debug-gated), and the experimental `cx_region.c.v` /
  transport-layer patches (consumer-specific; excluded from this proposal).
- Based on `a83aabb10f`; a rebase onto current master is required.
- Known follow-ups: sound concurrent-mark GC-assist (cooperative safepoints); generational
  option; and V's own `-gc e` codegen edge cases — **~10 of 2146** `vlib/v/tests` programs
  (all `-gc e`-specific, pass under `none`/`boehm`), characterized as three families:
  (1) **option-wrapper / generic / sub-module `_free` not generated** — e.g. an array of
  `?string` references `builtin___option_string_free` but the value-option wrapper free is
  never emitted (free-method generation vs `-skip-unused` DCE; the unwrapped element sym
  has a user `free`, so the option-wrapper free path is skipped);
  (2) **reflection metadata reclaimed** (4 reflection / generic-anon-fn tests segfault);
  (3) **Perceus string early-drop** (3 tmpl/comptime/interface-str tests produce
  truncated/aliased strings). These touch shared autofree/option/Perceus codegen
  (boehm-regression-sensitive) and runtime mark soundness — each warrants a dedicated pass,
  not bundled here. Fix #13 above cleared one (`option_init_ptr`).

## How to verify

```
# build the dev compiler, then for any program:
v -gc e   prog.v     # Perceus front line + vgc backstop
v -gc vgc prog.v     # backstop only
v -gc e -d vgc_concurrent prog.v   # opt-in concurrent mark
# benches (provider-neutral):
v -enable-globals -gc e bench/parallel-alloc/bench_scalar.v   # MP alloc scaling vs boehm
v -enable-globals -gc e bench/parallel-alloc/bench_mp.v
v -gc e test bench/parallel-alloc/vgc_residual4_test.v        # white-box fix self-check
```
