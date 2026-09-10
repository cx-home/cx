# RULED: 1373-b — the two diagram golden corpora re-record onto `#quot;`

**Class:** DR-8 mini-ruling — GOLDEN MOVEMENT, in BOTH diagram golden corpora.
`vcx/tools/regen_code_diagram_golden/main.v` and
`vcx/tools/regen_diagram_golden/main.v` each state that regeneration after
their wave cutover is forbidden "except under a DR-8 mini-ruling recorded in
the ledger BEFORE the bytes move". This file is that record, and it is
committed in the same landing as the moved bytes.

**Status:** NOT a new design ruling. `1373-a` (Fable, 2026-09-10 00:50Z, under
the owner's delegation —
`ledger/rulings_2026_09_10_mermaid_label_quote_1373.md`) already chose the
escape. The bytes below are the mechanical consequence of that choice in the
two corpora its own golden audit missed. Recorded by campaign worker A, which
implements it and rules nothing in it.

**Follows:** `1373-a` (the escape set); DRW3-1 in
`ledger/rulings_2026_08_20_diagram_wave3.md` and
`ledger/rulings_2026_08_20_diagram_renderer.md` (the golden-movement rule for
each corpus); `ledger/rulings_2026_09_09_mermaid_golden_sidecars_1350.md`
(#1350, whose `.source` sidecars are what make this a re-record rather than a
re-capture); `ledger/rulings_2026_09_09_diagram_node_id_ordinals_1349.md`
(#1349, the most recent DR-8 mini-ruling, same shape).

## What was wrong — a false negative in `1373-a`'s own golden audit

`1373-a`'s record and `2014e8d34`'s commit message both state:

> Goldens: no committed code-diagram golden or `diagram.cxd` pin carried `\"`
> (grep across both corpora: zero), so nothing moves

**That measurement is wrong.** At `b104651d4`, `grep -rl '\\"'` finds **twelve**
files across the two corpora:

| corpus | files carrying `\"` | of which goldens |
|---|---|---|
| `vcx/tests/testdata/code_diagram_golden/` (441 files) | 6 | 4 |
| `vcx/tests/testdata/diagram_mermaid_golden/` (165 files) | 6 | 6 |

The remaining two are the `.source` sidecars of the first corpus's pair, which
are inputs and do not move. So ten goldens were left holding the spelling
`1373-a` deleted, and the gate at `b104651d4` reddened
`diagram_umbrella_test.v` on exactly those ten — 4 failures at
`diagram_umbrella_test.v:88` (BYTE DIVERGENCE) and 6 at
`diagram_umbrella_test.v:1260` (SIDECAR DIVERGENCE):

```
pin-cfg-if-arm-quote.{compact,full}.golden        209B vs 193B, 853B vs 837B
pin-cfg-match-arm-quote.{compact,full}.golden     208B vs 192B, 852B vs 836B
pin-channel-escape.{min,compact,full}.golden      177B vs 169B
pin-nested-service-worker.{min,compact,full}.golden  497B vs 481B
```

Every delta is exactly `+4` bytes per occurrence — `\"` (2 bytes) becoming
`#quot;` (6) — with 4, 4, 2 and 4 occurrences respectively. That arithmetic is
the discriminator: it says the renderer changed one token and nothing else, so
the divergence is the escape and not a regression riding along with it.

## The ruling

**The goldens move; the renderer does not.** The renderer is right and the ten
goldens are behind. Re-record both corpora with their own tools
(`regen_code_diagram_golden`, `regen_diagram_golden`), from the repo root, and
accept only a diff confined to those ten files and to that one token.

Refused, explicitly:

- **Reverting `esc` to `\"` for these four sources.** That restores a label the
  bundled mermaid renderer cannot parse — the defect #1373 exists to remove —
  and it contradicts `diagram-034` (`conformance/stdlib/diagram.cxd:711`),
  which asserts `#quot;` present and `\"` absent and is `level=core`,
  `gate=enforced`.
- **Deleting the four quote-bearing pin sources.** They are the only corpus
  coverage of a quote inside a label in either renderer; dropping them would
  make the escape untested at byte level in exactly the corpora built to test
  it at byte level.
- **A hand-patch of the ten files.** The tools exist so a golden is never a
  hand-written artifact (#1350's whole subject). A hand-patch also cannot prove
  the fixed point.

## DELETES

The `\"` spelling from the last ten committed artifacts that held it, and with
it `1373-a`'s "nothing else moves" sentence — superseded by this record. After
this landing `grep -rl '\\"'` over `vcx/tests/testdata/*golden*` returns only
the two `.source` inputs.

## How it is graded, port-free

The byte gates live in `vcx/tests/diagram_umbrella_test.v`, which the
implementation lane may not run (umbrella suites bind the port bands a
concurrent full gate is using). So the lane grades the same property with the
tools themselves plus the CX-side fixture check:

1. **Red-proof, kept from the gate**: the ten divergences above, measured at
   `b104651d4` by the full gate — the strongest available red, since it is the
   gate's own instrument rather than a replica of it.
2. **Fixed point**: run each regen tool a second time after the re-record and
   assert a zero diff. `render(source) == golden` for the whole corpus is
   exactly what both umbrella assertions check, and a second regen computes it
   with the same renderer.
3. **Confinement**: the diff touches ten `.golden` files, no `.source`, no
   `MANIFEST`, and no line that is not the `\"`/`#quot;` token.
4. `make test-code-diagram` (the CX-side set comparison) and
   `make test-playground-mermaid` (the bundled renderer that refused `\"` in
   the first place — the check that measured #1373).

The umbrella's own verdict returns on the next full gate, which the loop starts
when the tip moves.
