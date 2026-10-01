# Owner decision 2026-10-01 ~18:5xZ — Letter 160, "recommendations accepted": the merge flow admits generated output behind the head, bug batches are the unit, opus runs every premerge-flow round, four rounds run continuously; the session hands off to another account when this one's weekly expires

**Status: RULED (owner, 2026-10-01 ~18:5xZ, in session, on the integrator's scorecard — three landings in 6.6 hours,
143 open, the hours measured as a hard stop, regrade churn, parked sonnet turns and one-issue rounds — and
Letter 160 posted on [#1591](https://github.com/cx-home/cx-private/issues/1591) at 18:4xZ). MADM-1, MQUE-1,
SHIP-1, SHIP-2, DELEG-3, OVER-1, INT-9, INT-21, RS-36, CXF-1.**

## The owner's words, verbatim

"scorecard and eta's? moving too slow. How to speed up but not overspend on tokens and keep soundness and
quality up?" — "we'll switch to another account when this one expires its weekly window. recommendations
accepted"

## MADM-2 — a branch behind a head whose extra diff is only generated output is admitted (L160 = (a))

MADM-1 admits a behind-head branch when the head's diff since the branch's merge-base is confined to ledger
additions and to pin rows of repositories the branch did not move. Measured on 2026-10-01: every landing
regenerates docs/llm pages, docs/*.html and the registry census tables (TIMEP-1's landing at 14:36Z sent
DBVOL-1 through a second regrade; LINTB-1's at 18:02Z sent READR-1 and WORDS-2 through a merge, deps-sync and
`make docs` each), so the rule refused the branches the generators would have reconciled anyway. Ruled: the
admitted set gains the GENERATED files — every path `scripts/gen_docs` and `scripts/gen_guide` write (docs/llm/*,
docs/*.html, docs/llm/llms*.txt, the generated tables of docs/llm/contributor-*.md) and the generated census
rows the registry generators write — because the post-merge loop regenerates and grades the union: a
hand-written page, a Makefile, a standing-rules file, a spec, a fixture, a script, a flow document or a
rewritten ledger page keeps the refusal with the path named. The admitted set is the generators' manifest,
not a hand list, so a new generated file joins it by being generated. Held by a case table in
`flows/sim/merge/` (admitted: only generated pages moved; refused: a hand-written docs-src page moved;
refused: a generator script moved), red first, `make merge-flow-gate` green. Rejected: (b) the rule kept
and landings batched (the churn stays wherever two land in one window); (c) admitting any docs path (a
hand-written page lands ungraded).

## The three operating takings ruled with it (L160 = (b), (c), (d))

(b) A bug batch of six to eight issues per repository is the unit of a round (SHIP-1's batching made the
default); the audit's labelled backlog goes by repository. (c) Opus runs every round that runs a
premerge-flow; sonnet runs ledger and notes edits only (three sonnet rounds parked on background polls on
10-01 and one reported READY with a required step unrun). (d) Four rounds run continuously, launched at each
window's start, never stopped for the meter (OVER-1: zero extra usage; the measured capacity is about
twenty round-hours per window). The session hands off to another account, Letter 157's shape, when this
account's weekly expires (10-06 13:00Z or sooner at 100 %).
