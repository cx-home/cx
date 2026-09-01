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

---

## W1 LANDED 2026-09-01 @ 9990c0fad — the normative statements

`code.md` §D4 governing line (+ `bytes` named as the sole exception),
`strings.md` §2 origin sentence + §3.1 / §3.2, `re.md` §4.2 / §4.3.
verify-doc-blocks 739/0.

**The spec now LEADS the engine.** That is the deliberate spec-first
order, but it is also the exact "grammar/spec ahead of engine" shape this
repo keeps finding as a defect (the D1 pattern), so it is recorded here
rather than left latent: #1177 stays OPEN tracking W2–W4, and the gap is
this file plus that issue, not a surprise for a later audit.

## W2 ATTEMPTED and REVERTED 2026-09-01 — with the findings that matter

The `strings` implementation change was written, built, and measured,
then **reverted deliberately** rather than landed half-done. What it
bought is the evidence below; the tree is back to a consistent state and
the full corpus is green.

### The measured red-proof (the ruling's constraint 3, discharged)

```
'héllo-WORLD'  (ONE multi-byte)  re start=7  compose -> 'WORLD'   PASSES BY COINCIDENCE
'héllö-WORLD'  (TWO multi-byte)  re start=8  compose -> 'ORLD'    WRONG
```

Confirmed live. Any fixture for this using one multi-byte character is a
VACUOUS PASS and must be rejected as evidence.

### The migration is NOT a blanket +1 — the two rules that make it per-site

1. **Only the START moves; END expressions are UNCHANGED.** 0-based
   half-open `[a, b)` covers exactly the characters of 1-based inclusive
   `[a+1, b]`. Verified: old `slice(s, 0, 3)` and new `slice(s, 1, 3)`
   both yield `'hel'`. So `slice($s, 0, [$strings:length $s])` becomes
   `slice($s, 1, [$strings:length $s])` — the length expression is
   already right.
2. **A `find` result threaded into a `slice` start needs NO edit.** Both
   origins move together, so the composition is invariant. Verified:
   `slice($s, find($s,'l'), length($s))` yields `'llo'` before and after.

A blanket `+1` over index arguments would therefore CORRUPT exactly the
compositions the ruling exists to make correct. This is why the
parser-driven migration is mandatory and a textual one is refused.

### Measured surface

- **217** `.cx` index-bearing call sites: 143 `slice`/`at`, 74
  `find`/`rfind`.
- Of 136 `slice` sites, only **23** carry literal index arguments; **113**
  carry expressions (`[+ $i 1]`, `[$strings:length $l]`, `[- $w 1]`,
  `[$min 160 …]`). The rewrite cannot be lexical.
- **31 fixtures** break on the `strings` change alone: 25 stdlib (10 in
  `diagram.cxd`) and 6 package (`gtin`, where an inclusive-end `slice`
  returned `'23'` for an expected `'3'` — a check-digit, i.e. a silently
  wrong VALUE, not a crash).

### Recommended wave shape for the next session

- **W2** = `strings` impl + its fixtures + its call sites, ONE commit
  (cutover, no dual-accept).
- **W3** = `re` impl + fixtures + call sites, ONE commit.
- **W4** = the oriel `tui.cx:1364` hand-reconciliation revisit.

Write the parser-driven migration tool FIRST; classify each site as
(a) literal start → successor, (b) expression start → wrap, (c) start
already sourced from a `find` → leave alone. Category (c) is the one a
careless pass gets wrong, and it is invisible in the diff.

---

## What the migration actually missed (recorded 2026-09-01, post-execution)

The wave note above predicted category (c) — a start already sourced from
a `find` — as "the one a careless pass gets wrong, and it is invisible in
the diff." That prediction was right about the *mechanism* and wrong about
the *location*. Every real defect found after the tool ran was on the END
of a range, or outside the tool's field of view entirely. Recorded here so
the next index-space change starts from the true list.

### The tool's six categories were sound; its BLIND SPOTS were not

**B1 — a length-derived end must NOT move.** `cd-erd-raw-attr` sliced
`[$str-length k]` as an exclusive end; decrementing it dropped the last
character of every raw attribute name. The rule is exact and worth
stating once: under `[a,b)` ≡ `[a+1,b]`, an end that was `length` STAYS
`length`. Only a *find-sourced* end decrements, because the find result
itself moved. Two different ends, two opposite rules, identical spelling
in the source.

**B2 — a LET-BOUND length hides from a guard rewrite.** Guards written
inline against `[$str-length $s]` were migrated `>=` → `>`. Guards
written against `[= $len [$str-length $s]]` were not. Three loops in
`diagram.cx` kept a 0-based guard while their tail slices were
decremented — two halves of one decision, applied inconsistently. In
1-based inclusive the last valid position IS `$len`: the guard is `>` and
the end is `$len`. Any future pass must resolve bindings, not match text.

**B3 — an exclusive bound returned by a HELPER.** `cd-ident-end` and
`cd-match-close` return "first position past the thing". The tool bumped
the start and left the end, shifting the whole range by one. A helper
that returns an exclusive bound is a find in disguise; the tool knows the
find FAMILY, not user code that re-exports a bound under a new name.

**B4 — a value that is already a migrated position.** `inject-svg-metadata`
got `[+ [+ $end 1] 1]`: the start rule fired on an expression that was
already 1-based. Double-bumps are mechanically detectable — `[+ [+ $x 1] 1]`
— and a future tool should refuse to emit one.

**B5 — an entire scanner the tool could not see.** The worst case was not
a mis-rewrite but a NON-rewrite.
`scripts/compile_binding_api_fixtures.cx` threads its position through its
own `ch` / `skip` / `ident-end` helpers, so no known index argument ever
appeared and the file was passed over whole — seed `[$parse-expr $src 0]`,
five `[< $i [$strings:length …]]` validity tests, and a header still
reading "0-based, mirroring the Python". The general shape: **a file that
defines its own indexing vocabulary is invisible to a rewriter keyed on
the stdlib's.** The detector that works is not the call site but the
BASE — a literal `0` seeding a position parameter.

### The gates did not carry the weight

Of the five defects above, the conformance corpus caught exactly the two
in the ERD path. The rest were found by reading the diff of one file end
to end and probing the uncovered paths by hand:

- `[?match]` arm rewriting has **no fixture**. It was broken outright —
  `[case` scanned as `"ase "`, so no arm was ever rewritten — and the
  suite stayed green. Verified afterwards against its documented contract
  by direct probe.
- The SVG carrier needs graphviz, so it is **not exercised**. Verified by
  an inject → extract round-trip on both a normal and a self-closing root.
- `test-binding-api-parity` is **vacuously green** (#1180): it reported
  51/51 on a compiler emitting `"ops": ,` — malformed JSON, zero
  operations — because all four bindings received the same nothing and
  agreed on it. The numbers are byte-identical before and after the fix.

The lesson is not "write more fixtures." It is that a mechanical rewrite
over a whole corpus is only as trustworthy as the WEAKEST covered path,
and the covered set must be established BEFORE the rewrite, not assumed
from a green gate afterwards.

### Rules for the next index-space change

1. An end that is `length`-derived stays; an end that is find-derived
   decrements. Classify ends separately from starts.
2. Resolve let-bindings before rewriting guards.
3. Treat a helper returning an exclusive bound as a find.
4. Refuse to emit `[+ [+ $x 1] 1]`; it always means the rule fired twice.
5. Detect 0-based scanners by their SEED (a literal `0` flowing into a
   position parameter), not by their call sites.
6. Enumerate the uncovered paths first, and probe each one by hand.
