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
