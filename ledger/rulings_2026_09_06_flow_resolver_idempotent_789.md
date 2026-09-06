# Ruling 2026-09-06 — #789, the resolver row carries `idempotent=` (WF-38)

**Status: RULED (a) under the standing letter-acceptance rule.** Ruling id
`789-WF-38a`. Branch `design/789-workflow`. Open to an owner veto.

**What raised it.** The `needs=` packet landed and stopped before
`attempts=` on a blocker that is real and structural, not effort. §4.8
requires `validate` to refuse `attempts=` where "the step's resolved command
declares no `[idempotent]`", naming the verb. The ONLY channel through which
`validate` sees a command is the resolver element, whose row is
`[act name= resolved= compensates=?]` — `vcx/cmd/flow.v:238` builds exactly
those three, and `idempotent=` exists nowhere in the tree. So WF-26's gate is
not implementable as the spec stands.

## WF-38 — how the `[idempotent]` disposition reaches `validate` — RULED: (a)

- **(a) RULED — the resolver `[act …]` row gains `idempotent=`, built by the
  executing environment from the resolved def, absent meaning NOT
  idempotent.** This is the `compensates=` precedent exactly: that field
  exists on the row for one reason — §4.7's pre-pivot check needed a
  disposition `validate` could see — and this is the same need one
  disposition over. Absent-means-not-idempotent matches
  `commands_effects.md`'s deny-by-default posture, so a resolver that has
  not been taught the field refuses `attempts=` rather than permitting it.
  Under `728-CK-3` a feature package's projected def supplies `[idempotent]`
  from `[verb idempotent=]`, and the row is filled from the projection like
  any other def — the read stays generic over whatever the resolver returns.
  **What it DELETES:** nothing. A row without the field is a valid row; only
  a step carrying `attempts=` cares. **Cost:** one sentence each in §3 and
  §4.23's `--env` description, which is why this is a ruling and not a
  detail.
  **Strongest counter:** the resolver row is accumulating def clauses one
  ruling at a time, and a third will follow. **Answer:** that is the correct
  shape and worth saying out loud — the row is the projection of exactly
  those def properties a flow's STATIC checks need, and it grows when a
  static check needs one. Two so far, each with a named check behind it. A
  row that carried every clause would be the wrong thing; a row that carries
  the ones `validate` must see is the right one.
- **(b) implement `attempts=` ungated for now.** REFUSED by `WF-26` (b) by
  name: it would let a document authorize a double charge.
- **(c) leave `attempts=` pending and implement `until` first.** REFUSED:
  `until`'s `attempts=` is a MANDATORY iteration bound and needs no resolver
  field, so it would ship while the step half stays pending — putting ONE
  attribute in `f--attrs-of` and `f--attr-pending` simultaneously. That is
  the exact drift `make flow-vocabulary-gate` exists to catch, and shipping
  it deliberately to save a round trip is the wrong trade. WF-26 merged the
  two spellings into one attribute for a reason; they land together.

**Sequence this unblocks:** rule (this) → `attempts=`/`every=` → `until` →
the rung-1 gate. That is the dependency order the round-2 packet named.
