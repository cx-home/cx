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
| `extended.cxd` ext-038 + ext-039 | L15/L17 (row 2): quoted canonical text escapes control bytes; triquote never emitted (body + AttValue pins) | re-bless both to the escaped single-quoted spelling |
| `code.cxd` program-string-triplequote-001/003 | L15 render-lane escapes (render_canonical is identity-bearing — store put-doc rides it) | re-bless rendered spellings |
| stdlib multiline-render pins ×18: `csv.cxd` ×11 (csv-008, 025–031, 033/034/037) + `json.cxd` 026–028 + `format.cxd` 009/010/012 + `cx.cxd` cx-060 | fixture results are multiline STRINGS; their rendered spelling now carries §2.4 `\n` escapes (values unchanged) | re-pin expected blocks to the escaped spelling |

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
5. Redundant-annotation strip (row 2) — element-level `::T` clears in a
   canonicalize pass (canonical_annotation.v, after datetimes) when bare
   re-typing of the body image reproduces the value; mirrors the attr lane
   (cx_attr_scalar, D3), which is now LOCKED by the same fixture file.
   Kept: sized/decimal/bigint/duration/period, `::T[]`, empty bodies.
   Eval gate unchanged at the same 47 ledgered reds (zero new).
6. Quote-lane rulings L15+L16+L17 (row 2, W-12/W-13/W-2): §2.4 escapes are
   EMITTED (LF/CR/tab → `\n \r \t`, other C0 → `\u00xx` lowercase, DEL →
   `\u007f`); both-quotes tiebreak = single-quoted `\'` in BOTH lanes
   (cx_choose_quote_render now aliases cx_choose_quote); canonical NEVER
   emits triquote — the verbatim-triquote body and AttValue branches are
   gone; raw control bytes force quoting (cx_has_control_byte). Bijection
   rule untouched (`'\d'` does not churn). New intended reds ledgered
   above (ext-038/039, code triquote ×2, stdlib multiline renders ×18);
   eval gate = those + the prior 47, zero unexplained.
7. Tier-A mechanicals W-1/W-5/W-6/W-10 (row 2): `#id` on an otherwise-
   empty element survives emit (`[a #x1]` → `[a #id-1]`); RawText is
   CONTENT — preserved in strict canonical (`[a [#raw#]]` ≢ `[a]`); the
   EMPTY string is a value — `[a '']` emits `''` (needs-quote covers the
   empty image; whitespace-only NON-empty runs still drop as XML-import
   layout); leading BOM consumed at new_parser, mid-content BOM in bare
   text = CXER0100, BOM inside quoted values stays content (L23 verbatim
   values). Companion fix W-6 exposed: the lossless JSON/YAML envelope
   dropped empty-string children (envelope_child_ll) — now crosses the
   wire. `[n::string '']` strips its annotation again (body survives).
   Zero corpus movers (W-28 coverage gap — pinned by V fixtures in
   canonical_mechanical_warts_test.v instead); gates at the same
   ledgered reds. NOTE (residual, unruled): whitespace-only NON-empty
   quoted strings (`[a ' ']`) still erase — same collision shape as W-6
   but entangled with XML-import layout text; needs its own ruling.

## Row-2 warts remaining

NFC names (owner ruled (a) 2026-08-05 — CX-owned generated tables from a
pinned UCD, generator committed; implement at this row) · multi-doc
addresses (L30, `\n---\n`) · CX-owned Ryū audit (L18, incl. W-3 NaN/±Inf
loud rejection — `1e400` still emits `+inf.0` today) · whitespace-only
string residual (see commit-7 note).
