# Integrator decisions 2026-09-30 — Letters 143 and 144, taken under DELEG-3 on the owner's "we want to speed up where possible": the merge flow admits a branch behind a head that moved only the ledger or other repositories' pins, and READY branches land from a queue the loop consumes

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~11:2xZ, in session: "has splitting the repos
helped us speed up work?" — "we want to speed up where possible"; DELEG-3). RFLOW-1 (L96–L104),
RUN-4, RUN-5, INT-10, OL-3, CXF-1, DOCS-51 §9, SHIP-1.**

## The owner's words, verbatim

"we want to speed up where possible"

## What was measured on 2026-09-30 before 11:2xZ

Four regrades in one night for no code change: every push to `release/0.18` — a ledger page, a pin
bump of a repository the branch never touched — put every READY branch behind the head, and the merge
flow's shape step refuses a branch behind a head whose inputs moved; `deps.cxd` and `ledger/` are read
by every branch's steps, so every push moved them. Each regrade cost an agent resume, a head merge, a
`deps-sync` and a re-run of four to six steps. The post-merge grade itself is fast now (23–32 minutes
for a selected run against 154 before the split), and rounds in different repositories no longer
collide — the drag is the admission rule and the integrator's presence between READY and the merge.

## MADM-1 — the merge flow admits a branch behind the head when the head's diff since the branch's merge-base is confined to ledger additions and to pin rows of repositories the branch did not move (L143 = (a))

Why it is sound: spec-freeze-gate resolves a commit's `RULED:` ids against the head's ledger, and a
ledger ADDITION can only make more ids resolve, never fewer, so a green spec-freeze-gate stays green
under it; a moved pin of a repository the branch never touched is what the trial merge unions anyway,
and the post-merge run grades the union exactly as it grades two READY branches merged together today
(OL-3's "graded on the final tree" is the post-merge run's for the union, as it has always been).
Taken: `ci/merge-shape` computes the head's diff since each branch's merge-base; a branch is admitted
when that diff touches only `ledger/*.md` additions (no deletion, no rewrite of an existing page other
than `ledger/README.md`) and `deps.cxd` / `registry/repos.cxd` rows whose repository the branch did not
move (its own pin rows equal or descend from the head's); any other moved path keeps today's refusal
with the path named. The rule is a case table in `flows/sim/merge/` first (admitted: ledger-only;
admitted: a foreign pin; refused: a Makefile move; refused: a page rewritten; refused: the branch's own
repository's pin moved under it), red-proofed, then the act. Rejected: (b) today's rule kept and the
integrator batching pushes — the drag stays wherever two things land in one night; (c) admitting any
behind-head branch — a moved Makefile or standing-rules file would land ungraded.

## MQUE-1 — READY branches land from a queue the post-merge loop consumes in its own gap (L144 = (a))

Today a merge waits for the integrator's next pass after a READY, and the flow's `gap` act waits
in-process for the loop; the loop itself already runs every 120 seconds under launchd and knows when
it is idle. Taken: a queue document `flows/merge-queue.cxd` — one `[branch name= dir= graded= msg=]`
row per READY branch the integrator has admitted (a docs branch is queued only after the browser read,
DOCS-51 §9 unchanged) — and `flows/postmerge.flow.cx` gains one step before its run: when the queue
has rows and the last RUN line is a RUN-EXIT, it runs `flows/merge.flow.cx` over the queue's rows as
one union (MADM-1's admission), removes the rows it landed, and only then grades the new head; a row
the shape step refuses stays in the queue with its refusal appended for the integrator; the queue file
is tracked, committed by the integrator (the act that admits), and the loop's removal commit rides in
the merge landing. Rejected: (b) a second launchd job for merges — two jobs racing for one checkout;
(c) the integrator polling faster — the cost this page measures. Cost: one opus round on cx-private
(`flows/ci-acts.cx`, `flows/postmerge.flow.cx`, `scripts/ci_flow_gate.cx`'s case tables for both
documents, `make merge-flow-gate postmerge-flow-gate` red-proofed, the plist untouched), landed in
LSWAP-1's shape (the loop booted out in the gap, the merge, `make runner-install-flow`, the first
tick's RUN line read) because the post-merge document changes.
