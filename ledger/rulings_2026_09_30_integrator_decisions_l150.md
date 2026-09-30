# Integrator decision 2026-09-30 — Letter 150, taken as delegated: code.md §11.4's partition word `reference-lane-only` becomes `reference-only`

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, DELEG-3; the flag came in WORDS-1's
RESULTS.md (`_gate_evidence/pipeline_words1/`, graded `11d283c63`) and was posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 20:4xZ with this taking; the owner may
reverse it on reading). WORDS-1 (L120), VOCAB-1, DOCS-51 §1, RS-8, RS-36, RS-38.**

## The owner's words, verbatim

"we're still using the term 'lane'?" (2026-09-30, the question Letter 120 answered) — "no decisions for
at least 8hrs … make best long term decisions for cx. no deferring. no partial work"

## REFL-1 — the gate-protocol partition of code.md §11.4 is spelled `reference-only`; the governance row follows; the allowance retires (L150 = (a))

Measured on the head `63299f88a` (cx-core-code `97f22c7bc`): WORDS-1 removed the word from every step
name, directory, row and prose line of the tree and left one allowance, governance.md's status row
citing code.md §11.4's own term `reference-lane-only` — five lines of cx-core-code's
`spec/03-approved/core/code.md` (5793, 6333, 6336, 6339, 7900) partition the gate protocols into
those bound to the reference implementation and those the conformance bar holds. Taken: the word is
`reference-only` on those five lines and in governance.md's row (`partitioned reference-only vs
conformance-bar`), the meaning unchanged — "the protocol is bound to the reference implementation"
is what the section already says — no corpus case moves, and the `[page path=… governance.md …]`
allowance row in `docs-src/site/vocabulary.cxd` retires with it. The move rides WORDS-2's round
(the three component files still carrying the word by name: cx-platform-ux `scripts/oriel_lane.sh`,
cx-platform-sso `scripts/sso_interop_lane.sh`, cx-platform-xap `oriel/keys.cx`), sonnet, with
`make spec-freeze-gate` and the vocabulary step as own steps; the round's RESULTS.md records each
moved sentence beside its line. Rejected: (b) a permanent allowance (a refused word kept in the core
spec by exception, for as long as the section lives); (c) holding the allowance for the owner's read
(the word ships in code.md at the cut, a debt on it).

The five sentences as they stand on cx-core-code `97f22c7bc` (the word moves, nothing else):

- line 5793: `is reference-lane-only per §11.4's partition — a distribution cannot`
- line 6333: `- **reference-lane-only** — the protocol is bound to the reference`
- line 6336: `  distribution tests). Gates 5–10 and 14–16 are reference-lane-only:`
- line 6339: `  reference-lane gate never defines conformance; the corpus does.`
- line 7900: `| **EV-SELECT-FAIR** | `[?select]` MUST NOT be deterministically biased toward source order among ready cases (the fixture-checkable form); the uniform-distribution test protocol is reference-lane-only (§11.4 partition) | deterministic first-ready selection |`

governance.md row (cx-private, line 568): `| code.md §11.4 gate protocols | C→B | partitioned reference-lane vs conformance-bar (L75) |`.
