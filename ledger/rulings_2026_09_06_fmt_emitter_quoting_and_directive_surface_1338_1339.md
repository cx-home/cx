# Ruling record — #1338 + #1339: the program emitter's quoting rule and its directive surface (2026-09-06)

Issues: #1338 (bug, area:tooling, prio:high) and #1339 (bug, area:tooling,
prio:high). Ruled one at a time, immediately before implementing, per the 3a
cadence. Both premises verified by RUNNING the prod binary, not by reading the
issues.

## How these were found: a bucketed census, not a file-by-file hunt

Every `.cx` outside `third_party/` (263 files) was run through the real
`fmt_source`, and every NO-OP was classified by WHICH verification failed:

| bucket | files | verdict |
|---|---|---|
| A1 program parse fails | 5 | not programs (data lane) |
| A2 canonical text does not reparse | 6 | defect |
| B canonical text is not a fixed point | 7 | defect |
| C interior comment | 73 | needs the #1058 T1.2 layout |
| D depth-0 comments, DATA lane answered | 16 | by design |
| E comment-free, DATA lane answered | 14 | by design |
| F canon reparses to a DIFFERENT SHAPE | 16 | defect |
| X fmt error | 5 | separate |

`changed=121 no-op=137 err=5`. **29 genuine gaps, and they are TWO causes.**

Two corrections this census forced, both recorded because the method matters
more than the count:

- A prior pass put the figure at **12**. It had no SHAPE bucket, so F's 16
  files — whose canonical text is a stable TEXT fixed point but re-parses to a
  different AST — were invisible.
- A first run of the new census reported **53**. `cf == src` is the WRONG
  "already canonical?" test for a comment-bearing file: `cf` never carries
  comments, so `cf != src` holds for every such file and all 16 D files were
  falsely labelled declines. The discriminator has to be per-lane — compare
  against `program_source_with_comments` for the comment lane, and ask whether
  the DATA lane answered before calling anything a decline. All 30 D/E files
  are data-lane answers and are NOT defects.

## RULED 1338-A — one quoting rule, and it is the one the language specifies

`emit_quoted_string` picks a quote character absent from the body and writes
the body VERBATIM. It never escapes. So the value `a\nb` (4 bytes: `a`,
backslash, `n`, `b`) emits as `"a\nb"`, which re-parses as 3 bytes. The
emitter's own output changes the value; `faithful_program_fmt` catches it and
declines the file. 9 files.

Measured on the prod binary:

    [$strings:length """a\nb"""]  -> 4      (triple quoted is VERBATIM)
    [$strings:length "a\nb"]      -> 3      (escapes processed)

Its third branch also emits the TRIQUOTE spelling. lexicon.ebnf [L31a] is
explicit: "Canonical NEVER re-emits the triquote spelling (canonical.md §2.3 /
L15+L17), so raw triple is an INPUT spelling only." `stdlib/csv.cx`'s canonical
program text carries 10 occurrences of `"""`. That branch is out of spec.

**RULED: `emit_quoted_string` delegates to `cx_choose_quote`** (which calls
`cx_escape_quoted`, `vcx/cx/emitter_cx.v`), the Ring-0 rule anchored to
lexicon.ebnf §5 [L32] / canonical.md §2.4 that the DATA lane already uses. Its
escape pass is deliberately lenient — a backslash before a byte that is not a
recognized escape initial is kept verbatim — so `\d` / `\.` / `\w` survive
undoubled and the regex surface does not churn.

**This is conformance, not a design choice.** The surface question was settled
by L15+L17 / W-2 (I1 identity epoch, owner-ruled); the program emitter simply
never adopted it, and the data lane's correct handling of the same files is what
made the divergence visible. Triple-quoted and raw-triple (`r'''…'''`, #93)
remain exactly as they are as INPUT spellings — nothing is removed from the
language. Only what the FORMATTER writes back changes.

Blast radius, stated rather than discovered later: `program_node_to_source` is
also the equality oracle for `let_collapse` / `predicate_migrate` AND the VALUE
of a `cx:expr` scalar (`vcx/code/dynamic_construction.v:795`,
`vcx/code/eval.v:1788`) AND the text `vcx/code/lower_to_cx_node.v` slices. A
`cx:expr` whose string content carries a backslash or a control character
changes spelling. It changes from a spelling that re-parses to a DIFFERENT
value to one that round-trips, which is the whole point.

Rejected: (b) preserve the raw triple-quoted spelling when the content holds a
backslash. It keeps more `cx:expr` values byte-identical, but forks a THIRD
quoting rule — the exact drift this family of defects is made of — and it
contradicts L17/W-2, which is not ours to re-open here.

## RULED 1339-A — the generic directive path emits the attribute form

`parse_directive_slot` states its own contract: "every directive modifier is
either a scalar attribute (`name=value`) or a clause-child element
(`[name …]`); the legacy `:label V` surface was removed." `emit_directive_slot`
still writes `:label VALUE`. Re-parsing reads `:label` as a positional ATOM, so
each labeled slot becomes TWO positional slots. Measured on
`scripts/serve_static.cx`: `[?http-service on=http port=… name=…]` emits as
`[?http-service :on "http" :port … :name "…"]`, slot count 6 -> 9. The TEXT is
a stable fixed point, so only the SHAPE check catches it. 20 files.

In the generic path a labeled slot can ONLY originate from the attribute branch
(`ident` followed by `=`) — the clause-child labeled slots are built by each
special form's own pre-pass (`[?eval]`'s `context`/`opts`, `[?match]`'s
`case`/`where`). So the generic inverse is unambiguous.

**RULED: the generic path emits `label=value`.**

CORRECTION, recorded 2026-09-06 after implementing: this record first said "the
value goes through `emit_program_node` unchanged". That is NOT what shipped, and
the difference is load-bearing, so the ruling is restated here rather than left
to be inferred from the code.

A plain string literal is emitted BARE exactly when `bare_run_is_lone_ident`
says the parser will read it back bare — the parser's own predicate, the one its
attribute branch uses to produce a `string_lit` from a bare run. Everything else
(numbers, calls, nested forms) goes through `emit_program_node`, which renders
from its own fields; routing a number through the attribute-string path would
strip the `src` spelling a `::T` coercion reads.

Two measurements forced that shape, in order:

1. Sending the value through `emit_program_node` unchanged quoted it —
   `on='http'` — which FAILS `conformance/fmt.cxd`'s §1 purity check. That
   check compares `cx_text_canonical` across a format, and the DATA reading of
   a `[?directive]` is VERBATIM: `on=http`, `on='http'` and `on="http"` each
   canonicalize to themselves, inner whitespace included. Quoting is visible
   there even when the program reading is identical.
2. Reusing `cx_quote_attr_if_needed` — the DATA emitter's attribute rule — was
   also wrong. It is tuned for the data tokenizer, so it returns `http://host`
   bare, after which the PROGRAM lexer reads `:` then `//` and raises
   "expected identifier after ':' in atom literal" (examples/code-tour.cx).
   Two tokenizers, two bare-safety rules; the program emitter must use the
   program one.

Shape-safety holds either way: a bare attribute value parses to
`str_val='http'` with `src=''`, and a re-parsed quoted `'http'` has
`src == str_val`; under #1328's rule both fingerprint as `shape_str('')`. A
number-shaped bare run keeps failing closed, as fmt-008 requires.

Because the §1 purity check cannot be satisfied for a directive's attribute run
at all, the end-to-end conformance case for this was DROPPED and the property is
asserted in `vcx/cx/directive_emit_surface_test.v` against
`program_node_to_source` directly — the right level, since the defect was in the
emitter rather than in lane selection.

**RULED: `[?str]` gets its inverse map.** `parse_str_body` requires a single
string-literal argument and reshapes it into alternating `[lit …]` / `[hole …]`
slots; the generic path emits those slots, so the canonical text raises
"[?str] requires a single string-literal argument". The emitter reassembles the
template. 4 of the 20.

**RULED: the gate enumerates the WHOLE `directive_names` registry.** For every
registered directive, a synthetic instance must satisfy emit -> reparse
shape-equality. A corpus-driven check only proves what these 263 files happen
to exercise, and that is precisely how the hand-rescued whitelist reached FIVE
(module directives, `let`, `modify`, `eval`, `match`) without anyone noticing
the default was broken underneath it.

Landing (1) cannot ship a corruption: `faithful_program_fmt` verifies every
candidate, so a directive whose real surface is clause-children would keep
failing closed rather than being rewritten wrongly.

Rejected: (b) add a sixth and seventh hand-rescue and leave the generic default
alone. Ships the same 20 files with a smaller diff, but preserves the exact
defect that produced five rescues and 20 broken files, and the next directive
regresses silently.
Rejected: (c) invert the dependency so each special-form parser registers its
emitter inverse. The right end state structurally, and the registry gate above
captures most of its value; but rewiring parser/emitter registration for a
formatting defect is the wrong blast radius today — the ground on which #1318
rejected its own option (d). The gate can be upgraded to (c) without rework.

## Out of scope, named so it is not mistaken for done

C's 73 interior-comment files (need #1058 T1.2), A1's 5 non-programs, X's 5
fmt errors, and #1319's 2-cycle (contained by #1330, not cured). Whether
1338-A also cures #1319 is a HYPOTHESIS to test after landing, not a claim:
#1319's symptom is a newline-bearing text run quoted by one rule and unquoted
by the other, which is 1338-A's shape in the DATA lane.
