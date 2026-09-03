# Ruling — the gate's dev builds stop compiling at -O2 (#1227)

**Date:** 2026-09-03
**Status:** RULED — owner letter **(a) then (b)**, recorded before the work.

## What was found

Dead-end **D3** in `dead_ends_700_test_duration.md` recorded a 4x gap between
devbox's nix clang and the host Apple clang per test binary, called it a
"toolchain swap", and closed it on the owner's dependency-management ruling
(VC-22). The gap was never diagnosed. Its cause is one flag: the nixpkgs clang
wrapper's `fortify` hardening (in `NIX_HARDENING_ENABLE`) prepends `-O2` to any
compile that carries no `-O` of its own, and V's non-`-prod` builds carry none.

Same 4.3 MB generated C for `vcx/cmd_data/`, same nix clang 21.1.8, M2 Max:

| variant | wall | output |
|---|---|---|
| nix cc, default hardening (the gate today) | 22.3 s | 3.4 MB |
| nix cc, `fortify`/`fortify3` removed | 3.6 s | 5.2 MB |
| nix cc, all hardening off | 3.5 s | 5.1 MB |
| host Apple clang | 2.8 s | 5.0 MB |
| V frontend alone (parse/check/cgen) | 1.1 s | |

The size column is the proof of mechanism (-O2 vs -O0). An explicit `-O0`/`-Os`
on the command line wins over the injected `-O2` (verified with `-###`), so
`-prod` builds are unaffected. The linux release lane compiles with plain gcc
and has always tested at -O0; macOS was the odd one out.

In the last full gate (`gate28`, 2026-09-02, 37 min wall born-to-modified),
the two largest `v test` lanes report compile time at >97% of their totals.
This is register lever **N2** — reduce total CPU work — which was believed not
to exist.

## Options put to the owner

- **(a)** filter `fortify fortify3` out of `NIX_HARDENING_ENABLE` for the
  tree's builds (Makefile export, project-local; same compiler, same nix
  store, same lockfile). RECOMMENDED.
- **(b)** fork-side compiler levers: `-parallel-cc` exists in the fork; it
  shortens SERIAL phases only and adds CPU, so it cannot pay while the gate is
  throughput-bound. tcc is dead on macOS (TLS + C11 atomics in the patched
  builtin). Re-cost AFTER (a), when the regime may have flipped to
  latency-bound.
- **(c)** accept the current gate. Wrong.

**Owner: "a then b".**

## What (a) deletes

Nothing from the dependency set. It deletes the -O2 the wrapper added to
builds that never asked for it. Two consequences are owned, not deferred:

1. **The `-usecache` key does not see this env var** (same class as audit hole
   H1 — compiler behaviour behind an unchanged name). The namespaces are
   cleared once before the acceptance gate; a key salt for the wrapper's
   effective hardening set is filed as a follow-up on the fork.
2. **Dev builds move -O2 → -O0.** Any behaviour that differs is a FINDING (UB
   the optimiser hid, or the reverse). macOS now tests what linux tests.

## Acceptance

Full `make test`, unpiped, `GATE-RC=0`, wall + CPU recorded here against the
1,126 s / 179 CPU-min baseline; then the regime check (parallelism ratio vs
12 cores) BEFORE (b) is sized — the register's corrected rule.

## Result

_(appended after the gate)_

## Found while taking the acceptance gate — #1228, the real root cause of #951

The first acceptance run (cold vcache after the one-time clear) came back
**GATE-RC=2 at 1,710 s / 183 CPU-min**: `supervise.cxd/sup-011` RED, and RED
again on the profile gate's serial re-grade and in an isolated rerun. Measured:

- both the -O0 profile binary and the **-prod** `cx` fail identically and finish
  in **0.15 s** — no 8 s deadline was ever waited;
- a receive deadline on a channel waits (1.5 s probe); a receive deadline on a
  **monitor** does not (0.02 s) — and it does not on the last green commit
  `21c2da416` either (worktree build). The defect predates #1119 and #1227.

Cause, `vcx/code/eval.v`: the monitor branch of `[?receive]` with `max=` looped
`monitor_receive_single` and never read `deadline=`; the single form returns
CXER0202 at once on the main thread when the terminal is not ready; the batch
form swallowed that into `()`. sup-011 only ever passed when the supervisor died
before the fixture asked. #1119's allocation cuts made the main path faster
(0.15 s vs 0.38 s per run) so the fixture now wins that race every time. This
is the `:no-terminal-within-deadline` marker #951 classified as a load-race and
closed with a retry class — **the retry roster re-ran a race until the fixture
lost it, converting a reproducible defect into an intermittent pass.**

Fixed under #1228: `monitor_receive_batch` honours the deadline like the
channel batch path. Fixture `program-conc-028a-monitor-deadline-waits-for-a-
live-worker` (red-proven: `([spawned name=slow], ())` before, `([spawned
name=slow], ([done name=slow 7]))` after). sup-011: 3/3 CXER5094, no retry.

**Pattern named (two instances in one day):** a performance improvement removes
accidental cover from a latent defect — #1227's -O0 dev builds lose the -O2
execution coverage the tests never designed, and #1119's speed-up flipped a
race the retry roster had been hiding. Neither improvement caused a defect;
both changed the timing that concealed one. The owner question this raises
(one optimised lane in the gate, a pre-cut -Os pass, or neither) is posed with
the gate number below.

Peer datum (cx-private-09, same day): at HEAD `ead51603a` their gate saw
`sup-001` SIGSEGV in `fire_close` (#1219) and sup-011 green — the family fails
in different places under different timing. #1219 is a separate defect and
stays with #1119; my quiet-box run did not reproduce it.

## Result — acceptance gate with (a) in place and #1228 fixed

`make test`, warm vcache (cleared once before the first run), quiet box, HEAD
`ead51603a` + this work, unpiped, **GATE-RC=0**:

| run | wall | CPU (user+sys) | parallelism |
|---|---|---|---|
| last comparable full gate (`gate28`, 2026-09-02, -O2 dev builds, profile gate already in the serial tail) | **2,235 s** (born→modified) | not captured | |
| 2026-08-25 reference in the register (profile gate still INSIDE the storm — not comparable on wall) | 1,126 s | 179 CPU-min | 9.5x |
| #1227 run 1 — cold vcache, sup-011 RED (#1228) | 1,710 s | 183 CPU-min | 6.4x |
| **#1227 run 2 — warm, #1228 fixed** | **1,485 s** | **120 CPU-min** | **4.9x** |

- **CPU: 179 → 120 CPU-min (−33%)** — register lever N2, the one that
  "did not exist". Per-lane compile in the two big `v test` lanes fell 16,363 →
  4,848 s and 15,334 → 3,906 s (summed, contended); their lane wall fell 1,448 →
  476 s and 1,379 → 565 s.
- **Wall: 2,235 → 1,485 s (−34%) against the comparable run.** The 1,126 s
  figure predates `60b78b270` (2026-08-27), which moved the profile gate out of
  the storm into a serial tail; it is not a wall baseline for today's gate.
- **Execution got slower, as predicted:** fixture RUNTIME in the 61-file lane
  1,525 → 1,616 s (was 496 s at -O2); the profile gate alone 660 → 427 s (its
  builds got cheap, its RUN did not). This is the -O0 cost, and it is why the
  gate is now **LATENCY-bound: 4.9x on 12 cores**. The serial head (the -prod
  prewarm) and the serial tail (the profile gate) are now the clock.
- `process_pty_test.v` failed under -j and passed its classified serial retry
  (#1125 roster, pty master read race) — the gate contract, unchanged here;
  after #1228 every roster entry deserves re-justification (posed on #1228).

**Regime check for (b), per the register's corrected rule:** wall × cores =
17,800 CPU-s available vs 7,200 used → latency-bound → a serial-phase lever CAN
pay now. `-parallel-cc` is confined to the serial phases anyway (it writes fixed
`out_N.c` into the shared V temp dir), which is exactly where the clock is.

**Evidence-strength note (owner question, not decided here):** a -O0 green
replaces the -O2 greens it supersedes and is WEAKER evidence for
optimiser-sensitive code (#1219 is the live example; `-prod` ships -Os).
Options: (a) one optimised lane stays in the gate — the profile gate's cli/embed
profiles at -Os are the natural candidate (they execute ~3,800 fixtures through
real binaries); (b) a pre-cut -Os pass in release-verify only; (c) none.

## (b) measured — `-parallel-cc` on the serial -prod prewarm

The prewarm (`make -C vcx build`, libcx.dylib -prod + cx -Os) is **171 s on one
core** while 11 idle. Built into scratch with an isolated `VTMP`:

| artifact | serial | `-parallel-cc` (12 TUs) | link |
|---|---|---|---|
| libcx.dylib (-prod -shared) | 88 s | **28 s** wall / 172 CPU-s | **FAILS** |
| cx (-Os) | 82 s | **24 s** wall / 143 CPU-s | **FAILS** |

The C stage parallelises 3x. The link fails on **5,032 duplicate symbols**, all
from five *definition-includes* — C implementation files a V module pulls in
with `#include "x.c"`: `zstd.c` (4,800+ symbols, vlib/compress/zstd), and cx's
own `cx_pty.c`, `cx_term.c`, `cx_stack_guard.c`, `cx_iowatch_darwin.c`. V's
parallel_cc puts everything before the first function into the shared `out.h`,
so each amalgamation is compiled once per split TU. The fork's cgen already
classifies these includes (the `is_def_include` owner rule that made -usecache
sound, #864); parallel_cc has no equivalent. Fixing it properly means a fork
patch: emit each module's definition-includes into ONE split TU and place that
module's functions in the same TU (other modules call the owner's V wrappers,
the invariant -usecache already relies on). Linker "multiply defined" flags are
NOT an option — N4 in the register removed exactly that masking on linux.

Ceiling if fixed: ~120 s off the serial head, ~8% of a 1,485 s gate.

**The larger serial chunk is the profile gate tail (~430 s at -O0), and its
reason for being serial is gone.** `60b78b270` (2026-08-27) moved it out of the
storm because sup-011's "load race" reddened tag takes 4/5/6 — that race was
#1228, fixed above. The move was a gate-hygiene fix, not a recorded ruling.
Returning the profile gate to the storm is a two-line Makefile revert worth
~400 s of wall (est. 1,485 → ~1,050-1,100 s), and it would expose #1219 more
often, which is where that defect should be found. Posed to the owner below.
