# RULED: 1058-T1.4-b — the parser names the construct that was never closed

Date: 2026-09-08. Issue: #1058 (T1.4). Ruled by Fable on the issue,
2026-09-08 13:50 ET. Recorded here before implementation, per the campaign's
ruling protocol.

## The defect

`cx FILE` reads source through the CODE projection (`vcx/cx/program_parser.v`)
and answers `[?def] unterminated (missing ']') at line 1:1`. `cx lint` — and
every embedder of `cx.parse` — reads through the DATA projection
(`vcx/cx/parser.v`) and answered `44:1: expected ']' got EOF`: end of file, 43
lines from the mistake. Measured 2026-09-08 on a 43-line file with one missing
`]` in the `[?def]` opening line 1. On `stdlib/flow.cx` one missing `]`
reported ~350 lines away and cost a bisect.

The lint path is the parse check that costs no build slot, so it is the
most-run of the two readings and it had the worse diagnostic of the two.

## The ruling

**(b), additive.** `cx.parse`'s message KEEPS its pinned sentence and its EOF
position and GAINS the opener, appended:

```
1:14: expected ']' got EOF (cx-err:CXER0100) (unterminated [not] opened at 1:1)
```

The pinned text stays an exact PREFIX — position, sentence, code, in that
order. `cx_text_lint` reports the same enriched sentence, so the CLI, the LSP
and the parser answer the same bytes for the same file.

Refused alternatives, with what each deletes:

- **(c)** adopt the code projection's wording verbatim
  (`[?def] unterminated (missing ']')`) — refused: it deletes the only fixture
  in the tree that pins an EOF COLUMN (`cx-137`, below).
- **(a)** enrich the lint path only — refused: it leaves `cx <file>` and
  `cx lint` disagreeing about the same file, which is T1.4's defect restated.

## The two fixtures are RE-CAST, not flipped

Both gained the appended clause; neither had its pinned text altered.

| fixture | corpus | what moved |
|---|---|---|
| `oph-408-unterminated-plus-head-at-eof` | `conformance/operator_heads.cxd` | `out-err` substring gains ` (unterminated [+] opened at 1:1)` |
| `cx-137-validate-schema-load-diagnostic` | `conformance/stdlib/cx.cxd` | exact `out-text` gains ` (unterminated [not] opened at 1:1)`; its `[note]` records why the guard survives |

**The #1178 EOF-column guard in `cx-137`'s `[note]` survives untouched**:
`1:14:` is still the head of the message. The opener's `1:1` is a second,
independent position, so a column regression still shows up in the pinned
head.

## Scope of the message gate — measured, not assumed

The enrichment fires only on an end-of-input failure, because that is the only
class where a bracket left on the tracking stack means "never closed": a parse
that dies mid-document (a duplicate attribute, a malformed QName) also leaves
its erroring bracket pushed, and calling that one unclosed would be a lie
(`vcx/tests/lint_lsp_umbrella_test.v` pins that negative).

The gate covers three families, every site of which this file raises only
under `p.at_end()`:

1. `expected 'X' got EOF` (`expect`, `parser.v:5106`);
2. `unexpected EOF after [`;
3. every `unterminated …` — element body, eval directive, raw text,
   array/sequence/map literal, `:table` header/block, quoted and
   triple-quoted text, `[?=` interpolation, block content.

Family 3 is included deliberately and is not an extension of the ruling's
question: **a missing `]` on a plain data element never reaches `expect`** — it
runs the body reader out of input (`unterminated element body`,
`parser.v:3332`), which is T1.4's defect for the commonest construct in the
language. No fixture and no test pins any family-3 sentence (grepped over
`conformance/`, `vcx/tests/`, `vcx/fixtures/`, `docs/`), so it re-casts nothing
beyond the two fixtures above.

## Cost, and why #1178 is untouched

#1178 is the standing reason not to keep a per-element open record on the hot
path. The diagnostic is therefore computed by re-parsing ONCE, only after a
parse has already failed: `Parser.track_open` is off for every successful
parse, and the cost when off is one bool test per `[`. The record lives at
`parse_bracket_node`, the single site where `[` is consumed for EVERY bracketed
form — element, `[?…]` directive, `[;…]` comment, `[#…#]` raw text, `[!…]`
declaration, array literal. Tracking `parse_element` instead would have missed
exactly the construct the defect was reported on: `[?def]` never reaches it.

`parse_stream` deliberately carries NO enrichment: it reads document after
document from one source, so a failure in the second document cannot be
explained by re-parsing the whole source from offset 0 — the opener named could
belong to a document that parsed cleanly.

## Also on the record from the verify-first pass

- **T1.5 is already implemented at HEAD**, both halves (the directive
  suggestion and the callable one, `vcx/code/eval.v:5960`–`:5966`). Struck from
  the open list by the same ruling.
- **T1.6** (`user-undefined` is load-bearing in the profile gate) and **T1.7**
  (declared routes of differing types) each need their own letter set before
  code.
