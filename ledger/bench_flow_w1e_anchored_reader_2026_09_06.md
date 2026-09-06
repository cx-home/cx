# bench/flow — W1-E RE-MEASUREMENT 2026-09-06: the snapshot-anchored reader

**Status: measurements plus one defect record, not rulings.** The authority
for the work is **RULED: 1265-PC-2** (`ledger/rulings_2026_09_04_flow_w1_map_scale_1265.md`)
— "the snapshot-anchored reader is a NAMED #1265 wave item (W1-E, before W3)
… its exit gate is exactly §9's flat-latency row (advance at 10 / 10³ / 10⁶)
and §11's 1 000-item map." This file is that exit, measured, and it re-pins
the floors `bench/flow/run.sh` carries. The first measurement it is read
against is `ledger/bench_flow_first_measurement_2026_09_04.md`.

## The instrument

| | |
|---|---|
| machine | Mac14,6 (darwin-arm64, 12 cores), `Darwin 25.6.0` |
| build | `make build-vcx-dev` (`v -cc cc -gc e -d cx_platform -d cx_db_sqlite -d cx_db_redis`), NOT `-prod` |
| binary | `vcx/target/cx`, this worktree, `impl/1265-flow-w1e` |
| store | `mem://` (`journal:attach` over `store:open`), one process, idle machine |
| clock | `[$time-monotonic-now]`, nanoseconds, inside the program under test |

Everything below runs the real public verbs over real journal entries. No
test double, no private entry point.

## What the wave shipped

`advance` and `status` no longer fold a run from position 1. `f--read-state`
looks for the newest `[flow-snapshot run= [snapshot …]]` anchor in the home
stream — a NARROW window (`interval + 8` positions back from the head) first,
a WIDE one (`8 × interval`) second, the genesis fold when neither holds one —
and reads `journal:fold-from` over it plus the tail, under a pinned fold
identity. `advance` takes the next anchor when the last one is a whole
`opts.snapshot-every` behind, on a commit and on a park; `status` never
writes. Map children inherit the policy. The interval a caller who names none
gets was 64 through the measurements above and is `max(16, ceil(sqrt(head)))`
after RULED 1265-PE-1 below; `0` turns anchoring off either way.

## The headline: `advance` is FLAT in run length

`bench/flow/latency.cx` seeds a run of N transitions in its home stream and
measures a PARKED advance — the read cost with no act in it. Two numbers per
length: the COLD read (an un-anchored history, folded from genesis — this is
what W1 did on *every* advance) and the steady-state anchored read after it.

| run length | W1 (09-04) | W1-E cold | **W1-E anchored** |
|---|---|---|---|
| 10 | 27.6 ms | 8.5 ms | **24.0 ms** |
| 1 000 | 1 446 ms | 1 304.9 ms | **10.4 ms** |
| 10 000 | not measured | 16 757.2 ms | **10.8 ms** |

**1 000 → 10 000 is 1.04×.** That is the flat-latency row PC-2 named as the
exit: 139× faster at 1 000 transitions and 1 552× at 10 000, and the curve is
a line, not a slope. At length 10 the run is shorter than the default
interval, so no anchor is ever taken and both columns are the same genesis
fold (the 8.5 / 24.0 spread there is run-to-run noise on a 10-entry stream,
not a cost of anchoring).

`start` → first effect is unchanged at 50.1 ms (44.2 ms at W1) — it reads
nothing.

## `map`: §11's 1 000-item row is REACHED

`bench/flow/map.cx`, `max-parallel=10`, one child run per item in its own
stream. A/B on the same binary, `snapshot-every: 0` against the default 64:

| items | parent entries | anchoring OFF | anchoring ON (64) |
|---|---|---|---|
| 40 | 43 | 3.38 s | 3.47 s |
| 200 | 203 | 81.4 s | **35.3 s** |
| 1 000 | 1 003 | not run (see below) | **574 s** |

At 40 items the parent stream is 43 entries — shorter than the interval, so
nothing anchors and the two columns are the same run. At 200 the anchored
reader is **2.3×** faster. At 1 000 the anchored run finishes in 9.6 minutes;
the OFF column was not run because W1's own fit (≈ N^2.4, first-measurement
ledger) and the 40 → 200 OFF pair measured here (exponent 1.97) both put it
between half an hour and an hour, which is a known quadratic ground out for
no new information — PC-2(b), rejected for exactly that reason.

**The §4.12 COUNT rows hold at every size**: 2 parent transitions per item
and 920 / 875 / 868 bytes per item at 40 / 200 / 1 000. `run.sh` now checks
them at every size the lane runs, so "constant per item across N" is an
assertion over a set rather than one point. The anchors are counted and
reported on their own row (8 anchors / 63 023 B at 200; 20 / 669 759 B at
1 000) and never folded into bytes-per-item: an anchor is a fixed overhead,
not a per-child cost, and folding it in would make it look like one.

The 1 000-item row is opt-in behind `CX_FLOW_BENCH_LONG=1`, as latency's 10⁵
row already is. Ten minutes is too long for the lane a developer runs; opt-in
is not unmeasured — the number is here and its ceiling is in the ratchet.

## Throughput (§9 rows 1–2)

| row | W1 (09-04) | W1-E (09-06) | floor now |
|---|---|---|---|
| ONE stream, a 20-step run (42 transitions) | 14 tr/s | **24 tr/s** | ≥ 8 |
| 1 stream × 4-step runs | 146 tr/s | 160 tr/s | ≥ 53 |
| 8 streams × 4-step runs | 133 tr/s | 176 tr/s | ≥ 58 |
| 64 streams × 4-step runs | 124 tr/s | 169 tr/s | ≥ 56 |

The ONE-stream row is the one the reader owns — a single run getting longer
as it is advanced — and it is the only one that moved for a reason this wave
can claim (14 → 24 tr/s). The N-stream rows are 4-step runs that never reach
the interval; their 10–30% gain is machine and build variance, and the floors
are re-pinned at the same 3× headroom the lane has always used.

## THE INTERVAL: what 64 actually costs

The default was justified in `stdlib/flow.cx` by a MODEL with borrowed
constants ("optimum near 32 at a thousand transitions and near 100 at ten
thousand … 64 is inside 15% of the optimum"). It had never been measured.
It is measured now, both halves.

**Read half** — a parked advance at run length 10 000, one anchor already in
the window, so only the tail is folded:

| interval | 8 | 16 | 32 | 64 | 128 | 256 |
|---|---|---|---|---|---|---|
| advance | 6.8 ms | 7.5 ms | 9.3 ms | 11.6 ms | 16.7 ms | 26.6 ms |

**Both halves** — a 200-item `map`, parent stream 403 entries, so every anchor
pays a real `1..at-seq` prefix walk:

| interval | off | 4 | 8 | 16 | 32 | 64 | 128 | 256 |
|---|---|---|---|---|---|---|---|---|
| wall | 81.4 s | 27.1 s | **18.0 s** | 18.7 s | 23.7 s | 35.3 s | 51.0 s | 82.7 s |
| anchors | 0 | 70 | 33 | 18 | 11 | 6 | 6 | 0 |

The bowl bottoms between 8 and 16. It is NOT changed by this wave — moving the
default is its own ruling, and this table is that ruling's input.

**That ruling is `1265-PE-1`, and the next section is its gate, measured.**

> **A correction this file owes its own reader.** "A 200-item `map` whose
> parent stream is 403 entries" is wrong: 403 is the TRANSITION count; the
> stream is **203 entries**. The distinction did not matter while the
> interval was a constant. It matters now, because the interval the rule
> computes is a function of the stream's HEAD — a position, not a transition
> count — so "√403 ≈ 20" was comparing an interval against the wrong
> quantity. √221 ≈ 15. Every head below is an entry position.

## THE INTERVAL, RE-SWEPT: RULED 1265-PE-1's GATE

`ledger/rulings_2026_09_06_flow_snapshot_interval_1265.md` rules the default
to `max(16, ceil(sqrt(head)))`, recomputed on each advance, and makes the
change conditional on a gate: the both-halves sweep re-run at TWO parent
lengths with the adaptive default within **1.3×** of the swept best at each.
Both tables are below, on the binary that carries the change, one point per
process, serially on an idle machine. `THE RULE` is the same run with no
`snapshot-every` key at all.

**200 items — the 09-04 row, re-swept. Head reaches 203-221.**

| interval | off | 4 | 8 | **16** | 32 | 64 | 128 | 256 | **THE RULE** |
|---|---|---|---|---|---|---|---|---|---|
| wall | 77.5 s | 27.7 | 19.0 | **18.4** | 23.4 | 34.9 | 51.1 | 80.8 | **17.9** |
| anchors | 0 | 70 | 33 | 18 | 11 | 8 | 6 | 0 | 18 |
| entries | 203 | 273 | 236 | 221 | 214 | 211 | 209 | 203 | 221 |

Swept best 18.4 s at interval 16; the rule 17.9 s → **0.97×. PASS.** The
old default of 64 is 34.9 s → 1.95× the best.

**500 items — the second length. Head reaches 503-537 (1 003 transitions).**

| interval | 8 | **16** | 24 | 32 | 48 | 64 | 128 | **THE RULE** |
|---|---|---|---|---|---|---|---|---|
| wall | 112.0 s | **84.9** | 86.3 | 92.4 | 106.5 | 124.6 | 195.2 | **84.9** |
| anchors | 76 | 38 | 26 | 21 | 15 | 12 | 8 | 34 |
| entries | 579 | 541 | 529 | 524 | 518 | 515 | 511 | 537 |

Swept best 84.85 s at interval 16; the rule 84.94 s → **1.001×. PASS.**
64 is 124.6 s → 1.47× the best. Anchoring-off was not run at this length:
the 09-04 fit and the 40 → 200 OFF pair here both put it near an hour, which
is a known quadratic ground out for no new information (PC-2(b)).

**The gate passes at both lengths. What it does NOT establish.** At neither
length does the sweep separate the rule from the ruling's own fallback (b), a
fixed 16. At 200 the rule *is* 16 — √221 is under the floor, and the two runs
produce the identical placement (221 entries, 18 anchors). At 500 the rule
ranges 16 → 24 and lands 0.1 % from fixed-16, which is inside run-to-run
noise. So the measured case for (a) over (c) is strong and the measured case
for (a) over (b) is **absent at these lengths**; what argues it is the shape,
which this ledger states as a shape and not a number: the write half is
O(length / interval), so a fixed 16 at 10⁶ positions walks a 10⁶ prefix every
16 advances while the rule walks it every 1 000. Measuring that needs a 10⁶
both-halves row, which is hours; it is named here as unmeasured rather than
asserted.

**A note on the 500 × 128 point.** It took 195 s and the dev build emitted a
long `[vgc tag=…]` diagnostic stream while its RSS grew past 1.6 GB. That is
the widest window this lane has ever asked for (`8 × 128` spans the whole
stream) on a `-gc e` dev binary; it is not on the rule's path (the rule never
reaches 128 at this length) and it reproduces on a PINNED interval, so it is
not caused by this change. Recorded, not chased.

The `stdlib/flow.cx` comment now carries these two tables and says, in as many
words, which of its claims is measured and which is a shape.

### The whole §9 lane, re-run on the rule, and what it re-pinned

`bench/flow/run.sh` on the same binary: **GREEN, every row.**

| row | W1-E (64) | PE-1 (rule) | pinned now |
|---|---|---|---|
| transitions/s, ONE stream | 24/s | 27/s | ≥ 8/s (unchanged) |
| transitions/s, 1 / 8 / 64 streams | 160 / 176 / 169 | 140 / 167 / 160 | unchanged |
| `start` → first effect | 50.1 ms | 10.4 ms | ≤ 150 ms (unchanged) |
| advance latency, length 10 | 24.0 ms | 8.7 ms | ≤ 90 ms (unchanged) |
| advance latency, length 10³ | 10.4 ms | 9.2 ms | **≤ 30 ms** (was 40) |
| advance latency, length 10⁴ | 10.8 ms | **14.1 ms** | ≤ 45 ms (unchanged) |
| advance FLATNESS, 10⁴/10³ | 1.04× | **1.53×** | ≤ 4× (unchanged) |
| map of 40 items | 3.43 s | 2.44 s | **≤ 8 s** (was 12) |
| map of 200 items | 36.0 s | 19.3 s | **≤ 60 s** (was 110) |
| map parent transitions / bytes per item | 2 / 920 | 2 / 920 | unchanged (COUNT) |

**Two rows got WORSE and are reported as worse.** The 10⁴ parked advance rose
10.8 → 14.1 ms and the flatness ratio 1.04 → 1.53×, both for the same reason
and both expected: at head 10 000 the rule reads at interval 100 where the
constant read at 64, and this row measures the READ HALF ALONE. A fixed
interval looks flat here only because the half it is bad at — the
O(length/interval) prefix walk — has never had a row in this lane; the map
rows are where the sum shows, and they moved the other way by 1.4–1.9×. The
flatness ceiling stays 4× and is now a bound on the SUM being sub-linear, not
a claim that the read is flat. `bench/flow/run.sh`'s header says this in the
tree.

**What was NOT re-pinned, and why.** The throughput rows and `start` are left
alone: three of four moved DOWN and `start` moved 5× (50.1 → 10.4 ms) on runs
too short to reach any interval — machine variance, and a floor tightened onto
variance buys a false red. The opt-in 1 000-item map row was not re-run, so its
ceiling still describes the 64 measurement; an unmeasured row is not tightened.

**The map of 40 now anchors.** 43 parent entries with the floor of 16 gives 7
anchors where the constant 64 gave none, and the row still got 1.4× faster —
the floor is not free but it pays for itself even at 43 positions.

## The defect this wave landed on top of

The W1-E work-in-progress commit `53733640b` was UNVERIFIED by its author.
Two defects were found and fixed here before anything was measured; both are
recorded because both are the kind that a green-looking tree hides.

1. **`[?def advance]` was one `]` short and `[?def status]` one `]` long.**
   Net zero across the file, so `stdlib/flow.cx` PARSED — and `[?def status]`
   became a child of `advance`'s body instead of a module def. `status` was
   silently not registered: `$flow:status` and `cx flow status` both answered
   `no callable "flow:status"`, while `cx flow run` looked perfectly healthy.
   A balanced file is not a correct one; the shape of this bug is that the
   two errors cancel.

2. **The genesis fold did not stamp `at=`, so every anchor taken from it was
   double-folded.** `journal:snapshot` seeds the new anchor with the state the
   read already produced and then walks `1..at-seq` itself (journal.md §3.7 —
   a snapshot signs "state at at-seq", which needs the prefix). The reducer's
   seq guard is what makes that walk a no-op, and the guard reads `at=` off
   the state. `f--state-full` folded the flattened TRANSITIONS, which never
   sets `at`, so the guard was open: every transition was applied a second
   time onto an already-folded record. The step rows survive that (last write
   wins) but the derived `ord=` does not, so an anchored read answered a
   record no genesis fold ever produces. The fix folds the ENTRIES with
   `f--fold-step` — the same fold, since the reducer's body is the transition
   fold, but the entry reduction is what stamps `at=`.

`conformance/stdlib/flow.cxd` gained four enforced cases for this, and each of
the first three FAILS on the pre-fix module and passes after:

| case | what it pins | pre-fix |
|---|---|---|
| `flow-045-anchored-read-equals-the-genesis-fold` | the anchored read ≡ anchoring-off ≡ the default's genesis fallback, over one document; anchors invisible to the fold (17 entries fold to what 9 do) | RED — the anchored record's hash differs |
| `flow-046-anchored-read-wide-window-aggregate-stream` | three runs sharing `order:o-1`; A's anchor at 15, narrow window from 27 (misses), wide from 7 (finds); the record still equals the genesis fold | RED — the wide-window record differs |
| `flow-047-anchor-on-park-and-status-never-writes` | `status` appends nothing; a parked/terminal `advance` appends exactly ONE entry (the anchor) and the next appends none; `snapshot-every: 0` appends nothing | RED — every read differs from the record |
| `flow-048-map-children-inherit-the-anchoring-policy` | `snapshot-every: 1` puts anchors in the parent AND both child streams; `0` in neither | green either way (it pins the inheritance, which the WIP had right) |
| `flow-049-the-default-interval-is-the-square-root-rule` (added by PE-1) | the DEFAULT interval, bracketed on both branches: head 15 → no anchor and 16 → anchor (the floor), head 297 → no anchor and 298 → anchor (the rule yields 18 there, gap 17 then 18) | n/a — the rule it pins did not exist pre-fix; a fixed 64 anchors at neither of the square-root rows and a fixed 16 anchors at both |

All four also exercise `$flow:status`, so any of them would have caught
defect 1 outright.

## What is NOT done here

- **§9 / §11's "W1-E exit" markers in `flow.md` are NOT flipped.** They are
  spec prose, this is an implementation phase, and the flip is a spec edit
  that wants its own pass. The rows they mark are measured above; the markers
  are now stale-in-the-caller's-favour, not wrong in a way that overstates.
- The 10⁵ latency row and the 10⁶ row §9 mentions are still opt-in /
  unmeasured; the 10 000 row is what this wave pins.
- **The 10⁶ both-halves row that would separate the rule from a fixed 16 is
  NOT measured** — see the gate section. It is hours of wall clock.
- **No spec edit.** `flow.md` §4.11 and RULED 1265-PC-2 name `snapshot-every`
  and no interval, and a grep for `snapshot-every` across `spec/03-approved/`
  finds one prose mention and no number — which is the whole basis on which
  PE-1 is rulable. Nothing in `spec/` needed to change and nothing did.
