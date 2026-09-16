# Integrator decision 2026-09-16 ~10:15Z — a batch branch carries several small bugs of one ring (RULED: BATCH-1)

Under the owner's throughput direction of 04:5xZ–05:3xZ: *"why aren't we closing 10 issues per hour"*.

| Id | Decision |
|---|---|
| **BATCH-1** | **(integrator, 2026-09-16 ~10:15Z, under the owner's throughput direction of 04:5xZ–05:3xZ: "why aren't we closing 10 issues per hour")** A BATCH BRANCH carries several small bugs of ONE ring — each fixed fixture-first as its OWN commit pair (`test(N)` then `fix(N)`, subjects naming the issue and ending in the ruling), one pipeline, one merge whose comment names every issue, one post-merge pass closing them all. Admitted: bugs whose fix is under ~50 lines and touches no spec sentence; a bug that grows beyond that is split back out to its own branch and flagged. The grammar's "a branch resolves one issue or a stated part of one" is read as: this branch resolves a STATED SET, named in the ledger row that opens it. |

## Batch

Batch 1 — Ring 0 language bugs, branch `impl/cx-F-ring0-language-bugs`, decisions INT-16 (each is in v0.18 as a fix,
fixture first) and ORD-1 (Ring 0 first):

| issue | title (short) |
|---|---|
| #1500 | cast: `parse_int_string` decides failure by a sentinel comparison |
| #1501 | cast: `[$cast "1e400" :float]` yields `+inf.0` — refuse under the finite-only rule |
| #1389 | `cx fmt` declines a namespaced call over a parenthesized group |
| #1436 | `cx fmt` declines a file whose interior comments the layout cannot place (CXER0301) |
| #1363 | code-diagram of a homoiconic answer — the output subject re-parses `cx:op` |
| #1488 | the purity gate's `module_impure_reach` skips every `module:member` token |
| #1446 | `scripts/apply_blesses.cx` calls `[$member-of …]`, a function that exists nowhere |
