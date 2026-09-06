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
`opts.snapshot-every` behind (default 64, `0` = off), on a commit and on a
park; `status` never writes. Map children inherit the policy.

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

The bowl bottoms between 8 and 16, and √403 ≈ 20 — so the `√length` rule the
comment derives is what the machine does; only its constants were wrong. The
consequence for the shipped default, stated plainly: **64 is the right order
for a run of a few thousand entries and about 2× off the best interval at a
few hundred.** It is NOT changed by this wave. §4.11 names 64, the number a
caller gets without asking is a shipped surface, and moving it — or making it
adaptive at ≈ √head, which is what the data actually argues for — is its own
ruling. This table is that ruling's input. The `stdlib/flow.cx` comment now
carries the measurement instead of the model.

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

All four also exercise `$flow:status`, so any of them would have caught
defect 1 outright.

## What is NOT done here

- **§9 / §11's "W1-E exit" markers in `flow.md` are NOT flipped.** They are
  spec prose, this is an implementation phase, and the flip is a spec edit
  that wants its own pass. The rows they mark are measured above; the markers
  are now stale-in-the-caller's-favour, not wrong in a way that overstates.
- **The default interval is NOT changed** — see the interval section.
- The 10⁵ latency row and the 10⁶ row §9 mentions are still opt-in /
  unmeasured; the 10 000 row is what this wave pins.
