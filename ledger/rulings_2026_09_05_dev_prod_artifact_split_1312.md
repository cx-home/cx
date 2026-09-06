# Ruling record — #1312 (a): the dev CLI gets its own path (2026-09-05)

Issue: #1312 (bug, area:tooling, prio:medium). Supersedes the shape of #1056.
No spec surface. Build system only: `vcx/Makefile`, `Makefile`,
`vcx/testenv/testenv.v`.

## The defect, as measured rather than as reported

The issue attributed the relink storm to a *leftover* stamp deletion from a
prior dev build. That is a real instance but not the mechanism. The mechanism
is structural and fires on **every** `make test`:

- `TEST_TARGETS` names ~30 lanes whose prerequisite is `build-vcx` (prod) and
  **9** whose prerequisite is `build-vcx-dev` (`test-vcx-suite`, `-code`,
  `-cmd`, `-cx`, `-cxstore`, `-conform`, `-columnar`, `-sqlite`, `-timing`).
- Both prerequisites wrote `vcx/target/cx`. `cli` wrote it guarded and stamped;
  `cli-dev` wrote it unguarded and `rm -f`'d the stamp first.
- They are prerequisites of the SAME `-j` storm, so they ran concurrently, and
  each replaced a binary its siblings were mid-`exec` on.

`make test`'s serial pre-build covers the prod half only, so it never closed
this. `scripts/test_changed.sh` pre-builds both — serially, prod then dev —
which under the old shape left `target/cx` holding the *dev* binary with no
stamp, so every prod lane it selected then relinked.

Observable shape: a lane red with **empty output**, a missing binary, or an
arbitrary doc block — never in the lane that caused it. Three recorded
instances (#1312 ×2, #1309 run 2), each costing a full re-run to disprove.

## The ruling — (a), separate paths

`cli-dev` writes `$(CLI_DEV) = target/cx-dev`. It no longer touches `$(CLI)`
or its stamp.

This is not a new idea in this Makefile: `lib` / `lib-dev` have always written
`$(LIB)` and `$(LIB_DEV)`. The CLI was the one artifact where two recipes
producing two different binaries shared one name. #1056 was the correct fix
for that *within* the shared-path premise — if the guard cannot vouch for the
artifact, it must not claim to — and the wrong shape once lanes run in
parallel, because "invalidate the other build's stamp" is itself a write to
another lane's artifact.

Rejected: (b) stamp the dev build with a profile-bearing id so the transition
invalidates by VALUE. It makes the relink *legitimate* but still puts it
inside the storm, on a path a sibling is executing. The race survives.
Rejected: (c) serialize the two halves. Costs the parallelism and still leaves
whichever ran second as the binary both halves must use.

## Resolution

- `vcx/Makefile`: `CLI_DEV := $(TARGET)/cx-dev`; `cli-dev` writes it; the
  `rm -f $(CLI).buildid` is gone.
- `vcx/testenv/testenv.v` `cx_bin()` — the single funnel every V lane resolves
  through — prefers `cx-dev`, falls back to `cx`. A prod-only tree (bare
  checkout, release verify) is unchanged.
- `vcx/tests/vgc_arena_ceiling_raise_test.v` was the one bypass, with a
  CWD-relative `os.real_path` that panicked instead of self-skipping. Routed
  through the funnel.
- `registry-publish` / `registry-serve` / `bench/xap/run.sh` /
  `bench/flow/run.sh` declare `build-vcx-dev` and exec'd `target/cx`. Now
  `cx-dev` (with a prod fallback and a `CX_BIN` override in the two harnesses)
   — which is the binary they were actually getting before the split.

## Evidence

Before, in this tree:

```
$ make build-vcx      # after a dev build
cx: relinking (no buildid stamp beside the artifact)
```

After, the same sequence:

```
$ make build-vcx      # prod: relinks, stamps
$ make build-vcx-dev  # writes target/cx-dev (17.4 MB, unstripped)
$ make build-vcx
libcx.dylib: up to date (identity + inputs unchanged; relink skipped)
cx: up to date (identity + inputs unchanged; relink skipped)
```

`target/cx` (12.4 MB, stripped) and `target/cx-dev` (17.4 MB) now coexist and
neither build evicts the other.

## What this does NOT close

Item 3 of the issue — adding "empty output + nonzero exit" to the runner's
classified-retry roster as a serial retry. Left open deliberately: with the
shared artifact gone, an empty-output red should now be rare enough to be
worth investigating rather than retrying. Re-open it if one appears.
