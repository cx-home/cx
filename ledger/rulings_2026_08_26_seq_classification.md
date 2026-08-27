# Rulings — 2026-08-26 · the SEQ classification hole (#1032)

Recorded BEFORE any behavior moves, per #832 (`ledger/` is the ruling
store) and the DR-8 discipline established in
`ledger/rulings_2026_08_20_diagram_renderer.md`: every spec-reality
divergence in the diagram renderer is adjudicated as a named
mini-ruling first, and zero golden movement is the expected verdict.

## The measured finding

`cx code-diagram` over playground examples 171 and 172 emits
`flowchart TD`. Both are titled "Sequence — …" and both notes promise a
`sequenceDiagram`. Measured on this head:

| source | header |
| --- | --- |
| example 161 (`[?worker …]` top-level) | `sequenceDiagram` |
| example 162 (`[?select …]` top-level) | `sequenceDiagram` |
| example 163 (`[?http-service …]` top-level) | `sequenceDiagram` |
| example 171 (producer / consumer) | `flowchart TD` |
| example 172 (dispatcher + worker + collector) | `flowchart TD` |
| `seq-002-worker-channel-pair.source` (golden) | `sequenceDiagram` |

## SEQ-1 — the filed mechanism is WRONG; this is not a port regression

The issue proposes that the sequence trigger "regressed in the
diagram-surface waves (#889 DRW3 / #992 / the code_tree ports)".
Measured: it did not.

`node_is_sequence_trigger` in the pre-cutover V emitter
(`722d4e055^:vcx/code/code_diagram.v`, lines 492-510) is BYTE-IDENTICAL
to the same function at its introduction (`8b8f474d0`, 2026-05-28). The
CX port (`cd-node-is-trigger`, stdlib/diagram.cx §9.2) reproduces that
walk faithfully, and its own comment records the limit it inherited:
"A `[= $ch [?channel …]]` clause-child does NOT qualify … the blind spot
is preserved."

What moved was the CORPUS, not the classifier. Example 172's source at
`4d7633083` terminated its `[?let]` spine with a BARE
`[?worker name="collector" …]` — a trigger directive in slot position,
which the walk sees. The v0.8.0 syntax migration
(`1ffef3024`, 2026-06-06, three months BEFORE the #889 port) rewrote the
spine to terminate in `[?let [= $_ [?wait-for worker=$d]] [?for …]]`.
`wait-for` is not in the trigger set and a for-comprehension is not a
directive, so the terminal stopped being visible and the latent hole
surfaced. Example 171 broke in the same commit for the same reason.

**Proof (decisive):** the pre-migration 172 shape, run through the
CURRENT binary, still emits `sequenceDiagram`. The classifier is
unchanged; the shape it was given changed.

**Adjudication:** the regression is recorded as a corpus-shape change
exposing a pre-existing classifier hole, NOT as a port defect. The
#889/#992/code_tree ports are exonerated on the record.

## SEQ-2 — the hole is a real contract violation, and the CONTRACT wins

The classifier's hole is not merely a historical accident to be left
alone. Two artifacts in the tree state the opposite behavior as the
contract:

1. The sealed WAVE-3 rule table (§9.0, `code-rules`, the DR-4a artifact
   the emitters read) carries
   `[trigger directive=channel rule="Channel lane; the [?let] binding aliases it"]`.
   "The `[?let]` binding aliases it" only means something if a
   let-BOUND channel is a lane — i.e. if a let-bound trigger counts.

2. The V classifier's own doc comment
   (`program_is_sequence_shape`, pre-cutover) names the shape and the
   examples BY NUMBER: "`[?let]` chains around sequence-trigger
   directives count, since the playground's reference examples
   (#161-#163, **#171-#172**) introduce channels via
   `[?let [= $ch [?channel ...]] BODY]` and the user-observable program
   shape is still sequence-shape."

The SEQ EMITTER already implements this reading. `cd-flat-let`
(§9.6's `flatten_let_seq_aliasing`) descends through an `[= $x V]`
clause — it reads the clause's two items, takes the bound name and the
bound VALUE, registers a `$bind → lane` alias for every
`[?channel]`-valued binding, and recurses into the value. So the
emitter, once reached, renders exactly the lanes the table promises.
Only the DISPATCH that decides whether to reach it disagrees.

**Adjudication:** the classifier is corrected to agree with the rule
table and with the emitter it dispatches to. `cd-node-is-trigger`, when
walking a `[?let]`'s slot values, descends through an `[= $x V]` binding
clause into the bound value, mirroring `cd-flat-let`'s existing descent
exactly. The trigger SET is untouched (worker / channel / http-service /
select / async — no row added or removed). Nothing else in the dispatch
moves: `[?def]` bodies still do not flip it, data still classifies ERD,
and the text-level fallback is unchanged.

## SEQ-3 — golden movement: ZERO, and it is measured, not asserted

The DR-8 expected verdict is zero golden movement. Measured against the
88-source / 264-golden corpus BEFORE the change:

- 92 `.source` files classify 30 ERD / 28 CFG / 34 SEQ.
- Exactly two sources carry a let-bound trigger
  (`seq-002-worker-channel-pair`, `seq-005-multiple-receivers-same-channel`)
  and BOTH already classify SEQ, because both terminate their spine
  with a bare trigger directive.
- No CFG-classified source in the corpus contains a let-bound trigger.

So no corpus source can flip, and the 264 goldens are expected to hold
byte-for-byte. This ruling is recorded anyway: the change moves
CLASSIFIER behavior for shapes the corpus never covered, which is
precisely the gap that let #1032 ship green.

**Adjudication:** zero golden bytes move. The corpus gains the shape it
was missing — example 172's spine, pinned as a SEQ golden (SEQ-4), so
the hole cannot reopen unobserved.

## SEQ-4 — the corpus gains the shape that was never pinned

The 88-source corpus pinned bare-trigger SEQ shapes and let-bound
triggers WITH a bare terminal, but never a spine whose triggers are
ALL let-bound and whose terminal is a non-trigger. That is why a
three-month-old classification flip in the shipped playground went
unobserved through two release cuts.

**Adjudication:** example 172's exact shape enters the golden corpus as
a SEQ pin at all three rungs, red-proven. Example 171's shape rides the
same pin class.

**Red-proof, measured.** With SEQ-2 reverted (`cd-unbind` removed from
the `[?let]` slot walk) and nothing else changed, the DR-8 byte gate
(`vcx/tests/diagram_umbrella_test.v`) fails with exactly six golden
divergences and no others:

```
pin-seq-let-bound-spine-fanout.{min,compact,full}.golden
pin-seq-let-bound-spine-pair.{min,compact,full}.golden
```

Two properties at once: the new pins ARE the guard for this shape (they
are the only thing that goes red), and the fix has zero collateral (no
other golden moves in either direction). Restored, the same gate is
green.

## Cross-reference

- DR-8 instrument: `vcx/tools/regen_diagram_golden`.
- The unreachability finding cited in the issue as "adjacent"
  (`mermaid:<detail>` not reachable from the CLI —
  `ledger/rulings_2026_08_20_diagram_renderer.md`) is NOT implicated:
  `cx code-diagram` reaches the renderer through
  `code_diagram_with_level`, which is live and which this change does
  not touch.
