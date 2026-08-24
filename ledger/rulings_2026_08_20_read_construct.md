# Rulings 2026-08-20 — collection read/construct split (#882)

## ARR-1 — readers destructure any collection; constructors keep container typing

**Status:** RULED (owner batch "still several bugs that should be able to be
fixed: 877, 881, 882" — fix authorization). Ratifies the SHIPPED engine
behavior, which itself implements the #529 ruling ("orderedness is a
property, not a representation").

**Ruling.** The Sequence/Array/Iterator container distinction binds
**constructors**, never **readers**:

- *Readers* — `count`, `length`, `empty`, `exists`, `first`, `last`, `nth`,
  `head`, `tail`, `distinct` — destructure ANY collection kind and answer
  over its items. `[$count [1,2,3]]` is `3`, exactly as on a Sequence.
  (All ten live-verified this session; `head`/`tail`/`distinct` project a
  Sequence result.) The refused alternative — readers rejecting Arrays —
  had produced the silent wrong answer of a collection counting as one
  scalar.
- *Constructors and combiners* — `concat` — keep strict container typing:
  `[$concat [1,2] [3]]` is a type error (live-verified: builtin-signature
  refusal), because building a Sequence out of Arrays would erase the
  distinction cxdm §2.1 exists to carry.

**What changed.** No engine change — the engine was already right; the DOCS
contradicted it.
- `spec/03-approved/core/cxdm.md` §2 — read-vs-construct paragraph added
  (RULED ARR-1), stating both halves.
- `docs-src/canonical/sections/02-data-language.cxd` — the passage that
  taught `count(arr)` as a type error (FALSE live) and named fictional
  builtins (`items`, `array:size`, `map:keys`, `map:get`, `union`,
  `intersect`, `except` — all `no callable` live) rewritten on verified
  facts only: the read/construct split, `[$concat]` refusal, `$m.name`
  map-key read.

Closes #882.
