# Scope-aware region allocation — cx-eval integration design

Status: design (pre-implementation). Prereq validated: see `region.c` / README —
a per-thread raw block registered as a GC root once, bump-allocated, reset per
scope, scales ~80× over Boehm at 8 threads and is GC-safe. This doc specifies how
to wire that mechanism into cx eval so in-process parallel compute
(`[?worker]`/`[?async]`, and later request handlers) scales. It is the v0.8.0
in-process-parallelism fix.

The naive transparent arena failed (40× conservative-scan tax — see README). The
difference here is **scope discipline**: regions are small and reset per work
unit, and the work unit's result is copied OUT before reset.

## 1. The model

A *work unit* is a thread-confined evaluation whose transient allocations can be
discarded wholesale at completion, after its result has been published. The three
work units, in rollout order:

1. `[?worker]` body (thread-confined; result published via a `[?channel]` send).
2. `[?async]` task body (result published into the future/promise).
3. HTTP request handler (result serialized to wire bytes).

Each runs on one thread for its lifetime and communicates results only by an
explicit, identifiable hand-off (channel send / future resolve / wire write).

## 2. The region (V runtime, in the patched fork)

Per-thread state (`@[thread_local] __global`), created lazily on first scope entry:

```
block   &u8      // one raw malloc'd block (e.g. 2 MiB), GC_add_roots'd ONCE
cap     isize
off     isize    // bump pointer
active  bool     // true between scope enter/exit
depth   int      // nesting count (nested workers/async share the thread region)
high   isize     // high-water offset across the current top-level scope
```

- On first use: `block = malloc(cap)`; `GC_add_roots(block, block+cap)`. Raw
  memory registered as a GC ROOT is the correct, supported bdwgc usage — it keeps
  region→GC pointers traced without making the block GC-heap-managed (which is
  what corrupted the transparent arena via interior `GC_FREE`/`GC_REALLOC`).
- Allocation while `active`: bump from `off`. If an allocation would overflow
  `cap`, fall back to `GC_MALLOC` for that object (correctness over speed) and
  log/count it; the block size is tuned so this is rare.
- Reset: `off = 0` (reuse). No free, no GC, no lock.
- Block stays small (one work unit's live transients), so the GC root scan stays
  cheap — the property the transparent arena violated.

## 3. Allocation routing

Reuse the V `malloc` hook (the seam the transparent arena used) but gate it on
`active`:

```
malloc(n): if cx_region_active && n <= REGION_MAX_OBJ { return region_bump(n) }
           else { GC_MALLOC(n) }   // unchanged default
```

- Only the SCANNED `malloc` path is routed (cx.Node / Element / arrays / maps).
  `malloc_noscan` (strings, byte buffers) stays on GC_MALLOC — a string that
  outlives the scope (e.g. returned in the result) must be GC-owned, and copying
  noscan leaf bytes out is the deep-copy's job (§5).
- `free`: already a no-op under `-gc boehm` — safe for region pointers.
- `realloc` of a region pointer: must NOT `GC_REALLOC` an interior pointer.
  While `active`, realloc = region_bump(new) + memcpy. (Same fix the prototype
  used; here it is correct because the block is reset, not GC-freed.)
- Gated behind `-d cx_regions` until validated; default build unchanged.

## 4. Scope boundaries

At work-unit entry (in eval of `[?worker]`/`[?async]`, or the request dispatch):
```
region_enter()  // depth++, if depth==1: active=true, save off as scope_base
```
At work-unit exit, AFTER the result is published (§5):
```
region_exit()   // depth--, if depth==0: active=false, off = 0 (reset)
```
Nesting: a worker that spawns a worker shares the thread region; only the
outermost reset actually frees. (Simplest correct rule; revisit if nested scopes
want independent reset.)

## 5. Escape-safety contract (the crux)

Invariant: **after `region_exit` resets the block, no live, reachable object may
point into the region.** Everything that must survive the scope is copied to the
GC heap before reset. Enumerated escape channels and their handling:

1. **The result value.** Deep-copy the result `cx.Node` to the GC heap before
   `region_exit`. The copy is recursive and total: every node and every
   noscan leaf (strings/bytes) reachable from the result is reallocated via
   `GC_MALLOC`/`malloc_noscan` (region OFF during the copy). After copy, the
   result references only GC memory. This is the one mandatory, well-defined
   operation; correctness of the whole scheme reduces to "the deep-copy is total."
2. **Channel sends / future resolves inside the body.** A `[?worker]` may send
   intermediate values before returning. Each send/resolve is a publish point →
   deep-copy the sent value to GC at the send (channels already cross threads, so
   they must be GC-owned regardless). Identify the send sites in eval and copy
   there.
3. **Writes to shared `ProgramState`** (registries, channels, service records).
   These are GC-owned, long-lived structures. A write of a region value into them
   is an escape → must deep-copy. Audit the eval write-paths that target
   `ProgramState`; route their stored values through the GC copy. (Many already
   construct via dedicated builders; confirm none store a raw region node.)
4. **Captured env (read-only).** Workers READ captured bindings (GC objects kept
   alive by the closure/`ProgramState`). region→GC reads are fine: the GC objects
   are independently rooted, and the region root traces them while live. No copy
   needed for reads.
5. **Mutation of captured/shared values.** If a worker mutates a value visible to
   other threads, that value must be GC-owned and the mutation GC-safe (existing
   `state_locks` discipline). Region values are thread-confined and never shared
   pre-copy, so this is unchanged.

If an escape channel is missed, the symptom is use-after-reset → corruption.
Therefore the rollout (§7) gates on a corruption battery, not just scaling.

## 6. The deep-copy

`region_export(n cx.Node) cx.Node` — recursively rebuild `n` in the GC heap:
- region OFF for the duration (so copies land in GC).
- Element: copy name, attrs (incl. attr string values), recurse items.
- ScalarNode / scalar values: copy the value; strings reallocated (a region or
  GC string both copied so the result owns GC strings).
- Closures/sentinels: copy the sentinel; the captured env it references is already
  GC-owned (closures are registered in `ProgramState.closures`, GC-owned) → keep
  the reference. (Verify: a closure created INSIDE the scope must have its captured
  bindings GC-owned — closures snapshot bindings; ensure that snapshot is a GC
  copy, not region.)
- Cycles: cx values are trees (no cycles by construction); assert/guard depth.

Cost: O(result size), paid once per work unit — negligible vs the scope's work.

## 7. Rollout + validation (corruption-gated)

1. Land the region runtime (§2–§3) behind `-d cx_regions`, inert by default.
2. Wire `region_enter/exit` + `region_export` for `[?worker]` ONLY first.
3. Gate widening on ALL of:
   - full `make test-vcx-v08` green under `-d cx_regions`;
   - the conformance corpus green under `-d cx_regions`;
   - a **corruption battery**: parallel workers under `GC_gcollect` pressure +
     small region blocks (force frequent fallback + reset) + heavy result trees,
     diffed against `-gc none` and default output for byte-equality over many runs;
   - `parallel_eval_bench.v` (adapted to run the body in a `[?worker]`) showing
     aggregate scaling 1→8 threads (the win) — not just non-regression.
4. Then `[?async]`, then request handlers, each repeating the gate.
5. Only after all green, consider flipping the default (or keep opt-in for v0.8.0
   and document, depending on confidence).

## 8. Open questions / risks

- **String ownership.** Strings created in the body but referenced by the result
  must be copied (handled by §6); strings READ from captured env are GC-owned
  (fine). The line is "noscan leaves reachable from the result are copied" —
  validate the deep-copy covers every string-bearing node kind.
- **Closure capture inside a scope** (§6) — must snapshot to GC, not region.
- **Region size vs fallback rate.** Too-small block → frequent GC_MALLOC fallback
  (loses the win); too-large → scan cost creeps up. Tune via the bench; the
  fallback is always correct, only slower.
- **Multi-process (path C)** remains the parallel story for servers and is
  independent of this; pursue in parallel.
