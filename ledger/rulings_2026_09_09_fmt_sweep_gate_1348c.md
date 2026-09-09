# RULED: 1348-c — the `cx fmt` census becomes a gate, and the ERROR column is a named roster

**Fable, 2026-09-09 09:34 ET, on worker A's letters:** `1(c)` — an expected-ERROR
manifest; `fmt-sweep` joins `TEST_TARGETS`; the declined ratchet is tightened by
whoever lowers it. LOW.

## What was wrong

`fmt-sweep` and `fmt-sweep-timed` existed and were in **no** `TEST_TARGETS` row,
so nothing ran them. The Makefile's own note said the sweep "becomes a gate lane
once the census is a committed number", and #1348's census had been a committed
number since `12abdac33` without the lane appearing. A report nothing runs is
the seam-with-no-consumer shape this repo refuses to ship.

## Why a roster and not `--max-errors N`

The five ERRORs in the census are all files that are *supposed* to fail — two
unterminated-bracket fixtures, two LSP diagnostic inputs, and
`tooling/vscode/test/grammar/basic.cx`, whose `invalid temporal literal '0o17'`
is an OCTAL integer and a live instance of #1347's hex/underscore family.

A count has **no lower bound**. Fix `basic.cx` and the total falls to 4, the
lane stays green, and the pin has silently loosened; a genuinely new error is
invisible until it is the sixth. The roster reds **both ways**:

* `UNEXPECTED` — a file errored and is not on the roster.
* `STALE` — a roster entry did **not** error, i.e. it was fixed or removed and
  the line must go.

The second is the half a count cannot express, and it is the one that matters
here, because one entry is a real defect somebody will fix. Same shape as the
#1350 golden MANIFEST (`99c25169d`): derived from a measurement, checked in,
compared by the gate.

## The census, re-measured at the landing base `3ef4d597e`

```
SWEEP-FILES=272  FORMATTED=173  DECLINED=94  UNSTABLE=0  ERROR=5
SWEEP-EXPECTED-ERRORS=5  SWEEP-UNEXPECTED-ERRORS=0  SWEEP-STALE-EXPECTED=0
```

**Not** the 271/93 of #1348's own census at `12abdac33`: #1317 added
`bench/flow/served.cx`, which declines. Re-measured rather than copied, because
a pinned number taken at a different sha is not a pin.

## Red-proved, all four paths, before the numbers were committed

Measured over a `--filter fixtures/errors` corpus so each run is three files:

| roster | result |
|---|---|
| both erroring files listed | `rc=0`, `UNEXPECTED=0 STALE=0` |
| one entry dropped | `rc=1`, `UNEXPECTED-ERROR fixtures/errors/nested_unclosed.cx` |
| a non-erroring file added | `rc=1`, `STALE-EXPECTED-ERROR fixtures/errors/empty_name.cx` |
| roster path missing | `rc=2`, dies |

The last row is deliberate. A missing or unreadable roster reads back as the
empty list, which would turn the gate into "every error is unexpected" or, with
the comparison the other way, into a lane that grades nothing — and an absence
is indistinguishable from a roster that legitimately lists nothing. So
`expected-roster` **dies** rather than returning empty.

## Scope

`DECLINED` stays a count, ratcheted at 94 and one-way by convention. `UNSTABLE`
reds at >0 with or without `--ratchet`, unchanged: §7 says `fmt_source` fails
closed rather than returning an unsettled candidate, so there is no number to
ratchet against. `--max-errors` is kept and still applies when no roster is
given, so a bare `--ratchet` invocation keeps working; the roster supersedes it.

`1348-d`'s memory column is **not** in this landing — see the correction on the
issue: #1119's own W1 guard rejected an RSS-shaped instrument under RP-5(a)(ii),
which my letter did not cite, and the question is re-drafted.
