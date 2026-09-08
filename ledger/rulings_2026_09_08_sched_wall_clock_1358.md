# RULED: 1358-a … 1358-d — sched's production `:wall` clock

Date: 2026-09-08
Issue: cx-home/cx-private#1358
Drafted by: worker B (Opus), campaign #1354. Approved by: Fable, under the
campaign's ruling protocol (Opus drafts, Fable approves).
Related: #1322 (the restore half, closed), #1313 (liveness, RULED 789-WF-27a),
#1265, `spec/03-approved/std-lib/sched.md` §2.1, §2.2, §2.6, §3.3, §4.2, §4.3.

## The defect these rulings answer

`clock_mode` is written `'manual'` at `vcx/code/stdlib_sched_notd_cx_no_pack_sched.v:143`
and `:160`, read at `:694`, and assigned `'wall'` NOWHERE. The only fire path is
`sch_test_clock_advance` (`:866`) → `sch_earliest_due` (`:907`) → `sch_fire_due`
(`:931`). `sched_reset_state` runs from `new_env` (`matcher.v:935`), so every
program — fixture or `cx FILE` — starts `:manual`. No armed timer fires in any
production process: supervise's restart backoff, every flow `deadline=`, and
every `cx flow serve` schedule binding are inert.

`sched.md` §3.3 states the opposite posture is normative — `:wall` is the
production default and there is "no public verb to flip a live production loop
to `:manual`". §9 is explicitly non-normative, so the MECHANISM was open and
these rulings fix it.

## Corpus position

`conformance/gates.cxd:74` enforces the sched module. All 41 sched cases plus
`sched-005-clock-mode-manual` pin the HARNESS posture, which §3.3 says is what
`clock-mode` exists to assert. **Zero `:manual` fixtures move under any ruling
below.** No gate-enforced fixture is flipped.

## 1358-a — the fire path is a safepoint pump at the blocking cancellation points

Due timers fire at the §10.5.4 BLOCKING cancellation points — `[?sleep]`, the
`[?receive]` / `[?try-receive]` / `[?select]` / `[?send]` waits, `[?await]`/join
— plus the blocking http serve loop. Those already loop on `chan_poll_interval`
(1 ms, `eval.v:19260`) or the 50 ms cancel poll. `[?sleep]` caps each poll slice
at the earliest due deadline.

REJECTED — a dedicated timer thread entering the evaluator: `sch_fire_due` takes
`mut env MatchEnv` and runs the callback INSIDE the evaluator, so a thread has
nothing to call it with. It would need a second evaluator entry or a lock over
the value graph, the shape #57 and #973 have already made expensive.

REJECTED AND NOT RESERVED — the hybrid (timer thread + ready queue drained at
the same points). Its only purchase was sub-poll-interval precision, and channel
waits already poll at 1 ms.

### Binding 1 — ownership

`sched.md` §2.1: "the arming worker owns the handle"; the callback is "invoked on
the loop". A `[?worker]` body is a real V thread (`eval.v:20206
spawn run_worker_thread`) sharing `ProgramState`. A pump draining the whole
global registry from any thread would run the main program's closure on a worker
thread — exactly what the rejected option was rejected for. `SchedTimer` records
its owner (`env.current_worker`; nil = the main lineage, `matcher.v:107-118`) at
arm time, and a pump fires ONLY its own lineage's timers. `test-clock-advance`
keeps draining everything, which is why no `:manual` fixture moves.

### Binding 2 — what this DELETES, stated honestly

A program that never reaches a blocking point fires nothing until it does. The
`[?for]` iteration boundary is deliberately NOT a pump point — it would cost a
clock read per iteration on hot loops. This is the posture CX already has for
channels and sockets; `sched` becomes consistent with it rather than uniquely
privileged.

## 1358-b — `:wall` is the process default; `:manual` has exactly two selectors

`sched_reset_state` sets `'wall'`.

§3.3 named two selectors and NEITHER existed: `http.md` carries no `clock` opt,
and `vcx/cmd/main.v` has no test mode. The only runner that needs `:manual` is
the in-process harness (`vcx/tests/code_eval_fixtures_test.v`, six
`code.new_env()` sites). `guide-check` diffs `stdlib/sched.cx`'s ten
`test-clock-advance` examples textually and never executes them.

Ruled selectors:

1. the harness, through an internal loop-construction setter called after
   `new_env` — §3.3's "set at loop construction";
2. `--manual-clock` on `cx FILE`, plumbed exactly like `--strict`
   (`main.v:338-341` → a process-wide setter). This is §3.3's "CLI test mode".
   Without it, a developer running a fixture body through `cx file.cx` hits
   `CXER4970` — a real workflow regression.

NO public CX verb flips the mode. §3.3's prohibition stands unchanged.

§3.3's dangling cross-reference to `http.md` §3.5 is corrected to name these two
selectors. FLAGGED BY THE APPROVER AS OWNER-VETOABLE: this is a
dangling-reference fix, not a truing to a shortfall.

## 1358-c — all five cadences land together

`after`, `at`, `every`, `recur`, `cron`. Every cadence shares ONE clock read —
`r.virtual_now` at `:468 :513 :553 :610 :960 :1352 :1394 :1406`, plus
`sch_rearm_intent` `:1387-1406`. The landing is one `sch_now()` substituted at
every site: virtual under `:manual`, epoch realtime ns under `:wall`. Landing
one-shots first would ship a scheduler that fires half its own surface.

TRAP for the implementer (inferred from the persisted representation, not run):
deadlines are stored as ABSOLUTE ns since epoch (`SchedTimer.deadline`; flow's
`f--intent-at` decodes from 1970) and `at` resolves a datetime to an epoch
instant. So `:wall` now MUST be the realtime epoch clock — §2.6's word
"monotonic" cannot be taken literally without making `at` and `restore`
incoherent. §4.2's deadline order and §4.3's fixed-rate / fixed-delay rules are
clock-source-independent and are untouched.

## 1358-d — how the wall arm is graded

Both halves. The `:manual` corpus is unchanged and remains the SEMANTICS gate
(ordering, catch-up policy), because a `.cxd` case cannot pin wall firing without
becoming a wall-clock flake.

The CLOCK SOURCE is graded in `vcx/timing/` — the serial `make test-vcx-timing`
lane that runs after the `-j` fan-out drains (`Makefile:2008`) — spawning the
binary via `testenv.cx_bin()` as `channel_timing_test.v` does, and asserting only
load-robust bounds:

1. `clock-mode` answers `':wall'` under `cx FILE`;
2. the filing's own repro — a 100 ms `after` is `fired` after a 600 ms `[?sleep]`;
3. `after` with a channel fire value delivers its `[tick …]` to a blocking
   `[?receive timeout=]` (the supervise shape, `stdlib/supervise.cx:370/400/479`);
4. a 60 s timer is still `armed` after a 100 ms sleep — the no-fire control;
5. `every 50ms` fires at least 3 times inside a 400 ms sleep — a lower bound only;
6. `test-clock-advance` under `:wall` answers `CXER4970`;
7. a timer armed inside a `[?worker]` fires at the WORKER's own receive, not the
   main thread's — the ownership rule of 1358-a.

Test FUNCTIONS go into an existing `vcx/timing/*_test.v`, not a new file: every
`*_test.v` links its own binary over the whole module graph, and this lane is in
the gate's serial tail (AGENTS.md, "Test files, not test functions, are the unit
of compile cost").

## Implementation order

1. `sch_now()` at every `virtual_now` site.
2. `SchedTimer.owner`, captured at arm from `env.current_worker`.
3. `sched_reset_state` → `'wall'`.
4. the harness's `:manual` setter, called after `new_env` in
   `vcx/tests/code_eval_fixtures_test.v`.
5. `--manual-clock` on `cx FILE`, mirroring `--strict`.
6. the pump at the blocking cancellation points and the serve loop, with the
   sleep slice capped at the earliest due deadline.
7. the seven `vcx/timing/` assertions.
8. spec: §2.2's status note and §3.3's selectors, in a commit carrying
   `RULED: 1358-a` … `RULED: 1358-d`; `make spec-freeze-gate` before push.

Unblocks: `cx flow serve` (WF-28) and #1313's implementation half.

## As implemented — four things the tree said that the letters did not

Recorded because each is a place where following the ruling verbatim would have
produced something wrong, and the next reader deserves the correction rather
than the discrepancy.

1. **`[?select]` has no pump point.** 1358-a names it among "the waits", but
   `eval_select` (`eval.v:20376`) does not block in this evaluator: it probes
   every case once and returns `CXER0202` when none is ready, so its `:timeout`
   case fires at entry and there is no loop to turn. Nothing was added there.
   The other named points are all real and all took the pump.

2. **The `:manual` selector had to be STICKY, not a post-`new_env` call.**
   1358-b says the harness "selects `:manual` through an internal
   loop-construction setter after `new_env`". That alone cannot carry
   `--manual-clock`: `sched_reset_state` runs from `new_env` for EVERY program,
   so a CLI flag set once before evaluation would be erased by the reset. The
   setter therefore writes a process-global (`g_sched_manual_clock`) that
   `sched_reset_state` reads, and both selectors go through it. Same surface,
   same prohibition — no CX verb reaches it — and now the flag survives.

3. **There are TWO in-process conformance harnesses, not one.** 1358-b names
   `vcx/tests/code_eval_fixtures_test.v`'s six `new_env()` sites. But
   `Makefile`'s `test-vcx-conform` banner records that `conformance/stdlib/*.cxd`
   is graded by *the eval lane AND the profile gate*, and
   `vcx/tests/runners/profile_gate/profile_gate.v` has three more `new_env()`
   sites over ring≤1 stdlib cases. Both harnesses take the setter; grading the
   same corpus under two different clocks would have been a false green in one
   of them.

4. **Letter 5 — the fire value's `at=` — SUPERSEDED by `RULED: 1358-e` below.**
   What this item argued (that `1358-c` alone answers it) was wrong on the
   record it matters for: under `:manual` the pair really is inconsistent, and
   `:manual` is where every deterministic replay is graded. Fable ruled the
   question on 2026-09-08 as `1358-e`; the note is kept rather than deleted
   because a superseded argument is evidence about how the question was read.

   Original text of this item:
   The draft found that flow stamps a fire value `at=[$time-now]` (real 2026
   wall time) against a deadline computed from `virtual_now`, which starts at 0
   — i.e. 1970. Under 1358-c the `:wall` clock IS the realtime epoch clock, so
   in production the two now agree and the defect is gone. It survives only
   under `:manual`, where a 1970-origin virtual clock disagreeing with
   `[$time-now]` is the deterministic clock working as designed. No separate
   ruling is needed and none is filed.

## RULED: 1358-e — the fire instant is bound into the fire value

Recorded verbatim in substance from Fable's ruling on #1358, 2026-09-08 09:25
ET. Questions 1, 2, 3, 4 and 6 of the 09:34Z letter set map onto `1358-a…d`
above (that mapping is on the issue and needs nothing here). Question 5 is
ruled:

> **sched binds the fire instant into the fire value from the clock that armed
> the timer**, and flow reads it instead of calling `[$time-now]` at
> `stdlib/flow.cx`. A replay must read a consistent (deadline, fired-at) pair;
> today a fired flow deadline records a 2026 instant against a 1970 deadline.

### What landed

1. **sched (`sch_invoke`).** A callable fire value that DECLARES a parameter is
   applied with the fire instant — a `::datetime` from `sch_now()`, the one
   clock read sched has (`1358-c`). A zero-arg callable is applied with no
   arguments, exactly as before, so nothing in the 43-case corpus moves. A
   builtin, operator or partial fire value is excluded by construction: each
   does its own arity checking over arguments the CALLER chose, so an extra one
   would change what it computes rather than tell it when it fired.

2. **flow.** Both live arming sites (`deadline=` and the `1314-c` re-attempt
   `wait=`) take the instant as a parameter and stamp `at=$at`. flow now keeps
   no clock of its own on the live path — the restored path already read the
   PERSISTED deadline (`789-WF-27a`) and is unchanged.

3. **The instant is the timer's own deadline under the manual drain**, because
   `test-clock-advance` moves virtual-now to each due timer's deadline before
   firing it (§4.2). `sched-044` pins exactly that: a 10-minute timer fires at
   `00:10:00Z` even though the advance runs the clock 30 minutes forward. That
   is the property the defect had inverted.

### What did NOT land, and why it is a ruling rather than a choice

The **channel face**. A `[tick timer=…]` reader has the same second-clock
problem a callback had, and the symmetric fix is an `at=` on the tick. But
`[tick timer=timer-1]` is asserted VERBATIM by twenty `gate=enforced` sched
expectations, so adding the attribute changes twenty prior rulings' recorded
output. Under the standing rule (a `gate=enforced` fixture is a prior ruling
with teeth) that is a ruling, not an implementation choice — drafted as
**1358-f** on #1358 and left unimplemented. `sched.md` §2.1 and
`gates.cxd`'s sched row both say plainly that the tick carries no instant, so
the gap is recorded where a reader meets it rather than left as silence.

The **flow-036 assertion the ruling names** cannot be written as stated, and
that is worth recording precisely: flow never RECORDS `at=` anywhere.
`f--apply-timer` reads `run=`, `step=` and `kind=` and ignores `at=`, and a
fired deadline appends a `[flow-transition status=:failed reason=:deadline]`
that carries no instant — so flow's live fire value is unobservable from a
fixture by construction. Making it observable means either flow recording the
fired instant on the transition (a change to flow's transition vocabulary and
to flow-036's `expired-step` expectation) or sched recording it on its own
`[sched-intent … status='fired']` close entry (a change to sched's durable
entry shape). Both are rulings; both are drafted as **1358-f**. What IS
pinned here is the mechanism, in `sched-044`, at the layer that owns it.
