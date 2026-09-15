# Integrator decisions, 2026-09-15 — INT-15

Decisions the integrator took inside rules already ruled (the shape of `rulings_2026_09_12_integrator_decisions.md`).

| Id | Decision |
|---|---|
| **INT-15** | **(integrator, 2026-09-15 ~11:00Z)** INT-9's "the files the branch's pre-merge steps read", applied to the SHARDED fixtures grader (1448-a): a branch's `make fixtures` verdict depends on the corpus files the branch edits and on the sources compiled into the binary that grades them — `vcx/`, `stdlib/*.cx`, the `third_party/v` pin. A head merge that changes only OTHER corpus files, whose cases are graded by their own shard against the same binary, re-runs nothing: the census line moves, and `RESULTS.md` records the new count beside the merge sha. A head merge touching `vcx/`, `stdlib/`, the pin, or a corpus file the branch edits re-runs `build-vcx` and `fixtures` (INT-9's own fix rule). Why: measured on 2026-09-15 between 04:35Z and 10:30Z — six landings, and each one forced a build + fixtures re-run (15–30 min on the shared pre-merge runner) on every in-flight branch, for verdicts that could not change; `#1453` ran five times and `#1496` twice for other branches' cases. |

## The `check-code-fixtures` lesson (the run on `4b3664230`, 10:42Z)

`scripts/check_code_fixtures.cx` grades `conformance/code.cxd` ALONE and is a post-merge step: every case id must carry a prefix registered in its `PREFIX-MAP` for the case's `level=`, and a `code.cxd` edit therefore runs `make check-code-fixtures` pre-merge. #1453 landed five `program-cx-…` ids (unregistered; `program-cx-pi-` is) with no such step in its pipeline, and the run failed on that step alone (72/72 V test files passed). The fix branch `impl/cx-F-1453-id-prefix` renames them to `program-builtin-…`. Recorded in `AGENT-STANDING-RULES.md` with this page.
