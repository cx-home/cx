# Batch #795 — canonical-forms kind erasure (#790, #791, #794)

Status: Working ledger (the batch's design + migration record)
Ruling basis: the #795 batch ruling (owner, **RULED: 1a**, 2026-08-13 —
recorded on the issue): the three siblings land in ONE sitting through
the quote-choice/canonical authority; **any canonical-byte movement
ships with an owner-visible migration note and a deliberate corpus
re-bless** (the #563–#565 precedent). The packet §10 arc-7 places the
batch before the cut.

## The unifying defect

Canonical text — the identity-bearing form — erases or mangles
identity-adjacent kinds in three places. The sharpest evidence (probed
live 2026-08-14): `[order [xref ("a", 2)]]` and `[order [xref (a, 2)]]`
have **identical Tier-1 hashes** while parsing to **different node
kinds** (string Scalar vs Text) — canonical is non-injective across a
type boundary, violating "byte-identity IS data equivalence"
(canonical.md's own §1 contract).

## The three fixes (each through the canonical authority)

### #790 — string scalars in sequences / map values render bare

- Live: `("a", 2)` → canonical `(a, 2)`; re-parse yields Text (kind
  flip); hashes collide with the genuinely-bare form.
- Fix: a **string ScalarNode** item in sequence / map-value position
  ALWAYS emits through `cx_choose_quote` (quoted). TextNode items keep
  the bare-when-safe policy (bare tokens re-parse as Text — already a
  stable fixpoint). Both kinds become fixpoints; canonical becomes
  injective across the boundary. The nested-ARRAY half of the issue's
  repro is already healed by the array-item rule (probed live: `"x"`
  in a nested array literal renders `'x'`); arrays' deliberate
  Text/Scalar conflation (the fmt-oscillation fixpoint) is untouched.
- Movement: documents spelling quoted strings in sequence/map-value
  positions re-address (their canonical gains quotes). The cxparse
  corpus-diff divergence count steps DOWN (the +2 rows of this class
  in the blessed baseline re-classify to agree).

### #791 — the text-run/child separator space is presentation

- Live: `[attr sku::string [req]]` → Text value `'sku::string '`
  (the separator space before `[` rides INSIDE the run) → canonical
  quotes it → the schema lane loses the annotated-bareword form
  (S002 enforcement silently vanishes). The class is GENERAL:
  `[attr x [req]]` → `[attr 'x ' [req]]` for ANY text+child body.
- Fix: the parser trims the whitespace at a text-run's CHILD-ELEMENT
  boundary — the separator between a body text run and an adjacent
  child `[` is a token separator (presentation), not content, exactly
  as the separator after the element head already is (the current
  behavior is asymmetric: head-side trimmed, child-side kept). Bare
  `sku::string` is already a stable bare canonical fixpoint (probed),
  so the schema lane heals with zero quoting special-cases. Internal
  run whitespace stays verbatim (`the quick fox` untouched).
- Movement: documents with text+child mixed bodies re-address (the
  quoted `'x '` forms become bare `x`).

### #794 — atom table cells render as quoted strings

- Live: `status::atom` cells `:ok`/`:err` → canonical `'ok'`/`'err'`
  (the atom kind erased; re-parse yields string cells under an
  atom-typed column). The wire (0x70 atom columns) is transparent —
  this is the text lane only; the ttp-004 pair fixture's out-cx pins
  the buggy quoted form and anticipated this re-pin by name.
- Fix: a cell in an atom-typed column whose value is atom-shaped
  emits `:value`; a non-atom-shaped value in that column keeps the
  quoted-string form (the honest escape — never invent an atom that
  would not re-parse).
- Movement: documents with atom-typed table columns re-address.

## Migration note (owner-visible, the ruled form)

All three fixes MOVE canonical bytes — and therefore Tier-1 addresses —
for the affected input classes (quoted-strings-in-sequences/maps,
text+child mixed bodies, atom-column tables). CX has no external users
(the standing record); the movement is repo-internal and lands as a
deliberate corpus re-bless in this batch: the cxparse corpus-diff
counted baseline (divergence steps down), the canonical/conformance
goldens of the affected classes, and any pinned hashes over affected
shapes. Every re-blessed pin is enumerated in the batch's commits.
