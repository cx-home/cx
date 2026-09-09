# RULED: 1313-d — `test_flow_serve_four_kinds_and_the_nonce_rule` asserts completion BY IDENTITY, and bounds the schedule kind's in-flight count

Date: 2026-09-09
Issue: cx-home/cx-private#1313
Drafted by: worker B (Opus), campaign #1354, on #1313 at 04:52Z, with the
full-matrix classification on #1354 at 04:51Z. Approved by: Fable + owner,
2026-09-09 04:15 ET, letter (a), recorded on #1313 at 07:15Z and on #1354.
Related: `789-WF-28a` (`--for` is a tick BUDGET, not a wall-time window) and
`789-WF-28b` (the two assertions this test already had retired on load
grounds: `ticks >= 6` as vacuous, `sched < ticks` as load-flippable);
`1265-PB-2`; `spec/03-approved/std-lib/flow.md` §4.2, §4.25;
`vcx/cmd/flow_serve.v:772-785` (`fs--advance-run`) and `:855-865` (the turn's
order); `stdlib/flow.cx` `f--init-record` (the record's `actor=`).

## What was wrong — in the assertion, not in the product

The `aa160b22c` full matrix failed this test:

```
flow_umbrella_test.v:928: fn test_flow_serve_four_kinds_and_the_nonce_rule
    assert rec.contains('status=:done')
    Message: a started run did not reach :done: [flow-run id='flow:sha2-256:4822dd23…'
      flow=sha2-256:ee9d3a4d… status=:running actor=principal:did:key:z6MkSched
      … [step name=sweep status=:waiting pivot=true]]
```

`flow=sha2-256:ee9d3a4d…` is `nightly.cx`, the payload-free document the
SCHEDULE binding starts. Four measurements settled it as a LOAD FLAKE over a
correct record rather than a defect:

1. The same code is green in a full gate at `b2c4d4f14`
   (`vcx/target/gate.log:122514`, `OK [25/62]`).
2. `git diff --stat aa160b22c b2c4d4f14 -- stdlib/flow.cx vcx/cmd/flow_serve.v
   vcx/cmd/flow.v vcx/tests/flow_umbrella_test.v` is EMPTY — the two verdicts
   are the same code, which makes the row non-deterministic by definition.
3. 16 standalone repros under gate load never reproduced it (12–13 runs per
   repro, `NOTDONE=0`, `ticks=10 elapsed-ms≈2877`).
4. The obvious "started too late to be advanced" race does NOT exist: the turn
   is `fs--tick-one` over every binding and THEN `fs--courier`, one flat
   `[?let]`, `[?sleep]` after both — so a run started by the FINAL turn's tick
   is advanced by that same turn's courier.

The printed record is a run correctly mid-flight. What is left is one line of
mechanism: `fs--advance-run` answers `[skipped run=… reason=<code>]` when
`[$cxflow:advance]` errs and the courier makes **exactly one attempt per run
per turn**, so a skip on any turn but the last is retried and a skip on the
LAST turn is unrecoverable. The named candidate refusal is `CXER1114` from
`f--cas-exhausted` — under load the ingress thread, the concurrent
`fsv_flow_streams` probe process and the courier all touch one file journal —
and it was NOT observed, so it stays a candidate, not a finding.

## The ruling

**(a)** `:done` is asserted BY IDENTITY for the four bounded kinds — the hook
run, both file runs and the intent run — each named by its binding's `as=`
principal, which `f--init-record` carries verbatim onto the record off the
`:started` transition. For the SCHEDULE kind, `sched >= 2` stays (recurrence,
stated against measured `elapsed-ms` and not against a ratio) and the test
gains **`sched-in-flight <= 1`**: every schedule run except at most the NEWEST
is `:done`, so a courier that stopped advancing mid-window leaves several and
still reds. The comment in the test names this ruling beside the two WF-28b
retirements.

The concession is a true statement about a `:fixed-delay` courier under a tick
budget: `--for` is a BUDGET (`789-WF-28a`), so the number of occurrences is a
function of wall time and the newest occurrence's run has exactly one advance
attempt before the budget ends.

**Refused:** (b) one courier turn of slack past the last occurrence — a margin
is a function of box speed, which is the property WF-28b retired twice already;
(c) leave it and re-run on failure as a classified flake (the #1125 pty
treatment) — a real courier regression would read identically to the flake and
nobody would look twice.

## What landed

`vcx/tests/flow_umbrella_test.v`, one test, no product change:

- the run loop classifies each journal stream by its binding principal
  (`z6MkSched` / `z6MkHook` / `z6MkFile` / `z6MkIntent`) and is TOTAL — a run
  belonging to no binding reds, so the classification cannot go vacuous;
- the hook run is additionally pinned to the run id the delivery answered
  (`hook_id`), so a second webhook run reds;
- the two file runs must include exactly one carrying `o-file2`, which is the
  CHANGED-bytes event stated as identity rather than as a count delta;
- the intent run must carry the committed entry as its `[args …]`;
- the schedule arm asserts `flow=<nightly address>` per run — a run of another
  document under that principal would mean the binding rows crossed — plus
  `sched >= 2` and `sched_in_flight <= 1`.

`others == 4` is kept as the sum check over the four named kinds.
