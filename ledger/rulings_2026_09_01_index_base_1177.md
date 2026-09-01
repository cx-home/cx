# Rulings 2026-09-01 — #1177 index base: 1-based across the value surface

**Status: RULED (a) BY OWNER 2026-09-01.** Recorded to `ledger/` on
2026-09-01 as the first act of the implementation wave, per the #832
process rule (the ruling was taken on the issue and explicitly left
un-recorded there: *"Issue-only. No repo edits made … the first act of
the implementation wave is writing this ruling to `ledger/`"*). This file
IS that act. No behavior has changed yet.

Issue: #1177. Labels `area:cx-stdlib`, `bug`, `design`, `prio:high`.

## The ruling

**1-based everywhere.** `cx-stdlib/strings` and `cx-stdlib/re` move onto
`code.md` §D4's 1-based space; `cx-stdlib/bytes` stays 0-based half-open
as the **one declared exception**, on the grounds it already states (a
sealed byte buffer is wire territory, `bytes.md:29`).

- **strings** → 1-based, **inclusive-end** `slice`, matching `array` /
  `substring` / D4.
- **re** → match positions become **codepoint** offsets in the same
  1-based space. Byte offsets, if retained for performance, ride as
  separately-named attributes (`start-bytes=`) — never the same word
  meaning two things. `group 0` = full match stays, documented as a group
  **ordinal**, not an index.
- **bytes** → unchanged.
- **Absent sentinels retired** — the `find` family and `[$position]`
  answer the empty-sequence channel (§9.0), not `-1` / `0`.
- **`strings.md` §2 must state the ORIGIN** beside its codepoint
  statement. The missing sentence is what let this drift.
- **One normative line in `code.md` §D4** stating that the 1-based rule
  governs every value-surface index, naming `bytes` as the sole declared
  exception, conformance-backed so the next module cannot drift.

## Why this is drift and not an adjudicated exception

`code.md` D4 has been unambiguous ("`$xs[1]` is the first element",
§D4), stop-inclusive per D5. The core surface honors it: `$xs[N]`,
`[$nth]`, `[$position]`, `[$substring]`, `cx-stdlib/array` (whose
out-of-range diagnostic even says "positions are 1-based"), and CXPath
predicates. A `grep` over `ledger/` for index-base language returns
nothing — no ruling ever carved `strings` or `re` out.

The composition is where it bites: `re` reports a match in BYTE offsets
while `strings` indexes in codepoints and `strings.md` §2 states there is
deliberately no byte-aware indexing surface. So a match position cannot
legally be fed to any string operation, and no conversion is named
anywhere — the two compose silently and wrongly.

## Measured scope (2026-09-01)

**436 call sites** in `.cx` / `.cxd` across the repo touch the affected
verbs (`strings:find|slice|rfind|at|find-from|find-all`, `re:find|group`)
— consistent with the issue's 237 + 217 estimate.

## Execution constraints (carried from the ruling, normative for the wave)

1. **This is a CUTOVER.** No dual-accept, no compatibility flag — the
   standing rule. The implementation, the spec, the fixtures and all 436
   call sites land together or not at all; a half-migrated breaking
   change is worse than an unstarted one.
2. **Migration goes through the parser/emitter — NEVER regex.** These are
   CX syntax, and the standing rule forbids text-replace for CX syntax
   migration. An index argument can be a literal, a binding, or an
   arbitrary expression, so `N` → `N+1` is not a textual operation: a
   literal rewrites to its successor, and a non-literal must wrap.
3. **The red-proof needs TWO multi-byte characters.** `'héllo-WORLD'`
   passes by coincidence — its byte start (7) equals the correct 1-based
   codepoint start (7). The discriminating case is `'héllö-WORLD'`, where
   the naive compose yields `'ORLD'`. An ASCII-only or single-multibyte
   fixture is a VACUOUS PASS and must not be accepted as evidence.
4. **`spec/03-approved/xap/demos/oriel/tui.cx:1364`** — the
   hand-reconciliation comment and its `[- $i 1]` reasoning — is retired
   by this ruling and must be revisited in the SAME wave, or the
   reference storefront silently regains the off-by-one from the other
   side.

## Wave plan

- **W1 — the normative statements.** `code.md` §D4 gains the governing
  line naming `bytes` as the sole exception; `strings.md` §2 states the
  origin; `strings.md` §3.1 and `re.md` §4.2 are corrected. Spec-first,
  per the standing spec-before-implementation gate.
- **W2 — `strings`.** 1-based `find` / `rfind` / `find-all` / `at` /
  `find-from`, inclusive-end `slice`, absent → empty sequence. Fixtures
  first, both polarities, including the two-multibyte composition case.
- **W3 — `re`.** Codepoint positions in the 1-based space; `start-bytes=`
  for the byte offsets if retained; `group 0` documented as an ordinal.
- **W4 — the 436 call sites**, via the parser/emitter, plus the oriel
  `tui.cx` revisit.
- **Exit:** full `make test` GATE-RC=0 (never `test-vcx`).

## Status

Ledger record written 2026-09-01. **W1 not yet started.**
