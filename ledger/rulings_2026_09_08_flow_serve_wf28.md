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

---

# RULED: 1265-WF-40, 1265-WF-41 (Fable + owner, 2026-09-08 15:20 ET)

Both answer letters drafted by worker B during the WF-28 landing. The owner's
frame, recorded because it governs how each was decided: flow is foundation,
alongside XAP, UX, SSO, Store and Fabric — it must work from one-shot scripts
to enterprise orchestration, performant, reliable, durable, high-trust.
**Neither ruling lowers a bar; each dates one.**

## 1265-WF-40 — the admission sentence in W1

Three normative sentences (`flow.md` §4.5, `flow.md` §4.23, `misc/cli.md`'s
serve capabilities bullet) said every step is *admitted at the PEP against the
run's recorded basis*. Measured, by reading every site on the path: **no
actor-keyed decision exists anywhere on flow's act path.** `f--perform-act`
(`stdlib/flow.cx:2926-2930`) passes exactly `{compensate: true}` to the seam;
`coord_flow_perform` (`vcx/platform/coordination.v:156-208`) reads only
`compensate` and calls `command_invoke_labeled`, which has no principal
parameter; `stdlib/flow.cx` never calls an authz verb; and `advance`'s only
basis check is NON-EMPTINESS (`f--check-basis`, `:3085-3092`) — it never
compares `opts.actor` against `$rec@actor`. What the basis does is real and is
now correct at both runner sites: it is the **attribution** on the journal
entry, inside its canonical bytes.

**Ruled 1(a) WITH A CONDITION: the requirement stays normative and dated; it is
not deleted.** Each of the three sentences now states what W1 does and
guarantees — the recorded basis is the attribution, never the runner's and
never a binding row's, fixtured at the courier and at the boot `rearm`; and
admission in W1 is the acting process's own capability gate (`[effects]`
narrowing, `[idempotent]` dedup, the `[requires-at]` bracket, `CXER0271` at the
act's effect point). **The same paragraph keeps the law**, as a normative,
dated requirement: every step is admitted at the PEP against the run's recorded
basis, **landing with the W3 performer axis, bus-side** (`authz.cx:5-7` —
authz DECIDES, the bus is the single ENFORCEMENT point that calls `check`),
the first rung at which an act is performed by someone other than the runner
and therefore the first at which the decision has a second answer to give. An
adopter reads a true spec that still promises per-run admission and says which
rung delivers it. The W3 landing inherits it as a named exit gate.

REFUSED — (b) an enforcement point inside `stdlib/flow.cx`: the wrong layer,
and it would be torn out when the bus does it. REFUSED — (c) leaving the
sentences as they stood: a law on the page with nothing behind it is the exact
condition under which two basis defects shipped unseen (the courier's, and
`rearm`'s twin found by WF-28's owed fixture).

## 1265-WF-41 — rung 1 exits on §4.16 flow 3 alone

Flows 1 and 2 were chosen to exercise `:principal` / `to=role:owner` and
`:agent` under `[bounds]` — the performer axis W1 does not implement and
`validate` refuses by naming its W3 landing (`stdlib/flow.cx:544-555`). They
land WITH that axis, in the change that makes them expressible. The dogfood
gate's property D (every `flows/*.flow.cx` must have a covered row, over a
non-empty case list) means they cannot land unnoticed.

REFUSED — (b) rung 1 waits for all three: it makes rung 1 a W3 milestone and
the ladder's own ordering self-contradictory, since rung 1 is defined by
`cx flow run`. REFUSED — (c) placeholder `:runner` documents: the "reads as
working, is inert" shape §4.24 already refuses for binding rows.

**Implementation note, recorded rather than glossed:** the rung-1 dogfood gate
landed at `89c4bed87` — `flows/repo-gate.flow.cx` plus `flow-dogfood-gate` in
`TEST_TARGETS`, green as `flow-dogfood-gate OK — 1 dogfood flow document(s), 5
cases` — about eight minutes BEFORE this ruling id existed, so its commit
(`86e66e659`) carries no `RULED: 1265-WF-41` token. The ruling ratifies exactly
what landed; this record is where the token lives.
