# Ruling 2026-09-06 — #1324, a restored one-shot that came due while the process was down (SK-1)

**Status: RULED (a) under the standing letter-acceptance rule.** Ruling id
`1324-SK-1`. Written on `design/789-workflow`; it merges with whatever change
implements it. **Flagged prominently for an owner veto**, for a reason stated
below: the outcome LOOKS like truing a spec to a shortfall, which is a hard
standing prohibition, and the argument that it is not needs to be checked
rather than assumed.

**The divergence** (found while fixing #1322; the implementer needed to
falsify flow's `on-missed` pin and could not do it off firing behavior).
`sched.md` §2.5 defines `:skip`, the DEFAULT policy:

> fire **only the next still-future occurrence**; drop the N that elapsed.
> Safe default — at-most-the-latest, no burst. **A one-shot already past
> simply does not fire.**

`sch_rearm_intent` re-arms an already-past one-shot at `virtual_now`, so it
fires. `:skip` and `:fire-all` are therefore behaviorally identical for a
restored one-shot — the exact case §2.5 draws the distinction for.

## SK-1 — which side is right — RULED: (a)

- **(a) RULED ON THE MERITS — a durable one-shot that came due while the
  process was down FIRES ONCE at restore under every `on-missed` policy, and
  `sched.md` §2.5's parenthetical is struck.** Two reasons, in order of
  weight:

  **1. `:skip`'s own definition does not cover a one-shot.** It says "fire
  only the next still-future occurrence". A one-shot HAS no next occurrence.
  The struck sentence is a deduction from that definition applied to a case
  the definition does not reach, and the deduction lands on the worst
  available behavior. The policy axis is about which of N missed
  RECURRENCES to replay; a one-shot has no N.

  **2. Silent loss is worse than a late fire, for every consumer of a
  one-shot in this tree.** A durable one-shot is a deadline, a timeout, a
  reminder, a cleanup, an incapacity window. Under the struck sentence, the
  thing you scheduled never happens, no entry records that it did not, and
  the caller learns nothing — a failure mode that is invisible by
  construction. Firing late is wrong about WHEN and right about WHETHER, and
  the lateness is visible: the fired instant is the intent's original
  deadline, so a consumer can see it fired late and decide. `flow` already
  relies on exactly this (`789-WF-27a`: a missed deadline fires carrying its
  ORIGINAL instant, never the boot instant).

  **What it DELETES:** the sentence "A one-shot already past simply does not
  fire", and with it the only way to schedule durable work that silently
  does not happen. A caller who genuinely wants staleness to cancel the work
  writes that as a guard in the callback, where it is visible, rather than
  getting it from a default they did not choose.
  **What it does NOT change:** `:skip` for recurring timers is untouched —
  fire only the next still-future occurrence, no burst, still the default.
  `:coalesce` and `:fire-all` are unchanged. No implementation changes; the
  behavior already shipped is the ruled behavior.

  **Why this is not truing a spec to a shortfall** (the hard rule it
  resembles). That rule forbids amending a spec because the implementation
  failed to deliver what was designed. The test is whether the spec sentence
  was an independently motivated design decision the code then missed. It
  was not: §2.5's table is organized entirely around "N occurrences due at
  once", every row is written in those terms, and the one-shot parenthetical
  is an aside extending the rule to a case with no N. Nothing in the spec
  argues FOR silent loss; it simply follows the sentence's grammar. The
  ruling is made on which behavior is correct, and it would be the same
  ruling if the code did the other thing — that is the check that
  distinguishes it. **It survives an owner veto only if that reasoning does;
  if the owner reads the parenthetical as a deliberate at-most-once posture,
  (b) is the answer and the code changes.**
- **(b) make the implementation match the spec — drop a past one-shot under
  `:skip`.** REFUSED on the merits above, and it would introduce a silent
  loss into every current consumer at once. Kept as the fallback if the veto
  goes the other way; it is a real position, not a straw one — "do not run
  stale work" is a defensible default, it is just not the better one when
  the alternative is invisible.
- **(c) add a fourth policy for one-shots.** REFUSED: a policy axis with a
  member that applies to one timer shape only is a second vocabulary for one
  concept, and three of the four values would be inert on a one-shot.

**Gate.** The fixture that does not exist today: a durable one-shot, a
restart across its deadline, asserted to fire ONCE, under EACH of `:skip`,
`:coalesce` and `:fire-all` — the case no current fixture distinguishes,
which is why the divergence survived. Plus the §2.5 text edit striking the
parenthetical and saying explicitly that the policy axis governs recurrences
and a one-shot always fires once.

**Consequence for flow.** `789-WF-27a`'s pin of `:fire-all` on deadline and
rung timers stays — under this ruling it is belt-and-braces rather than
load-bearing, and it stays because flow should not depend on another
module's default for a liveness guarantee it makes in its own spec.

---

# SK-2 — 2026-09-06, the OWNER REVISED SK-1 (asked "is (a) the best long term?")

**Status: SK-1's conclusion is WITHDRAWN. `1324-SK-2` RULED (a) by the owner
("1a") on the question SK-1's revision exposed.** SK-1's text above is kept
verbatim, not rewritten, so the record shows what it got wrong.

## What SK-1 got wrong

1. **It argued as if flow depended on it. Flow does not.** `789-WF-27a`
   already pins `on-missed: :fire-all` explicitly on every flow timer
   (`stdlib/flow.cx:2488`, verified). So SK-1 changed nothing for the one
   consumer whose liveness it invoked as justification — its whole reach was
   over callers who had asked for something *else*. Overriding an explicit
   choice on the grounds that the choice is probably a mistake is not a
   language surface's job.
2. **It collapsed the policy axis.** Under SK-1 all three `on-missed` values
   mean the same thing for a one-shot, so there is no way left to say "if this
   is late it is worthless". That class is real and is not a deadline: a sale
   that opens at noon and closes at 13:00, a cache warm, a notice that only
   makes sense while the reader is still on the page. SK-1 answered this with
   "write the staleness check in the callback" — which is the reasoning that
   shipped the retry storm (#1331): pushing a safety obligation onto every
   caller. It holds for flow, whose callback is `advance` and re-derives run
   state, and does not hold for an arbitrary callable.
3. **It mistook the harm.** What is intolerable is the SILENCE, not the
   not-firing — and firing is not the only cure for silence. The harm actually
   observed in #1322 came from a **default nobody chose** (`sch_parse_opts`
   defaults `on_missed: skip` for every kind), not from `:skip`'s semantics.
   SK-1 fixed the semantics and left the default alone, which is backwards.

## SK-2 — RULED: (a), three parts

- **(a-i) `on-missed` absent on a durable ONE-SHOT (`after` / `at`) defaults
  to `:fire-all`; a recurrence keeps `:skip` as its default, unchanged.** A
  recurrence has a next occurrence to skip to and a one-shot does not, and the
  common durable one-shot is a deadline — escalate, expire, cancel, charge —
  where late beats never. Reusing `:fire-all` rather than inventing a value
  keeps the axis closed (for one occurrence `:fire-all` and `:coalesce` are the
  same thing, because there is one occurrence, not because they were merged).
- **(a-ii) `:skip` keeps its meaning on a one-shot: the timer is NOT armed.**
  §2.5's parenthetical STANDS. SK-1's strike of it is withdrawn.
- **(a-iii) A one-shot dropped under `:skip` is RECORDED, never silent.** Two
  places, both required:
  - a named row in the restore report — a `[dropped [drop name= kind=
    deadline=]…]` block, the exact shape and posture of the existing
    `[orphaned [orphan name=…]]` finding (`sched.md` §3.2, "a finding, never
    silently dropped");
  - **and the intent is closed in the journal** with `status 'dropped'`.
    Without that append the same intent is still `pending` at the next boot,
    so every subsequent restore re-drops and re-reports it and the report
    never converges. A drop is terminal for that intent, which is exactly what
    §3.3's fire/cancel/terminal appends already record.

**What it DELETES:** SK-1's strike of §2.5's parenthetical; and sched's
uniform `:skip` default at a one-shot arm — a persisted intent for an
`after`/`at` that stated nothing now records `fire-all`.
**What it does NOT change:** flow (its `:fire-all` pin is explicit, so its
restore fixtures are untouched); `:coalesce` / `:fire-all` semantics; the
recurrence default; the CXER band.

**Why `dropped=` is NOT a fourth count on the report.** `skipped=` keeps
counting occurrences that did not fire, and the drop lands in it. The
reader's question is *which* timer is gone forever, which the named block
answers; a fourth count attribute would move every existing `[restore-report
rearmed= skipped= orphaned=]` expectation in `sched.cxd` and `flow.cxd` for no
information gain. The block is emitted only when non-empty, as `[orphaned …]`
already is.

## Verified against the code before ruling (sites, not prose)

- `sch_parse_opts` defaults `on_missed: sch_miss_skip` for every kind
  (`vcx/code/stdlib_sched_notd_cx_no_pack_sched.v:365`) and the arm path
  persists `t.on_missed` unconditionally (`:689`), so a persisted intent
  always names a policy and the restore-time fallback (`:1247`) reaches only
  journals written before this change. The default therefore has to move at
  the ARM site, per kind — not at restore.
- `sch_rearm_intent` arms a past one-shot at `r.virtual_now` under `:skip`
  (`:1265`). So today it fires — **and it fires stamped with the BOOT instant,
  losing the original.** That second half is a defect on `789-WF-27a`'s own
  terms and SK-1 never noticed it; under SK-2 it disappears, because the only
  arms left keep the persisted deadline.
- No current fixture has a past one-shot at restore: `sched-023`…`027` all arm
  ten minutes ahead and restore immediately. That is why the divergence
  survived, and it is why the fixture is the deliverable.
- Blast radius outside the new cases is one line: `sched-022`'s expected
  journal entry carries `[on-missed 'skip']` for an `after` that stated
  nothing, so it becomes `'fire-all'` and the payload and entry hashes move
  with it.

**Gate.** A durable one-shot plus a restart across its deadline, under each of:
`:skip` (not armed; named in `[dropped …]`; the intent closed so a SECOND
restore reports nothing; nothing fires), `:coalesce`, `:fire-all` (fires once,
carrying the ORIGINAL instant), and **nothing stated** (fires — a-i's new
default). Plus `sched-022`'s persisted intent.
