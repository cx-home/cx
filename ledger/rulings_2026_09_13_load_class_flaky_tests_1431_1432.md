# RULED: 1431-a, 1432-a — two load classes join the classified serial-retry policy

Date: 2026-09-13
Issues: cx-home/cx-private#1431, cx-home/cx-private#1432
Decided by: the integrator, under the owner's delegation. Both issues posted a
single lettered ask; (a) is taken in each.
Related: #1364 (the cmp-005 bounded-memory gauge, the sibling memory gauge),
#1425 (the daemon-start class), #572 / #648 (the classified-retry contract
itself), `spec/03-approved/process/delivery-grammar.md` §4 (a step that fails at
the same commit with no code change is a flaky test; a known one is retried
once).

## The decisions

| id | step(s) | class | what changes | what does NOT change |
| --- | --- | --- | --- | --- |
| 1431-a | `repr-guard` (`bench/repr/run.sh`) | memory gauge under load | the step joins the classified serial-retry policy under a new class beside cmp-005's (#1364): a reading over its bound re-measures ONCE, serially, before the run fails; `bench/repr/run.sh` records the machine load average beside every reading | `BOUND_xml=8.35` is NOT re-pinned; no bound moves; a driver failure, an unparsable measurement or a second exceedance is still a real failure |
| 1432-a | `vcx/code/code_module_umbrella_test.v`, `vcx/tests/code_eval_fixtures_test.v` | timing / early exit under load | both steps join the policy under a new class beside #1425's daemon-start class and 1431-a's; the fixture grader records the `cx` build identity at its start and at its first failure, so an early exit names its cause | the 42 ms bound in `test_retry_without_delay_does_not_suspend` is NOT loosened; no fixture, case id or expectation moves |

## Why 1431-a

The post-merge run on `984cd3c99` (2026-09-12 19:01Z–19:38Z) failed at
`repr-guard`:

```
xml         2128015     19026199    8.941     8.35   FAIL
bench/repr: FAIL — lane xml live multiplier 8.941x exceeds the pinned bound 8.35x.
```

That merge was ledger-only (`ledger/rulings_2026_09_12_*.md`) — the code is
byte-identical to `469ec08e7`, whose run **passed the same step at 13:53Z the
same day** — and the retry on the same head (`gate-loop.rerun`, 19:41Z–20:28Z)
passed. Same commit, no code change, opposite verdicts: delivery-grammar §4's
definition of a flaky test, and a known one now.

The reading is load-sensitive by construction: `bench/repr` measures live bytes
over input bytes and under `-gc e` the collection point moves with scheduler
pressure. The load average at the failure was **~300** (a pre-merge
`test-changed` full union at `-j12` plus five agents building) — an order of
magnitude past the "eight saturating CPU burners" the instrument was calibrated
against (`bench/repr/run.sh`, the ratchet block). `BOUND_xml=8.35` is baseline
7.941 + 5 %, and re-pinning it to accommodate a load reading is exactly what
RP-5 forbids; the answer is a second measurement, not a wider bound.

The load average joins every row because a number with no context is not
classifiable after the fact: #1431 had to be reconstructed from the runner's
own log to learn the machine was at 300. The next such row says so itself.

## Why 1432-a

The post-merge run on `5193e3752` (2026-09-13 03:20Z–03:51Z) ran at load
averages of **190–218** (two pre-merge pipelines building at `-j` on the same
machine). Four test files failed; two passed on their classified serial retry
(`net_real_socket_test.v`, `process_pty_test.v`). The two with no retry class
failed the run:

1. `code_module_umbrella_test.v:2730 test_retry_without_delay_does_not_suspend`
   — `delay=0 must not suspend: 42ms elapsed` against its 40 ms bound. A
   wall-clock bound on a scheduler under a load of 200 measures the machine, not
   the code, and **nothing in the head's merges** (#1394 routes, #1405/#1292,
   release notes) touches the retry path. The bound stays: it is the control row
   that keeps `test_retry_backoff_really_suspends`'s 60 ms floor from being met
   by any slow evaluator, and widening it is what would make that pair vacuous.

2. `vcx/tests/code_eval_fixtures_test.v` — `FAIL [11/66] C: 405943.8 ms,
   R: 13832.684 ms` with **no assertion text**. The grader runs 20+ minutes over
   4583 fixtures, so a 13.8 s exit is a process that died rather than a case that
   failed, and the run log shows a parallel step relinking `libcx.dylib` / `cx`
   in the same minute. The same tree's fixtures passed on the branch (4583
   fixtures, 0 enforced failures).

An early exit with no assertion is unclassifiable from its own output, which is
how this one cost a full run to diagnose. The grader therefore states the build
identity it started against (`vcx/target/cx.buildid` and its `.writer` sidecar,
#1056) in its first line, and re-reads both at its first failure: a stamp that
MOVED between those two reads names a mid-run relink as the cause, in the
grader's own log, without anyone correlating timestamps across steps.

Note for the reader: this grader links the `cx` module as SOURCE and execs no
`cx` binary, so "its first exec failure" in the issue's ask is implemented as
its first failure — the point at which the record can still be written, and the
only point at which the delta is meaningful.

## What was rejected

- Re-pinning `BOUND_xml`, or widening the 42 ms bound. Both were named "not
  asked for" in their issues and both would convert a measuring instrument into
  one that cannot red. The ratchet is not loosened to accommodate load (RP-5).
- Skipping either step under load (a threshold on the load average that
  self-skips). A step that stops grading on a busy machine grades nothing on the
  machine that is always busy; the retry keeps the verdict and pays one
  re-measurement for it.
- Leaving `repr-guard` out of the roster check. Its class is bound by
  `check-serial-retry-rosters` like every other: a roster row naming a file that
  does not exist is that step's red, so this class cannot go vacuous the way the
  retired `store_grpc_parity_test.v` row did.
