# B17 — where cx's GC pressure actually comes from (investigation (a))

Goal: understand why Perceus isn't dropping the GC pressure in cx `[par]`
workloads, so we can leverage it. **Finding: the dominant GC pressure is NOT
Perceus failing to free droppable garbage — it's an algorithmic OVER-ALLOCATION
in the closure-call path.** Perceus is largely beside the point for this hot
path; the win is allocating less in the first place.

## The numbers
Serial `[?map (1..8) [reduce [$range 0 400000] +]]` under -gc e: 70 collections,
each sweeping ~204MB → **~14GB total churn** over 8×400000 = 3.2M fold steps =
**~4.5KB allocated PER FOLD STEP**, for a `[+ $a $b]` on two ints. That ~4.5KB is
the GC pressure (drives the 70 collections); a minimal step needs ~tens of bytes.

## Where the 4.5KB/step goes (eval.v)
The fold is `acc = invoke_closure(closure, [acc, item], mut env)!` (eval.v:8318).
EVERY closure invocation — both `invoke_closure_l` (13166-13202) and
`bind_specs_and_eval` (3333-3345) — rebuilds the whole call environment per call:

1. `bindings: map[string]cx.Node{}` — a fresh map every call.
2. `closures: map[string]Closure{}` — a second fresh map, then
   **`for k,v in enclosing.closures { call_env.closures[k]=v }`** copies the
   ENTIRE program-global closures table into it on EVERY call (O(all closures)).
3. `dyn_context: enclosing.dyn_context.clone()` — cloned every call, even when
   empty (the common case: no `[?with-scope]` active).
4. + the `[acc, item]` arg array, captured-bindings copy, map internals
   (DenseArray + key buffer + metas per map).

So the per-call cost is dominated by **allocating 2 maps + copying the global
closures table + cloning dyn_context**, every single call, in a tight O(n) fold.

## Why Perceus can't help here (and why that's the wrong lever)
These structures escape into `eval_node(c.body_node(), mut call_env)` — they are
threaded by-ref through the recursive interpreter via the long-lived `MatchEnv`
and its dynamic `bindings`/`closures` maps. Perceus (static ownership) cannot
prove when a value stored into a dynamic container threaded through dynamic
dispatch dies, so it emits no drops → all of it falls to the tracing backstop.
**But the real problem isn't that these aren't freed — it's that they're
ALLOCATED at all.** A fold over an associative op needs ~O(1) live state and tiny
per-step allocation. cx is paying a full environment-rebuild (incl. a global
table copy) per call. Tuning Perceus to free 4.5KB/step faster just chases the
symptom; eliminating the 4.5KB is the fix.

## The leverage (cx-side, eval.v — biggest first)
Classic interpreter env-representation fixes; all reduce allocation, help SERIAL
too, and are independent of the GC:

1. **Don't copy `enclosing.closures` per call.** Closures are program-global and
   immutable during eval. Share the table (parent-pointer / chained env, or hold
   a pointer to the program-global closures map in MatchEnv) so lookups fall
   through instead of copying. Removes one map alloc + the O(closures) copy/call.
2. **Stop allocating a fresh `bindings` map per call.** Use a chained env (parent
   pointer) so captured_bindings aren't copied and param binding is a small
   frame, or pool/reuse a small structure for few-param closures.
3. **Skip `dyn_context.clone()` when empty** (common). Cheap, immediate.

Estimated effect: per-call allocation from ~4.5KB → ~tens of bytes ≈ ~100×
less churn → GC fires ~100× less on this class of workload → the par STW pressure
(B16) largely evaporates for fold/map/filter-style workloads WITHOUT touching the
collector. (Genuinely-large-live-set parallel workloads still need concurrent
mark — orthogonal.)

## Where Perceus fits, AFTER the allocation fix
A chained-env frame is stack-disciplined (born at call, dead at return) — exactly
what Perceus CAN drop. So the right order is: (1) fix the env representation so
per-call allocation is small and stack-shaped, THEN (2) Perceus cheaply drops the
small frames, and (3) the backstop only handles the genuinely-dynamic remainder.
"Leverage Perceus" turns out to mean "make the hot path allocate the kind of
short-lived, statically-scoped values Perceus is good at" — not "tune Perceus to
chase the interpreter's current dynamic churn."

## ✅ FIX IMPLEMENTED + MEASURED + GATED 2026-06-13 (copy-on-write closures + skip-empty dyn_context.clone)
Implemented fixes #1+#3 as **copy-on-write** (the safe form of "share, don't
copy"): the closure-call env aliases the program-global `closures` table for
reads (the fast path); `cow_closures()` clones it lazily before any of the 5
registration sites (lazy-builtin / partial / `[?fn]` anon / `[?def]` / module
member), preserving frame-local closure scoping. Plus skip `dyn_context.clone()`
when empty. Changes: `vcx/code/matcher.v` (MatchEnv.closures_shared field +
cow_closures method), `vcx/code/eval.v` (2 invoke paths alias + set shared; 5
write sites call cow_closures). CX-side only (no V repo touched).

MEASURED (cx -prod -gc e, best-of-3), vs the B16 baseline:
| workload | before | after | speedup | collections |
|----------|--------|-------|---------|-------------|
| serial   | 4756ms | **1355ms** | **3.5×** | 70 → **9** |
| par default | 8386ms | **1562ms** | **5.4×** | 66 → **10** |
| par 1GB floor | 3377ms | **1290ms** | 2.6× | — |

So the env-rebuild WAS ~70% of runtime and ~7/8 of GC pressure. The 1.76×
anti-scale collapsed to ~1.15× (par 1562 vs serial 1355); with the B16 1GB floor
par 1290 ≈ serial. boehm serial ref 10968ms → **cx_e is now ~8× faster than
boehm serial** on this workload (was 2.18×).

VALIDATED: V impl gate **125/125** + conformance (build with COW change); a COW
isolation stress test (mapped closure body that creates+captures an inner anon
lambda per call) matches the boehm oracle on all values. The residual ~1.15× par
gap is the genuine STW-mark of the materialized range (B16 territory: concurrent
mark / range streaming — orthogonal, not an allocation bug).

SEPARATE PRE-EXISTING BUG surfaced (NOT from this change): `[?map [par]]` does
not preserve source order under -gc e/vgc (returns nondeterministic completion
order; boehm preserves order). Reproduces on pre-COW cx_e. Flagged as a separate
cx-side par_eval.v fix.

REMAINING leverage (not yet done): fix #2 (stop allocating a fresh `bindings` map
per call — chained env / pooled small frame) would cut the residual 9-10
collections further. Lower priority now that the dominant cost is gone.
