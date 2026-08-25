# Rosetta Corpus Audit

This audit tracks which programs port cleanly to CX and
which surface gaps each surfaced. Refresh per release boundary.

Initial seed: 5 of 20 programs (acceptance-criteria minimum five).
Programs 03/04, 07–12, 14–20 still to write.
Extension #21 added 2026-05-26 to close gate 47.7 — exercises
the new `url` + `csv` + `validate` triad.

Last revised: 2026-05-26 against `v0.8.0-dev` HEAD (post math-operator surface).

| Program | Last-revised HEAD | Status | Gap count | Gaps / follow-ups |
|---|---|---|---|---|
| 01-fizzbuzz-shapes | post math-operator surface | green | 3 | math-operator surface closed `mod` builtin + math-builtin directive-form (resolved) · paren-expression ops (still NEW or fixture-recheck) · `[?def]` impl · multi-arg `[?fn]` apply (NEW) |
| 02-log-parser | `74fe4f5b` | workaround | 3 | string-ops surface — `split`/`tokenize`/`format` (NEW; string-ops hypothesis confirmed) · `contains` directive form (NEW; same family as fizzbuzz #2) · atom-as-attribute-value friction (spec note) |
| 05-rpn-calculator | `74fe4f5b` | blocked | 4 | `$path/child` empty-vs-CXER0001 (NEW or amend `spec/cxpath.md` §6) · predicate-context arithmetic on `last()` (extends CXPath predicate work) · multi-arg `[?fn]` re-confirm · no stack abstraction (note alongside `[?reduce]` companions) |
| 06-bfs | `74fe4f5b` | workaround | 5 | `$bind/child` single-match (CONFIRMED in the gap register) · no `[?loop]` / `[?recur]` (NEW) · no mutable state (deliberate-gap note) · no set ops (NEW) · pattern destructure of `:key val` attribute style (spec note) |
| 13-config-validator | `74fe4f5b` | green | 4 | `exists()` builtin missing (NEW; one-line) · `:where` outer-match modifier (spec clarification) · schema-path alternative (aligns with `spec/schema.md`) · `$bind/child` re-confirm |
| 21-fetch-csv-validate | `e44de53c` | blocked | 0 | **expected pre-impl** — url + csv + validate skeleton bodies pending; flips to green when Phase 3.x V impl ratifies the three companion specs |

## Summary

- **green**: 2 (#01 post math-operator surface, #13)
- **workaround**: 2 (#02, #06)
- **blocked**: 2 (#05, #21 — #21 expected pre-impl, not a surface gap)

## Cross-program gap clusters (≥2 programs)

| Gap | Programs affected | Recommended action |
|---|---|---|
| ~~Math / arithmetic builtins (`mod`, `div`, `floor` directive form)~~ | ~~#01, #05~~ | **Closed 2026-05-26 by the math-operator surface.** `mod`/`div`/`idiv` builtins ship + directive-form dispatch closure for `floor`/`ceiling`/`round`/`abs`. #05 still blocked on other gaps (predicate-context arithmetic, etc.). |
| Multi-arg `[?fn]` apply with non-trivial body | #01, #05 | New surface or extend `[?def]` / `[?reduce]` companions |
| `$bind/child` single-match | #06, #13 | Already in the confirmed-gap register; awaiting a fix slot |
| String ops surface (`split`, `tokenize`, `format`, regex-as-data) | #02 (#03 / #04 / #10 / #15 / #16 expected) | New surface (string-ops hypothesis) |
| Paren-expression with operators (`$x > 4`, `$a + $b`) | #01 (potentially most programs) | Fixture-recheck or new surface — `conformance/code.txt:3495` currently parse-fails |

## Hypothesis-register probes (2026-05-26)

Direct probes of the confidence-ranked surface-completeness hypothesis register
(probe-then-decide), not corpus programs. Each is WORKS (fixture
added) / FIXED (cheap impl + fixture) / GAP (writeup + parked stub).

| # | Hypothesis | Verdict | Evidence / disposition |
|---|---|---|---|
| #33 | Map iteration `[?for $k, $v :in $m]` / `:keys` / `:values` | **GAP** | Two-binding generator does not parse (`CXER0100` on the comma); single-bind `$kv :in $m` binds the whole map, not entries — `iterate()` + `materialize_to_items()` have no `cx.MapNode` case. Crosses parser + a missing entry-iteration *protocol* + eval binding; over the 30-line cap. Parked as a map-iteration design item. |
| #35 | `:order-by EXPR :desc` + multi-key | **WORKS** (desc) / **GAP** (then-by, with workaround) | `:desc` works — but the direction is a **bare ident** `desc` (`:order-by $u/@age desc`), NOT a colon-clause; `:desc` raises "unknown for-comprehension clause". Eval already honors `bc.direction == 'desc'` (`eval.v` ~5972) with a stable insertion sort. `:then-by` does NOT exist, but multi-key sort is fully expressible by **chaining `:order-by`** (sort secondary-key first; the stable sort preserves it within primary ties). Fixtures `program-order-by-desc-001`, `program-order-by-multikey-001`. |
| #42 | Char-level string access `"hello"[0]` | **WORKS-AS-DESIGNED** | `$s[1]` returns the whole string and `$s[2:4]` is empty — strings are scalars, `iterate(scalar)` → 1-element seq, so `[]` does not do char access (intentional; not a gap). The blessed path is the `substring(s, start, len)` builtin (1-indexed, XPath `fn:substring` convention): `[substring $s 2 3]` → `"ell"`, `[substring $s 1 1]` → `"h"`. Documented + fixture `program-string-index-001`. |

**Single most important gap for the next design cycle:** map entry
iteration (#33). It blocks corpus program #10 (word-count,
needs sort-by-count over a frequency map) and is the only one of the
three probes requiring real design (a Map-entry iteration protocol /
value-kind decision), not a doc note or a cheap flip.

**Surface-syntax footgun surfaced (worth a guide note):** the
`:order-by` direction is a bare `asc`/`desc` ident, not `:asc`/`:desc`.
Every other modifier in the for-comprehension is a colon-clause, so
`:desc` reads natural and silently fails to parse. Candidate for a
playground-cookbook clarification or accepting `:desc` as an alias.

## Acceptance-criteria status

Re-checking the five acceptance criteria for the audit process:

1. ☑ `corpus/rosetta/` exists with ≥5 programs + `.md` narratives.
2. ☑ `corpus/rosetta/AUDIT.md` exists with per-program table (this file).
3. ☑ ≥1 cross-reference doc exists (`spec/cross-ref/xpath-31.md`).
4. ☑ ≥1 surface fix motivated by a corpus gap — the **math-operator
   surface** was filed as the first deliverable from this audit cadence
   and now ships; it closed `01-fizzbuzz-shapes` from blocked → green.
5. ☑ Cadence reference carried into the next surface discussion — the
   math-operator surface work references both this audit and the corpus
   gap directly.

The acceptance criteria are met by the v0.8.0-dev cadence:
the audit caught a gap on program #1, a fix was filed within the
week, and it shipped before the next release boundary. The
discovery instrument is working as designed.
