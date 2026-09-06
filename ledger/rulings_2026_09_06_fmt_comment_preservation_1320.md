# Ruling record — #1320 wave 1: the program lane keeps comments (2026-09-06)

Issue: #1320 (bug, area:tooling, design, prio:high). Follows #1318.
No spec surface. Ring 0: `program_lexer.v`, `program_tokens.v`,
`program_ast.v`, `program_parser.v`, `program_fmt.v`.

## The defect

`parse_program` discarded `CommentNode`, so `program_node_to_source` had
nothing to re-emit and `fmt_source_lane` had to decline any comment-bearing
file (#967) or delete every comment in it. Measured after #1318: **194 of 263
`.cx` files were a no-op for this one reason** — the single largest cause of
`cx fmt` doing nothing, far larger than #1318 itself.

## RULED 1320-A — the comment inventory rides on `Program`, never on a node

Comments are collected by the lexer and returned on `Program.comments`.

**This placement is the ruling.** The obvious repair — trivia on AST nodes —
would put comments inside `program_node_to_source`, and that function is not
only the formatter's canonical form. It is the equality ORACLE for
`fmt_source` / `let_collapse` / `predicate_migrate`, the VALUE of a `cx:expr`
scalar (`dynamic_construction.v`, `eval.v`), and the text `lower_to_cx_node.v`
slices into `[?match]` components. A `cx:expr` must not start carrying the
author's comments.

Because `program_node_to_source` takes a `ProgramNode` and the inventory hangs
off `Program`, the canonical form is trivia-free **by construction rather than
by convention**: the function cannot reach the table even in principle, so no
existing consumer changes behaviour and no test is needed to prove it. Same
argument for `prog_shape_of`, which fingerprints `prog.body` only — a comment
change is not a meaning change and must not move the shape.

`tokenize` keeps its signature and discards the inventory;
`tokenize_with_comments` is the variant `parse_program` calls. Every existing
caller is untouched.

## RULED 1320-B — depth 0 only, and that is a boundary, not an omission

Only comments at bracket depth 0 — those standing BETWEEN top-level forms —
are put back, by interleaving them with the forms' canonical texts. A file
carrying even one INTERIOR comment fails closed, unchanged.

The reason is structural: a form's canonical text is a SINGLE LINE, so an
interior comment has nowhere to go until the emitter can break a form across
lines. That is #1058 T1.2's width-bounded layout, and it is why these two must
land in this order — a layout built against a trivia-free AST would need
trivia hooks retrofitted through every break decision.

Measured: 111 files carry only depth-0 comments, 103 carry at least one
interior comment, and 86% of all 8,226 comments are depth 0.

A comment TRAILING a form on its line stays on that line. It annotates the form
beside it, so promoting it to a standalone line above the NEXT form would
silently re-point it.

## RULED 1320-C — every accepting lane compares the comment inventory

This is the part the work actually turned on. `fmt_source_lane` had TWO places
that bless a candidate, and both were comment-blind, because the canonical text
and the shape fingerprint both ignore comments *by design*.

**A pre-existing data-loss bug fell out of this and is fixed here.** On the prod
binary at `f798b7a7a`, before any of #1320:

```
$ printf '[?let [= $n 1] $n]  # note\n' | cx fmt
[?let [= $n 1] $n]
```

The comment silently DELETED — in the command the LSP runs on save. #967's
guard consulted the DATA reading's inventory, and the data reader does not
report a comment trailing the last form (it reads it as a string), so
`carries_comment` was false, the program lane ran, and the comment went. The
guard was real; it was keyed on the wrong reading.

Both acceptances now compare `program_comment_texts` between input and
candidate, and the fail-closed guard takes the UNION of both readings. Equal
inventories is the lossless-for-comments guarantee and it is checked directly,
because nothing else in the lane can see a dropped comment.

## Measured

| | before #1318 | after #1318 | after #1320 |
|---|---|---|---|
| files `cx fmt` changes | 36 | 36 | **52** |
| files that no-op | 222 | 222 | 206 |
| comment loss | (silent, unmeasured) | 4 shapes | **0 / 263** |
| non-idempotent | 1 | 1 | 1 (pre-existing #1319) |

**What this does NOT fix, and the number is honest.** 87 files still no-op
while carrying ONLY depth-0 comments. Comments are not their blocker: stripping
every comment from `stdlib/similar.cx`, `examples/books.cx` and
`scripts/serve_static.cx` leaves all three still a no-op. Those are other
emitter round-trip gaps — the #1318 family, one form at a time — and they want
their own measurement. 91 more no-op on interior comments, which is 1320-B's
declared boundary and needs the layout.

## TRAP — a `mut` assigned inside an `if x := …` capture did not survive

The inventory was first carried in a `mut src_comments` declared before
`if prog := parse_program(input) {` and assigned inside it. In the optimized
build that assignment **did not reach the later read**: the guard saw an empty
list, the lane fell through to the comment-dropping exit, and every trailing-
comment case failed. Adding an `eprintln` that read the variable made it work,
which is what identified it — the trace was the fix, so the bug vanished
whenever it was observed. Restructured to a plain `program_comment_texts(input)`
call after the branch. **Do not carry state out of an `if x := …` capture block
in this codebase; compute it after, or in a function.**
