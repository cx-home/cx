# `sqlite:` module — RETIRED (tombstone)

**Status:** Retired (owner decision (a) on #294, 2026-07-11)
**Superseded by:** [`core/db_access.md`](../core/db_access.md)

This file described a module-activated, Arrow-stream-returning sqlite design
(`[?lib 'sqlite']`, `sqlite:open/select/…`, typed columns via chunked Arrow
C-Data, first-class prepared statements, a dedicated `CXER4200..4209` error
band). **None of it shipped.** The database-access surface that DID ship —
engine-neutral `$sql-open/exec/query/close` builtins with scheme-dispatched
sqlite/postgres/mysql engines, plus the `$redis-*` family — is normatively
specified in `core/db_access.md`, whose §11 records the full design delta and
the owner decision that retired this document.

Salvageable ideas recorded there for future spec-first work: typed results as
an Arrow C-Data handoff (the `libcx_arrow` bridge already exists), prepared
statements, per-function purity classes, a dedicated error band.

Do not cite this file as describing shipped behavior.
