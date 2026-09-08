# RULED: WF-28a, WF-28b — `cx flow serve`'s courier cadence and the occurrence invariant

Date: 2026-09-08
Issue: cx-home/cx-private#1265
Drafted by: worker B (Opus), campaign #1354. Approved by: Fable.
Prior records that bind this one: `789-WF-27a` (liveness belongs to the runner
PROCESS; `rearm` at boot), `789-WF-28a` (the runner document, the one binding
vocabulary, the embed gate), `789-WF-32` (what a courier tick reaches),
`1265-PB-1` (the one seam; a run records the basis it is admitted against),
`sched.md` §2.2 (`every` recurs `:fixed-delay | :fixed-rate`, default
`:fixed-delay`).

## What needed ruling, and what did not

`789-WF-28a` ruled the runner document, the kinds it serves, the embed gate and
the courier's reachable set. It did not say what `[courier every=D]` PROMISES,
and the corpus was pinning the occurrence invariant through a ratio that a
loaded machine can flip. Both were found by implementing the runner, and the
first turned out not to be a defect at all.

## The measurement that drove it

`vcx/cmd/flow_serve.v` computed the runner's tick budget as

```
ticks := if for_ns <= 0 { i64(-1) } else { for_ns / r.courier_ns }
```

`--for 1500ms` at `every=150ms` makes that **exactly 10, always**, carrying zero
wall-time information. `flow_umbrella_test.v` then asserted `sched < ticks`
(distinct 300 ms occurrence buckets against the constant 10) and
`ticks >= 6` — the second vacuous by construction, and its message
(`'the loop ticked ${ticks} times in 1500ms'`) shows its author believed the
constant was a measurement. Both assertions were worker B's own. The gate red
was the first, on a box under load: ten turns spanning more than ten 300 ms
buckets is not a defect, it is the cadence working as specified.

Ruled out by reading rather than by elimination: the occurrence bucketing is
exact (`fs--tick-schedule` buckets in MILLISECONDS — `$mod` reduces through f64
and an epoch instant in ns is past 2^53, which is why the ms rewrite was needed
and why the `[runner]` reader refuses a sub-1ms `every=`), and the dedup is
sound (an identical nonce gives an identical run id; three byte-identical
webhook deliveries yield one `[flow-run …]` and two `[deduped …]` in the same
fixture).

## WF-28a — `[courier every=D]` is `:fixed-delay`, sched's own default

The next turn begins `D` after the previous turn's work RETURNS. The real
period is `work + D`; turns are never queued to catch up; **a runner's
advertised cadence is a floor, not a rate.** `flow.md` §4.23 says so and cites
`sched.md` §2.2, where that is already the default for `every` — so the runner
implements the language's documented cadence and diverges from nothing.

REFUSED — `:fixed-rate` (the runner sleeps `D − elapsed`): it needs a
computed-remainder sleep that does not exist (`[?sleep]` takes a duration
LITERAL and refuses a bound value, CXER0100, measured — which is why the loop
splices the literal the document spelled), and it would make the runner the one
place in the tree where a cadence diverges from sched's default. If a rate mode
is ever wanted it is a `mode=` opt on `[courier]` over this default, not a
silent reinterpretation of `every=`.

REFUSED — leaving it unspecified: it is the runner's one statement about its own
liveness and it is already load-bearing in two fixtures.

## WF-28b — the corpus pins the invariant DIRECTLY, and `ticks=` stops posing as a measurement

**Primary.** "One run per OCCURRENCE, not per tick" is pinned by driving TWO
courier ticks inside ONE schedule period and requiring EXACTLY ONE run —
`--for 2·D` at `[courier every=D]`, which is a deterministic two-turn drive
because `--for` is a tick BUDGET and not a wall-time window. The schedule row's
own period is made wide and PHASED so that two turns cannot straddle an
occurrence boundary under any load: `every=1h at="00:MM"` with `MM` half an
hour away from the current UTC minute leaves a ~30-minute margin on both sides.
That is the invariant itself, and no machine speed can decide it.

**Alongside.** `[runner-stopped …]` reports `elapsed-ms=` beside `ticks=`, so
`ticks=` is read as the budget it is and any claim about the PERIOD is written
against real elapsed time. The runner measures it on the same clock the
occurrence buckets are computed on (`[$time-to-unix-ms [$time-now]]`, exact
integer ms — `[/ …]` is exact-or-CXER3002 and would answer a float here).
`cli.md`'s `--for` bullet documents both fields and which is which.

**Deleted, not widened:** the vacuous `assert ticks >= 6` and the load-sensitive
`assert sched < ticks`. The four-kinds fixture keeps `sched >= 2` — recurrence,
which ≥1500 ms of REPORTED elapsed over a 300 ms period guarantees — and the
occurrence invariant moves to a fixture of its own.

REFUSED — 2(a), widening `every=` to `3s` and relaxing `sched >= 2` to `>= 1`:
it still infers the invariant from a ratio, and it leaves the vacuous assertion
vacuous.

## Ratified as a defect fix against `1265-PB-1`, no ruling needed

`fs--courier` bound `$b [$first $bs/*]` and gave that ONE binding row's `as=` to
every run it advanced — but the courier reaches every pending run in the journal
whichever binding started it, so a webhook-started run was couriered under the
SCHEDULE binder's identity, as both actor and authority. It contradicted this
verb's own help text in the same commit ("every step is admitted against the
RUN's recorded basis, never the runner's"). It now reads `$rec@actor` /
`$rec@authority` off the record already in hand; `$b` and `$bs` are dropped
rather than left dead.

No test caught it and none would have: the fixture's couriered flow was a single
pivot step terminating on the start's own drive, so no couriered step ever needed
a grant the schedule binder lacked. **Correct under the one document the test
happens to use is exactly the shape that ships.** A fixture whose couriered step
is a SECOND step, carrying the run's own basis, is owed in the same landing.
