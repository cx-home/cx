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

## RULED: 1348-e — the memory column is dropped; `1348-d`'s instrument half is superseded

**Fable, 2026-09-09 10:14 ET**, on worker A's correction of its own letter.
`1348-d` had been ruled 2(c) — a report-only RSS column in the timed sweep,
with #1119 owning the reduction — on a recommendation that did not cite the
owning campaign's own finding.

**`bench/repr/repr.v:5-18`**, the #1119 W1 CXDM live-memory ratchet: *"Ratios,
never absolute times or absolute bytes: the guard has to hold on a loaded
machine and on other hardware (RP-5(a)(ii); (c) — an RSS-shaped bound — was
rejected for exactly that)."* It measures a live-set ratio inside the process,
`(live_after_parse - live_before_parse) / input_bytes`, from a forced collect.

So a report-only RSS column would have put the one instrument #1119 declined
into this sweep and named #1119 as its consumer. The series that was the whole
argument for the column would not have been a series.

**Ruled:** no memory column in `fmt-sweep-timed`. **DELETES** the column and
the `time -l` / `-v` platform split it would have needed. The measurement is
recorded on #1119 as a data point rather than a guard — `cx fmt` 61.69 s /
7,285,342,208 B and `cx lint` 22.07 s / 3,855,007,744 B over a 10,658,970-byte
input, output byte-identical across `fb3a3b686` and the tip — and #1119 chooses
its own instrument.

**The `1348-d` paragraph above is superseded on its INSTRUMENT half only.** Its
ownership half stands: the multiplier is the in-memory representation's, not
the formatter's, and #1119 owns the reduction. `cx lint`, which only parses, is
already 3.86 GB — 53% of `cx fmt`'s peak before a byte is emitted.

**#1348's remaining work was `1348-c` alone**, landed at `f34b55b3d` and green
on the gate at `2026-09-09T16:00:21Z`.
