# Rulings 2026-09-04 — #1265 W1 packet C: the map's parent cost, the scale rows, `max-parallel=` (PC)

**Status: PC-1 … PC-3 RULED (a) 2026-09-04 under the owner's standing
letter-acceptance rule and the 2026-09-04 directive. Recorded before the
spec sentences they authorize (packet D applies them with `RULED:
1265-PC-1`).** Ruling ids `1265-PC-1 … 1265-PC-3`.

**Inputs read.** `flow.md` §4.11, §4.12, §9, §11; the packet-C landing
(6c69681f2): `map` executes per §4.12's operational sentences — one
`:fanned-out` transition, then a cursor claim per item and a count update per
child terminal, each ONE CAS append on the parent (PB-6), so the parent
stream carries `2N + 2` fixed-size transitions in `N + 1` appends for N
items, constant per item (measured identical at 4, 10, 20, 40, 100 and 200
items: 2 transitions / 918 bytes per item); `fold-record` reads from
position 1, so `advance` is linear in run length (27.6 ms at 10, 1 446 ms
at 1 000 transitions) and a map is ≈N^2.4 wall time (7.9 s at 40 items);
`ledger/bench_flow_first_measurement_2026_09_04.md`.

## PC-1 — "O(1) transitions per map" — RULED (a)

- **(a) RULED — the wording is a defect; the mechanism is right.** §4.12's
  own sentences ("the advancers pull the next item from the parent's
  recorded cursor under its CAS", "thereafter only count transitions", "each
  child's terminal transition is a correlated act into the parent") require
  a parent append per claim and per completion. The claim that matters and
  holds: **the parent's cost per child is O(1) — a fixed-size count, never
  the child's steps, results or effects**; children shard across their own
  streams and commit under their own locks. §4.12, §9's row and §11's row
  are re-worded to "O(1) per child" with the measured constant recorded.
  **DELETES:** the unfulfillable "O(1) per map" phrase and §11's "parent
  bytes O(1)" assertion (replaced by "parent transitions and bytes per item
  constant across N — asserted"). **KEEPS:** every operational sentence and
  the shipped mechanism.
- **(b) journal no per-item parent transitions; derive counts by reading
  child streams; leave claims unrecorded.** Rejected: deletes the recorded
  cursor (two advancers would claim the same item), makes every `advance`
  read N child streams, and turns the parent's record into a derived view.
- **(c) leave the text as debt.** Rejected: §11 asks for a fixture that
  cannot be written.

## PC-2 — the 1 000-item map fixture and the 10⁵ / 10⁶ bench rows — RULED (a)

- **(a) RULED — the snapshot-anchored reader is a NAMED #1265 wave item
  (W1-E, before W3): `fold-record` reads from the last journal snapshot
  (§4.11: "a run of a million transitions is read from the last snapshot"),
  snapshots taken at an interval by `advance`, the fold identity pinned; its
  exit gate is exactly §9's flat-latency row (advance at 10 / 10³ / 10⁶) and
  §11's 1 000-item map.** Until it lands, §11's map row is fixtured at the
  sizes where the per-item constant is proven and the ledger names the
  reader as the reason the large rows are unreached. **DELETES:** nothing;
  §9/§11 gain the "W1-E exit" marker on those rows.
- **(b) grind the 1 000-item measurement by hand now.** Rejected: hours of
  wall clock proving a known quadratic; the number would be obsolete the
  day the reader lands.
- **(c) shrink §11's row by spec edit.** Rejected: hides the defect.

## PC-3 — `max-parallel=` in the W1 profile — RULED (a)

- **(a) RULED — enforced from the record now, fixtured from a seeded
  in-flight record (`flow-042`); W3's offered steps make it bind live.**
  In W1 a `:runner` child terminates inside its own start, so in-flight is
  0 unless a child parks. **KEEPS:** the bound and its fixture.
- **(b) hold the bound until W3.** Rejected: it is enforced today and cheap.

## Edit map (packet D, `RULED: 1265-PC-1`)

| Where | Edit |
|---|---|
| `flow.md` §4.12 last paragraph | "O(1) per map" → the parent's cost per child is O(1) (a count), children shard; the measured constant |
| §9 rows `map` and `advance latency` | "W1-E exit" marker; the flat-latency row names the snapshot reader |
| §11 map row | "parent transitions and bytes per item constant across N, asserted; the 1 000-item run is W1-E's exit" |
| #1265 body | W1-E named item |
