# Ruling — the two SEQ-4 pins re-sync to the page, and the cascade shape stays pinned (#1170)

**Ruling id:** 1170-d
**Date:** 2026-09-08
**Ruled by:** Fable session, 14:20 ET, on #1170, answering campaign worker C's
drafted letter sets (posted 14:08 ET).
**Status:** RULED before the work. Recorded here by campaign worker C, which
implements it and rules nothing in it.
**Class:** DR-8 mini-ruling — GOLDEN MOVEMENT. `vcx/tests/diagram_umbrella_test.v`
(the absorbed body of `code_diagram_golden_test.v`) states that regeneration of
`vcx/tests/testdata/code_diagram_golden/` after the wave-3 cutover is forbidden
"except under a DR-8 mini-ruling recorded in the ledger BEFORE the bytes move".
This file is that record, and it is committed in the same landing as the moved
bytes.
**Follows:** `ledger/rulings_2026_08_26_seq_classification.md` (SEQ-4, which
added the two pins and wrote the sourcing contract this ruling repairs),
`ledger/rulings_2026_09_08_let_cascade_lint_1170.md` (1170-c, whose §C3
flattening is what broke it), and
`ledger/rulings_2026_08_20_diagram_wave3.md` (DRW3-1, the golden-movement rule).

## What was measured, before the ruling

`vcx/tools/regen_code_diagram_golden/main.v` carries two pins added under SEQ-4,
`pin-seq-let-bound-spine-pair` and `pin-seq-let-bound-spine-fanout`, whose
comment states the sourcing contract in full:

> Sourced verbatim from scripts/gen_guide/playground/playground.examples.js
> — the page's own bytes, so a corpus edit that re-breaks the shape
> (as 1ffef3024's v0.8.0 syntax migration did) moves these goldens
> instead of passing unobserved.

Those two pins are playground examples `171-seq-mid-producer-consumer` and
`172-seq-large-workers-with-backpressure`. §C3's `[?let]`-cascade flattening
landed at `e13190397` and rewrote both page entries from a nested cascade to
one flat multi-binding `[?let]`. The pins did not move:

| | the page (`playground.examples.js`) | the pin string |
|---|---|---|
| `171` | flat, one `[?let]`, 4 bindings | 3 nested `[?let]`s |
| `172` | flat, one `[?let]`, 5 bindings | 4 nested `[?let]`s |

So "the page's own bytes" was a false sentence in both pins, and the property
it was written to buy — a corpus edit that re-breaks the shape moves these
goldens — no longer held. `test-code-diagram` and the golden byte gate were
green either way, because the pin strings are hardcoded V literals that nothing
in the corpus can red. That is the failure mode: the guard was silent about its
own staleness, and there was no automated page-to-pin sync check anywhere in
the tree.

## 1(c) — four pins, twelve goldens

Re-sync `pin-seq-let-bound-spine-pair` and `pin-seq-let-bound-spine-fanout` to
the page's current bytes for `171`/`172`, **after** the `172`
`[= $_w [?wait-for worker=$w]]` join has landed, so the pins do not go stale a
second time in one day. That join landed at `20e9495cb`; this landing syncs to
the page as of that sha.

ADD `pin-seq-let-cascade-spine-pair` and `pin-seq-let-cascade-spine-fanout`
carrying the cascaded strings the pins hold today, frozen, as the SEQ-4
regression for the shape that historically broke.

**Reason, as ruled:** the classifier reaches the let-bound trigger by two paths,
nested and flat, and both stay legal CX. §C3's lint governs the playground
corpus's style, not the language, so a cascade pin in the regen tool
contradicts nothing. Dropping either spelling chooses which regression the tree
stops noticing.

**Refused:** 1(a) — re-sync only — because it retires the exact shape whose
breakage motivated the pin (SEQ-4 records `flowchart TD` emitted for three
months and two release cuts against notes promising `sequenceDiagram`). 1(b) —
freeze and correct the comment — because a comment promising a tripwire that
cannot fire is worse than no guard.

## 2(a) — the contract becomes a check, on the `.source` files

The sourcing contract stops being a comment and becomes an assertion. The check
compares the **`.source` snapshot files beside the goldens** — what the byte
gate actually grades — against the page's `input` bytes for the two ids they
name. A check on the V strings in the regen tool alone leaves the same gap one
level down: the tool could be right and the committed corpus stale.

The two cascade pins are **exempt by id**: they are deliberately not the page's
bytes, so a check that demanded equality of them would be incoherent.

Consequence, and it is the intended one: any deliberate page edit to `171` or
`172` reds this check until the pins and goldens are re-synced, which forces a
DR-8 mini-ruling in the same landing. That is what SEQ-4 wanted and did not get.

## Implementation rules carried from the draft

- Record this ruling BEFORE regenerating. (Done: this file precedes the moved
  bytes in the same commit series.)
- Diff all twelve goldens and READ them against the pins' intent. Never accept
  a regeneration blind — 1170-a's rule about the answer pin, applied here.
- The commit carries `RULED: 1170-d`.
- Blast radius HIGH: fixture expectations move.

## What this ruling does NOT decide

- It does not touch `§C4`, which `1170-b` orders last and which stays open.
- It does not enroll `test-playground-mermaid` in `TEST_TARGETS`. That lane is
  separately measured red on `release/0.18` with 10 pre-existing failures and
  is recorded on #1170; fix-then-enroll is the order, and neither half is this
  ruling's.
- It does not change what the classifier emits. If a regenerated golden differs
  from its predecessor by anything other than the spine spelling, that is a
  defect to report, not a byte to accept.
