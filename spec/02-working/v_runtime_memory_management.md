# V runtime memory management — RC-first hybrid (long-term architecture)

**Status:** 02-working (promoted 2026-06-11; architecture E endorsed by the user — only the user graduates it to 03-approved)

**Scope:** This is a spec for the **V host runtime** (`third_party/v`), not for the
CX language. CX inherits V's memory behaviour; CX's parallel constructs
(`[?map [par]]`, `[?worker]`, the HTTP reactor) are bottlenecked by it
(cx-private issue #14). The spec defines the **target memory-management
architecture for V** and the phased path to it, to be carried upstream to
`vlang/v` as the work matures.

**Authority:** design intent. Empirical cruxes (§5) are resolved by measurement,
not by this document. No code is changed on the strength of this spec until it
is graduated.

---

## §0. Goal and requirements

### §0.1 Hard requirements

1. **R1 — single-thread parity.** Allocation + reclamation throughput **at least
   on par with the current default (`-gc boehm`)** on single-threaded workloads.
   Boehm's measured floor on the reference box (12-core Apple M-series, 64-byte
   objects, `bench/parallel-alloc/`) is **~77.5 M allocs/s, 1 thread**.
2. **R2 — reliable parallel scaling.** Multi-threaded allocation throughput that
   **scales positively with core count** and is **correct under concurrent GC
   pressure** (no deadlock, no OOM-by-stall, no silent heap corruption). The bar
   is "system-`malloc`-class scaling" (the control scaled ~5× to 252 M/s at 8
   threads on the same box) — not necessarily linear, but **monotonic up** and
   contention-bounded, never the current **anti-scaling** (Boehm 77→16 M/s).

### §0.2 Soft goals

- Deterministic destruction (no GC-pause-dependent finalization) for the common
  case.
- No new user-visible syntax, no required annotations, no mandatory opt-in flag
  (consistency with V's stated design ethos and the autofree v1.0 milestone).
- Keep a conservative, C-interop-safe fallback available at all times.

### §0.3 Non-goals

- **Data-race freedom.** This is a memory-*safety* spec, not a concurrency-safety
  spec. Reference-capability systems (Pony-style) are explicitly out of scope.
- **Removing the GC.** A collector remains, as backstop and escape hatch.
- **A new memory *mode* or borrow checker.** Explicitly rejected; see §2.

---

## §1. Current state of V memory management (as vendored)

V ships four mechanisms; a fifth (`vgc`) is in-tree but undocumented/experimental.

| Mechanism | Flag | Nature |
|---|---|---|
| Boehm GC (default) | `-gc boehm` | conservative mark-sweep, bundled libgc |
| Manual | `-gc none` | programmer-managed |
| Arena | `-prealloc` | bump-allocate, free-none |
| Autofree | `-autofree` | compile-time `free` insertion (~90–100%), RC residual; experimental, targeted for v1.0 |
| **vgc** | `-gc vgc` | partial port of Go's runtime GC; experimental |

### §1.1 Boehm is configured pessimally for MP (vendored)

`third_party/v/thirdparty/libgc/amalgamation.txt` builds libgc with:

```
--enable-thread-local-alloc=no      # the ONE alloc-lock mitigation, OFF
--enable-parallel-mark              # the macOS marker-starvation source, ON
```

Boehm uses a single global allocator mutex; thread-local allocation only
*batches* it. With TLA off, every free-list refill serializes. This is the root
of the measured anti-scaling (`bench/parallel-alloc/UPSTREAM-ISSUE-DRAFT.md`):
Boehm `GC_MALLOC` goes **77.5 → 34.8 → 12.2 → 15.8 M/s** at 1/2/4/8 threads
(zero collections; isolated to allocation), while system malloc goes
**50.8 → 81.4 → 157.7 → 252.1**. Boehm's own docs concede the multiprocessor
ceiling. **This config is a free near-term win to correct (§6 Phase 0), but it
does not change the architectural ceiling.**

**Marker-pin is a *partial* mitigation (measured 2026-06-11, upstream `a83aabb`,
`bench/parallel-alloc/boehm_mp_bench.v`, scanned-object alloc+collect loop).**

| threads | default markers (M/s agg, per-thr) | `GC_MARKERS=1` (M/s agg, per-thr) |
|--:|--:|--:|
| 1 | 21.7 (21.7) | 29.4 (29.4) |
| 2 | 24.1 (12.0) | 23.5 (11.8) |
| 4 | 22.8 (5.7)  | 25.2 (6.3)  |
| 8 | 19.1 (2.4)  | 18.5 (2.3)  |

Pinning markers to 1 **helps single-thread (+35%) but does NOT fix MP
anti-scaling** — per-thread throughput still collapses ~10× by 8 threads either
way. Marker-pinning removes the parallel-*mark* stomp (which dominated the
compute-bound HTTP reactor: measured 2.6× there), but an **alloc-heavy** loop is
bottlenecked on the **global alloc lock**, which markers do not touch. Therefore
marker-pin alone cannot make alloc-heavy `[par]` (cx-private #14, e.g. the guide
render) scale. The alloc-lock ceiling falls only to the demand-side (Perceus
reuse / regions → fewer allocations) + a per-thread-cache allocator — i.e. the
full architecture E, not a Boehm tweak.

### §1.2 vgc is a pre-alpha Go-runtime port (source read)

`vgc_gc_d_vgc.c.v` is explicitly "Translated from Go's runtime GC (mgc.go,
mgcmark.go, mgcsweep.go…)". The architecture is **right** — per-thread caches,
precise scan when typed, tri-color mark — but the implementation is incomplete
and unsafe:

- **STW handshake is a corruption hazard, not merely a hang.** `vgc_gc_start`
  (lines 32–40) busy-waits for mutators to stop, then on `wait_iters > 1000000`
  **breaks and proceeds anyway** — clearing mark bits and scanning roots while
  mutators run with the write barrier still off. The documented deadlock
  (`bench/parallel-alloc/VGC-MULTITHREAD-BUG.md`) is the benign face; the
  timeout path is **silent use-after-free**. Root cause: STW target
  (`gc_target_stops = ncaches − 1`) counts every thread that *ever registered*;
  there is **no deregistration**, and the only safepoint is the allocation path
  — so a finished or blocked thread never increments `gc_stopped_count`.
- **The collector itself does not scale.** Parallel mark is capped at 4 workers
  and contends on a **single global `work_lock`** (lines 322, 374) — the
  same single-lock disease relocated from alloc to mark. **Sweep is synchronous**
  (line 83), despite the "concurrent sweep" header. The **write barrier is an
  unbuffered inline shade** on every pointer write during mark (lines 404–413).
- **Scanning is only partly precise.** Stacks are scanned **conservatively**
  ("we don't have precise type info at runtime", lines 111–141). Heap objects can
  be precise via a `ptrmap`, but it is a single `u64` → objects > 64 pointer-words
  fall back to conservative.
- **Heap goal floored at 256 MB** (line 529) → under high churn the heap balloons
  to the 4 GB arena cap before triggering → the OOM variant of the bug.

**Conclusion:** vgc is *not* "one bug away." Making a Go-runtime port
production-grade is the multi-year engineering Go itself did (real safepoints,
thread lifecycle, buffered write barriers, lock-free/work-stealing marking,
concurrent sweep). It is the correct *allocator* skeleton with an incomplete
*collector*.

**Empirical confirmation (2026-06-11, upstream master `a83aabb`).** We built
upstream `./v` and ran the G-CHURN battery (`bench/parallel-alloc/g_churn.v`):
`-gc boehm` and `-gc none` PASS; **`-gc vgc` use-after-frees** under thread
create/exit churn (deterministic lldb crash: a live mutator local `last` points
to a swept object). We then implemented **five** correct fixes — thread
deregistration + cache-slot reuse, live-mutator STW targeting, abort-not-corrupt
on incomplete stop, full stop-the-world mark+sweep, and register spilling at all
root scans (mutator + collector) + a register-in-barrier
(`bench/parallel-alloc/vgc-stw-partial-fixes.patch`). **The UAF persists**,
including in a debug build where `last` provably lives on the stack — so vgc's
root scanning drops live objects under concurrent thread lifecycle beyond those
five issues. Fully fixing it needs OS-level suspend-the-world (mach/signals, à la
Boehm). This is the decisive evidence for §5.3: **do not hand-harden vgc.**

### §1.3 Arenas/regions are workload-shaped, not general

CX's own `-d cx_regions` experiment (`bench/parallel-alloc/INTEGRATION-FINDINGS.md`)
is decisive: scope-regions scale **bounded-footprint** work units (2–6× over
baseline, positive 1→4 threads) but a **high-churn bulk body overflows even a
64 MiB block and falls straight back to `GC_MALLOC` under the global lock.** An
arena cannot reclaim mid-scope. Arenas are an application-level tool, not a
runtime memory-management strategy.

---

## §2. Critical analysis of the design space

Scored against R1 (single-thread parity) and R2 (reliable MP scaling).

| Option | R1 | R2 | Fit for V | Effort |
|---|---|---|---|---|
| **A. Tune Boehm** (TLA=yes, markers=1, heap) | = baseline | ✗ global alloc lock is architectural | escape-hatch only | trivial |
| **B. Finish vgc** (Go-tracing) | ✓ potential | ◑ mcache scales alloc, but collector = single-lock mark + sync sweep + broken STW | tracing default *competes* with autofree roadmap; reintroduces pauses | very large |
| **C. Perceus autofree alone** | ✓✓ reuse beats Boehm | ◑ great until cross-thread *sharing* → atomic-RC cache-line contention | matches v1.0 roadmap + ethos | large |
| **D. Arenas/regions everywhere** | = | ✗ bulk churn overflows block → global lock (measured) | app-level tool only | done-ish |
| **E. Perceus front-line + precise per-thread-cache tracing backstop; Boehm = C-interop escape hatch** | ✓✓ | ✓✓ | matches roadmap; layered; collector de-risked | largest total, phaseable |

Disciplining facts:

- **D is settled by our own measurement** (§1.3): not a general answer.
- **C is never complete alone:** Perceus leaks cycles and still needs a collector
  for genuinely-shared/cyclic graphs. C therefore *implies* a backstop → E.
- **A cannot meet R2:** Boehm's single global alloc lock is architectural; TLA
  only batches it. A is a near-term config fix and the permanent escape hatch,
  not a destination.
- **B meets R2's allocator half but forces the hardest engineering** (Go-grade
  concurrent collection) while fighting V's stated autofree direction.

---

## §3. Decision — architecture E (RC-first hybrid)

V's long-term memory management is a **three-layer hybrid**:

1. **Front line — Perceus-disciplined autofree.** The compiler inserts the
   *minimum sufficient* `dup`/`drop` (Reinking et al., POPL 2021) and runs
   **reuse analysis**, so uniquely-owned data mutates in place (`arr << x`,
   `arr = arr.map(f)` → O(1), zero alloc/zero refcount on the hot path).
   Deterministically-freed objects **never reach the collector**. This is a
   *formalization and completion of the existing `-autofree`*, not a new mode.
2. **Backstop — precise, per-thread-cache tracing collector.** Handles the
   cyclic/shared/escaping residual. Built from the vgc lineage (per-thread
   mcache + precise scan) made correct, **or** an MMTk binding, **or** a minimal
   mark-region collector — decided by the §5.3 trade study. Because the front
   line front-loads frees, this layer runs **rarely**.
3. **Escape hatch — Boehm conservative GC.** Retained unchanged for
   C-interop-heavy / cycle-heavy programs and as the always-safe fallback.

### §3.1 Why E satisfies both requirements

- **R1 (single-thread):** reuse analysis turns allocations into in-place writes —
  strictly *less* work than any allocator — and the per-thread mcache bump-path
  beats Boehm's freelist refill. E clears R1 comfortably; R1 is the floor, not
  the prize.
- **R2 (MP scaling):** E attacks *how much hits shared runtime state* from both
  sides — Perceus removes most allocations entirely; the per-thread mcache makes
  the remainder lock-free. The tracing backstop runs rarely, so its STW/lock
  costs amortize toward irrelevance.
- **Engineering is de-risked.** Pure-B must solve Go-grade *concurrent* collection
  (sub-ms pauses, async preemption, lock-free marking). In E the collector need
  only be **correct and infrequent** — a far lower bar — because it is off the
  hot path.
- **Roadmap fit.** Autofree *is* V's committed v1.0 milestone; E finishes it
  rather than introducing a competing tracing default.

### §3.2 Precedent

RC-first-with-small-collector is the modern consensus for "safe + no-pause +
fast": Koka and Lean 4 (Perceus; Lean 4's entire elaborator runs on it),
Swift (RC + `__isUnique`), OCaml 5 (hybrid). Pure-tracing (Go) is the opposite
pole and the worse fit for V's identity.

---

## §4. Target architecture (detail)

### §4.1 Front line — Perceus insertion + reuse

- **Insertion pass** over V's IR replaces autofree's free-insertion. Existing
  autofree-clean code keeps identical observable behaviour (those cases are
  exactly the ones Perceus handles trivially).
- **Reuse analysis** downstream: when a value is dropped and a compatible-shape
  value is allocated on the same path, reuse the allocation in place. This is the
  R1-beating optimization and the hardest pass.
- **RC ops on the residual** (values whose uniqueness cannot be statically proven)
  are emitted as `dup`/`drop`; their atomicity is the §5.1 crux.

### §4.2 Allocator — per-thread mcache

- Bump-pointer fast path in a per-thread cache (Go/`tcmalloc` shape); central
  free-list refill is the only shared point and is sized to be rare.
- This is the vgc allocator skeleton; it is reusable independent of which
  collector sits behind it.

### §4.3 Backstop — precise tracing collector

- **Precise** is mandatory (not conservative): (a) RC interop needs to know which
  words are pointers to `dup`/`drop` correctly; (b) conservative scanning caps
  throughput and causes retention/false-pin. vgc's `ptrmap` path is the right
  direction; the conservative **stack** scan and the >64-word fallback must be
  closed, or the chosen collector must provide precision.
- Runs **rarely** by construction. Target: correct under thread churn + GC
  pressure, output byte-identical to `-gc none`. Sub-ms concurrent pauses are
  *not* a requirement (the front line removed the pressure).

### §4.4 Escape hatch — Boehm

- Unchanged behaviour; remains the default until the team flips it. The §6 Phase 0
  config fix (TLA on, markers pinned) applies here regardless of the rest.

### §4.5 How the layers compose

```
allocation request
  └─ Perceus says unique + reusable?  ── yes ─► in-place reuse (no alloc, no RC)
        │ no
        ▼
     per-thread mcache bump-alloc  ──► object lives
        │  (dup/drop track ownership; freed deterministically at drop=0)
        ▼
     escapes / shared / cyclic?  ── yes ─► precise tracing backstop (rare cycles)
        │ no
        ▼
     deterministic free at drop
```

---

## §5. Cruxes — resolved by measurement inside the spec, not asserted

Each crux is a **gated trade study**: a benchmark/prototype produces the decision;
the result is written back into §3/§4 before the dependent phase proceeds.

### §5.1 RC atomicity for the shared residual *(the R2 determinant)*

- **Options:** (a) thread-local RC with explicit handoff (Koka) — avoids
  cache-line bouncing, more compiler machinery; (b) atomic RC (Lean 4) — simpler,
  but refcount writes on shared objects bounce cache lines across cores, the
  classic RC MP-scaling killer.
- **Decision criterion:** on a deliberately **share-heavy** multi-thread workload,
  the chosen scheme must hold R2 (monotonic-up scaling). If atomic RC anti-scales
  on that workload, (a) is required.
- **Why it's the crux:** "Perceus scales MP" is true only to the degree
  uniqueness dominates; this study bounds the residual's cost.

### §5.2 Cycle policy

- **Options:** (a) opt-in cycle collector (Koka) — handles occasional cyclic data
  (parent-pointer ASTs, doubly-linked lists) without forcing arena-index
  rewrites; (b) structural prohibition (Lean 4) — simpler runtime, pushes cost to
  the programmer.
- **Decision criterion:** V user-base code shape (upstream call). Default lean:
  (a), because application code has occasional cycles and the GC backstop already
  exists as the collector for them.

### §5.3 Backstop collector strategy

- **Options:** (a) harden the bespoke **vgc** Go-port (fix §1.2 defects); (b) bind
  **MMTk** (mature pluggable precise/parallel/scalable GC framework — potentially
  *less* total work than perfecting a hand-rolled port, and battle-tested); (c) a
  **minimal mark-region** collector (smallest surface, since the front line makes
  collection rare).
- **Decision criterion:** a focused trade study scoring (effort to correctness,
  precision support, MP-scaling of the *collector* itself, upstream
  maintainability). **Do not default to "fix vgc" by inertia.**
- **Evidence (2026-06-11) — option (a) is down-weighted.** A direct attempt to
  harden vgc (§1.2 empirical block; `vgc-stw-partial-fixes.patch`) applied five
  correct fixes and the use-after-free under thread churn *persisted*. Correcting
  vgc requires OS-level suspend-the-world + a thread-registration barrier + a
  correct/removed concurrent-mark path — multi-year Go-class STW engineering.
  **Recommend (b) MMTk or (c) minimal mark-region** unless the V core team itself
  commits to finishing vgc's STW. (b) additionally gives precise + parallel
  collection out of the box, matching §4.3.
- **MMTk feasibility (2026-06-11; `bench/parallel-alloc/MMTK-BACKSTOP-FEASIBILITY.md`).**
  MMTk *inverts* the vgc problem: the **collector is already correct/tested**
  (Rust `mmtk-core`: MarkSweep/Immix/GenImmix), and the V binding is **plumbing**
  (ObjectModel via side-metadata → header-free; precise per-type ref scanning
  using V's compile-time types; conservative stack roots; OS-level thread
  suspend). Incremental **NoGC → MarkSweep → Immix** bring-up, each gated by
  G-CHURN. Main cost = a **Rust build dependency** (mitigated by shipping a
  prebuilt staticlib behind `-gc mmtk`; a governance call for the V team, not a
  technical blocker). **Refined recommendation:** (b) MMTk if the Rust dep is
  acceptable; else (c) a *non-concurrent* STW mark-region collector in V/C
  (tractable precisely because it drops the concurrency that made vgc unsound).
- **Shared hard part, independent of (b)/(c):** both need the *same* correct STW
  glue — **OS-level suspend-the-world (mach/signals) + conservative-stack /
  precise-heap root scan**. That glue (a clean `suspend_world()`) is the real
  engineering and is worth prototyping standalone; it is also what
  `vgc-stw-partial-fixes.patch` was reaching for.
- **`suspend_world()` PROTOTYPE-VALIDATED on darwin (2026-06-11;
  `bench/parallel-alloc/suspend_world.c`).** A coordinator using mach
  `thread_suspend`/`thread_resume` + `thread_get_state` froze **all** worker
  threads — including one **blocked in a syscall** and several in **tight
  non-allocating loops** (the exact cases vgc's cooperative alloc-path safepoint
  could not stop) — read each thread's SP, and resumed cleanly; 3/3 deterministic
  PASS. This de-risks the backstop's hardest piece and confirms the correct STW
  is *unilateral OS suspend* (Boehm's model), not vgc's cooperative polling. The
  linux/bsd path (dedicated signal + `pthread_kill` + handler-parks) is sketched
  in-file, not yet built.
- **Full root capture PROTOTYPE-VALIDATED (2026-06-11;
  `bench/parallel-alloc/stw_root_scan.c`).** Under STW, scanning each thread via
  `thread_get_state` recovered a heap pointer planted **only in a register**
  (x19) AND one planted **only on the stack** — both found exactly, 3/3 runs.
  Register roots come **for free** from the suspended register file; this closes
  vgc's bug #3 (stack-only scan dropping register-resident roots) by
  construction. Conclusion: the backstop's root scanning = OS-suspend + scan
  registers + conservatively scan `[sp, stack_base)` (heap interior stays precise
  via V's per-type maps). The two hard pieces of either backstop (stop + root
  capture) are now both demonstrated working.

---

## §6. Phased plan

Each phase ships standalone value and is independently gated. Phase 0 is the
B-minimal work that lands MP relief immediately and is absorbed by E, not wasted.

**Phase 0 — immediate relief for #14 (days, in our control). The reliable path
is Boehm-tuned, NOT vgc.**
- Pin markers (`GC_set_markers_count(1)` before `GC_INIT`) on the **eval / `[par]`
  path** (port the HTTP-reactor fix that gave 2.6×) and flip libgc to
  `--enable-thread-local-alloc=yes`. **Caveat (measured, §1.1): this is a PARTIAL
  #14 fix.** Marker-pin removes the parallel-mark stomp (helps compute/mark-bound
  `[par]`, e.g. HTTP) and TLA helps single-thread, but neither fixes the global
  alloc-lock anti-scaling that bottlenecks **alloc-heavy** `[par]` (the guide
  render). For alloc-heavy `[par]`, the honest near-term answer is **serial or
  `-d cx_regions`** (bounded units, proven 2–6×); true scaling waits on the
  demand-side (P1/P2 Perceus reuse + per-thread mcache). Update #14 to reflect
  this split rather than claiming a single Boehm tweak fixes it.
- **vgc is NOT on the P0 critical path** (revised 2026-06-11). The attempt to
  make `-gc vgc` correct uncovered ≥5 compounding soundness bugs and the UAF
  persists (§1.2 empirical / §5.3 evidence). The five partial fixes
  (`vgc-stw-partial-fixes.patch`) + the G-CHURN repro are filed **upstream as a
  bug report**, not shipped as a fix. vgc correctness, if pursued, is a large P3
  item — and §5.3 now recommends MMTk / minimal mark-region over it.

**Phase 1 — Perceus insertion (soundness).** Port the insertion algorithm onto
V's IR as the formal spec of autofree's frees + residual RC. Behaviour on
existing autofree-clean code is preserved. *Gate:* autofree test corpus
byte-identical; soundness argument documented.

**Phase 2 — reuse analysis (the R1 win).** Add the reuse pass. *Gate:* R1 met
(≥ Boehm single-thread on the bench corpus); `arr.map`/`arr << x` confirmed
in-place on unique data.

**Phase 3 — precise backstop + cycle policy.** Resolve §5.3 and §5.1 trade
studies; land the chosen collector + RC-atomicity scheme + §5.2 cycle policy.
*Gate:* R2 met (monotonic-up MP scaling, share-heavy workload included) +
correctness battery (§7) byte-identical to `-gc none` under thread churn + GC
pressure.

Phases 1–3 are **upstream `vlang/v` compiler/runtime work**; they are tracked
here and carried upstream as they mature. Phase 0 is local to our fork.

---

## §7. Tests, guardrails, and gates

Memory bugs are **silent** — the vgc timeout-break (§1.2) does not crash, it
corrupts. The gate philosophy is therefore **differential oracle + adversarial
liveness**, never "did it run." Tests assert *behaviour* (reclamation,
correctness, scaling), never name-existence.

### §7.1 Correctness gates (highest priority)

| Gate | What it does | Why it is required |
|---|---|---|
| **G-DIFF** — cross-mode differential oracle | Every fixture runs under `{-gc none, -gc boehm, -gc vgc, -autofree, +perceus}`; **all outputs byte-diffed against `-gc none`** (the only mode with no collector to corrupt). Any divergence = hard fail. | The strongest gate. Memory bugs manifest as wrong output or crash; `-gc none` is ground truth (cannot corrupt-via-GC). |
| **G-CHURN** — thread-lifecycle adversarial battery | N workers that **exit at staggered times**, some **blocked in a syscall**, some in **long non-allocating loops**, under a concurrent `GC_gcollect()` hammer; output byte-diffed. | Exactly the case that defeats the current vgc STW (`gc_target_stops` counts dead/blocked threads forever). The existing `region_corruption_bench.v` does **not** cover it. |
| **G-SAN** — sanitizer builds | ASan + UBSan on the correctness corpus (UAF, heap-overflow, bad-free); **TSan** added at P3 for RC refcount races. | The timeout-break path produces UAF that output-diff misses if freed memory is not yet reused. ASan catches it deterministically. |
| **G-LEAK** — bounded retention | RSS / live-bytes growth over fixed-work runs stays under a bound; classifies *expected* cyclic leak (§5.2) separately from regression leak. | Perceus leaks cycles **by design** — quantify and bound, do not assert zero. |
| **G-FUZZ** — randomized stress | Randomized sizes/lifetimes + **seeded, replayable** thread schedules, diffed against the oracle. | The vgc bug is "nondeterministic — the tell." Fixed fixtures miss schedule-dependent races. |

### §7.2 Performance gates (the R1/R2 requirements)

| Gate | Bar | Notes |
|---|---|---|
| **G-R1** — single-thread parity | alloc+reclaim throughput **≥ Boehm** (~77.5 M/s class, 64-byte, ref box) | Built on `bench/parallel-alloc/cbench.c`. Requires warm-up, CPU pinning, and a **variance band** (fail only on median regression > threshold over K runs) — perf gates flake otherwise. |
| **G-R2** — MP scaling, alloc-heavy | throughput **monotonic-up** 1→8 threads; never anti-scales | The current Boehm failure (77→16). |
| **G-R2s** — MP scaling, share-heavy | same bar, on a **deliberately cross-thread-shared** workload | The **§5.1 RC-atomicity crux detector** — distinct from alloc-heavy; the only gate that catches cache-line bouncing on shared refcounts. |
| **G-REUSE** — reuse actually fired (P2) | instrument alloc count; `arr.map`/`arr << x` on unique data does **0 allocations** | Without this, reuse silently *not* firing still passes G-R1 by luck. Verify the mechanism, not the wall-clock. |

### §7.3 Guardrails (prevent the bug classes from recurring or shipping silently)

1. **Liveness FAILS, never proceeds.** A collector that does not complete STW
   within a bounded wall-clock is a **hard test failure**, surfaced loudly —
   never a silent `break` / "proceed with what we have." Any in-collector timeout
   that *continues execution* is a banned pattern (it is the vgc bug itself).
2. **GC-mode parity is mandatory.** No fixture is green until green under *all*
   G-DIFF modes. A pass under one mode is not a pass.
3. **No-stub guard.** Gates test reclamation/correctness behaviour, never symbol
   existence. A collector that "registers" but does not reclaim fails a
   *retention* assertion.
4. **No silent caps.** Any sampling (top-N, capped threads, skipped modes) must
   `log` exactly what was dropped; a truncated run must not read as full coverage.
5. **OOM/arena-cap = stall failure.** Hitting the arena cap (the vgc OOM variant)
   fails as a stall, distinct from a legitimate out-of-memory.
6. **Environment guardrails.** `-prod` gates use the **patched V** (PATH/devbox
   V's Boehm segfaults under `-prod`); macOS fork→`posix_spawn` constraint holds;
   never run full suites back-to-back (capture once, inspect the capture).
7. **Upstream portability.** P1–P3 gates must run against **vanilla `vlang/v`**,
   not only our fork, or they cannot ship upstream.

### §7.4 Gate → phase mapping

| Phase | Gates that must pass |
|---|---|
| **P0** (Boehm config flip + vgc lifecycle fix) | G-DIFF + **G-CHURN** (red today, green after = the acceptance) + G-SAN + G-R2 + G-noregress |
| **P1** (Perceus insertion / soundness) | G-DIFF (autofree corpus byte-identical) + G-SAN + G-LEAK |
| **P2** (reuse analysis) | **G-R1** + **G-REUSE** + G-DIFF |
| **P3** (precise backstop + cruxes) | **G-R2 + G-R2s** + G-CHURN/G-FUZZ + **TSan** + G-LEAK with §5.2 cycle policy + §5.3 backstop scorecard |

- **G-noregress:** full CX gate green on the default build at *every* phase.
- **G-determinism:** deterministic destruction observable for the common
  (unique) case.

### §7.5 Harness — existing vs net-new

Existing: `bench/parallel-alloc/` (`cbench.c`, `vgc_repro.v`, `run.sh`) and
`vcx/tests/runners/` (`region_corruption_bench.v` + scaling benches). **Net-new:**
(1) generalize the corruption battery into **G-CHURN** with the dead/blocked-thread
cases; (2) wire the **cross-mode differential oracle** as a standing gate; (3) add
**sanitizer** build targets; (4) add the **share-heavy G-R2s** workload; (5) the
**G-REUSE** alloc-count instrumentation; (6) the **liveness-fails-not-proceeds**
wrapper.

---

## §8. Risks and open questions

- **R8.1 — RC atomic contention (§5.1)** is the single biggest threat to R2 and
  is not resolved until measured. If neither thread-local nor atomic RC holds R2
  on the share-heavy workload, E's MP story depends entirely on the backstop's
  per-thread allocator + rare collection — still viable, but the determinism win
  narrows.
- **R8.2 — Perceus reuse analysis is research-grade** and the schedule risk lives
  here (months, not weeks). Phase 1 (soundness) delivers value even if Phase 2
  (reuse) slips.
- **R8.3 — Upstream commitment.** Phases 1–3 are V-core work. This spec is the
  artifact for the upstream dialogue (the Perceus RFC,
  `vlang-perceus-rfc-draft.md`); V may choose a different frame. Phase 0 is
  ours regardless.
- **R8.4 — Conservative C-FFI roots** are unavoidable at the C boundary; the
  precise backstop must tolerate conservatively-pinned FFI roots without losing
  precision on the V heap.
- **R8.5 — `cx_regions` interaction.** The existing scope-region path (§1.3) is a
  complementary app-level tool; confirm it composes with (does not corrupt) the
  new allocator, or gate it off under the new GC.

---

## §9. References

**In-repo artifacts:**
- `bench/parallel-alloc/UPSTREAM-ISSUE-DRAFT.md` — Boehm alloc-lock anti-scaling
  data (DRAFT, unfiled).
- `bench/parallel-alloc/VGC-MULTITHREAD-BUG.md` — vgc STW deadlock/OOM
  root-cause (DRAFT, unfiled); repro `vgc_repro.v`.
- `bench/parallel-alloc/INTEGRATION-FINDINGS.md` — `cx_regions` scaling result
  (bounded scales 2–6×; bulk overflows).
- `vlang-perceus-rfc-draft.md` — the upstream dialogue artifact (unposted).
- cx-private issue #14 — `[?map [par]]` slower than serial (the motivating bug).
- `third_party/v/vlib/builtin/vgc_*.c.v` — the vgc source analysed in §1.2.
- `third_party/v/thirdparty/libgc/amalgamation.txt` — the pessimal Boehm config
  (§1.1).

**Literature:**
- Reinking, Xie, de Moura, Leijen. *Perceus: Garbage Free Reference Counting with
  Reuse.* POPL 2021.
- Lorenzen, Leijen, Swierstra. *Reference Counting with Frame Limited Reuse.*
  OOPSLA 2023.
- Koka (koka-lang), Lean 4 (leanprover/lean4) — production Perceus.
- MMTk — pluggable GC framework (candidate backstop, §5.3).
- Go runtime GC (mgc.go et al.) — the lineage vgc ports from.

**Upstream context:**
- vlang/v autofree milestone — discussions #16553, #13588, #17419.
- V memory-management docs — https://docs.vlang.io/memory-management.html
