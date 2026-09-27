# Owner decisions 2026-09-27 (afternoon) — Letter 55: the code phase of the sync module, SYNC-1…SYNC-9

**Status: RULED (owner, 2026-09-27 ~14:5xZ, in session, on the letter posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 14:1xZ; #1434, RULED: 1434-a, 1434-b, 1434-c, ODB-1).**

## The owner's word, verbatim

"recommendations accepted" — after asking what the module is and whether its per-record work
needs V; the measurement that answered: a polling-diff pass (match, rebuild, native content hash)
over 50 000 records takes 1.46 s on the release binary, 0.28 s of it the parse, about 24 µs per
record; the kit that feeds the pages is itself pure CX.

## SYNC-1 — the source is pure CX in the connector package, with a bench bound (L55.1 = (a))

`stdlib/sync.cx` beside the kit in the connector package; the modules.cxd row's `code=` trued to
`none`; the placement paragraph of sync.md trued in the same branch; a corpus bench case bounds
the 50 000-record diff so the perf ratchet catches a regression; a V half is promoted only when a
measured source exceeds the bound. Rejected: (b) a V half now; (c) a repository of its own.

## SYNC-2 — the engine is the spec's pure defs plus one `run` over the kit (L55.2 = (a))

`run` reads pages through the kit's `walk`/`run`, never from inside it; `advance` stays the one
pure function every refusal reaches; `diff-page` reads each element child of the page it is
handed as one record. Rejected: a capture inside the kit's walk; each `ingest` writing its loop.

## SYNC-3 — `[capture]` is one core element in feature.cxs (L55.3 = (a))

On `[gateway]` and `[verb]`, the same for every kind, with §2.1's closed attribute set; the
conditional requirements stay `sync:validate`'s; orders-db's statement gains a `:since` bind.
Rejected: a per-kind fragment row; capture in code or deployment data.

## SYNC-4 — the watermark is a per-source journal stream committed by compare-and-swap (L55.4 = (a))

Each commit one `journal:append` with `expect-pos`, the lease and the history in one mechanism;
the index a store document the watermark names; deltas land on the adapter stream the deployment
binds; one sentence in §2.4. Rejected: a store document plus alias; host memory with a checkpoint.

## SYNC-5 — the dedup key is `(source, identity, address)` (L55.5 = (a))

The address the native content hash over canonical bytes, computed purely, asserted equal to the
store's. Rejected: the address from the store at diff time; a version stamp or field subset.

## SYNC-6 — the host arms the cadence from a `[sync]` row (L55.6 = (a))

A `[sync source= every=|cron=]` child on the host's `[connector]` row, armed at boot through
`sched`; one sentence each in the distribution spec §6.3.1 and xap.md §8. Rejected: the package's
`ingest` arming the timer; a flow schedule row.

## SYNC-7 — log-based capture stays out of this phase (L55.7 = (a))

The pure half ships; `open` refuses `mode=log` for every backend; the `db_access` seam is filed as
its own issue with a named consumer. Rejected: a postgres logical-slot read now; dropping `log`.

## SYNC-8 — orders-db-005/006/008 flip to enforced in wave 1 (L55.8 = (a))

The package's feature gains the `[capture]` row and the three cases read it from there.
Rejected: waiting for `run`; keeping the inline capture.

## SYNC-9 — two waves (L55.9 = (a))

Wave 1: the pure half, `[capture]`, the audit registry row, the bench case, the three flips.
Wave 2: `open`/`close`/`run`/`status`/`pause`/`resume`/`reseed`, the CAS watermark, the host's
`[sync]` row, the live test, the orders-db scenario that closes #1467 and #1434. A spec branch
precedes wave 1. Rejected: one wave; three waves.
