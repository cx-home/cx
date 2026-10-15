# Owner decision 2026-10-14: the store's commit durability (WDUR-1, relayed as W1-DUR; cx-private#784 row W1)

**Status: RULED (owner, via the integrator on STREAMS/state/claims.txt, 2026-10-14T23:33:14Z; recorded by plat from that RULING line, verbatim below).** Issue: cx-home/cx-private#784, row W1 (the measured table: https://github.com/cx-home/cx-private/issues/784#issuecomment-6180754241; the flush-latency row: https://github.com/cx-home/cx-private/issues/784#issuecomment-6180921882). The ask was plat's DECISION-ASK of 23:28:36Z: RocksDB 11.8.1's `sync=true` on macOS calls `F_FULLFSYNC` (a drive-cache flush), while the cx store and SQLite's `synchronous=FULL` called plain `fsync`.

## WDUR-1 — (relayed as W1-DUR) the cx store is power-loss durable by default on every OS; durability is a per-commit level (full default; barrier and none named opt-ins); the W1 bar is native RocksDB sync=true

> RULING owner 2026-10-14T23:33:14Z (via integrator, W1-DUR = (b) + refinements; plat's DECISION-ASK 23:28:36Z, #784 W1 macOS durability): the cx store is power-loss durable BY DEFAULT on every OS — macOS commits use F_FULLFSYNC (Linux fdatasync/fsync + the dir fsync as today); group commit amortizes one flush per batch. Durability is a per-commit level like RocksDB WriteOptions.sync: full (DEFAULT), barrier (F_BARRIERFSYNC: ordered, crash-consistent, may lose the last commits on power loss) and none as NAMED opt-ins, never the default. The W1 bar = native RocksDB 11.8.1 sync=true (F_FULLFSYNC); the W=1 row is flush-bound for every store, so its bar reads equal-to-native-RocksDB; a plain-fsync DIAGNOSTIC row (RocksDB interposed F_FULLFSYNC->fsync vs cx none/barrier as fits) stays to track the per-append CPU gap (11-38x today). First row after the ruling: the measured F_FULLFSYNC vs fsync latency on dev2's SSD. Ledger id W1-DUR (plat's next ledger page). v0.18; nothing deferred.

What it binds (cx-platform-store, store.md §10.1 "Commit durability"):
- **The default is full.** On macOS a commit's flush is `F_FULLFSYNC`, and on Linux it is `fsync` plus the directory fsync as before. Acknowledged commits survive power loss.
- **Levels are per commit**, set by the open's `durability` option (the store's default) or by a commit's own `durability` key (put-doc's opts, a journal append's attribution map).
  - `barrier` (macOS `F_BARRIERFSYNC`) and `none` (no device flush) are named opt-ins, never the default.
  - A level that names nothing refuses (`CXER1100`). A misspelt level never silently weakens a commit.
- **Group commit** flushes once per batch, at the strongest level its commits asked for.
- **The W1 bar** (#784 design §7) is native RocksDB 11.8.1 `sync=true`.
  - The W=1 row is flush-bound for every store, so it reads equal to native RocksDB (about 4.2 ms per `F_FULLFSYNC` on dev2's SSD).
  - A plain-fsync DIAGNOSTIC row stays to track the per-append CPU gap: RocksDB with `F_FULLFSYNC` interposed to `fsync`, against cx at `none`/`barrier`.
- v0.18 work, nothing deferred.

**The id.** The ruling names it W1-DUR, which is not id-shaped (a ledger id is 2–6 capitals, a dash, digits: `W1-DUR` matches neither the index's declared-id pattern nor the commit-subject rule, so `make ledger-index` declared nothing for it). It is declared here as **WDUR-1**, the way KUBE-1 records K8S-1 and WBAR-1 records BAR1924-1. Commits cite `RULED: WDUR-1`; W1-DUR in claims.txt and in the cx-platform-store commit 93b900e means the same decision.
