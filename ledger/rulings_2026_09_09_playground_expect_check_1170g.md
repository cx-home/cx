# RULED: 1170-g — §C4 is EXACT: an optional `[expect [#…#]]` per example pins a substring of its output; the note↔output check reads that field, never the prose

**Fable, 2026-09-09 20:50Z, under the owner's delegation:** (a). Refused (b) a
heuristic extractor over the Markdown note (false-reds on prose by
construction — the failure 1170-b named) and (c) leaving §C4 manual for good.
Implemented by the Fable session the same hour.

## What changed

- `gen_examples.cx`: `load-examples` reads `[expect]` (trimmed); rows carry
  `expect=`/`no-stable=`; a §C4 block grades every `ok`, stable entry with a
  non-empty `[expect]` by `strings:contains` against its audited output and
  reports `EXPECT <key> output does not contain "…"; the output is "…"`; the
  lint verdict is `c2 or c3 or c4`; a `--lint-only PATH` mode audits and lints
  a corpus at PATH, writes nothing, compares against no pin, and exits by the
  lints alone.
- `scripts/gen_guide/playground/tests/expect_red.cxd`: the fixture corpus —
  one right `[expect]`, one wrong, one absent. `make verify-playground-examples`
  runs it through `--lint-only` and REFUSES unless the exit is 1 naming
  `02-expect-wrong` — the check proves itself non-vacuous on every run.
- `examples.cxd`: `[expect]` on all 37 v0.16→v0.18 examples (204–240), each
  the concrete answer its note states, measured from `examples.out.cxd`.
  One note was WRONG for the run the playground makes: `228` promised the
  scoped deny "leaves `net: true`", but the audit is grant-free, so both maps
  are empty; the note now says so and the `[expect]` pins what is true. That
  correction is the value of §C4, found on the first authoring pass.

## Census

`[expect] pins graded: 37 of 239 entries carry one`. The remaining 202 are
the pre-existing ring-0/1 corpus; adding their pins is a review pass per
example (read the note, pin the claim) and follows as its own landing.

## DELETES

The heuristic §C4 sketch on #1170; nothing shipped.
