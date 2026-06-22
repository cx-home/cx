# `sqlite:` module — embedded SQL database

**Status:** Current

Normative reference for the `sqlite:` external-system module. Wraps `libsqlite3` and exposes SQL operations as CX functions.

---

## §1. Module metadata

| Field | Value |
|---|---|
| `ns_prefix` | `sqlite` |
| External C library | `libsqlite3` (system or vendored) |
| `activation` | `[?lib 'sqlite']` |
| Default purity | `impure` (overridden per-function — see §2) |
| Error block | `CXER4200..CXER4209` (§7) |
| Arrow handoff | Required for tabular returns (§4) |

Module identity is established by the `[?lib]` resolver per [`spec/core/code.md`](../core/code.md) §12.1.

## §2. Function surface

| Fn | Signature | Returns | Purity |
|---|---|---|---|
| `sqlite:open` | `($path::string $flags::map=$nil)` | `sqlite-handle` | impure |
| `sqlite:close` | `($handle::sqlite-handle)` | nil | impure |
| `sqlite:select` | `($handle::sqlite-handle $sql::string $params::array=$nil)` | `arrow-stream` | impure |
| `sqlite:execute` | `($handle::sqlite-handle $sql::string $params::array=$nil)` | `int` (rows-affected) | impure |
| `sqlite:prepare` | `($handle::sqlite-handle $sql::string)` | `sqlite-stmt` | impure |
| `sqlite:bind` | `($stmt::sqlite-stmt $params::array)` | `sqlite-stmt` | pure |
| `sqlite:step` | `($stmt::sqlite-stmt)` | `map` (row) or nil (done) | impure |
| `sqlite:finalize` | `($stmt::sqlite-stmt)` | nil | impure |
| `sqlite:transaction` | `($handle::sqlite-handle $body::any)` | body value | impure |

`sqlite:bind` is `pure`: returns a new statement value with bindings applied, leaving the original unchanged (structural sharing per [`spec/core/cxdm.md`](../core/cxdm.md)).

`sqlite:transaction` wraps `$body` in `BEGIN` / `COMMIT` (or `ROLLBACK` on error). The transaction itself is `impure`; a body that is itself `pure` may still call it (the transaction's purity is its own classification).

The purity classifier per [`spec/core/code.md`](../core/code.md) §6.5.x refuses `impure` calls from a `pure` `[?def]` body (raises `CXER0233`). Pure pipelines that need query results materialise them in a non-pure document, write to a CX or Arrow file, then re-read via `cx:from-format` or `[?cx include]`.

---

## §3. Connection lifecycle

Handles are thread-local per [`spec/core/abi.md`](../core/abi.md) §1.5.1 (class **H**). A `sqlite-handle` MUST NOT be shared across threads; a worker thread that needs SQLite access opens its own connection.

`sqlite:open` flags map keys:

| Key | Type | Default | Effect |
|---|---|---|---|
| `read-only` | `bool` | `false` | `SQLITE_OPEN_READONLY` |
| `create` | `bool` | `true` | `SQLITE_OPEN_CREATE` (no-op if `read-only`) |
| `wal` | `bool` | `false` | Enables WAL journal mode after open |
| `foreign-keys` | `bool` | `true` | Enables foreign-key enforcement |
| `busy-timeout-ms` | `int` | `5000` | Lock-wait timeout |

Closing a handle finalises all prepared statements derived from it. Forgetting to close leaks the file descriptor; deployment guidance is to use `sqlite:transaction` blocks or explicit try/finally-equivalent patterns.

---

## §4. Arrow handoff

`sqlite:select` returns an `arrow-stream` value, not an inline CX value. Tabular data hands off through `libcx_arrow`'s `ArrowArrayStream` (per [`spec/core/abi.md`](../core/abi.md) §2.11, capability bit 23). The stream materialises in chunks (default 2²⁰ rows per chunk, configurable via `[?cx sqlite-chunk-size=N]`).

```
[?lib 'sqlite']
[?def $db [sqlite:open "data.db" {"read-only": true}]]
[?def $results [sqlite:select $db "SELECT id, name, ts FROM events"]]
```

Type mapping (SQLite affinity → Arrow):

| SQLite | Arrow |
|---|---|
| `INTEGER` | `Int64` |
| `REAL` | `Float64` |
| `TEXT` | `Utf8` |
| `BLOB` | `Binary` |
| `NULL` | nullable variant of the column's declared type |

Columns without declared affinity (SQLite dynamic typing) emit as `Utf8`.

---

## §5. Threat model

- **SQL injection.** `sqlite:select` / `sqlite:execute` accept a parameter array for placeholder substitution. Documents passing user-supplied data directly into the SQL string are vulnerable; use `?` placeholders plus `$params`.
- **Filesystem traversal via `sqlite:open` path.** A user-supplied database path can escape an intended directory. Applications validate paths before passing to `sqlite:open`; the loader does not enforce a path-trust check beyond filesystem permissions.
- **Resource exhaustion.** Unbounded `SELECT *` produces unbounded streams. Arrow handoff bounds memory per chunk; total CPU/I/O is uncapped.

See [`spec/process/threat-model.md`](../process/threat-model.md) for the full document threat model.

---

## §6. Conformance

Fixtures live at `conformance/module_sqlite.txt`. Categories:

1. Lifecycle round-trip — open / create-table / insert / select / close preserves bytes and types.
2. Parameter binding — `?` placeholders bind correctly for each SQLite type; injection attempts appear as literals.
3. Arrow handoff — `sqlite:select` returns a valid `ArrowArrayStream`; chunked materialisation honors `sqlite-chunk-size`.
4. Transaction — `sqlite:transaction` commits on success, rolls back on body error.
5. Purity refusal — `impure` `sqlite:*` calls from a `pure` `[?def]` raise `CXER0233` per [`spec/core/code.md`](../core/code.md) §6.5.x.
6. Error path — each code in §7 produced by at least one fixture.

---

## §7. Error codes

`sqlite:` claims `CXER4200..CXER4209`:

| Code | Description |
|---|---|
| `CXER4200` | Cannot open database (filesystem error, permissions, corruption) |
| `CXER4201` | Database file format unsupported (older / newer SQLite version) |
| `CXER4202` | SQL syntax error (sqlite3_prepare returned non-OK) |
| `CXER4203` | SQL runtime error (constraint violation, type mismatch, busy) |
| `CXER4204` | Transaction error (nested begin, rollback failure) |

`CXER4205..CXER4209` reserved.

Errors carry the original SQLite message in `$err:description`. Application code distinguishing constraint violations from busy errors reads SQLite's extended error code from `$err:vendor-code` (populated when the source is SQLite).

---

## §8. Cross-references

- [`spec/core/code.md`](../core/code.md) §12.1 — `[?lib]` module loading.
- [`spec/core/code.md`](../core/code.md) §6.5.x — purity classification.
- [`spec/core/abi.md`](../core/abi.md) §2.11 — Arrow C-Data interop (bit 23).
- [`spec/process/threat-model.md`](../process/threat-model.md) — document threat model.
