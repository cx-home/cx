# RULED: 1361-a — the document top is an unnamed value slot: a root `v::T` token is the typed scalar; an element body is a named slot and stays [27]

**Fable, 2026-09-10 02:40Z, under the owner's delegation:** (a). Refused (b)
keeping the top on grammar [27] (a root `2026-01-01::date` stays text, a
root `bytes` value has no spelling at all, and the issue's acceptance 2 —
"the top means what the map means" — is re-ruled away for nothing gained)
and (c) giving BOTH the top and the element body the postfix reading (tried,
measured, refused: the schema dialect's body tokens `[type job::null]`,
`[type title::int]`, `[type xref::ref]`, `[attr x::int]` — 30 rows in
`schema_validate.cxd`, 26 in the approved xap `.cxs` schemas, 27 in the V
umbrellas, every user `.cxs` — become coercion failures or CXER0107; the
`#1361` lane reddened three `sv-` fixtures with S009 on the first run).

## The principle

Explicit scalar typing has two spellings for two kinds of slot, and the
grammar already says so ([27] note, MSS-4): the **glued name** ascription for
a NAMED slot (element head `[port::u16 8080]`, attribute, param, key) and the
**postfix value** ascription `v::T` for an UNNAMED value slot (sequence item,
map value — L43). The document top is an unnamed value slot — a bare root
value stands there with no name to glue a type to — so it takes the postfix
reading, checked exactly as a map value is: `2026-01-01::date` is the date,
`true::string` is the string, `abc::int` is CXER0290, `5::bogus` is CXER0107.
An element body is a named slot: its type goes on the head (`[b::bytes
0x2a]`), and a body token `name::kind` is text — which is what the schema
dialect's declaration token has always been.

## RULED: 1361-b — canonical §2.6a's merged column is read per slot kind

`canonical.md` §2.6a's third column, "Element body / collection item / map
value", gave the decimal/bigint/bytes rows a single postfix spelling
(`2::decimal`, `0x2a::bytes`) for all three positions. Measured at the tip,
`[n 2::decimal]` and `[b 0x2a::bytes]` are Text — the element body has never
carried a postfix ascription, and grammar [27] (RULED MSS-4) says it must not.
The column is trued to the RULED grammar, not to the shortfall: a paragraph
before the table names the two slot kinds, and the three rows spell the
element-body form as the glued head. No image changes; no emitter changes.

## What changed

- `parser.v` root single-token lane: `try_split_postfix_ascription` +
  `coerce_scalar_checked` first, a `::`-carrying token with a bad tag refuses
  CXER0107, else `try_autotype`, else text. The element-body lane is
  UNCHANGED (the postfix attempt there was reverted before landing).
- `grammar.ebnf` [27] note names the document top beside collection
  positions and states the body rule; `canonical.md` §2.6a as above.
- Fixtures (`extended.cxd`): 059 pins the body split (`[b 0x2a::bytes]` is
  Text, `[b::bytes 0x2a]` is bytes); 060 the root date followed by an element
  (RED before: Text with the newline); 061 the root `5::bogus` refusal (RED
  before: text); 062–066 the composed playground shape (value, blank line,
  `[; … ]` note) for the four trigger-table rows of Defect 1 and the root
  twin — Defect 1 no longer reproduces at the tip, and these pin that.
- **Defect 1's mechanism, found and closed in the same landing:** the
  PROGRAM parser (`program_parser.v`) took the postfix value ascription only
  after a NUMBER token (#776), so `{c: 2026-01-01::date}`, `(1, true::string)`,
  `:ok::atom`, `100ms::duration`, `null::null`, `abc::string` were CXER0100
  in the program reading. A `cx FILE` run whose document opened with such a
  map therefore fell out of the program reading into the DATA reading, and
  the data reading's lossless emitter printed the `[; … ]` note as a second
  root — exit 0. The trigger table in the issue is exactly the set of
  non-numeric kinds. `postfix_ascription_ahead` + `ascribed_scalar_literal`
  now run for every scalar literal arm (bool, duration, period, date,
  datetime, ident, atom), through the same checked core the number arm and
  the data reading use — `abc::int` is CXER0290 in both readings.
- Fixtures: the composed shapes are PROGRAM-lane cases in `code.cxd`
  (`program-ascription-composed-001…005`, `program-ascription-postfix-001/002`)
  because `code_eval_fixtures_test.v` grades `code.cxd` + `stdlib/` only —
  the `[in-code]` cases in `extended.cxd` are graded by no lane, filed as
  #1379. The date row is pinned kind-precisely in the data reading
  (`extended.cxd` 062, `out-ast`): the program renderer images a date-typed
  map value QUOTED against code.md §11.1a R2 — a pre-existing renderer
  defect, filed as #1378, so its program-lane twin waits rather than pin a
  wrong image.
- Playground example `191-map-checked-ascription` returns to the corpus
  (issue acceptance 4) with float/string/atom entries (no date, per #1378).
- `cxparse_full_corpus_diff_test.v` baseline re-blessed for the four
  `in-cx`-bearing extended cases.
