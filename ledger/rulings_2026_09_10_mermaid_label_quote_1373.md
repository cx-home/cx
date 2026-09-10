# RULED: 1373-a — the mermaid label escape for a double quote is the entity `#quot;`

**Fable, 2026-09-10 00:50Z, under the owner's delegation:** (a). Refused (b)
folding or stripping the quote (lossy: the #992 class of silent wrongness) and
(c) skipping quote-bearing diagrams in the gate (hides a renderer refusal).
Implemented by the Fable session the same hour.

## What was wrong

`diagram.md` §4 prescribed the escape set `\` → `\\`, `"` → `\"`, newline →
`\n`, and `stdlib/diagram.cx` `esc` implemented it. Mermaid's quoted-label
grammar (`["…"]`, bundled renderer 10.9.8) has no backslash escape: `\"` is a
parse error, so every diagram whose label carried a quote was refused —
measured by `test-playground-mermaid` on 237 (worked around with single-quoted
attributes), on the new 241/242 format examples, and in worker C's ten-failure
census. The spec sentence was wrong for the renderer it names.

## What changed

- `esc`: `\` → `\\` first, then `"` → `#quot;` (mermaid's documented entity),
  then newline → `\n`. The ERD lanes keep their own entity-name quoting
  (`cd-erd-quote`, `&quot;` in comments) — those are erDiagram rules, not the
  flowchart label rule, and they were not the failing path.
- `diagram.md` §4 escape set and the "nothing else" sentence carry the new
  spelling and the token; §9 still says "the escape set is §4's".
- Fixture `diagram-034` (RED before: `(false, true)`): a source with a quote
  inside a single-quoted string images `#quot;` and no `\"`.
- Goldens: no committed code-diagram golden or `diagram.cxd` pin carried `\"`
  (grep across both corpora: zero), so nothing moves; `test-code-diagram`
  confirms.

## DELETES

The `\"` spelling in the spec and the emitter; the workaround note on
example 237 (its single-quoted attributes stay — they are also valid XML).
