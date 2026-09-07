# Ruling record — `cx fmt` layout follow-ups (2026-09-07)

Owner-ruled 2026-09-07, in session, three questions answered `a a a`. Raised
immediately after #1058 T1.2 landed at `ec7248861` and recorded BEFORE the work
they authorize (R4.2).

Context: `ledger/rulings_2026_09_05_fmt_module_directive_and_layout_1318_1058.md`
(1058-T1.2, 1058-T1.2-b, 1318-A) and its implementation record.

## RULED 1058-Q1 (a) — `cli.md` §3.1's "authorial structure" sentence is corrected

`spec/03-approved/misc/cli.md` §3.1 says `cx fmt`'s lossless canonical
"preserves comments, anchors, and authorial structure". The same claim appears
in that file's §2 registry row (`cli.md:107`) and in
`docs-src/canonical/sections/08-tooling.cxd`.

It contradicts `formatting.md` §2/§3, which are also approved and normative:
the `canonical` profile — the `cx fmt` default — IS
`indent=spaces=2  children=wrap=80  max-width=80`, and `idiomatic` is the
profile whose layout axes preserve author layout. So the sentence was false
BEFORE the layout landed; what the layout changed is that it is now visibly
false rather than masked by a lane that declined to format anything wide.

Ruled: correct the three spellings to match `formatting.md` §2. This is a stale
sentence, not a design choice.

Rejected: (b) leave it and file an issue — the contradiction is what nearly
sent an implementable, already-ruled change back to the owner as a
shipped-surface question, which is a cost this record exists to stop repeating.
Rejected: (c) change `formatting.md` instead — that would true the spec to a
shortfall.

`formatting.md` is NOT edited: it already says the right thing.

## RULED 1058-Q2 (a) — a number's SPELLING is preserved where it is meaning-bearing

The question asked whether `cx fmt` should preserve a number literal's
spelling (`0x3a7bd3e2`, `1_000`) instead of declining the file. Ruled (a):
preserve.

**The implementation is NARROWER than the question's wording, and the reason is
that `canonical.md` §2.5 is more specific than either the question or the
answer.** "Emit `ProgramLiteral.src` verbatim when non-empty" would violate
§2.5 in two places, so it is not what (a) can mean:

| §2.5 rule | verbatim `src` would give | §2.5 requires |
|---|---|---|
| Integer: "no underscores in canonical output (underscores in source are stripped)" | `1_000` | `1000` |
| Hex integer: "used in canonical output only if source used hex form (lossless preserves intent)" | `0x3a7bd3e2` | `0x3a7bd3e2` — correct |
| Float: shortest round-trip Ryū, "**always** carrying an exponent" | `1.10e0` | `1.1e0` |

So (a) is implemented as §2.5 CONFORMANCE — the same shape #1058 T1.2 turned
out to have. The program emitter preserves the HEX form when the source token
was hex (which is what makes `[hash::bytes 0x3a7bd3e2]` formattable and is the
case the question was actually about), and keeps normalizing everything §2.5
says to normalize.

## Measured before ruling — the defect is in BOTH lanes, not just the program one

Probed with deliberately NON-canonical input (doubled spaces), because
comparing fmt's output to its input on already-canonical text cannot tell
"formatted correctly" from "declined" — the trap that cost hours in the
#1318/#1320 work:

| input | data lane | program lane |
|---|---|---|
| `n=1.5` | formats | formats |
| `n=1.10e0` | **DECLINES** | **DECLINES** |
| `n=0x1f` | **DECLINES** | **DECLINES** |
| `n=1_000` | **DECLINES** | **DECLINES** |

Neither lane produces §2.5's answers (`1000`, `0x1f`, `1.1e0`). That is wider
than Q2 asked about and wider than this batch: §2.5's float
"exponent-always" rule in particular would move canonical bytes across the
whole data corpora, and `[?let [= $x 1.5] $x]` formats to `1.5` today rather
than `1.5e0`. Whether exponent-always is the shipped intent is an open
text-format question of the #1097 family.

**Split, deliberately:** the hex-preservation half lands under this ruling
(narrow, program-lane, unblocks files, no data-corpus churn). The
underscore/float/data-lane half is filed as its own issue with the table above
and is NOT smuggled into a bug batch.

## RULED 1058-Q3 (a) — the 10 MB `cx fmt` cost is filed

`cx fmt` on `fixtures/bench/bench_10mb.cx` runs for more than four minutes,
which stalls any corpus sweep (it is why every measurement script in the layout
work excludes `fixtures/bench/`). Filed rather than fixed here.

## A defect in what just landed, found while answering Q2

`vcx/cx/program_emit_head_ascription_test.v`'s
`test_a_number_spelling_under_an_ascription_still_fails_closed` asserts
`fmt_source(src) == src` on ALREADY-CANONICAL input, so it cannot distinguish
declining from formatting correctly — the exact vacuous-probe trap the
#1318/#1320 record warns about, reproduced in a test written the same day. It
is rewritten to feed doubled spaces and to assert the behaviour that is
actually observed.
