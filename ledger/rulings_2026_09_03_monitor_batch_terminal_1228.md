# Rulings 2026-09-03 — #1228 follow-up 2: the monitor batch `[?receive]` with nothing collected

**Status: RULED (a) by the owner, 2026-09-03 ("a"). Ruling id: 1228-Q1a.**

## The finding

`[?receive from=$mon max=N …]` over a MONITOR answered the empty sequence `()` when it collected nothing
because the monitor was closed, already drained (its terminal delivered), or named an unknown worker.
The same batch form over a CHANNEL (`channel_sub_receive_batch`) answers `CXER0200` for closed / drained
with nothing collected. Observed while fixing #1228 (the deadline defect) and left as-is there to keep
that change to the deadline. A deadline that expires on a LIVE worker with nothing collected answers
`()` on both forms and is not in question.

## Q1 — what the monitor batch form answers with nothing collected (RULED: a)

- (a) **TAKEN — align with the channel form.** Closed or drained with nothing collected → `CXER0200`
  (the channel-family terminal); an unknown worker → `CXER0222` (WORKER_NOT_FOUND, what the single form
  already answers). What it DELETES: the silent `()` on a terminal condition. What it KEEPS: `()` for a
  deadline expiry on a live worker; every collected-then-terminal case still returns what it collected
  (the terminal surfaces on the next receive, as on the channel form).
- (b) keep `()` and document it as the monitor form's own behaviour — rejected: two batch forms with
  different terminal answers for the same condition is exactly the kind of surface inconsistency the
  orthogonality objective exists to prevent.
- (c) leave it unrecorded — rejected: measured and known.

## Execution notes

- `monitor_receive_batch` (eval.v): the closed / drained / unknown-worker `break`s with `out.len == 0`
  become the err answers above; with `out.len > 0` they keep breaking (collected items win, the terminal
  comes on the next receive). The deadline branch is untouched.
- Spec: the `[?monitor]` section of code.md states the batch form's terminal answers by name, mirroring
  the `[?receive]` channel wording (refer by section title).
- Fixture first: a batch receive on a drained monitor answers CXER0200; on an unknown worker CXER0222;
  a deadline receive on a live worker still answers `()` (the #1228 shape).
