# Integrator decision 2026-09-30 — Letter 149, taken under DELEG-3: a queue-only head is graded by the docs pipeline

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, DELEG-3; the flag came in the MADM-1 +
MQUE-1 round's RESULTS.md (`_gate_evidence/pipeline_madm1/`, graded `e6d64badd`) and was posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 13:2xZ with this taking; the owner may
reverse it on reading). MADM-1, MQUE-1, INT-10, RFLOW-1, CXF-1.**

## The owner's words, verbatim

"we want to speed up where possible"

## QDOC-1 — a head whose diff since the last graded head is confined to `flows/merge-queue.cxd` and `_gate_evidence/` takes the docs pipeline (L149 = (a))

MQUE-1 makes the integrator's admission of a READY branch a commit to the queue document; the
post-merge loop would grade that commit as a full selected run before consuming it, so every queueing
push would cost the run the queue exists to avoid. Taken: INT-10's mechanism — `scripts/head_is_docs_only.sh`'s
path list gains the queue document and the evidence directory, so a queue-only head runs the seven-step
docs pipeline (the ledger, the version and the flow-document gates among them) and the loop's next
tick consumes the queue; a head that also moves code keeps the full run; a case in the post-merge
flow's table for each (a queue-only head → docs; a queue + code head → the full run), red first.
Rejected: (b) a queue push graded as a full run — the queue saves nothing; (c) the queue kept out of
the tree (a file under `vcx/target/`) — an act that admits a branch would leave no record in the
history the integrator protocol is built on. Same round, before its merge.
