# Owner decision 2026-10-15: [par] readers of one SQLite file (SQLPAR-1)

**Status: RULED (owner, via the integrator on STREAMS/state/claims.txt, 2026-10-15 01:18:14Z; recorded by core from that RULING line, verbatim below the heading).** It answers core's DECISION-ASK of 2026-10-15 01:00:29Z on cx-home/cx-private#1923 (sql-roundtrips per-core ledger: the k=2 cx workers serialized inside SQLite on the shared file's per-process shm-node mutex and fcntl locks, ~33 % of each worker waiting; Python's pool runs separate processes). Options asked: (a) the workload holds one read transaction per worker share in both runtimes; (b) read-only / immutable opens for [par] readers; (c) keep it. Issues: cx-home/cx-private#1923, #1936.

## SQLPAR-1 — (a): the #1923 workload holds one read transaction per worker share in both runtimes; and a v0.18 issue so cx [par] readers of one SQLite file do not serialize by default, never by immutable opens

> RULING owner 2026-10-15T01:18:14Z (via integrator, SQLPAR-1 = (a) + a new v0.18 issue): the #1923 sql-roundtrips workload holds one read transaction per worker share in BOTH runtimes (the bar row); core files a v0.18 issue so cx [par] readers on one SQLite file do not serialize by default (e.g. a per-worker read transaction opened by cx automatically; never immutable opens), and works it in v0.18.

Where it lands: the issue is cx-home/cx-private#1936. cx-platform-db's sqlite engine opens one implicit read transaction per `[par]` worker share on a WAL file (db_access.md §9), ended before any other statement on the handle, at `sql-close` and at the item's end; cx-core-code's `par_worker.v` gives the engine the worker token and the item-end hook. Never `immutable=1`, never `mode=ro`.
