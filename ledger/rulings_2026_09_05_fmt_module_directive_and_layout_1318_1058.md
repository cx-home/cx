# Ruling record — #1318 + #1058 T1.2: `cx fmt`'s module-directive round trip, and a width-bounded program layout (2026-09-05)

Issues: #1318 (bug, area:tooling, prio:high) and #1058 T1.2 (area:tooling).
Ruled one at a time, immediately before implementing, per the 3a cadence.
Premise verified by measurement, not by reading the issue.

## The premise, corrected by running something

#1058 T1.2 reports that `cx fmt` has "three layout behaviours": data elements
preserve authored line breaks, `[?def]` bodies preserve authored line breaks,
and bare directive expressions flatten unbounded. Two of the three are wrong.

- The data lane does NOT preserve authored breaks. It re-lays out by its own
  rule: `[a [b 1] [c 2]]` written on one line comes back on four, closer on its
  own line. Deterministic, not authorial.
- `[?def]` bodies are not preserved by a layout rule. **The whole file is
  returned verbatim.** `[?def   f  ($n)   [+ $n   1]]` formats to itself, triple
  spaces intact, while the structurally identical `[?fn   ($n)   [+ $n   1]]`
  formats to `[?fn ($n) [+ $n 1]]`.

Measured over every `.cx` outside `third_party/` (263 files):

| | changed | unchanged | fmt error |
|---|---|---|---|
| contains `[?def]` (153) | **0** | 153 | 0 |
| no `[?def]` (110) | 33 | 72 | 5 |

A flat zero across 153 files is the signature of a fail-closed lane. Excluding
the four synthetic `fixtures/bench/*.cx` blobs (12.1 MB of the 12.3 MB def-free
total), def-bearing files are **94% of real CX source by bytes, 58% by file
count**. So T1.2's own ask — bound the program lane's width — is unreachable on
the majority of the tree until the round trip is repaired. Filed the no-op
separately as #1318 (owner ruled 2b: the severities differ even though one
change fixes both).

## Mechanism

`[?def]` / `[?lib]` / `[?const]` get no structural program parse.
`parse_module_directive` (`vcx/cx/program_parser.v:4716`) captures the verbatim
span and defers the structural read to eval time via `parse_def` / `parse_lib` /
`parse_const`, deliberately — so there is ONE module-directive grammar, not two.
The AST node is `ProgramDirective{ name: 'def', slots: [labeled 'raw-source' ->
string_lit(RAW)] }`.

`emit_program_directive` has no module-directive lane, so it falls through to
the generic labeled-slot path and renders the RETIRED colon-slot spelling
`[?def :raw-source "…"]`. Re-parsing that re-enters `parse_module_directive` and
captures a different span, so `cf2 != cf_src` in `faithful_program_fmt` and the
lane returns the source unchanged. The fail-closed check is doing its job; the
emitter is not a fixed point on a module directive. This is #400's failure mode
surviving in one un-swept lane.

## RULED 1318-A — the emitter gets a module-directive lane

`emit_program_directive` special-cases `def` / `lib` / `const`: re-read the
captured span with the module loader's OWN reader — the same `parse_def` /
`parse_lib` / `parse_const` eval calls, never a second grammar — and emit

    [?def NAME <clause-region verbatim> (CANONICAL PARAMS) CANONICAL BODY]

Fail closed to the verbatim span whenever the reader errors or the body does not
re-parse as a program, so a `[?def]` that does not parse is never rewritten.

This is the FE-4 precedent applied one directive further: FE-4 moved `[?fn]` to a
structural parse that reuses `def_parse_param_list`, on the ground that the
parameter grammar must have one reader. The same argument reaches the emitter —
the def grammar must have one reader, and it is the module loader's.

**The clause region stays verbatim, and that is the ruling, not a deferral.**
`DefNode` models `requires`, `preconditions`, `effects`, `idem_window`,
`compensates` and `returns_type_source` as VERBATIM SOURCE STRINGS. A formatter
that re-spelled them would be inventing a canonical form for constructs whose
model is "the bytes the author wrote", which is exactly how a formatter changes
meaning. Body and parameter list have structural models and are canonicalized;
everything between the name and the parameter list is copied byte-for-byte.
Bounded, principled, and it is where none of the code lives.

Offsets: `parse_def`'s `DefParseCursor` already knows where the name ends, where
the parameter list opens and closes, and where the body starts and ends. Those
positions are recorded on `DefNode` as additive fields — no behaviour change to
any existing consumer.

Rejected: (b) emit the captured span verbatim and stop. It restores the fixed
point and un-blocks every non-def form in the file, but leaves the def BODY —
~all of the code in a def-bearing file — permanently unformatted. That is a
partial implementation of "the formatter works".
Rejected: (c) give `[?def]` a structural parse in the program grammar and keep
`raw-source` alongside it for eval. Two representations of one construct that
must not drift, against the no-dual-accept rule.
Rejected: (d) structural parse + cut eval over to it. The honest version of (c),
but it moves the module-directive grammar into the program parser and touches
`eval.v`, `lsp_features.v`, `lint.v`, `diagram_cx_seam.v`, `let_collapse.v` and
`stdlib_diagram.v` for a formatting defect. Wrong blast radius; the deferral to
eval time is a deliberate design this ruling has no reason to overturn.

## RULED 1058-T1.2 — one emitter, two widths

The layout does NOT go into `program_node_to_source`. That function is also:

- the canonical-equality ORACLE for `fmt_source`, `let_collapse` and
  `predicate_migrate`;
- the VALUE of a `cx:expr` scalar (`vcx/code/dynamic_construction.v:795`,
  `vcx/code/eval.v:1788`);
- the pattern/guard/body text `vcx/code/lower_to_cx_node.v` slices into
  `[?match]` / `[?modify]` components.

Width-aware indentation there would change shipped values. It also must not
become a SECOND emitter — two renderings of one grammar drift, which is the
defect this record is already fixing once.

So: the existing emitter becomes width-parameterised, and the canonical form is
that same emitter at width = unbounded. `program_node_to_source` is defined as
the unbounded call, byte-identical to today by construction — nothing fits-checks
when nothing can overflow — so the oracle and every `cx:expr` value are
unchanged, provably rather than by test. `cx fmt`'s program lane calls it at
width 80 and hands the result to the EXISTING canonical + shape verification, so
a laid-out candidate is accepted only if it re-parses to the same program.

**Layout rules** (deterministic, idempotent, verified):

1. A form is emitted flat when it fits in the remaining columns.
2. Otherwise: head and FIRST slot stay on the open line (hang style — `[?if COND`,
   `[?for [in $x $xs]`, `[$f arg`); each remaining slot goes on its own line at
   indent + 2.
3. Closers are GLUED to the last slot, never dangling. A depth-8 nest — the
   measured maximum in #1058's own corpus, with a 7-long closer run — costs one
   line, not eight. This is the Lisp/Clojure convention and the reason the
   bracket density #1058 measures is a layout problem rather than a syntax one.
4. Width is fixed at 80 with NO flag. A canonical form that depends on a setting
   is not a canonical form; a `cx fmt --width` knob would make the canonical-format
   gate undecidable.

**Cost.** Naive "render flat, measure, maybe recurse" re-renders each subtree once
per enclosing level. Instead the flat pass RECORDS each node's start and end
offset in the flat buffer in pre-order; the layout pass walks the same order with
a cursor, so a subtree that fits is a memcpy of its already-rendered bytes and only
overflowing forms recurse. Two traversals, O(n). This lane has form: #1281's
`prog.body.str()` fingerprint was `cx fmt`'s 26 s / 3.3 GB outlier, and a
quadratic re-render would put an equivalent one straight back.

## RULED 1058-T1.2-b — the data lane's dangling closer stays

T1.2's fourth complaint is that data elements close on their own line while
directive forms do not. Ruled: keep both. `emit_cx` is the LOSSLESS CANONICAL
DATA form — a shipped surface, the one lane that carries comments, and the
formatter for genuine data documents. Changing its closer placement is a
shipped-surface change with fixture churn across the data corpora and no
readability gain, to make a program lane and a data lane agree on a convention
they have no reason to share. A data document is a tree of records; a program is
a tree of calls; trailing-closer style is right for the second and wrong for the
first.

## RULED 1318-B — a `[?fn]` parameter list is space-separated

Found while probing for other non-fixed-point forms, and it is the same defect
one directive over. `parse_fn_param_list` produces a `sequence_lit` carrying the
[153] model in `def_params`; `emit_program_literal`'s `.sequence_lit` arm emitted
the generic comma form, so a two-parameter list came back as `($a, $b)`. That is
not a parameter list — it does not re-parse — so the emitter was not a fixed
point and **every `[?fn]` of two or more parameters was exempt from `cx fmt`**.
A one-parameter list has no separator to get wrong, which is why it survived.

`emit_def_param_list` now spells the [153] surface once and BOTH `[?fn]` and
`[?def]` emit through it — the FE-4 "one parameter grammar, one reader"
argument, extended to the writer. `is_named` selects `=` versus a bare
space-separated default and is never inferred from the presence of a default,
because that is exactly what separates [153c] from [153b].

## What this does NOT fix — the dominant cause is COMMENTS (#1319 sibling)

Measured after both fixes, over the same 263 files:

| | files |
|---|---|
| changed by `cx fmt` | 36 |
| no-op, comment-bearing | **194** |
| no-op, comment-free | 28 |
| fmt error | 5 |

Def-bearing files went from 0/153 changed to 3/153 — because **defs were never
the dominant cause**. 148 of the 150 remaining def-bearing no-ops carry a
comment, and `fmt_source_lane`'s `if carries_comment { return input }` (#967)
declines them: `parse_program` discards `CommentNode`, so the program lane would
delete every comment in the file.

That guard is correct and must stay until the program representation can carry a
comment. But it means **74% of the corpus is a no-op for a reason neither #1318
nor #1058 T1.2 addresses**. Making `cx fmt` a working command on real files
requires the program parser to retain comments as trivia — a change to the
program AST, its emitter, its shape fingerprint, and every
`program_node_to_source` consumer, with a live risk of trivia leaking into
`cx:expr` values. That is its own ruling and its own issue; it is NOT folded in
here, and this record does not claim `cx fmt` is fixed.

## Verification obligations

- `cx fmt` idempotent on all 263 `.cx` files (format twice, compare).
- Every formatted output re-parses to a shape-equal program — already enforced by
  `faithful_program_fmt`, but asserted directly over the corpus.
- `program_node_to_source` byte-identical before/after on the corpus (the oracle
  did not move).
- No output line exceeds 80 columns except where a single unbreakable token does.
- `vcx/tests/codecs_formats_umbrella_test.v`'s two fail-closed pins.
  **This obligation was predicted wrong when the record was first written** and
  is corrected here: neither test needed re-basing.
  `test_fmt_cli_cycle_stable_on_fail_closed_def` still fails closed because
  `parse_def` REJECTS `[?def [f] 1]` (`[f]` is not a function name), so
  `canonical_def_source` returns the verbatim span — a different mechanism
  reaching the same answer, and its comment is updated to say so.
  `test_fmt_cli_cycle_stable_on_the_reporting_corpus_program` still holds
  because `corpus/rosetta/21-fetch-csv-validate.cx` carries four comment lines
  and never reaches the def lane at all. Predicting a fixture would move, and
  checking, is cheap; asserting it would have been the error.

## Measured results

- Module directives and multi-parameter `[?fn]` both round-trip; def-bearing
  files changed under `cx fmt` went 0/153 → 3/153, the rest blocked on comments.
- **Idempotence: 257 of 258 formattable files.** The one violation,
  `spec/03-approved/xap/_notes/mesh-strategy.capture.cx`, is PRE-EXISTING —
  byte-identical behaviour on the unmodified prod binary at `6da1b6b74` — and
  lives in the DATA lane, not the program lane. `cx fmt` oscillates on it in a
  stable 2-cycle (2924 ↔ 2917 bytes) and never converges, violating
  `formatting.md` §7. Filed as #1319 with a delta-debugged 103-byte repro.
