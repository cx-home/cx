# RULED: 1314-c1 … 1314-c4 — the flow re-attempt WAIT and the timer's kind segment

Date: 2026-09-08
Issue: cx-home/cx-private#1314
Drafted by: worker B (Opus), campaign #1354. Approved by: Fable.
Prior records that bind this one: `789-WF-26a` (the bound and the
`[idempotent]` gate), `789-WF-18a` (one bound, one cadence, shared with
`until`), `789-WF-27a` (`rearm`, `:coalesce`), `1265-PB-5` (timer naming and the
fired-timer no-op), `728-CK-8` + `core/code.md` §10.2.1.1 (`retry-after=`),
`1334-SEAM-a` (the connector seam).

## What was already ruled, and what was not

`attempts=N` on a step, `every=` as its cadence, admitted only where the resolved
command declares `[idempotent]`, `CXER4952` naming the verb otherwise, exhaustion
as `:failed reason=:attempts-exhausted` — all of that is `789-WF-26a`, ruled
2026-09-05 and implemented on `impl/cx-B-1314`. The issue title's "(ruling
needed)" is stale for the feature.

What needed ruling is a mechanism WF-26a did not reach, found by implementing it,
and it is a LIVE DEFECT independent of `attempts=`.

## The defect

Measured: `vcx/code/stdlib_sched_notd_cx_no_pack_sched.v:448-456` DELETES every
live timer of the same name when arming a named one (its comment says why: a
second `restore` was producing two live timers per name). `flow.md` §6 and
`1265-PB-5` name `deadline=`, `every=` AND a rung's `within=` all
`<run id>:<step>`. So arming any second timer for a step silently cancels the
first — already true for `deadline=` + a W3 rung, before `attempts=` exists.

`1265-PB-5` is a prior RULED record, but it is self-contradictory with
`sched.md` §3.1's own rule that the name IS the registry key. The defect is in a
ruling's consequences — the class `1265-PV-1` already records as amendable — so
PB-5 is AMENDED, not overridden.

## 1314-c1 — the timer name gains a KIND segment

`<run id>:<step>:<kind>`, `kind` ∈ `deadline` | `wait` | `rung-<n>`, parsed from
the RIGHT (`f--timer-parts` / `f--timer-step` / `f--timer-run` / `f--flow-timer`,
`stdlib/flow.cx:3008-3026`; `f--flow-timer` requires ≥ 4 segments).

AMENDED FROM THE DRAFT: the draft proposed `retry`, which covers a step's
re-attempt wait and leaves `until`'s iteration wait (§4.18 — also `every=`, also
a durable timer) with no kind, i.e. a second spelling waiting to happen.
WF-18/WF-26 share `every=` deliberately ("one bound, one cadence, one thing to
learn"), so ONE kind carries both: `wait`.

The kind must reach `advance`, so PB-5's event becomes
`[timer-fired run= step= kind= at=]` with `kind=` REQUIRED — no default, no
dual-accept (the standing no-dual-accept rule); a `[timer-fired]` without it
takes the existing arg-invalid refusal. §6's row, the arm site (`:2529`) and
`f--rearm-ev` (`:3037`) change.

RE-CASTS, not flips (no fixture expectation is reversed; the names gain a
segment): flow-036 (`:1626`/`:1628` hand-built `timer-fired` gain
`kind=:deadline`; `:1637`'s intent name gains `:deadline`), flow-050 (`:2507`),
flow-051 / 052 / 053 / 055 (`[name [$concat $id ":reserve"]]` →
`":reserve:deadline"`, plus flow-052's orphan name). A rung fixture waits for W3
— the kind is a naming law, not a seam.

## 1314-c2 — the fired-timer law is KIND × STATUS

| kind | acts on | action |
|---|---|---|
| `deadline` | `:running` / `:pending` / `:retrying` | `:failed reason=:deadline` |
| `wait` | `:retrying` only | attempt K+1 activates (`:running attempt=K+1` + the act) |
| `rung-<n>` | `:pending` only (W3) | the rung |

Every other pairing is a no-op — the record decides (§4.2).

THE DRAFT'S REPLACEMENT CLAUSE IS REFUSED. It proposed "a fired timer whose step
is terminal is a no-op", which would make a `deadline` fire on a `:waiting` step
FAIL it; flow-036's `late-timer-noop` is gate=enforced and pins that a timer
naming a `:waiting` step is a no-op. The kind × status table is what PB-5's
two-status clause was actually protecting.

Corollary, left implicit by the draft: a `:retrying` step WITH `every=` is
re-offered only by its `wait` timer or `retry-now` (§4.21), never by a bare
courier tick; WITHOUT `every=` it re-offers on the next tick, which is WF-26a's
stated default.

Also refused: letting a step awaiting re-attempt be `:pending`. §4.6 defines
`:pending` as OFFERED to a performer; an ops inbox filtered on it would show
machine waits.

## 1314-c3 — `deadline=` bounds the WHOLE step, not each attempt

Armed once at first activation, never re-armed; its expiry beats the remaining
attempts (c2's table). Same reading §4.18 already gives `until`'s `deadline=`.

THE DRAFT'S PREMISE WAS FALSE and is corrected here so nothing is built on it.
The draft claimed (a) was what the landed code already implied. It is the
reverse: `f--arms-timer` (`stdlib/flow.cx:2304-2310`, unchanged from release)
arms on ANY `:running` transition of a construct carrying `deadline=`, with no
attempt check, and `f--activate-step` emits `:running attempt=K+1` for a
re-attempt — so each re-attempt re-arms the deadline under the same name and
`:448` swaps in a fresh full-duration timer. The SHIPPED behavior is per-attempt,
silently. (a) therefore requires a change the draft had not scoped: arm the
deadline only on first activation (`attempt=` absent or 1).

Per-attempt is refused on its merits too: the worst case becomes N × `deadline=`
and is no longer readable from the document, which is the opposite of §4.17's
reason for existing.

## 1314-c4 — `every=` lands in v0.18

`1334-SEAM-a` assigns it to flow's v0.18 implementation and the standing
no-deferral rule applies. The "Implementation status (honest, #1314)" blockquote
this branch put into the approved `flow.md` §4.8 is REMOVED when the wait lands
— an approved spec does not carry an implementation gap note past its landing.

Spellings ruled now to prevent a fork: the `:retrying` transition carries
`wait=<the duration actually armed>` and, only when it raised the wait,
`retry-after=<the err's value verbatim>`. Both are RECORD fields, not document
words — §2.3 is unchanged.

UNDER-SCOPED BY THE DRAFT: `retry-after=` does not currently survive the failure
path. `f--perform-caught`'s `recover-with` rebuilds
`[act-refusal code= message=]` (`:2742`) and `f--unrefuse` (`:2733`) rebuilds
`[err code= message=]`, BOTH dropping every other attribute. Both must carry it,
and the `:failed` transition's `[result [err …]]` must hold it for
`f--step-failed` to read.

The wait itself: `on-missed: :coalesce` (WF-27a), `max(every=, retry-after)`
(CK-8 and `core/code.md` §10.2.1.1 — `retry-after=` RAISES the wait, never lowers
it), an absolute `retry-after=` taken relative to now (virtual under `:manual`).

## Fixtures

New **flow-058** (c1–c3): a `deadline=` step re-attempted twice; the deadline is
armed ONCE (one `[sched-intent]`, name `…:deadline`); expiry during `:retrying`
→ `:failed reason=:deadline`.

New **flow-059..062** (c4), under `:manual`, beside flow-036/050: advance short
of `every=` stays `:retrying` and past it re-attempts; `retry-after=` longer than
`every=` waits the err's value, shorter still waits `every=`, with
`wait=`/`retry-after=` on the transition; a restart during `:retrying` → `rearm`
re-arms `…:wait` and it fires once (`:coalesce`); `every=` without `attempts=`
refuses `CXER4952`.

Lane: `v test vcx/tests/code_eval_fixtures_test.v` FROM THE REPO ROOT — not
`make test-vcx-code`, which does not grade `conformance/stdlib/*.cxd`.

## Relation to #1358

None of c1–c4 depends on it. Under `:manual` every fixture above is
deterministic. #1358 (`RULED: 1358-a` … `-d`) is what makes these timers fire in
a production process at all — for `deadline=` and `wait` alike.
