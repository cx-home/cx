# Rulings 2026-08-21 — the diagram ingress reads data documents (#910)

## D910-1 — the ingress gains the run surface's guarded data fallback

**Status:** RULED (owner directive "fix #910 in-line once the gates come back
green", 2026-08-21, on the #910 report and its suggested shape 1 — "give
`cx diagram` the same reading the run action uses"). Landed after the ASP-2
full gate returned green (`make test-vcx` GATE-RC=0, oriel lane OK at
ff60084d).

**The defect.** Every diagram lane — `cx diagram` / `of-source`,
`cx code-diagram`, the effects view — lifts source through the ONE ingress
primitive `[$diagram-program-image SRC MODE]` (DRW3-3,
vcx/code/stdlib_diagram.v), which parsed with the PROGRAM reading only. The
default run action reads a pure-data document via the data reading
(code.md §1.3 — "a pure-data resource evaluates to itself"), so a document
every other verb accepts could not be diagrammed: the shipped
examples/config.cx refuses with a token-level error in `cx diagram` and
silently degrades to the EMPTY `erDiagram` placeholder in `cx code-diagram`
(measured: three data-only idioms trip it in sequence — the spaced `::T`,
bare URLs, bare filesystem paths in prose bodies).

**The rule.** The ingress primitive applies the run surface's OWN guarded
fallback (the eval_code contract, verbatim guards): when the program parse
fails AND the failure is not unambiguous program intent (unknown/retired
directive, program-committed syntax error) AND the data reading carries no
registered `[?directive]` AND the source parses as DATA — the DATA tree is
lifted to the same injected image the program lift produces (elements,
`cx:attr` children, typed scalar tags, `cx:seq`/`cx:arr`/`cx:map`; the #898
`err`-rename applies identically). `eval_code`'s diagram-target arm applies
the same fallback so `cx diagram` reaches it. A source BOTH readings refuse
keeps the existing behavior verbatim: `of-source` surfaces the ingress
`[err]`; `code-diagram` degrades to the text-level classification
(spec §10.1 step 3) — every placeholder golden keeps its pin (verified
against the 88-source corpus: each placeholder source is blocked by the
directive guard, the unbalanced-source guard, or the pre-prim empty check).

**Not in scope, filed separately:**
- The data reader ACCEPTS the spaced `::T` annotation and silently
  normalizes it to the glued form, while lexicon [L50] defines the
  annotation as GLUED only ("binds to the token on its LEFT") — an
  undefined spelling silently accepted, the #793 class. Needs its own
  adjudication (refuse loudly vs spec the leniency): filed as #911.
  examples/config.cx showcases the spaced spelling and is left as-is
  pending that adjudication.
- `cx code-diagram`'s silent RC=0 placeholder for a source both readers
  refuse is spec'd (§10.1 step 3) and stays.
