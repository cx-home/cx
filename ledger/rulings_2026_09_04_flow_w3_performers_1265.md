# Rulings 2026-09-04 — #1265 W3: three questions the performer axis needs answered first (PW)

**Status: PW-1 … PW-3 RULED (a) 2026-09-04 under the owner's standing
letter-acceptance rule and the 2026-09-04 directive (run the campaign
through; best long-term decision). Recorded before any W3 edit. PW-1 adds
an OPTIONAL attribute to the feature grammar — flagged to the owner (a
schema-visible change; veto by letter).** Ruling ids `1265-PW-1 … 1265-PW-3`.

**Inputs read.** `flow.md` §4.1 (at the XAP face a step's act resolves
through ρ over the composed grammar), §4.5–§4.7 (the pre-pivot
compensability check: "every step BEFORE the pivot must name a command
declaring `[compensates]`"), §4.6 (`:principal`: a signed `[approval]` of the
recorded proposal; the runner then `commit`s), §4.13 ("the inbox is a
readout … a lensed projection over `fleet`"), §2.2 (the step row records
`proposal=<address>`), §11; `xap_schemas/feature.cxs` `[verb]` (attributes
`name`, `effect`, `scope`, `consequence ∈ none|reversible|irreversible`;
children `intent`, `reads`, `writes` — NO pairing); `xap.md` (`[compensates]`
appears only through the retired saga records; "the compensating intent is
itself a journaled event"); `authz.md` §3.10 (`approve` mints `[approval
[subject hash=<Tier-1 of the proposal>] [by …] [tier …] [signature …]]` —
the approval binds the proposal's ADDRESS, never its name or args; `commit`
re-hashes the presented proposal against the subject); W1's resolver element
(`[act name= resolved= compensates=? [fn $cmd]]`).

## PW-1 — how a composed-grammar verb declares its compensator — RULED (a)

- **(a) RULED — `[verb … compensates=<verb>]`, an OPTIONAL attribute naming
  the paired verb (bare within the feature, or qualified), carried verbatim
  onto the composed grammar; the compose gate refuses (a W-row conflict) a
  pairing whose target is not an `act` verb of the same composition.** The
  flow's XAP-face resolver reads it into the row's `compensates=`; the
  pre-pivot check (§4.7) refuses `CXER4954` for a pre-pivot step whose verb
  declares none — exactly as the program face refuses a def without
  `[compensates]`. **DELETES:** nothing — a verb without the attribute is a
  valid verb (only a flow placing it before a pivot cares). **KEEPS:**
  `consequence=` (a fact about the effect, not a pairing); every shipped
  feature unchanged. **Strongest counter:** `consequence=reversible` already
  says "undoable" — require the pairing there. **Answer:** that would refuse
  every reversible verb in every shipped feature (standard set, oriel, shop)
  for a property only flows use; "reversible" is what the effect IS,
  `compensates=` is HOW a flow reverses it.
- **(b) require `compensates=` on every `consequence=reversible` verb.**
  Rejected (above).
- **(c) read the pairing from the feature's contract module (`[?def …
  [compensates]]`).** Rejected: the grammar is the single statement of the
  feature (§1); a module-only fact is invisible to `[$xap:compose]`,
  `validate` at the XAP face and the picture.

## PW-2 — the inbox before `fleet` — RULED (a)

- **(a) RULED — the inbox lands in W4 WITH `fleet` (it IS a lensed
  projection over the fleet readout, §4.13); W3 ships the offered-step
  machinery — proposal/human-task/agent/peer completion, ladders,
  `claim`/`release`/`reassign` — against runs addressed by id (the #787
  approval widget renders a step from `status`).** §11's inbox-lens fixture
  moves to W4's row. **DELETES:** nothing. **KEEPS:** one readout mechanism.
- **(b) a W3 inbox over a per-run `status` scan.** Rejected: a second
  readout path the fleet replaces one wave later.

## PW-3 — how an `[approval]` correlates to a run and step — RULED (a)

- **(a) RULED — by the recorded proposal address, nothing new on the
  approval:** the offer records `proposal=<Tier-1 of the proposal>` on the
  step row (§2.2); the completing event is `[act run= step= status=:done
  [approval …]]` and `advance` accepts it iff the approval's `[subject
  hash=]` equals the step's recorded `proposal=` and the approval verifies
  (`authz commit` under the shipped rules) — `CXER4958` otherwise. **DELETES:**
  nothing; `authz` untouched. **KEEPS:** the approval's one binding (the
  address) and its forgery posture.
- **(b) add `run=`/`step=` to `[approval]`.** Rejected: changes a signed
  Lane-2 claim's shape for one consumer; the address already correlates.

## Edit map (W3, ruling-gated; `RULED: 1265-PW-1` on the commits that touch spec/**)

| Where | Edit |
|---|---|
| `xap_schemas/feature.cxs` `[verb]`, `grammar.cxs` | `compensates::string [opt]` |
| `xap_grammar_composition.md` §6 | one paragraph: the pairing attribute, carried verbatim; the gate row for a missing/non-act target |
| `flow.md` §4.1 / §4.7 | the XAP-face resolver reads `compensates=`; §4.13 "W4" marker on the inbox; §4.6 the PW-3 sentence |
