# Architecture E — full integration scope (V + cx)

What it takes to actually SHIP and leverage the RC-first hybrid (architecture E)
beyond the research build. The collector-completion work (perf fix + §7 gate) is
only the first box. This file is the authoritative "what" so nothing is lost when
integration starts from a green, trustworthy collector.

Current state (2026-06-12): P0 shipped in cx's fork. P1/P2 (Perceus) + P3 (vgc
backstop) live ONLY on the upstream-master clone (`/Users/ep/git-repos/cx/vlang-v-latest`),
gated `-autofree -d perceus` and `-gc vgc`, NOT in cx's shipping fork. cx builds
against its 0.7.0-era fork (`third_party/v`, branch `cx-home/v0.7.0-cx-patches`)
with P0 + DTLS + codegen patches.

## A. V-side — make E real & shippable

1. **Finish the collector** (queued P3): vgc_heap precise/excluded root scan (perf
   timeout on heavier g_churn / min_wg 0 60); §7 correctness battery byte-identical
   to `-gc none` under churn; R2 (alloc-heavy MP, monotonic-up); strip the
   diagnostic probes (vgc_watch_*/snapshot/roots; the GC-and-retry safety net is keep).
2. **Shared-object RC layer — VERIFY BUILT; likely NOT, and it is the R2s determinant.**
   This session built the *tracing* backstop (correct for shared + cycles). §5.1's
   decided **thread-local-handoff RC** for *shared* objects is probably NOT
   implemented — Perceus only drops UNIQUE objects; shared currently falls to STW
   tracing. Without RC, share-heavy workloads trigger frequent STW → **R2s
   (share-heavy MP scaling) fails**. Per-thread mcache → R2 (alloc-heavy); RC →
   R2s (share-heavy). DECIDE: build the RC layer (dup/drop + RC header +
   thread-local handoff per §5.1) or formally defer R2s.
3. **Unify the switch.** Today two flags (`-autofree -d perceus` + `-gc vgc`).
   Collapse into one mode/surface for "E on".
4. **Default policy decision (product call).** Is E default? Does `-autofree` imply
   Perceus? Is the backstop the default `-gc`, with `-gc boehm` as the retained
   C-interop escape hatch? Drives codegen defaults.
5. **Perceus coverage bar for v1.** Banked precision follow-ons: loop-body across
   branches/inner loops; reuse for filter/same-size-diff-type/other fresh ops;
   classifier slice/borrow tracking; generic-instantiation escape summaries;
   return-of-scalar-projection over-pin; deep-free of nested heap fields in dropped
   `&Foo`. More coverage = more GC pressure removed = bigger win. Decide "enough".
6. **Platform — LINUX IS REQUIRED for cx (not just "maturity"); Windows deferred.**
   Backstop is darwin/arm64-only IMPLEMENTED (mach thread_suspend + mach-o
   getsegmentdata; Linux/Windows are safe stubs returning 0). cx servers run Linux →
   the backstop is non-functional for real cx use until ported. **Linux port (do
   right after the STW gate is green, bounded/standard):** signal-based suspend
   (SIGUSR handler + registers from the signal `ucontext`) + ELF roots
   (`dl_iterate_phdr` / `__data_start`/`_end`/`__bss_start`). Allocator + Perceus are
   already cross-platform, so it's only the backstop's two touchpoints. Windows
   (`SuspendThread`/`GetThreadContext` + PE sections) deferred — cx not concerned now.
7. **Forward-port to cx's V fork.** All P1/P2/P3 is on the upstream-master clone;
   cx's fork is 0.7.0-era. Forward-port the patches onto the fork OR rebase the fork
   onto new upstream V (carrying ALL cx patches: P0 marker-pin/TLA, DTLS net.mbedtls
   submodule, macOS posix_spawn shims, codegen fixes). Substantial, risk-laden merge.
8. **Upstream-vs-fork decision.** PR P1/P2/P3 to vlang/v, or keep in fork (permanent
   maintenance cost). Upstream filing currently HELD (user 1c).
9. **spawn/thread-lifecycle codegen** (spawn-arg root registry, gated `-gc vgc`)
   folds into the unified mode.

## B. cx-side — consume & leverage

10. cx builds against the E-enabled fork (gitlink bump + Makefile).
11. **cx-eval under E** — interpreter per-request allocations (env clone, node alloc)
    compile clean and actually benefit; no conformance regressions.
12. **cx_regions reconciliation** — `-d cx_regions` arena tool vs E: subsume, keep for
    bounded compute, or retire. (See project_scope_region_integration.)
13. **`[par]` / parallel primitives** — the MP win lands here; validate real scaling
    under E (the actual #14 closure), not just the microbench.
14. **Full cx gate under E** — `make test` + conformance corpus green, `-prod` AND
    non-prod, with E enabled.
15. **http/picoev under E** — the (separate) transport backend compiled under E;
    confirm the allocation parts benefit. NOTE: HTTP req/s is transport-bound — E is
    not the HTTP lever; picoev is.

## C. Cross-cutting decisions — LOCKED 2026-06-12 (user)

- **A4 default policy → E is OPT-IN via one unified flag; Boehm stays the default
  `-gc`.** cx dogfoods E (the maturity long-pole) without defaulting to it before
  the integrated Linux gate + R2s land. Flip E to default only once the integrated
  Linux `g_churn` gate is green AND the Perceus coverage bar (A5) is met. `-gc boehm`
  remains the C-interop escape hatch either way.
- **A2 shared-RC → R2s FORMALLY DEFERRED for v1.** Ship E with R2 (alloc-heavy MP,
  already met via per-thread mcache). Share-heavy MP falls to STW tracing — document
  as a known limitation. Build the §5.1 thread-local-handoff RC layer post-v1 when a
  real share-heavy workload demands it. (cx's actual #14 pain is alloc-heavy `[par]`
  = R2, which E already fixes.)
- **A8 upstream-vs-fork → keep HELD.** Carry P1/P2/P3 in cx's fork; revisit upstream
  after cx dogfoods on Linux and the integrated gate is green (evidence > design doc).
- **A5 Perceus coverage bar → DEFER (measurement-driven).** Don't widen the classifier
  speculatively. Current coverage (spine + simple-loop-body; R1 win met) ships v1; the
  integrated cx gate (B11/B13 cx-eval + `[par]` under E) reveals which pins actually
  cost GC cycles, then widen those specifically.
- **A6 platform → Linux REQUIRED, touchpoint-port DONE + native-validated 2026-06-12**
  (commit 04342bd2; both touchpoints, arm64+amd64). Integrated Linux `g_churn` gate
  deferred to (B)/forward-port (Decision-1 = accept touchpoint level as (a)-done).
- **A3 flag-unify → DONE 2026-06-12.** Single `-gc e` mode = vgc backstop + Perceus
  front line, **decoupled from `-autofree`** (the naive union crashed — autofree+any-GC
  is incompatible; see E-INTEGRATION-FINDINGS.md). `-gc e` = `.vgc` + define `vgc` +
  define `perceus`, no autofree. Validated: corpus G-DIFF `none==-gc e` 4/4, churn
  12/12, reuse fires, flag-off byte-identical, `-autofree -d perceus` path intact.

## Biggest under-appreciated risks (updated 2026-06-12)
- **A2** shared-RC unbuilt → R2s gap — **RESOLVED by decision: R2s formally
  deferred for v1** (no longer a delivery risk; a documented v1 limitation).
- **A6** Linux port — **touchpoint-port DONE + native-validated** (arm64+amd64);
  residual = the integrated Linux `g_churn` gate, folded into A7/B14.
- **A7** forward-port onto cx's diverged 0.7.0 fork — **NOW THE DOMINANT RISK.**
  All P1/P2/P3 + the Linux port live on the upstream-master clone; the fork is
  0.7.0-era carrying P0/DTLS/posix_spawn/codegen patches. Substantial merge.

A7 is now the substance of "integration"; the collector gate + Linux touchpoints
are done.
