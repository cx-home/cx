# Rulings 2026-08-20 — postfix-step uniformity (#886)

## PS-1 — every program-position bracketed form's closing bracket takes the [135a] compact-step postfix

**Status:** RULED (owner "1a", 2026-08-20 — design letter
spec/02-working/postfix_step_uniformity.md, option (a): fully uniform).

**Ruling.** The [135a] compact-step postfix that BP-1 ruled for bindings
and CRS-1 extended to the two call forms applies to EVERY
program-position bracketed value form: the step run binds to the
closing bracket when BYTE-ADJACENT (the CRS-1 adjacency gate,
unchanged), explicit `axis::` spellings refuse with the BP-1
diagnostic (inherited by construction — one shared step parser), and
`?`/`!` error-marks bind before steps exactly as CRS-1 ruled for
calls. One rule, one grammar sentence: **any value's bracket takes a
step.**

Heads gaining the postfix (beyond `$binding` / the two call forms,
already landed):

- **Directive results** — `[?let …]/name`, `[?if …]@attr`,
  `[?match …]/x`, the `[?for]`/`[?for-array]`/`[?for-map]` family, and
  every other §4.1 directive (special forms included: the attach site
  is the ONE expression-position dispatch, so `[?element]`, `[?cx]`,
  `[?str]`, module directives inherit it uniformly).
- **Operator forms** — `[+ 1 2]/x`, `[= $a $b]@k` (operator heads parse
  as element-form literals; the same carrier serves both).
- **Element literals in program position** — `[user [b 1]]/b`
  (redundant-but-legal per the letter; a style lint may advise).
- **Collection literals in program position** — array `[1, 2]/x`,
  sequence `(1, 2)/x`, map `{a: 1}.a`, and the first-class slice
  literal (a bracketed value form like any other).

**Semantics: ZERO new.** Steps on any result behave exactly as on a
binding of that result — the let-equivalence holds per head class by
construction, because evaluation routes every stepped form through
`apply_value_path`, THE machinery the binding read uses (kind-driven:
a child step on a scalar yields empty; `@attr` on a non-element
refuses typed CXER0001; ARR-1 collection destructuring and the
err-inspection lane ride along):

    [?let …]/name        ≡ [?let [= $t [?let …]] $t/name]   (any head)

A stepped form is a READ, never a trampolined tail call and never a
streamable head — the TCO fast paths and the streaming mode gates
treat a path-bearing node as a plain value expression.

**Identity discipline.** Every AST node gaining a `path` field
(ProgramDirective, ProgramForComp, ProgramLiteral,
ProgramSliceLiteral) follows CRS-1's presence-marked T2 preimage
pattern: a step-less form writes ZERO new bytes, so its identity is
byte-identical to the pre-PS-1 preimage; a stepped form is a distinct
computation. Golden movement predicted: **zero** — the corpus carries
no glued `]`-step spellings on the new heads (verified by
cxparse_full_corpus_diff), and adjacency gating preserves every
current spaced reading (`[cfg /a/b]`, top-level rooted paths).

**Out of scope (named, with reasons — not riders, no ambiguity
found):**

- **Pattern literals in expression position** (`[** ]`, `[:User …]`
  heads): a ProgramPattern is a structural-only AST node — the
  evaluator refuses it as a value (`eval_node`'s structural-only arm),
  so it is not a value-producing head; a step on it could only ever
  follow a refusal. The parse surface is unchanged.
- **Grouping parens** `(expr)/x`: not a bracketed LITERAL — `(a, b)`
  the sequence literal IS covered; bare grouping stays the operand
  reading. (In this grammar `(a)` parses as a one-item sequence
  literal, so it is in fact covered by the sequence arm.)
- **Pattern-position brackets** (match-arm patterns, [?modify] action
  clauses, [?match] clause children): bind/clause sites, not value
  positions — no steps.

**What lands.**
- `spec/03-approved/formal/grammar.ebnf` — the [125]-style postfix
  generalized: [127] Directive, [125f] OperatorForm, element and
  collection literal productions gain the `(BindingStep)*` postfix
  with the adjacency gate; one shared note.
- `spec/03-approved/core/code.md` §6.2 — the one-sentence rule: any
  program-position bracketed value's closing bracket takes the same
  steps; the table's subject extends from "bindings and call results"
  to every bracketed value form.
- `spec/03-approved/core/ast.md` — the four nodes' optional `path`
  field recorded, mirroring ProgramCall.
- `vcx/cx/program_ast.v` — `path []ProgramPathStep` on
  ProgramDirective / ProgramForComp / ProgramLiteral /
  ProgramSliceLiteral.
- `vcx/cx/program_parser.v` — ONE attach helper
  (`attach_postfix_result_steps`) wrapping the shared
  `parse_postfix_path_steps`; attach sites: parse_atom's
  directive / paren-sequence / map-literal arms + parse_bracket's
  expression-mode literal arms (element, arrays, slice literal).
  Call arms keep their CRS-1 internal attach.
- `vcx/code/eval.v` — eval_directive / eval_for_comp / eval_literal
  apply `apply_value_path` to the path-less result (the CRS-1
  pattern); eval_tail + cx_element_as_tail_call gate stepped forms to
  value evaluation; stream_mode_of / stream_map_directive decline
  stepped heads (a stepped form is a read).
- Projections: program_emit.v (canonical emit appends the glued step
  run at the ONE dispatch); code_identity.v (presence-marked, as
  above); ast_json.v (labels extend, the CRS-1 label pattern);
  program_xml.v (stepped forms ride the existing `<cx:expr>` bijective
  escape hatch — the same hatch dynamic element names use; step-less
  forms keep their structural encodings byte-identically).
- Tests: vcx/tests/postfix_step_uniformity_test.v (arms per head
  class: positive step, @attr, let-equivalence pin, ONE axis::
  refusal) + conformance/code.cxd program-callstep-005…
  continuing the CRS-1 numbering.

**Evidence target (gates).** code_parse_fixtures,
parser_units_umbrella, cxparse_full_corpus_diff (zero movement),
eval_semantics_umbrella, code_units umbrella + the new gate — full
logs, RCs echoed.
