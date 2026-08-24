# vgc-debug — toolkit & methodology for vgc memory / concurrency bugs

Reusable tools and process for hunting `vgc` (the V-fork garbage collector) memory
and concurrency bugs on **macOS arm64** — especially multi-mutator use-after-free
(sweep-while-live) under concurrent HTTP reactors / `[?worker]` threads. Distilled
from the #63/#58 investigation (see the case study below).

> Build note: `cx` is built from `vcx/` against the patched V fork in `third_party/v`.
> Diagnostic builds add `-d <flag>` to the standard build:
> `cd vcx && ../third_party/v/v -n -w -cc cc -gc e [-d <flag>...] -o target/<name> cmd/`
> (always `-cc cc`). The shipped collector is cooperative-safepoint by default;
> `-d vgc_legacy_stw` reverts to the legacy mach-suspend-all collector.

## Contents
- `probes/` — standalone C programs that validate a single OS/runtime assumption in
  isolation (no fork build). The cheap "kill it before you build it" layer.
- `patches/` — `git apply`-able diagnostic instruments for the fork (+ one cx-private
  hook). Gated behind `-d` flags; revert before committing real work.
- `../../scripts/concurrency_soundness_gate.sh` + `../../vcx/tests/soundness/` — the
  committed regression gate (multi-reactor HTTP + workers, asserts zero sweep-while-live
  via the detector oracle). Run via `make test-vcx-concurrency-soundness`.

## Methodology (the part worth re-reading)

1. **Box state is a first-class variable.** Before trusting any capture, gate the box:
   swap < ~500 MB + low compressor; single-reactor throughput CV < 10% (NOT 8-reactor —
   it's intrinsically bimodal via SO_REUSEPORT); crash still reproduces at baseline.
   A too-quiet box that stops crashing is an ABORT, not a pass.
2. **Crash rate is noisy Bernoulli — use paired comparison, never absolute bands.**
   Same binary swings (e.g. 35% ↔ 7%) at N=20. Compare instrumented vs base in the
   SAME session: instrumented ≥ 0.5× base AND two-proportion z p > 0.05 (not
   significantly lower), plus absolute sanity (base ≥ 1 crash / 20).
3. **A precise detector oracle beats crash-counting.** A detector that catches the
   freed-buffer *read* (sweep-while-live) is **masking-proof**: it fires regardless of
   timing, so 0 catches means the bug didn't happen — not that a slowdown raced it away.
   Crashes are lossy (reuse-before-read) and noisy; the oracle is the robust signal.
4. **Slow instruments MASK timing-sensitive races.** A heavy probe narrows the race
   window and produces a false "fix" (the classic: extroots 1/100 was 44× slowdown, not
   coverage). Always pair-test the instrument for non-masking before trusting it.
5. **PROVEN / INFERRED / FALSIFIED ledger; pre-register falsifiers.** Write down what a
   run would show if the hypothesis is WRONG, before running it. Never promote
   correlation to causation. Keep a running list of dead ends so you don't re-chase them.
6. **b-before-a economy.** Kill a hypothesis with a cheap standalone probe (`probes/`)
   before sinking a fork-instrument build. The GAP-1 and single-step questions were each
   settled in ~30 lines of C, saving days.
7. **When localization is exhausted, eliminate the mechanism class.** Don't keep hunting
   "the missed pointer" — if the unsoundness provably lives in one mechanism (here: the
   arbitrary-PC external register scan), replace that mechanism with a sound one
   (cooperative safepoints), which dissolves the bug without naming it.

## Tool index
| Tool | Question it answers | Where |
|---|---|---|
| `probes/neon_syscall_probe.c` | Does `thread_get_state` return the full user GP+NEON for a thread blocked **in a syscall**? (it does — GAP-1) | probe |
| `probes/single_step_probe.c` | Can a controller hardware-single-step another thread (ARM_DEBUG_STATE64 MDSCR_EL1.SS) + read its regs per instruction via a mach exception port? (yes) | probe |
| `probes/anon_walk_probe.c` | Does a `mach_vm_region` walk + word-scan find a planted pointer in private/anon memory? (validates the holder-find scanner) | probe |
| `probes/go_host_suspend_probe/` | Can signal-suspend stop a registered thread under a Go host? (NO — any signal, either install order; mach suspend 200/200 — cx #743) | probe |
| `probes/go_host_suspend_probe/libcxforce/` | Deterministic #743 forcing repro against REAL libcx (straggler + `VGC_NEXT_GC_MB=1`): pre-fix 0x0acd hang, post-fix FORCE-OK | probe |
| `patches/passive_detector.patch` | The sweep-while-live ORACLE: catches a freed map-key buffer read in `map_clone_string`/`string.clone` (tag `0xbf1`; `0xc0de` GOLD if matched to a swept-log). ~6.3% single-reactor, non-masking with `-d vgc_nosweep`. | `-d vgc_passive -d vgc_nosweep` |
| `patches/holder_find.patch` | Read-time search for the persistent root of a confirmed victim (legacy/diagnostic; defeated by co-free — kept for reference). | `-d vgc_holderfind` |
| `patches/bstep_*` | B-STEP: single-step `MatchEnv.clone` and check the keys-array's reachability from vgc's captured roots at each instruction (root-coverage localizer). Needs the cx-private hook (`bstep_matcher.patch`). | `-d vgc_bstep` |

## Case study: #63 / #58 (multi-mutator sweep-while-live UAF)
- **Victim:** a tiny-packed 16/24 B no-scan map-**key** char buffer, GC-freed while still
  referenced, read in `string.clone` ← `map_clone_string` ← `MatchEnv.clone` on the
  `eval_let_tail` (TCO) path. Proven a **root miss** (mark-closure verifier `0x5CA0==0`;
  no-op sweep ⇒ objects live), only under **≥2 mutators**.
- **The sound/unsound asymmetry:** single-reactor is sound because the collector
  self-scans via `setjmp` (`vgc_run_gc_spilled`) — spilling its own callee-saved + NEON
  registers onto its own scanned stack at a controlled boundary. Multi-reactor was
  unsound because other reactors were `mach_suspend`ed at an **arbitrary PC** and scanned
  externally (`thread_get_state`); the residual root miss lived in that external scan.
- **Falsified leads (don't re-chase):** encoded/tagged pointers (V sumtype = raw boxed
  ptr + separate `u32` tag; `vgc_shade` accepts raw/interior); degenerate in-syscall
  capture (GAP-1 probe: capture is complete); five holder-find variants (immediate holder
  co-freed); B-STEP F1 (within-clone, own-thread root coverage is complete → the miss is
  cross-thread). Localization was structurally exhausted.
- **Fix:** make the cooperative-safepoint collector the default — every running mutator
  self-parks at the alloc-path poll and self-spills its own roots (the proven-sound
  shape); syscall-blocked stragglers are mach-suspended (GAP-1 makes that sound). This
  removed the arbitrary-PC scan entirely. Evidence: HTTP `CX_HTTP_WORKERS=8` 0/60 crashes +
  0/40 oracle (vs legacy 7/40 + 3/20); workers 0/20 oracle (vs 12/20); full gate green.
- **Tuning follow-up:** the cooperative stop costs ~22% 8-reactor throughput (single
  ~flat) — tracked in issue #68.

## cx_watch (not committed)
`cx_watch` was a GOLD-reference binary (force-collect + holder-find) that *masks* the
crash — forensic only, ~14 MB, kept out of git. Rebuild a detector binary instead from
`patches/passive_detector.patch` (`-d vgc_passive -d vgc_nosweep`) when you need the oracle.
