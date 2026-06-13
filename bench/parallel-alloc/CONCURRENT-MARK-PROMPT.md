# New-session prompt — implement CONCURRENT MARK in the V runtime (autonomous)

> Paste the block below as the first message of a fresh session (optionally prefix
> with `/loop` to let it self-pace). It is self-contained and instructs the agent
> to run to completion without further prompting.

---

Implement **concurrent mark** in the V garbage collector so parallel alloc-heavy
workloads stop paying a full stop-the-world (STW) pause per collection. This is
**V-runtime-only, CX-agnostic** work: do it in the clone
`/Users/ep/git-repos/cx/vlang-v-latest` with CX-free repros, and NEVER put
anything CX-specific in any V repo (clone or `third_party/v` fork) — see memory
`feedback_v_fixes_cx_agnostic`. CX is only ever the microscope.

**Work autonomously to completion. Do NOT stop to ask for confirmation between
phases.** Only halt early if (a) you hit a genuine user-only decision (a
trade-off the code/spec can't resolve), or (b) an unresolvable soundness failure
you must document. Otherwise drive all phases below to done, gating at each.

## Read first (orient before touching code)
- Memory topic `project_v_runtime_memory_mgmt_spec` — the "NEXT SESSION" block +
  the PHASE 2 (2c) concurrent-mark note (this task), and `spec/02-working/v_runtime_memory_management.md` §7.
- `bench/parallel-alloc/{B16,B17}-FINDINGS.md` — why this is needed: B17 fixed the
  cx interpreter's per-call over-allocation (the bulk of #14), leaving a residual
  ~1.15× `[par]` gap that is the genuine STW-mark-of-concurrent-live-set cost.
  Concurrent mark is the structural fix for workloads with a real large live set.
- The collector itself: `vlib/builtin/vgc_gc_d_vgc.c.v` (`vgc_gc_start`, mark/sweep,
  `vgc_scan_suspended_roots`) and `vlib/builtin/vgc_d_vgc.c.v` (heap struct,
  `vgc_maybe_gc`, span alloc). **Scaffolding already exists** (translated from
  Go's concurrent collector but currently wired STW-only): `wb_enabled` (write-
  barrier flag), `work_full`/`work_empty` grey-work queues, the phased `gc_phase`.
  This is "finish wiring + prove sound", not greenfield.
- `thirdparty/vgc/vgc_platform.h` — the mach/signal suspend + root-scan touchpoints.

## Goal & mechanism
Mark the live graph **while mutators run**, with only two brief STW points:
1. **STW start**: enable the write barrier, snapshot/scan roots (or shade them),
   flip `gc_phase` to a concurrent-mark phase, resume.
2. **Concurrent mark**: the collector drains the grey set (`work_full`) while
   mutators execute. Mutator pointer stores go through a **write barrier** that
   shades objects to preserve the tri-color invariant (no black object holds a
   pointer to a white object without a grey somewhere). New allocations during
   mark are **alloc-black** (colored live so they're not swept).
3. **STW mark termination**: re-scan dirtied roots, drain the final grey set,
   disable the barrier, then sweep (sweep may stay STW or be lazy as today).

Add **GC-assist pacing**: a mutator that allocates during mark performs a
proportional slice of mark work, so mark keeps up with allocation instead of the
heap overshooting (Go's gcAssist model).

## Hard requirements
- **Behind a flag, STW stays the default + diff-able.** Gate concurrent mark on a
  build define (e.g. `-d vgc_concurrent`); `-gc e`/`-gc vgc` keep the proven STW
  collector until the new path is green. The STW baseline MUST remain runnable so
  soundness bisection (concurrent vs STW, same program) works.
- **Soundness first.** A wrong write barrier = silent live-object reclamation (the
  exact failure class behind the ptrmap + tiny-free bugs). Prove correctness in
  isolation before integrating.
- **CX-free.** All repros/instrumentation are pure-V in the clone. Forward-port to
  the fork only after the clone is green; never leave CX tokens in a V repo.

## Phases (drive all of them)

**Phase 0 — baseline.** Rebuild `./v2 -o v2 cmd/v` (macOS: `-cc cc`). Confirm the
current STW `-gc e` is green: g_churn battery, corpora none==e, map_test/array_test
(commands below). Confirm cx builds + gates under the fork (`make test-vcx-v08`
125/125 + `make conform`) so you have a known-good integration starting point.

**Phase 1 — design + standalone soundness prototype.** Write a short design note
(`bench/parallel-alloc/CONCURRENT-MARK-DESIGN.md`): barrier choice (Dijkstra
insertion vs Yuasa SATB — pick and justify; SATB pairs naturally with a snapshot
start), tri-color states, alloc-black, the two STW points, assist pacing, and the
exact race it must close. Then build a **standalone CX-free harness** (in the
spirit of the existing `suspend_world.c` / `stw_root_scan.c` prototypes) that
reproduces the classic hazard — a mutator rapidly rewriting pointers in a large
live graph while the collector marks (hide-a-white-behind-black) — and prove the
barrier prevents reclamation of live objects. Do NOT proceed to Phase 2 until the
prototype demonstrably closes the race.

**Phase 2 — implement.** Wire the write barrier into codegen (`vlib/v/gen/c/`,
emitted at pointer stores, gated by the concurrent build define), alloc-black in
the allocator, the concurrent drain loop in the collector, the STW start + mark-
termination points, and GC-assist in `vgc_maybe_gc`/alloc. Keep diffs minimal and
reuse the existing `wb_enabled`/work-queue scaffolding.

**Phase 3 — gate hard (CX-free, clone).** ALL must be green under the concurrent
path:
- g_churn battery `100 1 30` / `200 1 50` / `100 2 40`: 0 corruptions.
- corpora none==e byte-identical: perceus_corpus, deep_free_hazard_corpus,
  uref_corpus, p2_reuse_corpus.
- map_test + array_test under `-gc e`.
- the NEW Phase-1 concurrent-mark stress repro: 0 reclamation of live objects,
  many iterations, multi-thread.
- `./v2 -o v3 cmd/v` self-hosts; ASan build clean.
- Measure the payoff: build the par scaling repros (`par_live.v` faithful,
  `par_reclaim.v` control) STW vs concurrent — concurrent `[par]` should now
  scale (no full STW per collection). Record numbers.

**Phase 4 — integrate + cx validation + capture.** Forward-port the change to the
fork `third_party/v` (CX-free), rebuild cx (`cd vcx && ../third_party/v/v -n -w
-cc cc -prod -gc e -o /tmp/cx_e cmd/`), and re-gate cx: `make test-vcx-v08`
(125/125) + `make conform`, plus re-measure the #14 `[par]` payoff (`/tmp/w_par.cx`
vs `/tmp/w_serial.cx`, verify `80000200000 ×8` — a fast time can be time-to-abort,
always check correctness). Write `CONCURRENT-MARK-FINDINGS.md`, commit on the
fork's `cx-home/v-cx-patches` branch + bump the cx-private gitlink on
`wip/v-runtime-memmgmt`. **Do not push** unless explicitly told — leave commits
for user review (the project's push discipline is user-gated). Update the memory
topic file with the outcome.

## Reference commands (clone = vlang-v-latest)
```
# build a repro both ways and diff
./v2 -gc e   -prod -cc cc -o /tmp/x_e   repro.v
./v2 -gc none -prod -cc cc -o /tmp/x_none repro.v
diff <(/tmp/x_none) <(/tmp/x_e)            # must be byte-identical for corpora
# churn battery
./v2 -gc e -prod -cc cc -o /tmp/gchurn_e g_churn.v && /tmp/gchurn_e 100 1 30
# builtin tests under e
./v2 -gc e -cc cc test vlib/builtin/map_test.v
./v2 -gc e -cc cc test vlib/builtin/array_test.v
# self-host
./v2 -o v3 cmd/v
# concurrent build (your new define)
./v2 -gc e -d vgc_concurrent -prod -cc cc -o /tmp/x_cm repro.v
```
cx gate (from cx-private root): `make test-vcx-v08` then `make conform`.
The #14 workload files `/tmp/w_serial.cx` + `/tmp/w_par.cx`:
`[?to-sequence [?map (1,2,3,4,5,6,7,8) [using [?fn $x [?reduce [$range 0 400000] [using [?fn ($a $b) [+ $a $b]]] [init 0]]]] [par]?]]`
(serial = drop `[par]`).

## Definition of done
Concurrent mark behind its define, fully gated green (all of Phase 3 + cx Phase 4),
`[par]` measurably scaling under it, STW still default + diff-able, findings +
design docs written, commits staged on the V-runtime branches (unpushed). Stop and
summarize: the scaling numbers, the soundness evidence, and whether to flip the
default / when to push.
