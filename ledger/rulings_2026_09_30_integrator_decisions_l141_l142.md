# Integrator decisions 2026-09-30 — Letters 141 and 142, taken under DELEG-3: the two readers of a bare head that BARE-1's round found unfixed

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, "no decisions for at least 8hrs … make
best long term decisions for cx. no deferring. no partial work" — DELEG-3; the two flags came in
BARE-1's RESULTS.md (`_gate_evidence/pipeline_bare1/`, merged as `0f09ba4e2`, green 07:00Z) and are
posted on [#1591](https://github.com/cx-home/cx-private/issues/1591) with this taking; the owner may
reverse either on reading). BARE-1, CBKEY-1, RS-8, SHIP-1, FIX-1, CXF-8, D78a.**

## The owner's words, verbatim

"no decisions for at least 8hrs. pause if limits are hit and resume when lifted. make best long term
decisions for cx. no deferring. no partial work. only complete, sound, performant implementation that
follows the expectations"

## DIAGB-1 — the diagram module draws a bare def-named head as data, never as a call edge (L141 = (a))

BARE-1 ruled that a bare head is data, namespaced or not, and rewrote every call site with `$`; the
diagram module in cx-tooling (its CX half) and its V half in cx-core-code (D78a) still classify a bare
head whose name matches a def as a call edge — the round rewrote the diagram sources so its output is
unchanged, and left the module's rule as a flag. Taken: the module follows the language — only a
`$`-headed form or an operator head is a call edge, a bare head is a data node — fixture first in the
diagram corpus (a bare def-named head drawn as data; the `$` form drawn as the call), the goldens
re-blessed by running. Rejected: leaving the module's rule (a reader that contradicts the ruled
grammar; RS-8 makes the mover fix every reader); documenting the exception. One small sonnet round on
cx-tooling and cx-core-code's diagram half.

## LINTB-1 — `cx lint` flags a bare head that names a def in scope or an imported member (L142 = (a); #1664)

#1664 found a bare head with a `[cast …]` argument "loud nowhere": under BARE-1 it is data, silently,
and the existing bare-builtin-head finding (1170-b) covers builtins only. Taken: a lint rule, warn
severity, for a bare head whose name is a `[?def]` in scope or an imported module's public member —
the writer almost always meant the call — with the message naming the `$` spelling; the rule is
syntactic over the program reading and needs no evaluation; fixture first in the lint corpus (the
def case, the import case, a bare head that names neither stays silent). Rejected: making the
evaluator refuse (BARE-1 ruled it data; a refusal would reopen the ruling); a finding only under
`--strict` (the class is exactly the silent wrong answer CXF-8 files). One small opus round on
cx-core-data's lint (`vcx/cx/lint.v`) with the LSP hover kept in step; #1664 closes on it.
