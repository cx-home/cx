# RULED: 1262-a — `[$exists]` keeps its content-arity meaning; the presence question is `present`, and the lint names the trap

**Fable, 2026-09-10 06:05Z, under the owner's delegation:** (a). Refused (b)
making `[$exists EL]` answer true for any element `[$first]` returns: that
reverses the owner's rulings #584 / #854 / #849 (exists / count / empty ask
CONTENT ARITY; `present` was added for exactly the presence question), and it
would change `[$exists $el]` where the author means "does this element have
children" — the shape `stdlib/diagram.cx`'s `lab` relies on. Refused (c) a
half-measure (true iff children OR attributes): a bare `[input]` would still
read false, and the rule would be one more thing to know.

## The principle

Two questions, two builtins. `exists` / `count` / `empty` ask how much CONTENT
a value has — over a sequence its items, over an element its children, over
an attribute or path whether it is there. `present` asks whether a value is
there at all and never looks inside. The issue's `[$exists [$first
$d//grant]]` asked the first question and meant the second.

## What changed

- `cli.md` §3.5: **CX-L010** — `[$exists X]` where `X` is a single node BY
  CONSTRUCTION (a one-item call `first` / `last` / `nth` / `find` / `head` /
  `cx:parse` / `store:get-doc`, or an element literal) is `warn`, suggesting
  `[$present …]`. A bare `$binding` or a path is not flagged (either may hold
  a sequence; `[$exists $_@name]` is the attribute test).
- `code.md` §6.5 `exists` row: the single-element sentence and the lint.
- The primer's presence-vs-content-arity passage is worker A's landing
  (`35c525387`, "the primer teaches [$present] against [$exists]", with the
  `conformance/llm/antipatterns.cxd` rows) — the docs half of the same
  finding, landed first; this ruling adds the lint and the spec sentences on
  top of it and carries no primer edit of its own.
- `stdlib/diagram.cx`'s `[hit …]` wrappers are left as they are: they carry a
  possibly-multiple slice as one value as well as a found-test, and moving
  them would re-derive two golden corpora for no behaviour change; the lint
  does not flag them (their arguments are bindings).
- `cx_text_lint` (lint.v): the PROGRAM-side checks (L006–L010) now run when
  only the program reading accepts the source. Before, a document the data
  reading refused — the issue's own `[probe has=[$exists [$first …]]]`, a
  node-valued attribute — got NO lint at all (#921's arbitration returned an
  empty list), so a lint written for exactly that shape could never fire. The
  doc-shaped checks (L001/L003/L004/L005) and the `[?cx lint-disable]` scopes
  still need the data tree and run only when it exists.
- Tests: `lint_lsp_umbrella_test.v` `test_l010_*` (fires on the issue's
  shape and on an element literal; silent on bindings, paths, attributes).
