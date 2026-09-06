# Ruling record — #1172 whole-element capture: `[NAME$x]` is the head-bind (2026-09-04)

Issue: #1172 (bug, area:cx-lang, prio:medium). Spec: `spec/03-approved/core/code.md` §5.1 / §5.2 rule 5.

## The defect

§5.2 rule 5 promised TWO ways to force whole-element capture and neither worked:

- `[NAME$x]` (glued head-bind) parsed as the body-position bind `[NAME $x]` — the parser's named-head
  arm deliberately never consumed a trailing `$x` because the token stream did not tell glued from
  spaced — so it auto-unwrapped a text or scalar body exactly like the spaced form. An author who
  wrote `[cat$n]` because the spec said it captures the element got the unwrapped string: silent wrong
  value, no diagnostic.
- `[NAME * $x]` is, per grammar [126g], TWO body items (`*` then `$x`): it needs ≥ 2 children and
  binds the LAST child, never the element. The sentence claiming otherwise was false.
- The rule ended in "where supported by the parser" — the spec deferring a semantic to the
  implementation — and pointed at a §5.1 that defined nothing.

## Question 1172-Q1 — what does `[NAME$x]` mean?

- **(a) RULED.** `[NAME$x]` — the `$x` GLUED to the name, no whitespace — is the head-bind form for a
  named head, as `*$x`, `**$x` and `:T$x` already are for theirs: the name is tested and `$x` binds
  the WHOLE matched element, unconditionally — text body, scalar body, structured body, empty body,
  attribute-only, with or without attribute predicates. `[NAME $x]` (whitespace: `$x` is a body item)
  keeps rule 5's auto-unwrap: text → string, single scalar → scalar, structured → element. DELETES:
  the `[NAME * $x]` sentence (false), the "where supported by the parser" hedge, and the parser's
  refusal to consume a glued head-bind. Two spellings differ by one space — the legibility cost is
  real and accepted: the glued form is already the head-bind spelling for the three other head kinds
  ([126a]), it is what §5.2 promised, and no fixture, script, test, doc or example in the tree writes
  `[NAME$x]` today (git grep, 2026-09-04), so nothing changes meaning under it.
- (b) Keep `[NAME$x]` as a no-op alias and invent a distinct whole-element spelling — rejected: it adds
  a fourth binding spelling to carry a meaning the grammar already has a slot for, and leaves the
  alias as a trap.
- (c) Drop the affordance; document `[NAME @attr $x]` and bind-only `$x` — rejected: "match an element
  named N and bind the whole element" is a basic query with no attribute filter to hang it on, and
  `[$x]` performs no name test.

Ruled (a) under the standing letter-acceptance order (long-term-best recommendation, campaign
authority 2026-09-04). Id: **1172-Q1a**.

## Rider

`[NAME @* $x]` (attribute REST, grammar [126d]) is admitted by the grammar and refused by the parser
("expected attribute name after @, got *"). Split into its own issue, #1270 — same class as #1136.

## Execution record

- `vcx/cx/program_parser.v` named-head arm: consumes `$x` as the head-bind when the `$` token's byte
  offset equals the name token's end offset (glued); a whitespace-separated `$x` stays a body item.
  Path steps on a head-bind remain a parse error.
- `vcx/code/matcher.v` bind-capture short-circuit: a head-bind ALWAYS binds `cx.mk_element(el)`; the
  auto-unwrap applies only to the body-position single `$x` on a named head with no attribute
  predicates (unchanged).
- Spec: §5.2 rule 5 tail rewritten; §5.1 gains the head-bind production and the glued rule; [126a]
  says the binding on a Name head is glued.
- Fixtures: `program-match-head-bind-whole-element-1172` (matrix: `[cat$n]` against `[cat]`,
  `[cat hello]`, `[cat 12]`, `[cat [x 1]]`, `[cat k=1]`, `[cat k=1 hello]`, `[cat [x 1] [y 2]]` — all the
  element) and `program-match-body-bind-auto-unwrap-unchanged-1172` (the spaced column: `hello`,
  `12`, element, element).
