# `$redis-*` — external Redis engine (catalog entry)

```cx
[module-meta name=redis tier=C status=current
  [standard ref='RESP' title='Redis serialization protocol (client side)']]
```

**Status:** Current (owner G3 2026-07-11, #294 decision (a))

Catalog entry for the `redis_stdlib_builtin` dispatch family. The normative
reference is [`core/db_access.md`](../core/db_access.md) — the `$redis-open` /
`$redis-cmd` / `$redis-close` builtins, the `-d cx_db_redis` build gate, the
capability gate at open, reply mapping, and error codes are all specified
there. This file exists so the stdlib catalog (and its gate) carries one
entry per dispatched family; it adds no normative surface of its own.
