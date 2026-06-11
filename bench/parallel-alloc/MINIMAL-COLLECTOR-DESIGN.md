# §5.3 option (c) — minimal STW precise mark-region collector for V

Loop increment 6 (2026-06-11). Design only. The no-Rust backstop behind the
Perceus front line (spec §4.3). Synthesizes the validated prototypes
(`suspend_world.c`, `stw_root_scan.c`) with the *sound parts of vgc* and V's
precise per-type maps.

## 0. Core thesis — this is NOT a from-scratch collector

vgc's failure was localized. Its **allocator** (per-thread mcache, size-class
spans, bump fast path), its **precise heap scan** (`vgc_scan_precise` + per-span
`ptrmap`), and its **sweep** (`vgc_sweep_span` bitmap sweep) are all sound. Only
the **collector coordination** was broken: cooperative alloc-path safepoint,
`gc_target_stops = ncaches-1`, timeout-proceed, concurrent mark with no
alloc-black / no real write barrier, parallel-mark `work_lock`.

So the minimal correct backstop = **vgc-minus-concurrency-plus-validated-STW**:
*delete* the unsound coordination, *keep* the allocator + precise scan + sweep,
and *wire in* the now-validated OS-suspend STW and full root capture. Simplicity
(no concurrency) is the correctness feature — it removes every window that made
vgc unsound.

## 1. Shape

Non-concurrent, **stop-the-world**, **precise-heap / conservative-roots**
mark-sweep over size-class regions. Runs **rarely** (Perceus deterministically
frees the unique majority; the collector only handles the cyclic/shared/escaped
residual). Single-threaded mark is fine — rare + small live set; parallelism is a
*later, optional* optimization gated by G-CHURN, never a correctness requirement.

## 2. Components and where each comes from

| Component | Source | Status |
|---|---|---|
| Per-thread alloc cache + size-class spans + bump fast path | vgc `VGC_Cache`/`vgc_cache_get_span`/`vgc_span_alloc_obj` | **reuse** (sound) |
| Side metadata: alloc + mark bitmaps per span | vgc `alloc_bits`/`mark_bits` | **reuse** (header-free; no per-object word) |
| **Stop the world** | `suspend_world.c` (mach suspend/resume) | **validated**, replaces vgc cooperative safepoint (DELETE `vgc_safepoint`, `gc_stop_flag` polling, timeout-proceed) |
| **Root capture** (registers + conservative stack) | `stw_root_scan.c` (`thread_get_state` regs + `[sp,base)` scan) | **validated**, replaces vgc stack-only `vgc_mark_roots` (closes bug #3) |
| **Precise heap interior scan** | vgc `vgc_scan_precise` + per-type `ptrmap` | **reuse**, but **widen** the `ptrmap` past a single `u64` (vgc fell back to conservative for objects >64 ptr-words) — emit full per-type maps from V's compile-time type info |
| **Sweep / region reclaim** | vgc `vgc_sweep_span` + `vgc_put_free_span` | **reuse** (runs under STW → the "avoids race conditions" comment becomes literally true) |
| Thread registry (live mutators to suspend) | thread register/deregister (the *correct* parts of `vgc-stw-partial-fixes.patch`: dereg + slot reuse) | reuse the dereg/slot-reuse fixes; drop the cooperative-stop accounting |

## 3. Collection cycle (all STW, single-threaded mark)

1. Trigger: `heap_live >= next_gc` on an allocation (the existing pacer), OR
   explicit `gc_collect()`. Collection is **rare** by design.
2. **Suspend the world** — `suspend_world()` over all *currently-registered live*
   mutators except self (unilateral mach/signal suspend; handles syscall-blocked
   and non-allocating threads — the cases vgc could not stop).
3. **Scan roots** — for each suspended thread: registers (`thread_get_state`) +
   conservative `[sp, stack_base)`; plus globals. Shade discovered heap objects.
   Both register and stack roots are captured (validated by `stw_root_scan.c`).
4. **Mark** — drain the work queue; scan each grey object's interior **precisely**
   via its span's `ptrmap` (no conservative-interior tax — V's structural
   advantage). No write barrier needed (world is stopped → no mutation).
5. **Sweep** — bitmap sweep each span; free unmarked; return empty spans to the
   region pool. Synchronous, race-free (world stopped).
6. **Resume the world.**

No concurrent phase ⇒ no alloc-white hole, no barrier correctness burden, no
parallel-mark lock, no cooperative-safepoint coverage problem. These were vgc's
exact failure modes; the design removes them by construction.

## 4. How it plugs in behind Perceus (spec §4.5)

Perceus (P1/P2) deterministically frees the uniquely-owned majority at last-use;
only the **residual** (provably-shared, cyclic, escaped) is GC-managed. So the
collector's live set is small and it triggers infrequently → the STW pause
(proportional to live set) is amortized to near-irrelevance. This is precisely
why a *simple* STW collector suffices here and why the spec's "correct +
infrequent, not sub-ms-concurrent" bar (§4.3) is the right target.

## 5. Correctness gate

The collector is "done" only when **G-CHURN passes** under `-gc <thiscollector>`
(byte-identical to `-gc none`/`-gc boehm`, zero UAF, zero deadlock) — the same
battery that exposed vgc. Bring-up order, each G-CHURN-gated:
1. Allocator + **no collection** (NoGC-equivalent) — proves alloc + object model.
2. + STW + root scan + mark + sweep, **single mutator** — proves the cycle.
3. + multi-mutator under thread churn — the real G-CHURN bar (the test vgc fails).
4. (optional, later) parallel mark / generational — only with G-CHURN staying green.

## 6. Effort / risk vs the alternatives

- vs **harden vgc (a):** strictly less — we *delete* the broken concurrency rather
  than debug it, and reuse vgc's sound allocator/scan/sweep.
- vs **MMTk (b):** more collector code to own, but **no Rust build dependency**
  and no binding-impedance work; the collector is simple and the two hard pieces
  (stop + roots) are already validated prototypes.
- Residual real work: widen `ptrmap` to full per-type maps; port `suspend_world`
  to linux (signal path, sketched); a precise globals map. All bounded.

## 7. Recommendation refinement (§5.3)

(c) is now **well-de-risked and concrete**: it is *not* a from-scratch GC but a
recomposition of validated/sound parts. **Pick between (b) MMTk and (c) minimal
on the Rust-dependency question**: if the V core team will accept a prebuilt-
staticlib Rust dep, (b) gives tested parallel/generational collectors for less
owned code; if not, (c) is fully tractable in V/C with the hard mechanics already
proven. Either way, **harden-vgc (a) stays rejected**, and the shared STW+root
glue (validated here) is reusable across (b)/(c).

Next loop increment: (7) prototype the precise heap-mark on a toy typed heap
(ptrmap-driven interior scan + bitmap mark/sweep) to validate the one remaining
unproven mechanical piece, OR advance the Perceus CFG/last-use design.
