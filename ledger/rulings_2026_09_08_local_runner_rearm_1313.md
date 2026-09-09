# RULED: 1313-b — `cx flow run` re-arms the WHOLE journal, each timer under its run's RECORDED basis

Date: 2026-09-08
Issue: cx-home/cx-private#1313
Drafted by: worker B (Opus), campaign #1354, on #1313 at 18:35Z. Approved by:
Fable + owner, 2026-09-08 16:25 ET, letter (a), recorded on #1313 and #1354.
Related: `789-WF-27a` (`ledger/rulings_2026_09_06_flow_liveness_and_standalone_runner_789.md`),
which deleted this issue's filed premise; `789-WF-28a` (`cx flow serve`);
`1265-PB-1` (a step is admitted against the RUN's recorded basis) and the
commit that first applied it to a restored timer, `dbe776fcd`; #1322 (the
`rearm` verb and `on-missed` by kind, closed);
`spec/03-approved/std-lib/flow.md` §4.15, §4.9, §4.2, §4.10, §4.12;
`spec/03-approved/std-lib/sched.md` §2.5, §3.2.

## The defect

`flow.md` §4.15 gives the local runner's posture — no liveness of its own,
and timers "re-armed on the next invocation". **Nothing implemented the
second half.** MEASURED: zero occurrences of `rearm` in `vcx/cmd/flow.v`, at
`82f222963` when the branch was written and still at `4d128743b`. The
generated `run` program opened its journal and went straight to `start`, so a
parked run whose deadline elapsed while no process held the journal stayed
parked for ever — the defect #1313 was filed about, minus the premise
`789-WF-27a` deleted ("the deployment host is THE scheduler", which would
have made ladder rungs 1 and 3 permanently second-class).

## The ruling

**(a) `cx flow run` calls exactly the `rearm` that `cx flow serve` calls** —
the whole journal's pending timers, each with its run's RECORDED basis —
between opening the journal and `start`. §4.15's local-runner row gains the
clause: the next invocation over that JOURNAL re-arms every pending timer it
carries, and the same-command-line rule (the run id is derived from the args,
RULED: 1265-PB-2) governs only which run `start` then resumes. One law, three
runners; no new public surface.

Added to the record by Fable: **a capability refusal raised while firing
ANOTHER run's timer is recorded on THAT run's journal as its own refusal,
never swallowed and never attributed to the invoking run.** That holds by
§4.2's act-refusal path, which records the command's own code and message on
the step of the run `advance` was called for.

REFUSED **(b)** "only the invoking command line's run": it needs a scoped
`rearm` (a new `opts.run`, or a `restore` over one intent) — new W1 surface —
is unobservable in a one-flow checkout, so it would ship untested in exactly
the case that distinguishes it, and it strands every other parked run in that
journal. REFUSED **(c)** "no timers in the local profile": it contradicts
§4.15, which already promises the re-arm.

## What (a) required beyond the call

`rearm` folds the whole journal, so one call restores timers for runs many
different principals started, in many different streams, against many
different documents. `dbe776fcd` had already found and fixed the first
consequence — the BASIS — by reading `actor=`/`authority=` off the run's
record when the timer fires (`f--rearm-basis`), against a measured defect: a
run recorded under `z6MkOwner` had its restored deadline's compensation
appended under `z6MkFirstRow`, the first `[on …]` row's binder. That fix
stands and its reasoning is unchanged; what follows extends it, and one part
of it repairs a silent fallback in it.

Two consequences were left, and both are certain from the code:

1. **The stream.** `f--home-stream` prefers `opts.stream` over the run id, so
   an invocation carrying a stream — `cx flow run --stream S`, or
   `cx flow serve`'s own opts — made every re-armed timer's `advance` read AND
   append **that** stream for a run whose transitions live elsewhere. The read
   finds no `:started` there, so the timer fires into a not-found refusal and
   nothing is recorded.
2. **The fire-time read degenerated with it.** `f--rearm-basis` performed its
   record read through the same `[f--home-stream $opts $id]`, so for any run
   that is not the caller's it found nothing, fell back to the caller's opts,
   and the defect it was written to fix returned — silently, because a
   fallback that is correct for the one-run case is invisible in it.

Both are fixed by deriving all of it from the run's own record at arm time —
`actor=`, `authority=`, the stream it was found in, and `flow=` for the pin.
The basis values are the same immutable ones the fire-time read looked for; a
run's basis is written once, at `start`.

**And a measured fact that shaped the fix, worth recording on its own.** The
first attempt folded the `:started` rows out of the entry sweep `rearm`
already performs, on the assumption that the sweep sees the journal. It does
not: `[$journal-since $journal 1 "" {}]` returns the **DEFAULT stream only**.
That is where `sched` appends its `[sched-intent …]` rows — which is why the
pending fold works over it — and a run's transitions are in the run's own
home stream (its id verbatim by default, §4.11 RULED 1265-PB-3, or wherever
its starter's `opts.stream` put them). Measured 2026-09-08 with a two-entry
journal: `[default-stream 1] [order-p 1]`, the intent in the first and the
transition in the second, and `journal:query` over `//flow-transition` and
`/event/flow-transition` both answered 0 hits. So there is no all-streams
sweep to fold, and the record has to be LOCATED: the run's own id first, then
the stream the invocation carries — two reads at most, one in the ordinary
case, the same order of cost as the per-fire read this replaces, moved to
boot where a finding can still be reported. A run neither read finds is not
re-armed and is named in the `[orphan …]` rows.

## The one thing §4.15 left open, and how it is settled

A pending flow timer whose run pinned a **different document** than
`opts.flow` cannot be driven by this invocation at all: `advance` refuses a
document it did not pin (`f--check-pinned`, §4.10). Re-arming it would arm a
callback that can only refuse, and a refusal inside a timer callback reaches
no record — an invisible failure at fire time, replacing a visible finding at
boot. It is therefore **not re-armed and stays an `[orphan …]` row in the
`[restore-report …]`**. A run with no readable `:started` is the same case.

This is not a new rule: it is the rule `sched`'s own `restore` states — "a
runner never re-arms, and never buries, a timer it does not own"
(`sched.md` §3.2, and the verb's `[fn-doc]` summary) — and the identical
answer `rearm` already gives a non-flow intent (§11b, "A NON-FLOW INTENT IS
LEFT ALONE"). It is recorded here rather than left implicit because a reader
could otherwise expect a two-flow checkout to be fully re-armed by one
command. **Flagged on #1313 for Fable to overturn if it is judged new design
rather than the application of an existing rule.**

## Corpus position

`conformance/gates.cxd:75` enforces the flow module. The four `rearm` cases
`flow-051`, `flow-052`, `flow-054` and `flow-055` each seed (or `start`) a
run whose recorded `stream=`, `actor=`, `authority=` and `flow=` are exactly
what the invoking opts carry, so the derived opts equal the forwarded ones and
**no gate-enforced fixture moves.** That is checked case by case, not assumed:
it is the reason both defects above were invisible.

`flow-063` is added for the case the four cannot see: one journal, two parked
runs, neither of them the invoker's — one whose document the invocation holds
(re-armed, fires, compensates on its OWN stream under its OWN basis) and one
whose document it does not (orphaned, untouched) — with a third actor and a
third stream on the invocation.

Both parked runs are seeded in their DEFAULT home streams (the run id
verbatim), which is the production shape — `cx flow run` passes no
`--stream` — and the invocation carries a third stream, `order:boot`.

MEASURED at `4d128743b`, before the change, with the fixture's own program
run against that tree's own binary:

```
[probe [report rearmed=2 skipped=0 orphaned=0] [p-run :running]
       [p-basis actor=did:key:z6MkP] [p-reserve [row status=:running]]
       [r-run :running] [invoking-stream-entries 0]]
```

`rearmed=2` — it re-armed the run it cannot drive — and the long-expired
`:fire-all` deadline of the run it could drive **never fired**. The expected
answer after the change is `rearmed=1 orphaned=1`, `p-run :compensated`,
`[row status=:failed reason=:deadline]`, `r-run :running`.

## The re-arm had to FIRE, and that took a safepoint

§4.15's row promised more than arming: "the next run finds the parked run and
FIRES what is due". A re-arm whose timers never fire is a seam with no
consumer, and that is what the first working version shipped: the generated
`run` program had no safepoint between `rearm` and `start`, and a due timer
fires at the process's next blocking cancellation point (RULED: 1358-a) under
the production `:wall` clock (RULED: 1358-b).

MEASURED at `c39be6437` over `flow-063`'s journal, wall clock, in that
program's own shape:

```
no sleep / [?sleep 0ms]  →  rearmed=1, reserve :running                (no fire)
[?sleep 1ms]             →  rearmed=1, reserve :failed reason=:deadline,
                            run :compensated                           (the ruled answer)
```

So the invocation now reaches one safepoint after the re-arm and before its own
`start`. 1 ms is not a wait dressed as a fix: what is needed is the SAFEPOINT,
and 1 ms is the smallest cadence the language admits — `cx flow serve`'s own
tick floor. It is skipped entirely when nothing was re-armed, so an ordinary
invocation over a journal with no pending timer pays nothing.

The ORDER is part of the rule and is stated in §4.15: a deadline that elapsed
BEFORE this invocation belongs to the record it was armed against, so it fires
on its own run, under its own recorded basis, before the invoking run starts.
