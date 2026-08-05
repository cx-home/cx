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
| `conversions.cxd` conv-006 | row 1 L43: a decimal MAP VALUE now carries its postfix ascription (`score: 3.14::decimal`) — the pre-epoch bare spelling silently re-imported as FLOAT (the defect stream 11 names) | re-pin to the ascribed spelling |

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
8. Multi-doc addresses L30 (row 2, W-27): a legal multi-document CX file
   HAS a canonical form and an address — per-document strict-canonical
   fragments joined by the bare `\n---\n` line, one file-level trailing
   LF (W-14). cx_text_canonical rides parse_stream (single-doc bytes
   unchanged — same lexer, `---` only at top level); the per-document
   pipeline is extracted as cx_canonical_doc_text, the single source of
   pass order. §3.12.2 alignment: cx_data_bin_hash had DRIFTED (missing
   datetime + annotation passes and the W-14 LF) — it now composes the
   same helper, so data-bin and text lanes hash one logical document
   identically (its digests were never pinned — invariance-only use).
   Zero corpus movers; gates at the same ledgered reds.
9. CX-owned Ryū L18 (row 2, W-14-float) + W-3: float bytes are Ring-0-
   owned — ryu_f64.v vendors the shortest-digits core + pow5 tables from
   the pinned V fork's strconv (MIT; FROZEN — never re-sync without an
   identity migration) and renders §2.5 exactly: mandatory decimal
   point, sci only when STRICTLY shorter (tie → fixed: `0.0001`),
   `1.0e10` mantissa-dot form, bare lowercase exponent (`1.0e-7`, was
   V's `1e-07`), `-0.0` distinct, subnormals exact. Spellings converge:
   `1e10` ≡ `1.0e10` ≡ `10000000000.0` (one address). W-3: non-finite
   floats have NO canonical form — reject_nonfinite_floats errors the
   canonical/hash lane (§1.3), and `::float` coercion of an overflowing
   literal fails loud at parse (CXER0109). Zero corpus movers (corpus
   floats are all simple fixed forms); float-form pins live in
   canonical_float_test.v.
10. Whitespace-only strings are VALUES (W-6 companion, owner-ruled (a)
   2026-08-05): `[a ' ']` survives quoted — the emit-side whitespace
   skip is gone; XML LAYOUT whitespace now strips at IMPORT
   (xml_parser.v text flush), which is where layout exists. The
   lossless envelope forwards every string child. One carve-out: a
   single-space TextNode BETWEEN two siblings is the parser's
   reconstructed join space (`[p &amp; &lt;]` round-trips it) — the
   bare spelling is canonical; multi-space between siblings quotes.
   `[n::string '  ']` strips its ascription (every string body carries
   its own type now). Zero corpus movers after the join-space rule
   (core-013/xml-009 entity fixtures pin the bare spelling and stay
   green); gates at the same ledgered reds.
11. Unicode names L22 (W-9) + UTF-8 validity (L23 first half): both
   engines widen to the grammar's [L10a]/[L10b] ranges IN STEP (data
   lex_name + element-vs-array disambiguator; program-lexer ident
   dispatch + continuation; xml_read_name — CX⇄XML stays bijective).
   The codepoint predicates + UTF-8 decoder live in lexical.v — the
   ranges are the grammar's own, no Unicode database involved. The
   data parse entries (parse / parse_stream) validate UTF-8 up front:
   truncation, bad continuation, overlongs, encoded surrogates, and
   >U+10FFFF all refuse (CXER0100), so no invalid byte can reach a
   name, value, or the canonical byte stream. Non-name codepoints
   (`[© 1]`) keep routing to the array/text lane. Differential
   unchanged (both engines moved together; namechar fork green).
   OPEN half: NFC normalization of names (L23 second half) — BLOCKED
   on the UCD source files (owner asked a/b on downloading them);
   until it lands, NFC-vs-NFD spellings of one name are two names.
   MUST land before the re-bless.

12. Row-1 invariant slice (stream 11, L39/L43/L45/L47): postfix value
   ascription `value::T` in collection positions — map values, sequence/
   array items, AND map keys (`{1.10::decimal: x}`; read_map_key keeps a
   glued `::` in the key token). Typed carriers are STRICT (defect G):
   decimal = fixed-point base-10 only (exponent form is scale-ambiguous
   → CXER0109), bigint = base-10 integer, duration/period validate via
   temporal_span_kind. §6 normalization at coerce: `+`/redundant leading
   zeros strip, `.5` → `0.5`, negative zero → positive with scale kept,
   trailing fraction zeros PRESERVED. Emit: decimal collection values/
   keys always carry the postfix ascription; bigint carries it exactly
   when ≤ i64 (annotation-iff-retyping, both attr + element lanes).
   Ascribed non-key kinds reject as map keys. One corpus mover ledgered
   (conv-006). OWNER RULINGS RECORDED: 2b — bare fixed-point fractions
   become DECIMAL at I1 (floats = exponent form / ::float; float
   canonical amends to exponent-always); 1a — I download the UCD files.
   SEQUENCING: the 2b autotype flip lands WITH/AFTER decimal arithmetic
   (evaluator still rejects decimal math — flipping first would break
   every fraction computation). Remaining row-1 commits: value
   semantics (equality/ordering), arithmetic+casts (L44, CXER3002
   division), the 2b flip + idh-023, data-bin 0x18/0x28 (row 16) +
   ast-bin widening + M23 advisory window, json all-decimal/streaming/
   --strict/host mappings. Table CELLS with decimal columns still ride
   lenient coerce_scalar — normalize at the arithmetic commit.
13. Row-1 value semantics (L40/L42): equality and ordering are
   MATHEMATICAL across the exact family int/bigint/decimal — pure digit
   comparison (cx/numeric_exact.v: cx_exact_num_cmp on the base-10
   images; no f64 round-trip, so bigint ordering is exact beyond 2^53
   and decimal scale digits never merge). `bigint 99 = int 99` and
   `1.10::decimal = 1.1::decimal` are now true; decimal/bigint vs
   STRING is ALWAYS false (the string arm said decimal "1.10" = string
   "1.10"); decimal vs FLOAT stays unbridged — equality false,
   ordering CXER0100 (L44: [cast] is the only bridge). nodes_equal +
   the `<`-family both gained the exact branch; int×int keeps its
   legacy path byte-for-byte. Pinned in
   decimal_bigint_semantics_test.v; zero corpus movers, gates at the
   ledgered reds.

## Row-2 warts remaining

NFC name normalization ONLY (owner ruled (a) — CX-owned generated
tables; owner ruled 1a on sourcing: I download the three UCD files
with a pinned version; the last row-2 item).
