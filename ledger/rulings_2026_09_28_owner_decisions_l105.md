# Owner decision 2026-09-28 (evening) — Letter 105: the private flow gates live in a private make include

**Status: RULED (owner, 2026-09-28 ~21:1xZ, in session, "105a", on the letter posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 21:0xZ with RELFLOW-1's first READY).
RFLOW-1 (its choice 1, the allocation of the flow documents), D83a, INT-10, RS-11.**

## The owner's word, verbatim

"105a"

## PRIVMK-1 — the private flow gates and their rows live in `flows/private.mk`, pulled in by `-include` (L105 = (a))

RELFLOW-1's first two documents added `merge-flow-gate` and `premerge-flow-gate` as `TEST_TARGETS`
rows, and their inputs — `flows/merge.flow.cx`, `flows/premerge.flow.cx`, `scripts/ci_flow_gate.cx`
— stay in the private orchestration repository by RFLOW-1's first choice; a public `cx` refreshed
from that tree would list two steps whose subjects it does not carry, and its `make test` would fail.
Ruled: the private flow targets and their `TEST_TARGETS` and selection-manifest rows live in
`flows/private.mk`, pulled in by `-include flows/private.mk` from the Makefile; the public projection
carries no such file (the path allocation keeps it private), so the public `make test` never lists
them; the post-merge and refresh documents, private too, join the same include; the release document
and its acts, allocated public, stay in the Makefile proper. Each tree grades exactly what it carries;
the projection stays path-based and rewrites no code. It lands as the first commit of RELFLOW-1's
second round, before the refresh's `make test` proof runs again. Rejected: (b) the gate targets
exiting 0 with a message when the document is absent — a green that grades nothing in the public
tree, the class the standing rules refuse; (c) making the merge and pre-merge documents public —
public documents describing a private process, rejected at RFLOW-1's first choice.
