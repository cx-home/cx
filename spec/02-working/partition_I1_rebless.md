# I1 identity epoch — deliberate-red ledger + re-bless obligations

**Status:** live working ledger on `impl/I1-identity-epoch`. Every entry is a
fixture class that is RED ON PURPOSE mid-epoch (its pinned bytes moved by a
manifest row) plus the obligations the final coordinated re-bless must
discharge. Nothing here is a regression; anything red that is NOT in this
ledger IS one. Updated per epoch commit.

## Red classes (verified intended, per triage)

| Class | Cause (manifest row) | Re-bless action |
|---|---|---|
| `identity_hash.cxd` singles idh-001…005 | W-14 LF (row 2) — every Tier-1 digest moved | re-bless digests; record old→new in the mapping file |
| `operator_heads.cxd` oph-001…005 digests | W-14 LF now; row 8 will move them AGAIN (stringify → element) | re-bless ONCE, after row 8 lands |
| `journal.cxd` ×27 + `sched.cxd` sched-022 | chain preimages ride canonical bytes (rows 2/10-12) | re-bless chains after the ts-form (#712) + detached-payload (#720) land, not before |
| `store.cxd` ×6 (address literals) | store keys are Tier-1 canonical addresses | re-bless literals |
| `xap-dist.cxd` ×4 (pinned tree/manifest hashes) | package tree hashes are Tier-1 | **re-seal the committed `registry/`** (gtin@0.1.0 re-publishes under epoch bytes) + re-pin fixtures + `xap_registry_serve_real_test.v` consts |
| `bus.cxd` bus-026 (hardcoded doc address) | store put-doc address moved | re-bless the literal |
| `cx.cxd` ×8 incl. cx-010 | address literals + the serialize-vs-canonical LF seam | re-bless literals; **cx-010 fixture-semantics note:** `cx:serialize` is the FRAGMENT emitter (LF-less), `cx:canonical` is a complete POSIX text file (W-14) — the fixture's equality re-forms as `serialize + "\n" ≡ canonical` |

## Pins that FLIP at specific rows (stay red until that row, then re-bless)

- `idh-023` (decimal scale) → row 1 (L40 scale-preserving identity)
- `idh-026` ($x vs '$x') + `cx-094` (quote-hash E210) → row 9 (quote lowering)
- `oph-001…007` semantic flips → row 8 (operator-head lexer fix)
- `store-code-003…006` (Tier-2 collisions) → row 13 (participating-field set)
- data-bin decimal/bigint goldens → rows 1+16 (0x18/0x28); ch-008…011 must stay
  BYTE-IDENTICAL (proven-untouched kinds) — if they move, that is a REGRESSION

## Mapping file

`spec/02-working/partition_I1_hash_mapping.md` (authored at re-bless): one row
per moved artifact class with a representative old→new digest pair per row,
plus the full corpus diff as the exhaustive record (the re-bless commit).

## Epoch commits so far

1. W-14 trailing-LF-in-hash (row 2) — every digest +1 byte coverage.
2. W-7/L20 UTC-Z datetime normalization (row 2) — instant identity.
3. Datetime/date typing precedes the float arm (row 2 companion) — fractional
   temporals type correctly everywhere; closes the quoted-attr residual.
4. W-19/L24 duplicate attrs incl. xmlns = parse error `cx-err:E214` (row 2) —
   parse gate green, no corpus reliance. SPEC-EDIT OBLIGATION: E214 row into
   cxdm.md's error table (rides the epoch's spec-edit-map execution).

## Row-2 warts remaining

redundant-annotation strip · quote tiebreak · NFC names (needs a Ring-0 NFC
table decision) · multi-doc addresses · CX-owned Ryū audit · triquote-never-
canonical check.
