# Rosetta Corpus Audit

This audit tracks which programs port cleanly to CX and which surface gaps each
one surfaces. Refresh per release boundary.

The corpus is **adoption evidence** (RULED: VC-28) — the artifact that answers
"can CX do ordinary things". It is therefore gated: `make corpus-audit` runs
every program and fails on drift between a program's live status and the status
recorded here, so this table cannot quietly become fiction again.

Seed: 5 of 20 programs (acceptance-criteria minimum five). Programs 03/04,
07–12, 14–20 still to write. Extension #21 added 2026-05-26 to close gate 47.7 —
exercises the `http` + `csv` + `validate` triad.

**Last revised: 2026-08-25 against `release/0.17`** — re-derived from
measurement after all six programs were rewritten for the v0.8.0 surface.

**Re-run 2026-08-31 against `release/0.18`** (ergonomics campaign #1144 W4):
all six programs re-run unchanged, every live status matches the table below.
No program carried a pre-campaign workaround shape for the campaign's idioms
to retire — the sweep's findings, including why the op-table idiom does not
apply to `05-rpn-calculator`'s atom token stream, are recorded in
`05-rpn-calculator.md` under "Post-campaign re-derivation". The idiom swaps
the campaign *did* find live in the teaching corpus landed in
`conformance/llm/antipatterns.cxd`, `conformance/stdlib/fp.cxd` and
`conformance/stdlib/array.cxd`.

## What the 2026-08-25 re-derivation found, and why it was needed

Every program in this corpus had been **unrunnable since the v0.8.0 homoiconic
reshape**, and the table recorded two of them as `green`. `make corpus-audit`
detects exactly that, correctly, and was wired into no lane — so nothing read
it (#957).

They were not stale by a syntax detail; they predated the reshape wholesale:
retired infix `to` ranges (now refused by the `check-no-infix-range` gate), the
`[?let $x = … :in body]` colon form, `:when`/`:yield`/`:using`/`:init` colon
clauses, `[?fn ($a, $b)]` comma params, and `contains(a, b)` / `nth(x, 1)` /
`count(…)` call-parens in a prefix Lisp-1 language.

Five were rewritten and MEASURED green or workaround (rc=0 with the correct
answer, not merely parsing) in the first pass; **#21 followed** once the same
audit was re-run against a fresh binary and it was the one program still
failing to parse. The old gap register described a surface that no longer
exists and is retired below rather than carried forward as though still true.

### The #21 tail (2026-08-25, second pass)

The first pass left #21 alone on the reasoning that it was "legitimately
blocked (pre-impl)". Two things were wrong with that. Its source still did not
parse — a corpus program that cannot be read is not evidence of anything — and
its recorded reason, that the `url`/`csv`/`validate` bodies were pending, had
stopped being true: all three are `gate=enforced` in `conformance/gates.cxd`,
impl complete. A shipped module recorded as pending is the same species of
fiction as an unrunnable program recorded as green, and the gate could not see
either, because a `blocked` row matches a non-zero exit whatever the cause.

It is rewritten, it parses, and it is still `blocked` — now for the true
reason, which is the capability boundary rather than a missing surface.

| Program | Last-revised HEAD | Status | Gap count | Gaps / follow-ups |
|---|---|---|---|---|
| 01-fizzbuzz-shapes | `release/0.17` 2026-08-25 | green | 0 | Clean on the current surface: `[$range 1 30]`, `[$mod]`, `[?match true [when …] [else …]]`. Yields shapes (atoms / the number), not text. |
| 02-log-parser | `release/0.17` 2026-08-25 | workaround | 1 | Clean with `[$contains]` + `[?for [in $line $lines] [yield …]]`. Remaining gap: no `split` / `tokenize` / `format`, so the line is classified but not FIELD-parsed (timestamp / level / message stay inside one string). |
| 05-rpn-calculator | `release/0.17` 2026-08-25 | green | 0 | Folds with `[?reduce … [using [?fn ($acc $tok) …]] [init …]]`, stack carried as a document. Both former constraints RETIRED by the Cluster A settlement (R-A1, 2026-08-25): a node-set in element content now splices — `[?splice $acc/*]` IS the push (new head + every existing item) — and the child axis reads the stack (`$acc/n`); the silent grouping envelope (#961) can no longer be constructed (a bare sequence as content refuses loudly, #847-1a). Re-measured: `[stack [n 35]]`, rc=0. |
| 06-bfs | `release/0.17` 2026-08-25 | workaround | 1 | Graph-as-document: `$graph//edges` + a comprehension, no adjacency list built. Enumerates edges — as the original did. A true breadth-first TRAVERSAL (frontier queue, visited set) is not demonstrated; `[?def]` recursion exists on the current surface, so it is plausibly expressible now, but claiming so without writing it would be a guess. |
| 13-config-validator | `release/0.17` 2026-08-25 | green | 0 | Clean: `[$count $config//port]` + `[$and]` + `[?match true …]`. Verified DISCRIMINATING, not vacuous: removing `[port 8080]` flips it to `:invalid`. |
| 21-fetch-csv-validate | `release/0.17` 2026-08-25 | blocked | 0 | Rewritten for the v0.8.0 surface (it did not parse: retired `:scope` colon-slot on `[?def]`, and `[?http-client]` is a client-handle constructor, not a request form). Now `http` + `csv` + `validate`, all three `gate=enforced`. Blocked by the **capability boundary, not a surface gap**: the fetch needs `net`, the offline audit grants none, so `[$http:get]` refuses with `CXER0271` before any byte moves. The pipeline downstream of the fetch is measured working and discriminating — same three `[?def]`s over a literal CSV body return `1` from 3 rows. |

## Summary

- **green**: 3 (#01 #05 #13) — no workarounds, correct output. #05 graduated
  2026-08-25: the Cluster A settlement (R-A1) retired both of its gaps —
  `[?splice]` in element content is the push idiom and the child axis reads
  the stack; the #961 envelope is unconstructible.
- **workaround**: 2 (#02 #06) — both RUN rc=0 with the correct answer, but
  each leans on a documented gap: no `split`/`tokenize` (#02), reduced scope
  versus a real traversal (#06)
- **blocked**: 1 (#21 — the `net` capability the offline audit cannot grant,
  not a surface gap)

**All six were `blocked` before this re-derivation** — every program in the
corpus was unrunnable, while the table claimed two `green`. The move is
6 unrunnable → 3 green + 2 running-with-known-gaps + 1 parsing-and-refusing
at the capability boundary.

A note on the classification, because the temptation runs the other way: a
program that runs and prints the right answer is NOT automatically `green` here.
`green` means no workaround was needed. Calling #02/#05/#06 green because they
now produce correct output would re-create precisely the fiction this
re-derivation removed — a table that reads better than the surface behaves. (I
drafted it that way first; the sibling `.md` write-ups are what forced the
correction, which is a point in favour of the detector reading them.)

## Live cross-program gaps (2026-08-25)

| Gap | Programs affected | Recommended action |
|---|---|---|
| String field-parsing: `split` / `tokenize` / `format` | #02 (#03 / #04 / #10 / #15 / #16 expected) | Unchanged from the previous audit and still the biggest cross-program gap: a log line can be classified but not decomposed. |
| Breadth-first traversal with a frontier | #06 | Probably expressible via `[?def]` recursion now; write it and find out rather than asserting either way. |
| No live end-to-end run of the fetch leg | #21 | Not a surface gap — every stage is proven offline and composes. Needs a fixture HTTP server the audit can point at, plus a `net` grant, before the program can be measured green. |

Two rows left this table on 2026-08-25: #05's child-axis-vs-grouping row
(**#961**) and its no-sequence-append row. Both were retired by the Cluster A
settlement (R-A1) at the same time #05 graduated to `green`, but the table was
not updated with the status row — so it went on recommending a `//n`→`/n`
switch that had already been made. Recorded here because it is the same
failure mode the whole re-derivation was about: one half of a document
updated, the other half left asserting the old world.

## Retired: the 2026-05-26 gap register (v0.7.x surface)

The previous table's gaps are retired because they were measured against the
pre-reshape surface. Kept as history, not as findings:

- *Math / arithmetic builtins* — already closed 2026-05-26 by the math-operator
  surface; `[$mod]` is used by #01 and #05 today.
- *Multi-arg `[?fn]` apply with non-trivial body* — **closed by measurement**:
  #05's `[?fn ($acc $tok) …]` inside `[?reduce]` is exactly that, and works.
- *`$bind/child` single-match* — superseded by the more precise #961 finding
  above (grouping transparency, not single-match arity).
- *Paren-expression with operators (`$x > 4`)* — void: the surface is prefix
  Lisp-1 (`[> $x 4]`), so the shape that "parse-failed" is not a shape CX has.
- *Atom-as-attribute-value friction* — void: attributes are `name=value`
  (`level=:error`), which #02 and #06 use.

## Where the gate is wired

`corpus-audit` is in `TEST_TARGETS`, so both `make test` (the release gate) and
`make test-no-parallel` run it. `scripts/test_changed.sh` carries a manifest row
naming `corpus/*`, the ring lanes, and `scripts/corpus_audit.sh` as its inputs,
so the development-loop entry point runs it whenever the corpus or the audit
script moves. Wiring landed last, deliberately: wiring it while the corpus was
red would have painted that red into `make test`.

## Method note

Statuses here are MEASURED, never inferred: a program is `green` only when it
runs rc=0 AND produces the expected value. #13 additionally carries a negative
check (remove the port, expect `:invalid`), because a validator that answers
`:valid` unconditionally passes a naive audit while proving nothing. #21
carries the same discipline the other way: its pipeline is measured over a
literal CSV body with a deliberately bad row, so "blocked on the fetch" is a
statement about the capability boundary and not a cover for an unproven
program.

The detector's blind spot, recorded so the next reader does not trip on it: a
`blocked` row matches ANY non-zero exit. Parse failure, capability refusal, and
a genuine surface gap are indistinguishable to it. That is why #21 sat green in
the gate for a full pass while its source did not parse. If a program is
recorded `blocked`, the reason lives in this table and in the sibling `.md` —
and the gate cannot check it for you.
