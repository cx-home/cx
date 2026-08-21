# Rulings 2026-08-21 — the open-issue sweep (#893, #894, #898, #899, #900)

## ISW-1 — the sweep's scope and its per-issue dispositions

**Status:** RULED (this file is the ruling-store entry, written BEFORE the
work, per R6.1/#832 — `ledger/` is the ruling store and a ruling precedes
its landing). One ruling id, `ISW-1`, covers the whole sweep; every
spec-touching commit in it carries `RULED: ISW-1`.

The sweep takes five issues left open at the v0.16.0 cut-readiness line.
They are unrelated in subject and deliberately land as five independent
commits (plus this ledger and any mechanical doc fix in its own commit) so
the integrator can take or drop each one on its own.

Order is not arbitrary: **#900 first**, because a flaky gate poisons every
other measurement in the sweep and teaches the house to re-run instead of
to read.

---

### ISW-1.1 — #900: the fabric retention flake is a CLIENT that ignored a normative retry

**Disposition: fix the test, not the daemon. The daemon is correct.**

`test_fabric_serve_retention_policy_rotates_and_archives` asserted
`p.ftype == 3` on each of eight publishes and collected `7` under `-j 12`
suite load. Measured cause (forced deterministically, not inferred): the
error frame is

```
[err code=cx-err:CXER4935 message='E_FABRIC_ROTATING: mount "main" is
 rotating its journal — retry the publish shortly']
```

The rotation clause of `spec/03-approved/xap/fabric.md` makes that refusal
NORMATIVE — "publishes refuse with `E_FABRIC_ROTATING` while a rotation
runs (an append landing mid-copy would vanish on the swap)". The retry is
the CLIENT's obligation. The test is the client and did not retry.

The race is exactly the shape the reviewer suspected: `[retention
sweep-ms=300 …]` is a WALL-CLOCK trigger and the ingest loop is not
synchronised with it. With `hot=4`, the stream is over its window from the
fifth entry on; standalone the eight-publish loop completes inside one
300 ms sweep interval so the rotation always lands after it, and under
parallel suite load the loop outlives the interval and a publish lands in
the swap window.

**Ruled:** `7` IS legitimate here, but ONLY for `CXER4935`, and the test
must say so with the reason. The fix is a rotation-aware request helper
that retries only that code, only for a bounded window, fails on
exhaustion, and returns every other frame to the caller's assertion
unchanged. Loosening the assertion to "7 is fine" is refused; so is
registering the lane in the runner's retry class (the failure is not a
retry class, it is a missing protocol step).

**Recorded as a gate hole, not fixed here:** the normative
`E_FABRIC_ROTATING` refusal itself has NO direct test — the only way to
observe the window without a controlled clock is to widen it artificially,
which would re-introduce exactly the timing dependence this ruling removes.
Named for a follow-up rather than papered over with a flaky gate.

---

### ISW-1.2 — #893: the mermaid bench gate asserts a WALL TIME it cannot own

**Disposition: demote wall time to an advisory; assert a deterministic
bound instead. The amplification gate's precedent governs.**

The reported 55 ms against a 25 ms budget was measured with five agents
compiling in parallel; on a quiet machine the same gate passes. The defect
is therefore NOT the renderer and NOT the budget's calibration — it is that
a wall-time assertion on a shared, load-variable box is not a property of
the code under test. A gate that goes red because of a neighbour's `clang`
is a gate that trains the house to re-run.

`vcx/tests/parse_amplification_test.v` already settled this class: it
demoted wall time to a printed advisory and asserted a deterministic,
load-invariant bound. This gate follows it. The 25 ms figure in
`spec/03-approved/std-lib/diagram.md` stays as the recorded landing
measurement (a calibration note naming its machine and conditions), and
stops being the gate's pass/fail criterion.

Spec-touching (the §8 budget clause changes status from normative-assertion
to calibration-note) — the commit carries `RULED: ISW-1`.

---

### ISW-1.3 — #898: `[err …]` in the source contaminates the injected image

**Disposition: implement the issue's option (a) — engine-side rename in the
image, label mapped back — after re-verifying the recommendation holds at
this head.**

The recommendation is re-verified before implementation, not assumed. If
the verification shows the exposure is gone or differently shaped, this
section is amended before any code moves.

Option (b) (a sequence-carrier convention across ~40 module defs) is
refused for the reason the issue gives: an unenforced convention with no
gate is a partial implementation by the house's own rule
(`feedback_no_stubs_no_partial_impl`). Option (c) (leave it recorded)
is refused because the shape is one real programs write.

The fix is engine-side by construction — the image is engine-built, so this
is an image-contract defect, not a renderer defect. Consequences: the
`stdlib/diagram.cx` edit, if any is needed at all, is MINIMAL and named
explicitly in the commit message (a sibling agent owns that file this
session).

Pinned by a fixture that would have caught the original. Zero movement in
the existing goldens is the expected verdict.

---

### ISW-1.4 — #899: the `/Name` → `//Name` source rewrite RETIRES

**Disposition: retire it, and re-record the affected goldens as a
deliberate, reviewed diff.**

DRW3-2 ported the rewrite verbatim and named the retirement as a thing to
be "flipped by a ruling rather than by drift". This is that ruling. The
rewrite is no longer needed for parseability (measured at the wave-3 head
and re-measured here) and is output-visible: it makes a label read
`//users/user` where the source wrote `/users/user`, i.e. a
descendant-anchored path where the author wrote an absolute one. A
workaround that outlived its reason and now only lies is retired.

Golden movement is EXPECTED and is the point. It is deliberate on these
terms:

- every moved golden's before/after is stated in the commit message;
- ONLY label bytes move — a non-label byte moving is a defect, not a
  re-record, and stops the landing;
- the 120 mermaid goldens and the completeness gate stay green.

Rewrite (1) (`[case [< 13] …]` → `[case '< 13' …]`) SURVIVES: measured
again at this head, the bracket-shaped match-arm pattern is still refused
by the parser, so it is still load-bearing.

Spec-touching (`spec/03-approved/std-lib/diagram.md` §10.1 step 2 names
only the surviving rewrite) — `RULED: ISW-1`.

---

### ISW-1.5 — #894: the missing comma in an array literal

**Disposition: MEASURE FIRST, then decide by a rule fixed in advance.**

`[$g ("a","b")]` is accepted and yields `[($g, (a, b))]` — a missing
separator silently absorbed into a differently-shaped value. That is the
#793 silent-acceptance class and the acceptance is the defect. The issue
itself records that it was deliberately NOT fixed at the cut, for an
UNMEASURED reason: "a parser-acceptance change with unmeasured golden
reach". This sweep's job is to replace the guess with a number.

The decision rule, fixed before the measurement so it cannot be fitted to
the result:

- the corpus diff is run BEFORE the change lands, and the predicted reach
  is stated before it is run;
- if no corpus document relies on the leniency, the refusal lands and the
  issue closes;
- if a document DOES rely on it, that document is a FINDING to report — a
  real document written with a missing separator is evidence about the
  surface, and it is reported, never silently re-blessed;
- if the reach is genuinely large, the landing STOPS and the outcome is the
  measurement plus lettered options for the owner. A measured "here is the
  reach" is an acceptable outcome for this one, by the issue's own terms.

---

## Gates

Per issue, plus the union at the end: build; `cxparse_full_corpus_diff`;
`code_eval_fixtures` (with `-d cx_db_sqlite -d cx_db_redis`);
`eval_semantics_umbrella`; the diagram lanes for anything touching the
module; the fabric/platform lanes for #900; `spec-freeze-gate`. Full logs,
every RC echoed, verdict read FROM THE LOG.
