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

## C. Cross-cutting decisions to lock BEFORE integration code

- Default policy (A4) · platform targets darwin-only vs +Linux (A6) ·
  upstream-or-fork (A8) · Perceus coverage bar (A5) · shared-RC in scope or
  R2s deferred (A2).

## Biggest under-appreciated risks
- **A2** shared-RC may be unbuilt → R2s (share-heavy scaling) gap.
- **A6** Linux port (mach/mach-o are darwin-only).
- **A7** forward-port onto cx's diverged fork.

These three are the substance of "integration"; the collector gate is the
prerequisite, not the bulk.
