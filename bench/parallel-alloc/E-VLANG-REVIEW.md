# Architecture E — notes for vlang/v review

Companion to the RFC/issue drafts (vlang-perceus-rfc-draft.md, UPSTREAM-ISSUE-DRAFT.md,
VGC-MULTITHREAD-BUG.md). Captures (1) what E is, (2) how it compares to Go's memory
management + MP, (3) the platform-portability status — the questions a V reviewer
will ask first. Honest design-vs-maturity framing throughout.

## What E is

RC-first hybrid, NOT "a better tracing GC":
- **Front line — Perceus-disciplined autofree** (compiler codegen). Inserts drops at
  last-use and reuses unique buffers in place. The unique majority of objects is
  freed deterministically at compile-time-decided points — no GC for them. Pure
  codegen; no OS coupling.
- **Shared objects — thread-local-handoff RC** (§5.1; the R2s determinant). [STATUS:
  decided by measurement; build/verify pending — see INTEGRATION-SCOPE A2.]
- **Backstop — precise STW mark-region collector**, runs RARELY (only cycles +
  shared residual). Reuses a sound mcache/span allocator + precise/conservative
  scan; mach OS-suspend STW; full-STW mark+sweep (single-threaded mark, deliberately
  — see below).
- **Boehm — retained** as the conservative C-interop escape hatch (`-gc boehm`).

## V+E vs Go — trade-for-trade

Different strategies: Go = great concurrent tracing GC + escape analysis; V+E =
mostly free at compile-time/last-use, trace rarely.

| Dimension | V + E | Go | Edge |
|---|---|---|---|
| MP allocation scaling | per-thread mcache, no global lock | per-P mcache | parity |
| GC CPU overhead | backstop runs rarely (Perceus frees unique w/o tracing) | traces continuously | **V** (unique-heavy) |
| Memory footprint | prompt last-use frees (RC-like) | non-gen, ~2× live to next GC | **V** |
| Determinism | deterministic frees for unique | non-deterministic GC timing | **V** |
| Throughput (alloc-heavy) | no tracing for unique + in-place reuse | always tracing | **V** slight |
| Pause / tail latency | full STW, single-thread mark — ms+ when it fires (rare) | concurrent, sub-ms | **Go**, decisively |
| Cycles | RC leaks; backstop reclaims when it runs (bounded leak) | native, clean | **Go** |
| Collector MP (the GC itself) | single-thread STW mark | parallel mark | **Go** (but V mostly avoids needing it) |
| Maturity / robustness / platforms | new, STW, darwin-impl today | 15 yrs, concurrent, all platforms | **Go**, wide margin |

**Net.** On throughput / MP-scaling / footprint / determinism, E is competitive with
Go — and better on GC overhead and footprint for typical (unique-heavy) code —
because it minimizes GC rather than doing GC well. Go stays ahead on pause/tail
latency (concurrent vs STW backstop), cycle handling, and production maturity.
Closest analog is Koka/Lean (Perceus) + a tracing safety net, not "Go's GC later".

**Honest caveat for reviewers.** This is the *design* comparison. Day-one E trails Go
hard on *implementation maturity*: STW backstop (no concurrent/parallel mark yet),
darwin-only backstop glue, unproven at scale. Matching Go's latency + robustness is a
long road (concurrent mark + generational + years of hardening). The claim is "the
model can be competitive-to-better on throughput/MP/footprint/determinism," NOT "E
beats Go's collector."

## Platform portability — important, and better than "darwin only" sounds

- **Cross-platform TODAY:** Perceus codegen (no OS coupling); the allocator's memory
  primitives (`VirtualAlloc` / `mmap` branches present); atomics, CPU count, SP.
- **Darwin-only IMPLEMENTED (backstop's two OS touchpoints; Linux/Windows are safe
  stubs returning 0):**
  1. **STW thread suspension** — mach `thread_suspend`/`thread_get_state`. Linux port =
     signal-based suspend (SIGUSR handler parks the thread + reads registers from the
     signal `ucontext`); Windows = `SuspendThread`/`GetThreadContext`.
  2. **Data-segment root scan** — mach-o `getsegmentdata`. Linux = `dl_iterate_phdr`
     or `__data_start`/`_end`/`__bss_start`; Windows = PE sections.
- **Not a fundamental limit.** These are exactly the mechanisms Boehm and Go already
  use for STW + root scanning on Linux/Windows — bounded, well-trodden ports, not
  research. Mach was chosen first only because it suspends a thread in ANY state
  (incl. syscall-blocked/tight-spin), which de-risked getting correctness right;
  signal-based suspension achieves the same on Linux.

## Roadmap to maturity (ordered by leverage; cx-prioritized)

V doesn't have to out-build Go's collector — Perceus removes most of the work, so the
backstop runs RARELY. "Close the gap" = make the rare STW collector concurrent +
portable + hardened. Committed near-term order (cx priorities; Windows deferred):

1. **Finish the STW collector** — perf (vgc_heap precise root scan) + §7 gate +
   R2 + strip probes. The known-good baseline.
2. **Linux port (REQUIRED for cx — servers are Linux).** Signal-based suspend
   (SIGUSR + ucontext registers) + ELF roots (dl_iterate_phdr / __data_start/_end/
   __bss_start). Bounded/standard (Boehm/Go do this). Allocator + Perceus already
   cross-platform; only the backstop's two touchpoints need it. Gets a correct,
   DEPLOYABLE collector on Linux with rare STW pauses (acceptable MVP).
3. **Concurrent mark (latency; HIGHEST RISK — do LAST, on the proven baseline).**
   Closes most of the pause/tail-latency gap vs Go (STW collapses to root-scan +
   mark-termination, sub-ms). BUT it re-opens the exact soundness surface removed
   during bring-up: needs a CORRECT write barrier on every heap pointer store
   (codegen-wide), alloc-black (objects born mid-mark start marked), careful
   termination, + its own battery (TSan + barrier-coverage). Must NOT be layered
   until the single-threaded STW backstop is gate-green and hardened.
4. **Later:** parallel mark (multiple workers; low priority — backstop is rare),
   OS scavenging + allocator polish, Windows port.

Reality: items 1/2/4 are bounded engineering (quarters). Item 3 is real but
deferrable — cx can ship on 1+2 (rare STW pauses, like Boehm's but rarer). The
genuine multi-year long pole is "trusted at scale," earned via dogfooding (cx) +
upstream adoption, NOT coding — and it's softened because the hot path isn't the
collector.

## Why the backstop is single-threaded STW (a deliberate choice, not a gap)

Concurrent/parallel mark was REMOVED during bring-up: objects allocated during a
concurrent mark were not alloc-blacked and stack-local pointer writes carry no write
barrier → a freshly-allocated-but-live object was swept (UAF). Full-STW mark+sweep
removes that entire unsound-concurrency window. Because the Perceus front line
front-loads frees, the backstop runs rarely, so single-threaded STW is an acceptable
v1; concurrent/parallel mark is a later perf optimization that must reintroduce
alloc-black + a correct barrier.

## Correctness evidence (this build, darwin/arm64, -gc vgc -prod)

- Thread create/exit churn × GC (the hard case Boehm/cooperative-safepoint vgc could
  not do): g_churn 100 1 30 = 12/12 fully clean, 0 corruptions, 0 mid-workload crashes.
- Bugs found+fixed en route (all in P3-COLLECTOR-BUILD.md): find_span addr_map
  collision; STW lock-steal breaking allocator mutual exclusion; sweep recycling
  central-linked spans; missing global/BSS root scan.
- Perceus front line: differential oracle `none==boehm==perceus`, ASan + leak clean,
  measured 1.6× faster than Boehm single-thread on an alloc-heavy map workload.
- OPEN before submission: §7 battery completion; heavier-load perf (global-root scan
  over vgc_heap); strip diagnostic scaffolding; Linux backstop port.
