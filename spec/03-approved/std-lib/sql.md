# `$sql-*` — external SQL engines (catalog entry)

```cx
[module-meta name=sql tier=C status=current
  [standard ref='SQL' title='engine-specific dialects (sqlite/postgres/mysql)']]
```

**Status:** Current (owner G3 2026-07-11, #294 decision (a))

Catalog entry for the `sql_stdlib_builtin` dispatch family. The normative
reference is [`core/db_access.md`](../core/db_access.md) — the `$sql-open` /
`$sql-exec` / `$sql-query` / `$sql-close` builtins, URL-scheme engine dispatch
(`sqlite:` / `postgres:` / `mysql:`), the `-d cx_db_*` build gates, the
capability gate at open, result shape, and error codes are all specified
there. This file exists so the stdlib catalog (and its gate) carries one
entry per dispatched family; it adds no normative surface of its own.
