# RULED: 1058-T1.9-a — def-body comments are RECORDED with their depth and PLACED by the width-bounded layout

**Owner + Fable, 2026-09-09 04:11 ET, on worker A's letters (#1058, T1.9;
#1320's stated reason for the decline was false):** `(a)`. HIGH tier
(canonical emitter). Implemented by the Fable session, 2026-09-09.

Refused: `(b)` a verbatim body for a comment-bearing def deletes the
ONE-canonical-spelling property `fmt_program_width`'s no-flag rule protects,
and would be undone by (a) later against a corpus pinned to the interim
spelling; `(c)` reports the hole without closing it and leaves `cx fmt` a
no-op on every LSP save of a def-bearing file.

## What was wrong

`program_fmt.v:242-247` said a comment inside a `[?def]` "lives in the module
directive's raw span, not in the program comment list" and is "preserved by
the span being copied verbatim". Both halves were false at `03ebabce4`:

- the lexer records EVERY comment it skips (`record_comment`, depth = the
  bracket-context depth), and `parse_module_directive` advances the token
  stream THROUGH the def's span, so a def-interior comment IS in
  `prog.comments`, at depth ≥ 1;
- a `[?def]` body is not copied verbatim — `emit_canonical_def_source`
  re-parses it (`parse_program(raw[body_start..body_end])`) and re-emits it
  through `emit_program_node`, which carries no comments.

What actually declined the file: the body is re-parsed from a SUBSTRING, so
every body span's `src_off` was body-relative while the comment inventory is
file-absolute; `layout_program_source_with_comments` could never match a
comment to a break site, left it unplaced, and returned none. The fail-closed
union then returned the source unchanged. Measured: `[?def f ($n)` + a first-
line, a between-statements, a same-line trailing and an own-line trailing
comment → DECLINED byte-for-byte; the same shapes at top level FORMAT.

## What changed

1. **Offsets are rebased.** `Emitter.src_base` is added to every recorded
   `src_off`; `emit_canonical_def_source` sets it to the def's absolute body
   start while the body is emitted and restores it after, so a nested def
   composes (its own absolute offset is `d.pos.offset + src_base`).
2. **The def span knows its edges.** `NodeSpan.src_body` (where the body
   begins in the source) and `NodeSpan.src_end` (where the span ends) are
   recorded for the def span; both stay -1 everywhere else.
3. **Three new placements in `layout_node`, all guarded by those edges:**
   - a comment between `src_body` and the first child (the first line of a
     body) puts the head on its own line and the comment(s) at the body
     indent — a def's head is trimmed of its trailing space;
   - a comment after the last child but before `src_end` (trailing the body)
     is flushed before the closer: a same-line comment stays on the last
     statement's line, an own-line comment gets its own line, and the closer
     then stands at the def's indent;
   - a def whose body holds ANY pending comment before `src_end` is forced to
     break even when it would fit — the existing `interior_between` test could
     not see a comment inside a single child.
   A comment at the def's nesting that begins BEFORE `src_body` sits in the
   verbatim clause/params region (RULED 1318-A); it is marked unplaceable and
   the whole file stays unchanged, never relocated.
4. **The headless-span rule.** A span whose first child begins at its own
   start (a multi-statement `.block` body) opens no bracket of its own, so it
   no longer counts one nesting level for comment matching; without this a
   between-statements comment at depth 1 was compared against nest 2.
5. The false sentence at `program_fmt.v:242-247` is replaced by what the code
   does. The fail-closed union (canonical text + shape + comment inventory)
   STAYS as the last line of defense.

## Fixtures (`conformance/fmt.cxd`, `fmt-033..fmt-037`, each measured RED at `03ebabce4` unless marked GUARD)

- `fmt-033` the `# forced` shapes inside a def: first line of the body,
  between two statements, trailing (same-line and own-line);
- `fmt-034` a def body widened past 80 columns with a comment inside a nested
  form — the layout's break sites and the comment agree;
- `fmt-035` a comment inside a NESTED def (rebasing composes);
- `fmt-036` the fixed point — fmt of the formatted output is identical
  (asserted by the runner's idempotence pass on 033–035 and pinned here on
  an input that is already canonical, GUARD);
- `fmt-037` NEGATIVE — a def whose comment cannot be placed (inside a map
  literal, which has no break site) returns the source unchanged, never a file
  with the comment gone (GUARD).

`vcx/cx/program_interior_comments_test.v` gains the same shapes as unit tests;
`test_a_comment_in_a_def_clause_region_fails_closed` (RULED 1318-A) is
unchanged and still passes.

## Census

`make fmt-sweep` at the landing base `03ebabce4`: SWEEP-FILES=272 FORMATTED=173
DECLINED=94 UNSTABLE=0 ERROR=5. After (measured on this branch, release
binary): SWEEP-FILES=272 FORMATTED=174 **DECLINED=93** UNSTABLE=0 ERROR=5.
`FMT_SWEEP_MAX_DECLINED` lowered 94 → 93 in the same landing. UNSTABLE stayed
0 — every newly formatting file is a fixed point.

Why only one file moved, honestly: the def-interior-comment CLASS is fixed
(the five fixtures prove it), but most def-bearing files in this tree still
decline on the layout's OTHER limits — a def whose head alone runs past 80
columns cannot break at all (Rule 1's second half; e.g. `[?def f--fold-anchored
scope=private pure [returns element] ($st $anchor::int)` is 79 columns before
its body), and a comment inside the LAST child of a form that fits is invisible
to `interior_between`. Both are pre-existing layout limits, not T1.9's; they
are the next census movers and deserve their own letters.

## DELETES

- the decline for the def-interior-comment class;
- the sentence at `program_fmt.v:242-247`.
