# Ruling record — #1075 pipeline rows when the deadline stops a stage (2026-09-04)

Issue: #1075 (bug, area:cx-stdlib, prio:medium). Spec: `spec/03-approved/std-lib/process.md` §3.3.
Sibling landed in the same commit: #1073 (`signaled` from the real wait status; `signal` implemented).

## The defect

A 3-stage pipeline whose stage 1 is killed at the deadline returned ONE `[proc-result]` row and
`[exit-codes 143]`: the stage loop `break`s at the timed-out stage and the row assembly walks
`exit_codes`, so stages 2 and 3 — which the deadline stopped before they started — have no row at all,
though §3.3 says each stage row reports that stage's own `stderr` and `timed-out`. Not a resource
issue (0 zombies, fds flat); purely result assembly.

## Question 1075-Q1 — what row does a stage the deadline stopped before it started get?

- **(a) RULED — every declared stage gets a §2.3 row, in order.** A stage that never ran reads
  `exit-code=null signaled=false signal=null timed-out=true stderr=''` with its `[argv …]`: `null`
  exit code is the existing §2.3 convention for "no such status" (the `signal=null` shape), and
  `timed-out=true` is literally true under §4.3's one-deadline-for-the-run — the budget expired
  before the stage could run. `[exit-codes …]` keeps ONE entry per stage that produced a status
  (the pipefail aggregate is unchanged). No new attribute, no new element. DELETES: the truncated
  result; a consumer indexing rows by stage position can now do so.
- (b) add a `started=false` attribute to the row — a new §2.3 attribute for one pipeline case;
  `exit-code=null` already carries the fact.
- (c) keep the truncated rows and document them — the reporting gap the issue names.

Ruled (a) under the standing letter-acceptance order (campaign authority 2026-09-04). Id: **1075-Q1a**.

## #1073 (no ruling needed — §2.3 already says it)

`signaled` was inferred as `exit_code > 128 || timed_out`, so `sh -c 'exit 143'` read
`signaled=true`. V's `os.Process` records the real wait status: `WIFSIGNALED` → `status == .aborted`
and `code = 128 + WTERMSIG`. `signaled` now reads the status; `signal` names the delivering signal
(`os.sigint_to_signal_name`, e.g. `SIGKILL`) and is `null` otherwise — the attribute §2.3 has shown
since the spec was written and the builder never emitted. Every `[proc-result …]` pin moves by the
inserted `signal=…` attribute (nine fixture rows + one V pin), named movement.

## Execution record

- `proc_result_element` gains `signal string` ('' → null); `run` derives both from `p.status`.
- pipeline: per-stage `aborted`/signal captured; after the loop the never-started stages get their
  rows; `exit-codes` unchanged.
- Fixtures: `process-098-normal-exit-above-128-is-not-signaled` (signaled=false signal=null), `process-099-terminating-signal-is-named`
  (`kill -TERM $$` → exit-code=143 signaled=true signal='SIGTERM'), `process-100-pipeline-timeout-keeps-every-stage-row`
  (3 rows; rows 2–3 exit-code=null timed-out=true).
- §3.3: one sentence on the never-started row; §2.3 example unchanged.
