# Ruling 2026-08-22 — the R2.2 profile gate becomes a lane (#741)

**Status:** AUTHORIZED by the owner ("1a", 2026-08-22) against the finding
below. Recorded BEFORE the work per R6.1. The design calls are mine under
the standing letter-recommendation grant, each with its reasoning stated so
a later reader can overturn one without re-deriving the rest.

## The finding, measured

`scripts/release.sh --dry-run` does NOT exercise the R2.2 blocking gate.
The gate — stage four tarballs (platform + data/embed/cli), extract each
the way the installer extracts it, assert an executable `cx` at the tar
root, probe `cx -v` for the expected `profile  <name>` line — lives at
`scripts/release.sh:161-180`, entirely inside the `else` arm of the
`if [ $DRY_RUN -eq 1 ]` at line 114. Dry-run takes the `then` arm at 115,
prints one `plan` line, and returns. The gate's FIRST execution is
therefore inside a real cut.

What IS already covered pre-cut, stated so the finding is not overstated:
`test-profile-gate` (vcx/Makefile) probes the `profile` line via
`vcx/tests/runners/profile_gate/profile_gate.v:700` — but only for the
`cli` and `embed` profiles, from `build-profiles-dev` binaries, never from
a staged tarball. The tarball-shape half (extract, `cx` at tar root) and
the `platform` + `data` probes have never run.

Severity, stated honestly: phase 2 runs BEFORE the phase-3 push, so a
gate failure is local-only — the tag and the main merge exist on disk and
are recoverable. This is not a published-broken-release class. It is a
blocking gate whose correctness is unmeasured until the worst moment to
measure it.

## PGL-1 — one implementation, reachable from a pre-cut lane

1. **The gate loop is extracted VERBATIM to one shared function** in
   `scripts/lib/r22_profile_gate.sh`, parameterized by (public dir,
   platform string, label). Behavior-preserving: the three assertions,
   their order, their messages and their exit status are unchanged; the
   linux lane keeps its `R2.2/linux` label through the parameter. It is
   duplicated verbatim in two lanes today, and a gate that exists twice
   can drift in one place — the copy is the defect, not the assertions.
2. **All three call sites use that ONE function**: `release.sh` phase 2,
   the `release_linux.sh` in-container body (the container's lean copy
   already includes `scripts`, so the file is present at `/build`), and
   the new pre-cut lane. No second copy, no dual-accept.
3. **The darwin staging is extracted the same way** and reused by the new
   lane, so the lane gates the SAME bytes a cut would stage. The tolerant
   `cp … 2>/dev/null || true` form is PRESERVED exactly — this landing
   changes no lane's strictness.
4. **The linux staging stays in-container and is NOT unified.** It builds
   under a different make target with a different lib set, and unifying it
   would force a choice between weakening linux (which copies its `.so`
   strictly) and strengthening darwin (tolerant today). Either is a
   cut-path behavior change, and this landing is explicitly not that.
   The residual duplication is disclosed here rather than hidden.
5. **New lane `make release-profile-gate`**: build the profiles, stage into
   `dist/_precut_public/` — deliberately NOT `dist/public/`, so a pre-cut
   run can never be mistaken for real staged release assets — and run the
   gate with the `/precut` label. Wired into `release-verify` as its own
   row so the cut checklist executes it.
6. **#741 does NOT close on this landing.** Its item 2 verifies the
   PUBLISHED assets on macOS and Linux, which by construction requires the
   cut to have happened. This landing delivers item 1 (the gate passes,
   now demonstrable on demand) and nothing more; the issue keeps its
   blocking status and its post-publish items.

## Disclosed, NOT fixed here (follow-up in the tracker, per standing rule)

The R2.2 gate asserts only the `cx` binary — it never checks that a staged
tarball carries the LIB and header its profile promises (`data` = libcx-core
+ cx.h, `embed` = the embed-shape libcx + cx.h). Combined with darwin's
tolerant staging copies, a cut could stage a lib-less `data` tarball and
the gate would pass it. That is a real hole with a real asymmetry between
the lanes, and it is out of scope for a landing ruled behavior-preserving.
Filed as its own issue rather than widened into this one.

---

# PGL-1a — AMENDMENT: the gate was BROKEN, and the lane proved it on its first run

Recorded after the measurement, because PGL-1 authorized a
behavior-preserving extraction and this is a genuine behavior CHANGE. The
amendment exists so the change is findable by anyone grepping the ledger
for PGL-1, rather than hidden inside a "refactor" commit.

## What the lane found, first time it ran

The R2.2 gate FAILED — on a correct artifact. The staged platform tarball
carries the right contents (`cx`, `cx.h`, `libcx.dylib`, the re2 license)
and its binary reports `profile  platform`, verified byte-for-byte with
`od -c`. The gate reported it missing anyway, 3 runs out of 3, confirmed
under `bash -x` (the pipeline at trace line 102-103 returns non-zero; the
same binary prints the wanted line at trace line 106).

## Root cause, MEASURED — SIGPIPE under pipefail

    "$vdir/cx" -v | grep -q "profile  $prof"

`grep -q` exits the instant it matches. The profile line is line 2 of 8,
so `cx` is still writing when the pipe closes; it takes SIGPIPE and exits
**141** (128+13); `set -o pipefail` promotes that to the pipeline's status;
the `||` arm fires a false failure on a good artifact.

A/B, one `-prod` build, both probe forms against the SAME staged bytes,
the probe form the only variable:

| probe form | result |
|---|---|
| `cx -v \| grep -q …` (original) | **FAIL(rc=141) 6/6** |
| capture once, then match the text | **pass 6/6** |

Why nobody had ever seen it:
- the **darwin** lane had never run — the gate landed 2026-08-09, AFTER
  both prior releases, and sits in the arm `--dry-run` skips (the PGL-1
  finding);
- the **linux** lane runs under `bash -euc`, which has NO pipefail, so
  grep's 0 wins and the pipeline passes. The gate was only ever broken on
  the lane that never executed.

**This class was already known in this repo.** `scripts/test_playground_smoke.sh`
(around line 120) carries a comment naming the identical mechanism —
`grep -q` early exit, SIGPIPE 141, pipefail propagating a false failure —
and works around it with a here-string. The R2.2 gate is the SECOND
instance. A hazard documented in one file's comment is not a defense; see
the follow-up below.

## The change

The probe captures `cx -v` ONCE into a variable and matches the captured
text with `case`. One exec, no pipeline, nothing to receive SIGPIPE. On
failure it prints the probe's **exit status** and the **actual captured
bytes**.

That second half matters as much as the fix. The original probe was
undiagnosable BY CONSTRUCTION: it discarded the exit status and stderr,
then re-ran `cx -v` to print diagnostics — and the re-run could succeed
where the first failed, so a real failure printed a "does not report"
verdict directly above the very line it claimed was missing. That
self-contradicting evidence is why three wrong hypotheses got proposed and
killed before the A/B settled it. A gate that cannot explain its own
failure costs more than the bug it hides.

## Blast radius of the class, swept

Every `| grep -q` under `pipefail` in `scripts/` and `tools/` was checked.
All remaining instances pipe a **builtin** (`echo`/`printf`) of a small
string, which completes before `grep` can exit, so the producer never
receives SIGPIPE — safe in practice, not merely unobserved. The R2.2 gate
was the only site piping a slow, multi-line EXTERNAL binary into `grep -q`.
`tools/verify-doc-blocks.sh` (`head -n 1 … | grep -q`) is the nearest
remaining relative and is low-risk (one short line, producer exits
immediately), NOT zero-risk — noted, not touched.

## Follow-up, filed not absorbed

The class deserves a mechanical check, not a comment in one script: a lint
forbidding an external multi-line producer piped into `grep -q` inside a
`pipefail` script, pointing at the here-string / capture-once forms. Two
independent instances, one of which sat inside a BLOCKING release gate, is
the argument. Filed as its own issue.
