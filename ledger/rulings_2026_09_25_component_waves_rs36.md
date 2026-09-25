# RS-36 — how a wave in a component repository lands after the split (owner, 2026-09-25, Letter 4 (a))

**Status: RULED (owner, 2026-09-25 ~12:2xZ, confirmed ~12:3xZ, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591)).**

## The owner's word, verbatim

The integrator's post of 2026-09-25 ~12:0xZ put Letters 3 and 4 to the owner. The owner answered
twice:

- ~12:2xZ: **"a a"** — Letter 3 = (a), Letter 4 = (a).
- ~12:3xZ: **"L3 b L4 a"** — Letter 3 = (b) (W3 launches now; not decided on this page), Letter 4 =
  (a), confirmed.

## The letter, verbatim (#1591, 2026-09-25 ~12:0xZ)

### Letter 4 — how a flow wave lands after the split (needed before the first wave launches; a rules change → RS on the ledger)

cx-platform-flow's tree is no longer in cx-private (RS-12); cx-private pins it. The preamble's rule
is "push nothing to any other repository".

- **(a)** the agent works in a worktree of a clone of `cx-home/cx-platform-flow`, branch
  `impl/<issue>`, and pushes THAT branch to cx-platform-flow with the literal
  `git push origin HEAD:refs/heads/impl/<issue>` (its one allowed push there, never main); its
  pre-merge steps run in the front door's shape — a cx-private worktree whose `deps.cxd` pins its
  pushed branch commit; READY = that pin-bump branch's RESULTS with MERGE-READY; the integrator
  fast-forwards cx-platform-flow `main` to the branch, then merges the pin bump (the union grades).
  Long-term: one shape for every component repository from now on (cx-core-code's own gate, RS-32,
  follows the same path); the standing rules gain one sentence.
- **(b)** the agent prepares commits in a local clone, the integrator pushes them to a branch of
  cx-platform-flow before the agent can grade. Long-term: the integrator on every agent's critical
  path, twice per wave.
- **(c)** work flow in cx-private under a re-admitted `vcx/flow` and re-extract at the cut.
  Long-term: undoes RS-12 for one repository and re-runs a leave.

**Recommendation: (a)**, recorded as RS-36 by the first wave's ledger commit, and the preamble
amended before it launches.

## The decision

| Id | Decision |
|---|---|
| **RS-36** | **(owner, Letter 4 = (a))** A wave whose tree lives in a component repository (a `registry/repos.cxd` row with `status=extracted`) is worked in a fresh clone of that repository under `/Users/dev2/git-repos/cx/<short>-<issue>`, on a branch `impl/<issue>`; the agent pushes THAT branch to THAT repository with the literal `git push origin HEAD:refs/heads/impl/<issue>`, after every commit — never its `main`, never a tag, never another ref. The agent's cx-private branch pins the pushed commit (`deps.cxd` `sha=`, `registry/repos.cxd` `at=`), runs `make deps-sync`, and grades in the front door's shape: the front door's steps that read the pin, plus the component's own `make check` with `CX_BIN=<the main checkout's vcx/target/cx>` as an own step. READY = the cx-private branch's RESULTS.md with `MERGE-READY <sha>`. The integrator fast-forwards the component's `main` to the agent's branch, then merges the pin bump; the union grades. A component history rewritten under RS-33 while the agent runs (messages only, trees identical) is followed before READY: fetch, rebase onto the new `main` if it moved, re-push, re-pin. Rejected: (b) — the integrator on every wave's critical path twice; (c) — undoes RS-12 for one repository and re-runs a leave. First applied by W3 (cx-home/cx-platform-flow#3). |

## What this page does not decide

- Letter 3 (when FW-1's ladder launches) is the board's record on #1591, not this page's.
- Which steps a given component's pin bump owes beyond the component's own `make check` — each
  brief names them from the front door's step list.
