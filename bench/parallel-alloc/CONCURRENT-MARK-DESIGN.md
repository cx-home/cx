# Concurrent mark for the V collector — design (spec §7, Phase-2 2c)

V-runtime-only, CX-agnostic. The goal is to mark the live graph **while mutators
run**, leaving only two brief stop-the-world (STW) points, so alloc-heavy
parallel workloads stop paying a full-STW mark pause per collection (the residual
~1.15× `[par]` gap that survives B17's interpreter alloc fix — see
`B16-FINDINGS.md` / `B17-FINDINGS.md`). It is gated behind a build define so the
proven full-STW collector stays the default and remains runnable for soundness
bisection.

## 0. Where we start (the existing scaffolding)

`vlib/builtin/vgc_gc_d_vgc.c.v` + `vlib/builtin/vgc_d_vgc.c.v` already carry a
Go-derived concurrent-collector skeleton, currently wired **STW-only**:

* `gc_phase` ∈ {`off`, `mark`, `mark_term`, `sweep`} (atomic u32).
* `wb_enabled` (atomic u32) — write-barrier on/off flag.
* `vgc_write_barrier(new_val)` — **already a Dijkstra insertion barrier**: it
  calls `vgc_shade(new_val)`, and `vgc_shade` validates the argument is an
  allocated heap object before marking it grey (so it is safe to call with
  non-pointers / nil / interior junk — they fall out at the arena-bounds and
  alloc-bit checks).
* `work_full` / `work_empty` — the grey-work buffer free-lists, with
  `vgc_work_put` / `vgc_work_get` (a single-marker fast path + a locked path).
* `vgc_gc_start` already: takes every allocator lock up-front, mach-suspends all
  mutators, clears mark bits, **scans suspended-thread roots** (stacks refreshed
  from the suspended SP + register-resident roots, via `vgc_scan_suspended_roots`
  → validated standalone in `stw_root_scan.c`), scans globals/BSS
  (`vgc_data_segments`), drains the grey set, sweeps, then resumes.
* The mark is **conservative**: `vgc_drain_mark_work` scans each scannable
  (non-`noscan`) object's whole footprint word-by-word for heap pointers. The
  precise per-span `ptrmap` path was **removed as unsound** (one span serves one
  size *class* but holds many *types*, so a single recorded ptrmap mis-describes
  most objects → live children skipped → reclaimed-while-reachable). Conservative
  scanning over-retains, never under-retains.

Today (lines 140–147 of `vgc_gc_d_vgc.c.v`) the world is deliberately kept
stopped through the whole mark+sweep, with an explicit note that resuming
mutators mid-mark was reverted because objects allocated during the concurrent
mark were not alloc-blacked and stack-local pointer writes carried no barrier.
**This design supplies exactly those two missing pieces** (alloc-black + a
barrier that the conservative mark can rely on) plus the termination root
re-scan, behind the define.

## 1. Barrier choice — insertion-family, realized as a card / dirty-span barrier

**Decision: an insertion (Dijkstra-family) barrier, realized as a card /
"dirty-span" barrier** — at a heap pointer store, the barrier marks the target
object's span *dirty*, and the collector re-scans every dirty span at mark
termination — combined with a **full STW root re-scan at mark termination** and
**alloc-black**.

Re-scanning a dirty span conservatively shades every heap pointer its objects now
hold, which is a **superset** of the textbook Dijkstra insertion barrier (which
shades exactly the newly-stored referent). So it closes the same hazard, and the
soundness proof for Dijkstra insertion (below) carries over.

**Why a card/dirty-span barrier rather than immediate shade — preemption safety.**
This collector stops mutators with **OS-level mach suspend, not cooperative
safepoints** (it must stop threads blocked in syscalls or spinning in
non-allocating loops — see `vgc_gc_d_vgc.c.v` lines 41–45). A mutator can
therefore be frozen **mid-barrier**. An immediate-shade barrier that enqueues the
new value to the shared mark queue can *lose* the enqueue if the thread is frozen
between writing the buffer slot and bumping the count → the greyed object is never
scanned → silent live reclamation. The dirty mark is instead **one idempotent
atomic byte store** with no queue interaction, and it is emitted **before** the
pointer store, which makes it preemption-safe:

* frozen *before* the dirty mark → the pointer store also has not executed → no
  black→white edge exists yet → nothing to lose;
* frozen *after* the dirty mark → the span is dirty and will be re-scanned at
  termination, catching whatever the store installs.

`cm_barrier_proto.c` hazard 3 proves exactly this: `dirty-after`+freeze reclaims a
live object and its subtree, `dirty-before` is sound under every freeze. As a
bonus, because mutators never touch the mark queue, the queue stays
**collector-exclusive** during the concurrent middle — no MPSC queue, no
work-queue locking from the barrier, and no frozen-lock-holder hazard at the
termination STW.

Justification, weighed against Yuasa SATB (snapshot-at-the-beginning, shade the
**overwritten** value):

1. **It reuses the scaffolding that already exists and is already a Dijkstra
   barrier.** `vgc_write_barrier` shades the new value. SATB would require
   loading the *old* slot value before every pointer store (a read-before-write
   at every store site, including array/map interiors) — more codegen surface and
   more runtime cost, for a collector whose front line (Perceus) already makes
   collection rare.

2. **It composes with the conservative collector via a footprint scan.** The
   barrier primitive we wire is "shade every heap pointer now living in the
   written slot": for a scalar pointer store that is one `vgc_shade`; for a
   composite (struct/array element) store it is a conservative
   `vgc_scan_range(dest, dest+sizeof(T))` over the destination — uniform with how
   the mark itself scans. SATB's "shade the old value" needs the old value's
   *type* to know what to shade; conservative-shading the old *bytes* is possible
   but is strictly more work than shading the new destination.

3. **The hard part of SATB — catching pointers deleted via the stack/registers —
   needs a stack barrier or a snapshot of every stack at start that is never
   re-mutated.** We instead **re-scan all roots at the brief STW
   mark-termination** (the collector already re-scans suspended-thread roots at
   STW start; termination re-runs the same `vgc_mark_roots` +
   `vgc_scan_suspended_roots`). That single mechanism closes the
   "load-to-a-root-then-unlink" hazard for free and is why a Dijkstra **store**
   barrier (which never sees a deletion) is sufficient. Go's runtime reaches the
   same conclusion from the other direction (its hybrid barrier exists precisely
   to *avoid* a STW stack re-scan); we keep the STW termination re-scan because
   our STW points are already there and cheap (collection is rare behind
   Perceus), so we do not need the hybrid's extra deletion half.

4. **Dijkstra floats less garbage.** SATB retains everything reachable at the
   start snapshot even if it dies during the mark; Dijkstra only retains what is
   actually linked-in during the mark. Less floating garbage = the pacer's
   `heap_marked` is closer to the true live set.

## 2. Tri-color states (as realized in the bitmaps)

There is no separate grey *color* bit; grey = "marked but not yet scanned", which
is exactly "on the grey work queue":

| color | `mark_bits[i]` | on `work_full` queue | meaning                              |
|-------|----------------|----------------------|--------------------------------------|
| white | 0              | no                   | not yet discovered → swept if it stays|
| grey  | 1              | yes (if scannable)   | discovered, children not yet scanned |
| black | 1              | no                   | discovered AND children scanned      |

* `vgc_shade(addr)`: white→grey — `test_and_set` the mark bit; if it flipped
  0→1 and the span is scannable, enqueue the object (`vgc_work_put`). Idempotent
  and safe on non-pointers (bounds/alloc-bit guarded). `noscan` objects go
  straight to black (marked, never enqueued — no pointers to scan).
* `vgc_drain_mark_work`: pop grey → conservatively scan its footprint (shading
  referents grey) → it is now black (marked, off-queue).

**Strong tri-color invariant** the barrier maintains: *no black object holds a
pointer to a white object.* Any store that would create a black→white edge shades
the white target grey first.

## 3. Alloc-black

While `gc_phase` is `mark` or `mark_term`, a newly allocated object has its
**mark bit set at allocation** (alloc-black): it is not swept this cycle, and it
is not enqueued for scanning (its bytes are either zero-filled, or are filled by
subsequent stores that each hit the write barrier). This is sound *because* of
the store barrier: a fresh object that the mutator points at a white object does
so via a store, which shades that white object.

Sites (in `vgc_d_vgc.c.v`), all guarded by `gc_phase != off`:

* `vgc_span_alloc_obj` (the small-object scan + tiny paths) — set
  `mark_bits[obj_idx]` right after setting the alloc bit.
* `vgc_alloc_large` — set `mark_bits[0]`.
* tiny sub-allocation reuse — the tiny block's slot mark bit was already set when
  the block was carved (first sub-alloc), so sub-allocs in the same slot inherit
  it.
* `memdup`/`realloc`/clone paths that copy bytes with `zero_fill=false` —
  alloc-black **and** run the footprint barrier over the copied bytes (they may
  contain pointers copied from a live source).

## 4. The two STW points + the concurrent middle

`vgc_gc_start`, under `-d vgc_concurrent`, becomes:

```
STW START  (brief, world stopped):
  take allocator locks; suspend all mutators
  vgc_sweep_finish()            # finish any lazy sweep from last cycle
  vgc_clear_mark_bits()
  wb_enabled = 1                # barrier on BEFORE resume
  gc_phase = mark
  vgc_mark_roots()              # globals/BSS + each thread stack (snapshot)
  vgc_scan_suspended_roots()    # refresh stacks from suspended SP + reg roots
  shade in-flight spawn args
  resume all mutators; release allocator locks   # <-- world runs again

CONCURRENT MARK  (world running):
  collector thread drains the grey set (vgc_drain_mark_work) while mutators:
    - run the Dijkstra store barrier at heap pointer stores  (§5)
    - alloc-black new objects                                (§3)
    - perform GC-assist when they allocate                   (§6)

STW MARK-TERMINATION  (brief, world stopped):
  take allocator locks; suspend all mutators
  gc_phase = mark_term
  vgc_mark_roots() + vgc_scan_suspended_roots()   # RE-SCAN dirtied roots
  re-shade spawn args
  vgc_drain_mark_work()                            # final drain of grey set
  wb_enabled = 0
  recompute heap_marked / rebase heap_live
  gc_phase = sweep; vgc_do_sweep(); vgc_fixup_caches()
  resume; release locks; update pacer
```

The default (no define) keeps the current single-STW path verbatim (mark and
sweep both inside the one stop), so `-gc e` / `-gc vgc` stay byte-for-byte the
proven collector and remain runnable for concurrent-vs-STW soundness bisection on
the same program.

### Why the concurrent middle is sound (the exact races closed)

* **Hide-a-white-behind-a-black** (insertion): collector has blackened A; mutator
  does `A.f = B` (B white) and drops B's other pointers. Black A is never
  re-scanned → B would be swept. **Closed by the store barrier**: `A.f = B`
  shades B grey → B is drained → survives.
* **Load-to-a-root-then-unlink** (deletion via stack): mutator loads `&W` from a
  heap slot into a stack local, then nulls the heap slot. The *store* barrier
  shades the new value (nil) — it cannot see this. W ends up reachable only from
  the stack. **Closed by the STW mark-termination root re-scan**: at termination
  every stack/register is re-scanned, finding `&W`.
* **New allocation during mark** swept as white: **closed by alloc-black**.
* **Bulk pointer moves** (struct copy into a heap field, `array << ptr`, `map[k] =
  v`, `memdup`): these install pointers into possibly-black heap objects without a
  per-field user store. **Closed by running the footprint barrier at those
  builtin mutators** (`vlib/builtin/array.c.v`, `map.c.v`, the `memdup`/`realloc`
  helpers) — an enumerable, bounded set of sites, each scanning the written
  region.

Over-approximation is always sound here: shading more (extra barriers, scanning a
wider footprint, alloc-black on a soon-dead object) only ever *retains* — it never
reclaims a live object. Under-approximation (a missed heap-store site) is the one
unsound direction, so the codegen rule is **"when unsure whether a store targets
the heap, emit the barrier."**

### Proven in isolation (gate before Phase 2)

`cm_barrier_proto.c` (CX-free, `cc -O2 -o cm_barrier_proto cm_barrier_proto.c`)
scripts the worst-case interleaving for both hazards and runs each with its
closing mechanism **off** (must reproduce the reclamation — proves the harness
has teeth) and **on** (must prevent it). Result:

```
[hazard1 barrier=off]            A=black B=DEAD  -> B RECLAIMED (live!)
[hazard1 barrier=on ]            A=black B=alive -> B retained
[hazard2 rescan=off]             H=grey  W=DEAD  -> W RECLAIMED (live!)
[hazard2 rescan=on ]             H=grey  W=alive -> W retained
[hazard3 dirty-before freeze=no ]  store=done    -> B retained, C retained
[hazard3 dirty-before freeze=yes]  store=skipped -> B n/a, C n/a
[hazard3 dirty-after  freeze=no ]  store=done    -> B retained, C retained
[hazard3 dirty-after  freeze=yes]  store=done     -> B RECLAIMED(live!), C RECLAIMED(live!)
cm_barrier_proto PASS
```

So the insertion barrier closes hazard 1; the STW-termination root re-scan closes
hazard 2; and the card/dirty-span realization is preemption-safe **iff the dirty
mark precedes the store** (hazard 3: `dirty-after`+freeze reclaims a live object
*and its subtree* C, `dirty-before` is sound under every freeze). With
alloc-black these are the *only* mechanisms needed. Phase 2 wires the existing
scaffolding (`gc_phase`, `wb_enabled`, the grey-work queue) to this shape plus the
per-span `dirty` flag, rather than inventing a new barrier.

## 5. Write barrier in codegen

The barrier must fire at every pointer store the concurrent mark will not
otherwise observe — i.e. stores into **heap** objects (already-scanned black
objects are never re-scanned). Stack-local stores need no barrier (the
termination root re-scan covers them).

Primitive (builtin, `vgc_gc_d_vgc.c.v`): `vgc_wb_store(obj voidptr)` — if
`wb_enabled == 0` return (a single atomic load; the common off-cycle path); else
`vgc_find_span(obj)` and, if it is an in-use scannable span,
`atomic_store(span.dirty, 1)`. No work-queue interaction. Under the default build
(no `vgc_concurrent` define) the body is `$if vgc_concurrent ?`-empty *and*
codegen emits no calls, so the STW collector is byte-identical.

The collector clears and re-scans dirty spans only at termination, via
`vgc_rescan_dirty_spans()` (conservatively scans each dirty scannable span's
allocated objects, shading their current referents, then clears the flag).

Codegen (`vlib/v/gen/c/`, gated by `-d vgc_concurrent`):

* **Pointer/composite stores through an indirection** — `p.f = v` where `p` is a
  `&T`, `*p = v`, `a[i] = v` where `a` is heap-backed — emit `vgc_wb_store(<base>)`
  **immediately before** the store (dirty-before-store is load-bearing for
  preemption safety, §1), where `<base>` is any interior pointer of the mutated
  heap object (e.g. the dereferenced base pointer `p`, or `a.data`). Emitted when
  the stored type may contain a pointer (pointer, string, array, map, interface,
  sum type, or struct transitively containing any of those). The chokepoint is
  `assign.v`; V already tracks whether the LHS root is a pointer (`is_pointer`).
* **Over-approximate when unsure**: if codegen cannot prove the destination is on
  the stack, emit the barrier. Span granularity means an extra/imprecise base only
  dirties a span that gets re-scanned at termination — always sound, never
  reclaims.
* **Builtin bulk mutators** get explicit `vgc_wb_store` calls in their V source
  (not codegen): `array.push` / `array << x` / `array_insert` / `array.clone`,
  `map.set`, and the `vgc_memdup*` / `vgc_realloc` helpers. These are the
  enumerable set of places pointers move in bulk into heap objects.

Primitive-typed stores (`int`, `f64`, `bool`, fixed numeric arrays, `noscan`
buffers) emit **no** barrier — they cannot create a black→white edge.

## 6. GC-assist pacing (Go's gcAssist model)

Concurrent mark must finish before the mutators allocate enough to exhaust the
heap goal. A mutator that allocates during `mark`/`mark_term` performs a
proportional slice of mark work so allocation cannot outrun marking:

* Maintain an atomic `gc_assist_bytes` debt counter. On each allocation during
  mark, `vgc_maybe_gc`'s assist hook adds the allocated bytes to the thread's
  assist debt.
* When debt crosses a threshold, the mutator drains a bounded number of grey
  objects (`vgc_drain_mark_work_n(k)`) itself before returning from the alloc,
  paying down the debt proportionally (scan work ∝ bytes allocated, scaled by the
  ratio of remaining mark work to remaining heap headroom).
* If the grey set is already empty, the assist is a no-op (mark is keeping up).

This bounds the heap overshoot during a concurrent cycle to a small multiple of
the goal, and degrades gracefully to "mutators help finish the mark" under
allocation pressure rather than busting the heap. The collector still owns the
two STW points; assist only accelerates the concurrent middle.

## 7. Gating (Phase 3, all CX-free in the clone, under the define)

* `g_churn 100 1 30` / `200 1 50` / `100 2 40` — 0 corruptions.
* corpora `none == e` byte-identical: `perceus_corpus`, `deep_free_hazard_corpus`,
  `uref_corpus`, `p2_reuse_corpus`.
* `map_test` + `array_test` under `-gc e`.
* a **new** concurrent-mark stress repro: many iterations, multiple mutator
  threads each churning a large live linked/branching graph while allocating hard
  (forces collections to overlap real mutation), asserting 0 live-object
  reclamation against a `-gc none` oracle.
* `./v2 -o v3 cmd/v` self-hosts under the define.
* ASan clean.
* payoff: `par_live.v` (faithful large-live-set parallel) + `par_reclaim.v`
  (control), STW vs concurrent — `[par]` should now scale where full-STW
  anti-scaled.

## 8. Risks

* **A missed heap-store site = silent live reclamation.** Mitigation:
  over-approximate in codegen, enumerate builtin bulk mutators, and lean on the
  stress repro + corpora-vs-oracle gates (which exercise structs, arrays, maps,
  and deep graphs) to surface any omission as corruption.
* **Barrier on stack-local stores would be wasteful but is sound** — start
  over-approximating, narrow to heap-targeted stores only after the gates are
  green.
* **Assist mis-pacing** can overshoot the heap (too little assist) or stall
  mutators (too much). Tune the ratio against the stress repro; worst case falls
  back to a forced STW collection via the existing
  `vgc_collect_and_retry_span` exhaustion path, so it cannot OOM.
* Concurrent `vgc_work_put`/`get` now run with mutators live — the locked
  (non-fastpath) work-queue path must be used whenever `ncaches > 1`, and
  `vgc_shade`'s `test_and_set` is already atomic.
