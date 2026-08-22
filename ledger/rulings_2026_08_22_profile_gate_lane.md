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
