# Ruling record — #1328 + #1330: the shape fingerprint hashes structure, and §7 idempotence is verified (2026-09-06)

Issues: #1328, #1330 (both bug, area:tooling, prio:high). Follows #1318, #1320.
No spec surface. Ring 0: `vcx/cx/program_fmt.v`.

## How these were found

Not from the issues — from measuring what `cx fmt` still declined after #1320
and grouping all 184 remaining no-op files by WHICH verification fails:

| cause | files |
|---|---|
| **shape mismatch (#1328)** | **~96** |
| interior comment (#1320-B's declared boundary) | 73 |
| canonical text not a re-parse fixed point | 7 |
| canonical text does not re-parse at all | 5 |
| not a valid program (data lane — correct) | 3 |

Comments were NOT the dominant blocker, and neither was layout. Grouping by
cause before touching anything is what turned "87 files still no-op" into one
field in one function.

## RULED 1328-A — `src` is fingerprinted only when it differs from `str_val`

`prog_shape_of` hashed `ProgramLiteral.src`, the literal's ORIGINAL SOURCE
TOKEN. Measured shape diff on `[foo name=bar [scope "t"]]`:

```
source:    L0 3:bar 3:bar   <- bare `name=bar`   -> src = "bar"
canonical: L0 3:bar 0:      <- emits name="bar"  -> src = ""
```

Only `src` differs; kind, `str_val` and `data_type` are equal. The two parse to
the same program.

`src` is genuinely meaning-bearing for a NUMBER — a `::T` ascription coerces
from that text, so `[hash::bytes 0x3a7bd3e2]` must never become
`[hash::bytes 978374626]`. Dropping it outright would be unsound, and that was
my first instinct and wrong. But it is ALSO set by the [L20] string fallback,
where a bare run becomes a `string_lit` carrying its raw token; there
`src == str_val`, the value is fully described by `str_val`, and `src` records
only whether the author wrote `name=bar` or `name="bar"`.

So the rule needs TWO conditions: **drop `src` only when it adds nothing to
`str_val` AND re-emitting it cannot change how it reads.**

    if src == str_val && !cx_would_autotype(src) { /* excluded */ }

- bare string fallback (`name=bar`) → equal, not number-shaped → excluded →
  shapes match → formats;
- `1_000` (emitter re-renders `1000` from `int_val`) → `src != str_val` →
  included → still fails closed, verified;
- `0x3a7bd3e2`, `1.50`, a 20-digit bigint → emitter reproduces the spelling →
  shapes match → these now FORMAT instead of failing closed;
- `[a m=007]` → equal BUT number-shaped → included → fails closed, as written.

**The second condition was missing on the first attempt and the GATE caught
it** — `conformance/fmt.cxd` fmt-008-scalars-as-written went red with
`m=007` → `m='007'`. `007` has `src == str_val`, so the one-condition rule let
it through, and the emitter must QUOTE a number-shaped run to keep it a string.
That quoting changes the DATA reading (where the bare image auto-types) even
though the PROGRAM reading is identical either way, so a bare number-shaped run
has to stay in the fingerprint. I had verified `1_000`, hex, decimal and bigint
and concluded the numeric cases were covered; a leading-zero string was the
shape I did not think to try, and "verified" was too strong a word for what I
had actually tested.

Same class as #1318: **a fingerprint that hashes source text rather than
structure reports a meaning change every time the formatter does its job.**
That is now twice in this file, so #1328 carries a note to sweep `shape_node`
for any other field carrying spelling.

## RULED 1330-A — idempotence is checked, not trusted

`fmt_source` verified the canonical text, the AST shape and (since #1320) the
comment inventory. It never verified the one property `formatting.md` §7
actually names: `fmt(fmt(x)) == fmt(x)`.

It does not always hold. The data emitter's document-level text handling quotes
a multi-line text run in one position and re-emits it bare in another, so
`mesh-strategy.capture.cx` oscillates forever in a 2-cycle (#1319) and
`design-capture.vocab.cx` needed two passes (2936 → 2803 → 2772). **The second
was newly reachable because 1328-A let more files through** — the improvement
exposed it, which is exactly why the property had to become checked rather than
observed.

A candidate that is not its own fixed point now fails closed to the SOURCE.
Unchanged text is trivially a fixed point, so the stable answer is always
available. The re-run calls `fmt_source_lane`, not `fmt_source`, so it cannot
recurse.

Rejected: fix the data emitter's quoting rule instead. That is the real cause
and #1319 stays open for it, but it is the LOSSLESS CANONICAL DATA form — a
shipped surface with fixture reach across the data corpora — and reshaping it
was not the right move at the end of a long session. This is a containment, not
a cure, and it is recorded as such: #1319 must not be closed on the strength of
it, and those two files stay unformatted until it is fixed.

Rejected: iterate to a fixed point (format until stable, bounded). It would
"succeed" on the 2-cycle file by picking whichever half the bound landed on —
an arbitrary answer dressed as a canonical one.

## Measured

Over all 263 `.cx` outside `third_party/`:

| | changed | comment loss | non-idempotent |
|---|---|---|---|
| session start | 36 | silent (4 shapes) | 1 |
| after #1318 | 36 | " | 1 |
| after #1320 | 52 | 0 | 1 |
| after 1328-A | 125 | 0 | 2 |
| after 1330-A | **123** | **0** | **0** |

125 → 123 is correct: the two unstable files now fail closed rather than
emitting output that does not settle.

**Cost of 1330-A**, prod-vs-prod (the same build profile both sides — a
dev-vs-prod comparison conflates the unstripped build and reads as 11×):

| file | baseline | with both | ratio |
|---|---|---|---|
| `bench_medium.cx` | 0.037 s | 0.049 s | 1.32× |
| `stdlib/similar.cx` | 0.017 s | 0.019 s | 1.12× |
| `examples/cx-tour.cx` | 0.017 s | 0.018 s | 1.06× |
| `bench/bench_1mb.cx` | 0.679 s | 1.234 s | 1.82× |

Within the analytical bound (one extra lane pass, ≤2×, and only on inputs the
lane actually changes — a fail-closed file skips the check entirely). No
blowup of the #1281 kind.

## Still open, stated plainly

`cx fmt` changes 123 of 263 files. 135 remain a no-op: 73 on interior comments
(#1320-B, needs a width-bounded layout so a broken form gives the comment a
line), 12 on emitter round-trip gaps (the #1318 family, 7 not-a-fixed-point +
5 canon-does-not-reparse), 2 on #1319, and the rest already canonical or not
programs. #1058 T1.2's layout is still unbuilt.
