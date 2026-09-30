# Owner decisions 2026-09-30 — Letters 115 and 116: a computed attribute name keeps the NCName refusal; a string that would read back as another type is quoted

**Status: RULED (owner, 2026-09-30 ~02:1xZ, in session, "l115 a, l116 a", on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 23:2xZ 09-29 with the Ring-1 batch's
letter lines). FIX-1, RS-38, the Ring-1 batch of 2026-09-29 (`_gate_evidence/pipeline_batch0929/RESULTS.md`).**

## The owner's words, verbatim

"l115 a, l116 a"

## NCNAM-1 — a computed attribute named `null`, `true` or `false` stays refused, CXER0236 (L115 = (a); #1699)

code.md §6.4.2.1 rules that a computed attribute name "must be a valid NCName (the same validity
the `string → :atom` cast enforces, §6.5 — rejects `true`/`false`/`null` …)", and the binary does
so. Ruled: the refusal stands as the spec says it; one NCName rule for names everywhere, and a
program that wants such a key spells it as data; #1699 closes on this word. Rejected: narrowing the
rule for computed attribute names — a name that reads as a boolean or null in every other position,
the auto-typing surprise the primer warns of.

## STRQ-1 — a string whose text would read back as another type is quoted when rendered (L116 = (a); #1691)

code.md §11.1a R2 renders duration-shaped strings (`<digits>` + one of `us|ms|s|m|h`) bare, and R4
the same for attribute values, so `'5m'` renders as `5m` and reads back as a duration — the
renderer writes a value the reader cannot read back, the class of #1575. Ruled: a string whose
text would read back as another type is quoted — R2 and R4 amended by that one clause, the round
trip through `cx canonical` the invariant for every string — fixture first (the two cases #1691
measured, red on the pinned cx, green on the fix), the clause carrying the case ids (RS-38), as a
small Ring-0 round on cx-core-data after the round now holding that repository merges. Rejected:
keeping R2/R4 and documenting the loss — against "exact by default".
