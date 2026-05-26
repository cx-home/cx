# Rosetta Corpus Audit

Per ADR 0045, this audit tracks which programs port cleanly to CX and
which surface gaps each surfaced. Refresh per release boundary.

Initial seed: 5 of 20 programs (per ADR 0045 D3 acceptance criteria
#1 — minimum five). Programs 03/04, 07–12, 14–20 still to write.
Extension #21 added 2026-05-26 to close [ADR 0047 §D8 gate
47.7](../../spec/decisions/0047-stdlib-surface-v0_8_0.md) — exercises
the new `url` + `csv` + `validate` triad.

Last revised: 2026-05-26 against `v0.8.0-dev` HEAD `e44de53c`.

| Program | Last-revised HEAD | Status | Gap count | ADRs motivated |
|---|---|---|---|---|
| 01-fizzbuzz-shapes | `74fe4f5b` | blocked | 5 | no `mod` builtin (NEW) · math builtins directive-form (NEW) · paren-expression ops (NEW or fixture-recheck) · ADR 0034 `[?def]` impl · multi-arg `[?fn]` apply (NEW) |
| 02-log-parser | `74fe4f5b` | workaround | 3 | string-ops surface — `split`/`tokenize`/`format` (NEW; ADR 0045 hypothesis #34 confirmed) · `contains` directive form (NEW; same family as fizzbuzz #2) · atom-as-attribute-value friction (spec note) |
| 05-rpn-calculator | `74fe4f5b` | blocked | 4 | `$path/child` empty-vs-CXER0001 (NEW or amend `spec/cxpath.md` §6) · predicate-context arithmetic on `last()` (extends ADR 0043) · multi-arg `[?fn]` re-confirm · no stack abstraction (note under ADR 0040) |
| 06-bfs | `74fe4f5b` | workaround | 5 | `$bind/child` single-match (CONFIRMED in 0045 register) · no `[?loop]` / `[?recur]` (NEW) · no mutable state (deliberate-gap note) · no set ops (NEW) · pattern destructure of `:key val` attribute style (spec note) |
| 13-config-validator | `74fe4f5b` | green | 4 | `exists()` builtin missing (NEW; one-line) · `:where` outer-match modifier (spec clarification) · schema-path alternative (aligns with ADR 0009) · `$bind/child` re-confirm |
| 21-fetch-csv-validate | `e44de53c` | blocked (expected pre-impl) | 0 | ADR 0047 url + csv + validate skeleton bodies pending — flips to green when Phase 3.x V impl ratifies the three companion specs |

## Summary

- **green**: 1 (#13)
- **workaround**: 2 (#02, #06)
- **blocked**: 3 (#01, #05, #21 — #21 expected pre-impl, not a surface gap)

## Cross-program gap clusters (≥2 programs)

| Gap | Programs affected | Recommended action |
|---|---|---|
| Math / arithmetic builtins (`mod`, `div`, `floor` directive form) | #01, #05 | New ADR for directive-form `floor`/`ceiling`/`round`/`abs` and `mod`/`idiv` |
| Multi-arg `[?fn]` apply with non-trivial body | #01, #05 | New ADR or extend ADR 0034 / ADR 0040 |
| `$bind/child` single-match | #06, #13 | Already in ADR 0045 confirmed-gap register; awaiting new ADR slot |
| String ops surface (`split`, `tokenize`, `format`, regex-as-data) | #02 (#03 / #04 / #10 / #15 / #16 expected) | New ADR (hypothesis #34) |
| Paren-expression with operators (`$x > 4`, `$a + $b`) | #01 (potentially most programs) | Fixture-recheck or new ADR — `conformance/code.txt:3495` currently parse-fails |

## Acceptance-criteria status (ADR 0045)

Re-checking the five criteria from ADR 0045 §"Acceptance criteria":

1. ☑ `corpus/rosetta/` exists with ≥5 programs + `.md` narratives.
2. ☑ `corpus/rosetta/AUDIT.md` exists with per-program table (this file).
3. ☑ ≥1 cross-reference doc exists (`spec/cross-ref/xpath-31.md`).
4. ☐ ≥1 NEW ADR motivated by corpus gap — pending: the math-builtin or string-ops or `[?fn]` apply gap each motivates a separate slot. File the next-numbered ADR after merging this seed.
5. ☐ Cadence reference in next ADR-affecting discussion — to be confirmed by the next ADR's "Composes with" / "Acceptance criteria" sections.

This audit is therefore one ADR-slot away from moving ADR 0045 itself
from Draft → Accepted. The unblocking move is to file the highest-
signal new gap as an ADR (suggested: math-builtin directive form,
which blocks the smallest possible program — FizzBuzz).
