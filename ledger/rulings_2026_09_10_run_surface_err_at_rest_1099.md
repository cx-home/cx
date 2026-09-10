# RULED: 1099-a — the run surface's exit status counts a COMPUTED err at any depth of the result; a WRITTEN err is data wherever it sits

**Fable, 2026-09-10 09:40Z, under the owner's delegation:** the issue's second
acceptable outcome, made exact. Refused its first (propagation out of the
construction): CO-2 (#975, owner-ruled) confirms collection members REST as
data and moves the REFUSAL to the effect boundary; an implementation of
propagation reddened nine enforced fixtures (`flow.cxd` records a failed
step's err as data; `store-err-boundary-001` stopped seeing the err it
refuses). Not reopened.

## Why this is not CO-2's question

CO-2 rules what CONSTRUCTION does with an err member (rest) and where the
REFUSAL lives (the effect boundary); its Amendment 1 says the run-surface
print "is deliberately NOT a refusal point — it is how errors are inspected;
a top-level err already exits nonzero". The print is untouched here: STDOUT
is the rendered result, the document is built around the member. What moves
is R5.13's EXIT STATUS, which #1058 T1.1 had already extended from "the
result is an err" to "a collection carrier holds one" (owner-accepted), and
which stopped at a named element for no reason CO-2 gives — so
`([/ 1 0], 2)` exited 1 while `[doc [?splice ([/ 1 0], 2)]]` and the issue's
`[out [doc …]]` exited 0: one value, two exit codes, decided by the carrier's
shape. The reference-cli passage that attributed the element case to CO-2
over-read the ruling; it is rewritten.

## Two rules, one per depth

A result that IS an err is classified by its top-level FORM's spelling —
R5.13 as shipped and pinned: a literal `[err …]` form is data; a call, a
`[?element 'err' …]`, or a form an err propagated out of is a failure. A
result that CARRIES an err deeper down is classified by the err's provenance
below. The top-level rule is untouched so every existing R5.13 pin holds.

## The discriminator for a nested err is PROVENANCE, not position

Measured before: the literal carve-out was the top-level FORM head only
(`is_literal_err_head`), so a WRITTEN `{a: [err code='c']}` exited 1 (T1.1's
collection walk cannot tell written from computed) while a written
`[wrapper [err …]]` exited 0. Now every `[err …]` the two readers CONSTRUCT
— parsed from source (`parser.v`, the two `new_element` sites) or built by a
program's own literal `[err …]` spelling (`eval_cx_element`; a
`[?element 'err' …]` construction is NOT marked, matching the top-level rule) —
is marked
`ElementMeta.literal_err`; `mk_err` and the twenty other runtime refusal
constructors never mark. `result_carries_err` walks every element and counts
an unmarked err at any depth. The mark is not serialized: a re-parsed err is
written again, which is what it is by then.

## What changed

- `ast.v`: `ElementMeta.literal_err`, `set_literal_err` / `is_literal_err`.
- `parser.v`: both element constructions stamp `name == 'err'`.
- `eval.v`: `eval_cx_element` stamps its `[err …]` literals (computed
  refusals arrive through dispatching heads whose literal name is not `err`);
  `result_carries_err` walks all element children and skips written errs.
- `cli_umbrella_test.v`: the CO-2 splice pin keeps its resting assertions and
  re-pins the exit to 1 with the stderr path; the issue's headline program
  exits 1 naming `/out/doc/err`; written errs exit 0 as the top-level form, a
  map value, a sequence item and inside an element (the map and sequence
  cases were exit 1 before — the T1.1 over-reach, now removed).
- `docs-src/llm/reference-cli.md.tmpl` exit-code passage; `cli.md` §3.7 gains
  the run-surface exit-status bullet (token carried).
- `find_err_at_rest` (the effect boundary) is unchanged: CO-2 refuses every
  err at rest there, written or computed.
