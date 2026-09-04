# bench/flow — FIRST MEASUREMENT 2026-09-04 (#1265 W1 packet C, RULED: WF-14)

**Status: measurements, not rulings.** §9 of
`spec/03-approved/std-lib/flow.md` says floors are set from the first
measurement and ratcheted like `bench/repr`, and that the spec carries floors
rather than bare numbers, none of them written before a measurement exists.
This file is that measurement. The floors it sets live in
`bench/flow/run.sh`'s ratchet block; `bench/flow/README.md` is the contract.

## The instrument

| | |
|---|---|
| machine | Mac14,6 (darwin-arm64, 12 cores), `Darwin 25.6.0` |
| build | `make build-vcx-dev` (`v -cc cc -gc e -d cx_platform -d cx_db_sqlite -d cx_db_redis`), NOT `-prod` |
| binary | `vcx/target/cx`, sha256 `c84862a076a97a28ef11fb189f8da248631f67fffb6d52edfb721080b7e0ec56` |
| tree | `impl/1265-flow-w1` at `a4b9af461` plus packet C's working tree |
| store | `mem://` (`journal:attach` over `store:open`), one process, idle machine |
| clock | `[$time-monotonic-now]`, nanoseconds, inside the program under test |

Every row runs the real public verbs (`start`, `advance`, `status`) over real
`[?def … impure [effects] …]` command defs and real journal entries. There is
no test double and no private entry point: the numbers are what a caller gets.

## The rows (§9)

### Throughput

| Row | Transitions | Elapsed | Rate | Floor pinned |
|---|---|---|---|---|
| ONE stream, a 20-step run | 42 | 2.918 s | **14 tr/s** | ≥ 4 tr/s |
| 1 stream, a 4-step run | 10 | 68.1 ms | **146 tr/s** | ≥ 45 tr/s |
| 8 streams, 4-step runs | 80 | 599.9 ms | **133 tr/s** | ≥ 44 tr/s |
| 64 streams, 4-step runs | 640 | 5.160 s | **124 tr/s** | ≥ 41 tr/s |

**What the shape says.** Across streams the rate is all but flat — 146 → 133 →
124 tr/s from 1 to 64 independent runs, a 15% fall over 64× the work, which is
§4.11's per-stream-lock claim behaving as advertised at this scale. Within ONE
stream it is 10× WORSE per transition (14 tr/s), and that gap is the finding
below: a longer run costs more per transition because the record is re-read
from position 1 on every `advance`.

### Latency

| Row | Measured | Ceiling pinned |
|---|---|---|
| `start` → first effect (a one-step run: the effect and the terminal append are in it) | **44.2 ms** | ≤ 150 ms |
| `advance` at run length 10 | **27.6 ms** | ≤ 90 ms |
| `advance` at run length 1000 | **1446 ms** | ≤ 4500 ms |

The measured `advance` is a PARK — it finds the step already in flight, so it
appends nothing and performs nothing (§4.5) — which isolates the READ cost.

### `map` fan-out (max-parallel 10 unless noted)

| Items | Wall | Parent transitions | Parent entries | Parent bytes | per item |
|---|---|---|---|---|---|
| 4 (max-parallel 2) | 0.565 s | 16 | 7 | — | 2 tr |
| 10 | 1.076 s | 28 | 13 | — | 2 tr |
| 20 | 2.188 s | 48 | 23 | — | 2 tr |
| **40 (the lane's row)** | **7.88 s** | **88** | **43** | **36 745** | **2 tr / 918 B** |
| 100 (by hand) | 52.86 s | 208 | 103 | — | 2 tr |
| 200 (by hand) | 290.0 s | 408 | 203 | — | 2 tr |

The document is `fetch` → `map(per-line)` → `ship(pivot)`, so the parent's
transitions are `2N + 8` and its entries `N + 3` at every size — the per-item
cost is EXACTLY two transitions and one append, measured, at every N.

### Racing advancers

`vcx/tests/flow_umbrella_test.v`, 8 real `cx` processes over a `file://`
journal in a temp dir, a three-step run:

| Lane | Result |
|---|---|
| relay — 8 processes in turn, ONE `advance` each | run `:done`; **exactly 1 journaled effect per step**; 1 `:done` transition per step; the home chain verifies |
| concurrent — 8 processes at once | ≥ 1 advanced; every other refused with **CXER1143** (`journal.md` §3.3: one writer + N read-only readers on a local root) as a VALUE naming the live holder and the recovery; the run's integrity untouched |

Both lanes together: 5.45 s.

## Three findings, recorded rather than papered over

**1. `advance` is not flat in run length; the snapshot anchor is unused.**
27.6 ms at length 10 against 1446 ms at length 1000 — roughly linear, because
the record is the fold over `journal:since 1` on every call. §4.11 says a run
of a million transitions is "read from the last snapshot"; W1's reader does not
consult the journal's snapshot anchors at all. §9's "flat past the snapshot
interval" row and the 10⁶-transition row of §9/§10 need that reader; at today's
cost a 10⁶-transition fold is ~24 minutes, so the row was NOT measured — the
extrapolation is stated here instead of a fabricated number.

**2. The map's wall time grows faster than its item count, for the same
reason.** 0.57 s at 4 items to 290 s at 200 (≈ N^2.4 over that range: each of
the N advances that drive the fan-out re-folds the parent's growing stream).
Consequences, both taken honestly:

- §9's `map` of 10⁵ items with `max-parallel` 10³ is out of reach at W1 — the
  extrapolation from 200 items is ~10⁵ s (≈ 28 hours). NOT measured.
- §11's fixture row "map of 1 000 items with `max-parallel` 10" is likewise
  unreachable as a conformance case (the same extrapolation puts it at ~2–4
  hours, in a suite whose whole stdlib corpus runs in 100 s). The fixtures that
  DID land pin the same invariants at a size the corpus can carry:
  `flow-040-map-child-runs` asserts the parent's exact transition and entry
  counts for three items, and `flow-041-map-tolerance` runs four. The
  per-item cost is the quantity the spec's claim is about, and it is measured
  at 4, 10, 20, 40, 100 and 200 items above — identical at every size.

**3. What the parent stream carries per child is 2 transitions, not O(1) per
map.** §4.12 says three things that cannot all hold: "the parent appends ONE
`:fanned-out` transition (count, the child-id derivation, a cursor) and
thereafter only count transitions"; "each child's terminal transition is a
correlated act into the parent"; "the advancers pull the next item from the
parent's recorded cursor under its CAS" — and then "the parent stream carries
O(1) transitions per map". A recorded cursor pull is one transition per item
and a recorded completion is one more, so a set of N costs **2N + 2**
fixed-size transitions in **N + 1** appends (a claim and the preceding
completion ride one CAS — RULED 1265-PB-6). What IS O(1) per child is the
parent's cost per child: a count, never the child's own steps, results or
effects, which stay in the child's stream — so the parent grows with the SET,
never with the body's depth. **No approved text was edited.** The wave
implements the operational sentences literally, measures the cost, and reports
the sentence for a ruling; `bench/flow`'s two COUNT rows and `flow-040` pin
what it actually is, so whichever way the ruling goes, the numbers are on the
record first.

## The competitive table §9 asks for

§9 says the comparison against the field's published limits is "recorded in the
ledger as a measured table when the lane exists, never as a sentence". The lane
now exists; the comparison is NOT recorded here, because at W1 these numbers
measure the CX evaluator's per-advance read cost (findings 1 and 2) rather than
the design's ceiling, and a comparison drawn now would be a comparison of an
interpreter against production engines. It belongs at the wave that lands the
snapshot-anchored reader, with the same instrument re-run.
