# RULED: 1371-a — `ux:form` takes a verb's SUBJECT NOUN as `emits-of` does: `[writes]`, else `[reads]`; neither → untyped parameters, never an error

**Fable, 2026-09-09 20:35Z, under the owner's delegation:** (a). Refused (b)
untyped controls regardless of a read noun (the two readers would disagree on
the very document the 1259-j agreement row exists for) and (c) a named refusal
(makes the corpus's canonical arrange verb un-projectable, against 1259-i's
premise). Implemented by the Fable session the same hour.

## What was wrong

`x/ux.cx:2132` `[$first $v/writes]` over a verb with no `[writes]` child
errored (`nth: index 0 out of range (1..0)`), and the error element was
emitted INSIDE the form at exit 0 — every `effect=arrange` verb in the corpus
(`[reads viewport]`, 30 occurrences) and every read-only act verb.

## What changed

`feature-form-of` derives the subject noun: `[writes]` first, else `[reads]`,
else none; the existing paths then do the rest — intent parameters typed from
that noun, the noun's fields as the form when no list is declared, an untyped
`kind=text` control per parameter when there is no noun, a heading and a
submit when there is nothing to fill. This is the rule `[$xap:emits-of]`
applies (`xap_verb_subject_noun`, RULED 1352-b), so the two readers agree by
construction.

## Fixtures (measured with the built binary; RED at `3ae64d274` — the `[err]`)

`ux-126` (the issue's reproduce: highlight → zoom + note controls typed from
the read noun), `ux-127` (an act verb with only `[reads]` and a parameter
list), `ux-128` (neither clause: untyped), `ux-129` (neither clause, no
parameters: heading + submit); `xap-compose-165` — the 1259-j agreement row:
`emits-of` slots and `ux:form` controls name the same parameters with the same
types for all four verbs.

## DELETES

The `[err]`-inside-the-form answer for every no-`[writes]` verb; the
"unpinnable until #1371" note on 1259-j.
