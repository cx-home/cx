# Rulings 2026-08-20 — path steps on call results (#862)

## CRS-1 — call-result heads gain the [135a] compact-step subset

**Status:** RULED (owner 862b, 2026-08-20: fix PRE-CUT — do not defer).

**Ruling.** A head-dispatch call result is a VALUE exactly like a
binding's value, so the postfix-step surface that BP-1 ruled for
bindings applies to it unchanged: the element-form call (`[$fn …]`,
grammar [125]) and the qualified-call form (`[prefix/fn …]`) accept a
trailing run of grammar [135a] BindingSteps — child (`/name`),
wildcard (`/*`), descendant (`//name`), kind tests, attribute
(`@attr`), parent (`/..`), map-key (`.key`), and per-step predicates —
gated by the SAME byte-adjacency rule that already disambiguates the
binding step loop: a step token binds to the preceding closing `]`
(or `?`/`!` postfix) ONLY when byte-adjacent; a whitespace-separated
`/…` / `@…` stays a separate operand (`[$count //*]` is unchanged).

This is ONE grammar surface, never a divergent one:

- **Same step set.** Call-result steps are the [135a] value-meaningful
  compact subset — nothing more. Explicit `axis::` spellings refuse
  with the SAME BP-1 diagnostic (the shared step parser carries the
  three-site wording; extraction does not fork it).
- **Same semantics.** Steps on a call result destructure the RESULT
  VALUE — semantically identical to binding the result and stepping
  the binding:
  `[$string [$f …]/name]` ≡ `[?let [= $t [$f …]] [$string $t/name]]`.
  The evaluator applies the SAME machinery the binding read uses (the
  fast path / `walk_binding_path_seq` pair, terminal-field and
  terminal-attribute unwrap, node-set distribution, the err-inspection
  lane — navigating an err result reads its structure, per code.md
  §6.2). ARR-1 (cxdm §2, same day) rides along: readers destructure
  any collection kind, and result-stepping agrees because it IS the
  binding-read machinery.
- **Heads stay names.** A call HEAD with steps (`[$fn/x …]`) remains
  refused ("bind the value first") — a head is a name, not a value.
  Only the RESULT gains steps.

**What changed.**
- `spec/03-approved/formal/grammar.ebnf` [125] — ProgramCall gains the
  optional `(BindingStep)*` postfix with the adjacency gate and the
  BP-1 refusal noted; the qualified-call head-dispatch shares it.
- `spec/03-approved/core/code.md` §6.2 — the path-access table's
  subject extends from bindings to "bindings and call results"; the
  [?let]-equivalence is stated.
- `spec/03-approved/core/ast.md` ProgramCall — optional `path` field
  mirroring `ProgramBinding.path`.
- `vcx/cx/program_ast.v` — `ProgramCall.path []ProgramPathStep`.
- `vcx/cx/program_parser.v` — the step loop lifts out of
  `parse_binding_with_path` into `parse_postfix_path_steps` (shared,
  byte-for-byte the same arms incl. the BP-1 refusals); both call
  parsers invoke it after the closing `]` / `?` / `!`.
- `vcx/code/eval.v` — `apply_value_path` factors the post-lookup half
  of `eval_binding_opt`; `eval_call` applies it to the result when
  `path` is non-empty; `eval_call_tail` routes stepped calls through
  the value path (a stepped call is a read, never a trampolined tail
  call).
- Projections agree with the AST: `program_emit.v` (canonical emit —
  the steps round-trip), `code_identity.v` (T2 preimage — presence-
  marked so path-less calls keep their exact bytes; `[$f $x]@v` and
  `[$f $x]` are different computations), `ast_json.v`,
  `program_xml.v` (`<cx:step>` children on `<cx:call>`).

**Non-goals.** Operator forms (`[+ 1 2]@v`), directive results
(`[?let …]/x`), and rooted-path fused predicates keep their current
surfaces — fused predicate bodies (`//user[$flagged $_]/name`) never
route through the call parsers, so the enclosing StepList is
untouched. Steps on call heads stay refused.

### CRS-1a rider — code.md §6.2 trued to BP-1

The §6.2 table edited for CRS-1 still granted "full CXPath step
syntax" with an `$x/axis::name` row and two explicit-axis examples
(`$node/ancestor::section`, `$h2/following-sibling::p`) — text the
BP-1 ruling (ledger/rulings_2026_08_20_binding_axes.md, grammar [135a]
MUST-reject) had already falsified but whose doc row was not trued
that session. Ruled toward BP-1: the row and examples are replaced
with the compact-step surface and the rooted-path alternative. No
behavior change — the parser already refuses.

**Evidence target (gates).** `[$first $h]@v`, `[$paint $doc]//l`,
`[$nth $xs $i]/*` parse and evaluate; `[$f $x] @v` (whitespace) stays
two operands; `[$f $x]/ancestor::y` refuses with the BP-1 message;
the [?let]-equivalence pin holds. Closes #862.
