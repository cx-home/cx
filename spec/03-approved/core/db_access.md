# Database access — external engines (`$sql-*` / `$redis-*`)

**Status:** Current (owner G3 2026-07-11 — decision (a) adopt-shipped on #294)
**Tracks:** #294 (shipped surface had no owning spec); shipped via the
external-engines milestone, merged to `release/0.13.0`.

This spec is authored **from the shipped behavior** (issue #294): the
database-access surface went live on the `release/0.13.0` integration line without an
owning spec, which is drift by definition. Every normative statement below was
either **[verified]** by running programs against a live build (sqlite + redis
engines compiled in, plus the engine-less default build) or **[inferred]** from
the implementation source and marked as such. Any change *beyond* what is
written here goes spec-first. §11 records the conflict with the older
`modules/sqlite.md` design and the owner decision that resolved it.

Mental model (user-confirmed at design time): external databases are **not**
cxstore. They are separate surfaces exposing each engine's *own native power*
(SQL text, redis commands), not content-addressed document storage. Two
distinct flag families exist and must not be conflated: `-d cx_db_*` (this
spec — database access) vs `-d cxstore_*` (cxstore blob/columnar backends,
covered by the store spec and the cxstore working drafts).

---

## §1. Surface

### §1.1 SQL verbs (engine-neutral, compiled into every build)

The four SQL verbs are language builtins reached by bare head dispatch — no
`[?lib]` import, no module prefix:

```
[$sql-open  URL]                 -> [sql-db handle=N url='…']
[$sql-exec  HANDLE SQL PARAM*]   -> [result changes=N last-rowid=M]
[$sql-query HANDLE SQL PARAM*]   -> [rows [row [<col> 'val'] …] …]
[$sql-close HANDLE]              -> null
```

They are routed **unconditionally**: an engine-less build still resolves all
four names and answers with honest errors (§6). The engines behind them are
opt-in build gates (§2); the URL scheme at `sql-open` selects the engine.

`sql-exec` and `sql-query` run the *same* statement path and differ only in
result shaping: `sql-exec` returns the change summary, `sql-query` returns the
row set. A `SELECT` through `sql-exec` executes and returns a (meaningless)
change summary; an `INSERT` through `sql-query` **executes the insert** and
returns an empty `[rows]`. **[verified]** Callers choose the verb by the shape
they want, not by statement class.

### §1.2 Redis verbs (existence gated)

```
[$redis-open  URL]               -> [redis-db handle=N url='…']
[$redis-cmd   HANDLE WORD+]      -> RESP reply mapped to CX data (§8)
[$redis-close HANDLE]            -> null
```

Unlike the SQL verbs, the redis verbs **do not exist** on a build without
`-d cx_db_redis`: dispatch is compile-time gated, so `[$redis-open …]` on an
engine-free build fails name resolution —
`[err code=user-undefined message='no callable "redis-open"']`. **[verified]**
This asymmetry (SQL verbs always resolve, redis verbs conditionally exist) is
shipped behavior, recorded here as-is. Since the **default build carries
`-d cx_db_redis`** (#520, §2), the redis verbs resolve on the shipped
artifact; the no-callable lane applies to engine-free override builds
(`CX_ENGINES=''`) and wasm.

Redis is deliberately **one generic command verb**, not a fixed subset:
`[$redis-cmd HANDLE WORD+]` passes the words verbatim as a RESP command, so
the *entire* native redis command surface is reachable (`SET`, `GET`, `INCR`,
`RPUSH`, `HSET`, `SMEMBERS`, `SELECT`, pub/sub, server admin — anything the
connected server accepts). There is no command allowlist; authority is the
`net` capability at open (§5) plus whatever the server itself enforces.

### §1.3 What does not exist (shipped scope)

- No prepared-statement objects, no `prepare`/`bind`/`step`/`finalize` verbs.
- No transaction verbs — transactions are plain SQL statements (§9).
- No connection-pool surface; one open = one connection.
- No typed parameter binding and no typed result values (§7): everything
  crosses the boundary as text.
- No stdlib wrapper module: there is no `stdlib/db.cx`, no
  `[?lib 'cx-stdlib/db']`, no `[$db:…]` prefix form. The verbs are bare
  builtins only.

---

## §2. Build gates and engine matrix

Engines are compile-time build flags. Since #520 the **default build carries
sqlite + redis** (`vcx/Makefile` `CX_ENGINES ?= -d cx_db_sqlite
-d cx_db_redis` — threaded through the shipped `lib`/`cli` targets, the dev
targets, the `-prod` strictness checker, and every test-gate compile, so the
gate tests what the artifact ships): sqlite adds only binding code and
dynamic-links the **system** `libsqlite3` (macOS: SDK-provided; Linux:
`libsqlite3-dev` at build time), redis is a pure-V RESP client linking
nothing — measured cost **+155 KB (+2.1 %)** on the stripped CLI, verified
via `otool` (the only new load command is `/usr/lib/libsqlite3.dylib`).
postgres/mysql stay opt-in because they add runtime library dependencies
(`libpq` / `libmysqlclient`) the installer base can't assume. The **wasm**
build and any `CX_ENGINES=''` override build remain engine-free and link no
database client library (the historical default posture, still verifiable
via `otool`). Adding an engine never touches the neutral `sql.v` layer; each
engine is one gated file implementing the `SqlConn` trait
(`run(stmt, params) -> {cols, rows, changes, last_rowid}` + `shutdown`).

| Engine | Build gate | Default artifact | URL scheme(s) | Links | Capability at open | Status |
|---|---|---|---|---|---|---|
| sqlite | `-d cx_db_sqlite` | **yes** (#520) | `sqlite://` | system `libsqlite3` (dynamic) | `write` | **[verified]** live (this spec's evidence run) |
| postgres | `-d cx_db_pg` | no — opt-in | `postgres://`, `postgresql://` | `libpq` | `net` | **[inferred]** from source; live-verified at merge time (external-engines milestone) |
| mysql | `-d cx_db_mysql` | no — opt-in | `mysql://` | `libmysqlclient` | `net` | **[inferred]** from source; live-verified at merge time |
| redis | `-d cx_db_redis` | **yes** (#520) | `redis://` (`rediss://` accepted, see §4.4) | none (pure-V RESP client) | `net` | **[verified]** live (this spec's evidence run) |

Note the postgres gate is **`cx_db_pg`**, not `cx_db_postgres` (issue #294's
prose used the longer name; the flag in the build is `cx_db_pg`).

Opt-in engines build shipped-shape (#520 threaded `CX_DFLAGS` through the
production targets):

```
make -C vcx build CX_DFLAGS='-d cx_db_pg'          # + postgres (needs libpq)
make -C vcx build CX_DFLAGS='-d cx_db_pg -d cx_db_mysql'
```

Every binary reports its compiled-in engine set in `cx -v`
(`engines  sqlite redis`), probed from the same `$if` gates that select the
engine at `sql-open` — capability is discoverable without tripping
`CXER1100`.

Implementation anchors: `vcx/code/sql.v` (neutral layer),
`vcx/code/sql_sqlite_d_cx_db_sqlite.v`, `vcx/code/sql_pg_d_cx_db_pg.v`,
`vcx/code/sql_mysql_d_cx_db_mysql.v`, `vcx/code/redis_d_cx_db_redis.v`.

Verb availability per build (the **default build** is the sqlite + redis
column pair; "engine-free" = `CX_ENGINES=''` override or wasm):

| Verb | Engine-free build | Any `-d cx_db_{sqlite,pg,mysql}` build | `-d cx_db_redis` build |
|---|---|---|---|
| `sql-open` | resolves; `CXER1100` no-engine error | resolves; opens matching scheme | resolves; `CXER1100` unless a SQL gate is also present |
| `sql-exec` / `sql-query` / `sql-close` | resolve; behave per §3/§6 | same | same |
| `redis-open` / `redis-cmd` / `redis-close` | **do not resolve** (`no callable`) | do not resolve | resolve |

---

## §3. Connection lifecycle and handles

`sql-open` (and `redis-open`) register the live connection in a
**process-global registry** and return a plain CX element handle:

```
[sql-db  handle=0 url='sqlite://:memory:']
[redis-db handle=0 url='redis://127.0.0.1:6390']
```

- Handle ids are integers, monotonically increasing from `0` per process, per
  registry (SQL and redis registries are independent), never reused within a
  process. **[verified]**
- The handle is **plain data**, not an opaque reference: any element named
  `sql-db` carrying a numeric `handle=` attribute addresses registry slot N —
  the `url=` attribute is informational only. A forged/stale handle is not a
  capability violation; it simply misses the registry (§6, `CXER1120`).
  Possession of a live handle is the only post-open authority check (§5).
- `sql-close` shuts the connection down and frees the slot; closing an
  unknown/already-closed handle is **idempotent `null`**. **[verified]**
- Use after close = the slot is gone = `CXER1120 E_SQL: unknown sql handle N`.
  **[verified]**
- Nothing auto-closes: connections live until closed or process exit. An open
  transaction on an abandoned handle is neither committed nor rolled back by
  the layer (the engine's own disconnect semantics apply at process exit).
- The registry is process-wide with no synchronization guarantees; concurrent
  use of one handle from parallel evaluation is unspecified (matches the
  capability layer's documented v1 single-threaded enforcement posture).

---

## §4. URL forms

`sql-open` splits the scheme at the first `://`; a URL without `://` has no
scheme and therefore no engine — `CXER1100` names the empty scheme.
**[verified]** (`sqlite:relative.db` → `no SQL engine for scheme ""`).

### §4.1 sqlite

`sqlite://<path>` — everything after `sqlite://` is the filesystem path,
relative or absolute; `:memory:` gives an in-memory database. The file is
created if absent (standard sqlite open semantics). **[verified]** An empty
path (`sqlite://`) is `CXER1101` malformed-URL. **[verified]**

### §4.2 postgres **[inferred]**

`postgres://…` or `postgresql://…`, passed **whole** to libpq's conninfo/URI
parser. Everything libpq accepts in URI form works (host, port, dbname, user,
password, options). Bare key=value conninfo strings do NOT work — scheme
dispatch requires the `postgres(ql)://` prefix, so a conninfo string never
reaches the engine.

### §4.3 mysql **[inferred]**

`mysql://[user[:password]@]host[:port]/dbname` — parsed by the layer itself.
Defaults: user `root`, empty password, host `127.0.0.1`, port `3306`, empty
dbname.

### §4.4 redis

`redis://[user:password@]host[:port][/db]` — parsed by the layer itself.
Defaults: host `127.0.0.1`, port `6379`. The userinfo's text after the last
`:` is the password (a lone `user@` token is treated as a password); the
username is otherwise ignored (redis AUTH with default user). A `/db` index
path segment is **ignored** — issue `[$redis-cmd $h 'SELECT' '2']` instead.
**[inferred]** from source except defaults, which the evidence run exercised.

**Caveat — `rediss://` is accepted but NOT TLS.** The parser strips a
`rediss://` prefix identically to `redis://` and dials plain TCP; no TLS is
negotiated. Shipped behavior, recorded honestly; treat `rediss://` as a trap
until a TLS client lands (candidate follow-up: reject it loudly instead).

---

## §5. Capability model

The **only** capability gate is at `open`, and it sits *behind* engine
selection:

| Point | Capability | Rationale |
|---|---|---|
| `sql-open` `sqlite://` | `write` | local file effect (sqlite creates/writes the db file) |
| `sql-open` `postgres://`/`postgresql://` | `net` | networked |
| `sql-open` `mysql://` | `net` | networked |
| `redis-open` | `net` | networked |
| `sql-exec` / `sql-query` / `sql-close` / `redis-cmd` / `redis-close` | none | possession of a live handle is the authority |

Deny-by-default per the security spec (`spec/core/security.md` model): with no
grant, a gated open raises
`CXER0271 E_CAP_DENIED: write capability required for sql open sqlite://…`
(**[verified]**, and the redis/net equivalent **[verified]**). Grants come
from the host (`--allow-write`, `--allow-net`, `--allow-all`, or the embedding
ABI's caps spec); `[?with-caps]` narrowing applies as everywhere else.

**Evaluation order at `sql-open`** (observable, so normative):

1. operand check — non-string URL → `CXER0100` (before anything else);
2. engine selection — scheme matched against *compiled-in* engines only;
   no match (unknown scheme, or engine not built) → `CXER1100`, **without**
   any capability check;
3. capability check for the matched engine → `CXER0271` on denial;
4. connect → `CXER1101` on failure.

Consequence: the same program + same (empty) grant answers `CXER1100` on an
engine-less build but `CXER0271` on a gated build — the error you get for
`sqlite://:memory:` reveals whether the engine is compiled in. Both lanes
**[verified]**. `redis-open` checks `net` *before* parsing/dialing (its verbs
only exist on gated builds, so there is no no-engine lane).

Note the open capabilities are the coarse v1 grants: `write` for sqlite is
not path-scoped, `net` for pg/mysql/redis is host-scopable exactly as the net
spec's host-scope grants define (`--allow-net` scoping applies to the dial).

---

## §6. Error model

All failures are **err values** (elements), not raised conditions: the program
continues, the CLI exits 0 with the err rendered. Codes reuse the store/effect
bands rather than claiming a new band:

| Code | Symbol | Fires when | Example message (verbatim from live runs) |
|---|---|---|---|
| `cx-err:CXER0108` | `E_ARG` | missing required operands — `sql-open`/`sql-close`/`redis-open`/`redis-cmd`/`redis-close` called with none, `sql-exec`/`sql-query` with fewer than two; checked before anything else | `E_ARG: sql-exec expects ($db, $sql, $params…)` |
| `cx-err:CXER0100` | `E_OPERAND_KIND` | `sql-open` URL not a string scalar; `sql-close` operand not a `[sql-db]` element; `redis-cmd`/`redis-close` operand not a `[redis-db]` element; `redis-cmd` with a handle but no command word | `E_OPERAND_KIND: sql-open expects a url string` |
| `cx-err:CXER0271` | `E_CAP_DENIED` | open without the required capability (gated builds) | `E_CAP_DENIED: write capability required for sql open sqlite://:memory:; none granted (grant via --allow-write)` |
| `cx-err:CXER1100` | `E_STORE_UNRESOLVED_BACKEND` | no compiled-in SQL engine matches the scheme | `E_STORE_UNRESOLVED_BACKEND: no SQL engine for scheme "sqlite" (rebuild with -d cx_db_sqlite / -d cx_db_pg / -d cx_db_mysql) in sqlite://:memory:` |
| `cx-err:CXER1101` | `E_STORE_BACKEND_UNREACHABLE` | connect/open failure (bad path, refused dial, malformed engine URL) | `E_STORE_BACKEND_UNREACHABLE: dial_tcp failed for address 127.0.0.1:6391 …` |
| `cx-err:CXER1120` | `E_SQL` / `E_REDIS` | everything at run time: unknown/stale handle, SQL syntax/constraint error (engine message passed through), redis error reply, bad operand shape at `sql-exec`/`sql-query` | `E_SQL: near "SELEKT": syntax error (1) (SELEKT 1)` / `E_REDIS: ERR unknown command 'NOSUCHCMD'` |

All rows **[verified]** live. One sharp edge, shipped as-is and recorded:

- **Operand-error asymmetry.** A non-handle first operand is `CXER0100` at
  `sql-close` but `CXER1120 E_SQL: expected a [sql-db] handle` at
  `sql-exec`/`sql-query` (the run path wraps its own operand validation into
  the E_SQL lane). Same for a non-string SQL argument
  (`E_SQL: expected a SQL string`). **[verified]** Candidate tightening:
  uniform `CXER0100` for operand-kind everywhere; that change goes spec-first
  here before code moves.

History: the surface originally V-panicked on missing operands (`[$sql-open]`
took the process down — issue #305). The `CXER0108` arity guards above closed
that: all seven verbs answer the honest `E_ARG` err value, checked before the
operand-kind / engine / capability logic. **[verified]** on gated and
engine-less builds.

---

## §7. Parameter binding and result shapes

### §7.1 Parameters

Every argument after the SQL string is a bind parameter. Parameters are
**string scalars only**, and the boundary is **strict** (owner ruling
2026-07-21, #524): a non-string scalar (int, float, bool), an element, or
absence in parameter position raises `cx-err:CXER0100` (`E_OPERAND_KIND`)
**naming the parameter** — `[$sql-query $db 'SELECT ? AS a' 7]` is a
CXER0100 telling you parameter 1 is not a string scalar; write `'7'` or
convert explicitly (`[$concat '' $v]`). The pre-ruling behavior (silent
bind as `''`) was a recorded silent-wrong-answer and is retired — same
doctrine as the type-strict operators (code.md §6.5): everything crosses
the SQL boundary as text (§1.3), and the conversion is the author's,
stated in the program.

Placeholder syntax is **engine-native**:

| Engine | Placeholders | Mechanism |
|---|---|---|
| sqlite | `?` (sqlite positional) | real `sqlite3_bind` parameter binding **[verified]** |
| postgres | `$1 … $N` | real `PQexecParams` binding **[inferred]** |
| mysql | `?` | **string splice**: each `?` replaced by the `escape_string`-quoted value (injection-safe — all params arrive as strings and are escaped — but not typed prepared-statement binding) **[inferred]**, per the engine file's own documentation |

Excess `?` holes beyond the supplied params stay literal `?` (mysql splice
path); supplying params to a statement without holes is engine-defined.

### §7.2 `sql-exec` result

```
[result changes=N last-rowid=M]
```

- sqlite: `changes` = affected-row count, `last-rowid` =
  `last_insert_rowid()`. Both are connection-cumulative engine values — a
  subsequent non-modifying statement reports the *previous* statement's
  values (e.g. `sql-exec` of a `SELECT` after an `INSERT` reports
  `changes=1 last-rowid=1`). **[verified]**
- postgres: `changes` = **returned row count** (not the affected count — the
  simple result API doesn't expose it; use `RETURNING` to get ids),
  `last-rowid` always `0` (postgres has no rowid). **[inferred]**, per the
  engine file's own documentation.
- mysql: `changes` = `affected_rows()`, `last-rowid` = `last_id()`.
  **[inferred]**

### §7.3 `sql-query` result

```
[rows
  [row [id '1'] [name 'alice'] [score '9.5']]
  [row [id '2'] [name 'bob']   [score '7.0']]]
```

- One `[row]` element per result row, columns as child elements **in
  projection order**, element name = engine-reported column name, content =
  the value as a **single string scalar**. **[verified]**
- **Everything is text.** Numbers come back as their engine text form
  (sqlite REAL `7` → `'7.0'`); typed CX scalars are an acknowledged follow-up
  (spec-first, here).
- **SQL NULL flattens to `''`** — indistinguishable from an empty string in
  the result. **[verified]** Acknowledged limitation; a follow-up would need
  an absence channel per row.
- Empty result set → bare `[rows]`. **[verified]**
- **Unaliased expression columns keep the engine name verbatim**, e.g.
  `SELECT COUNT(*) …` → `[COUNT(*) '1']` — an element name that may not
  re-parse as written. **[verified]** AS-alias every computed column
  (`COUNT(*) AS n`). If the engine reports fewer column names than a row has
  values, surplus columns are named `col<i>` by position.
- Column names are taken from the engine's row/result metadata; for mysql
  they come via map iteration in insertion order **[inferred]**.

---

## §8. Redis command surface and RESP mapping

`redis-cmd` sends `WORD+` verbatim (each word a string scalar; a
non-string word raises `cx-err:CXER0100` naming the word — the same #524
strict boundary as the §7.1 bind parameters) and maps the RESP reply
recursively:

| RESP reply | CX value | Example **[verified]** |
|---|---|---|
| simple/bulk string, verbatim string | string scalar | `SET` → `'OK'`, `GET k1` → `'v1'` |
| integer, double, boolean, big number | **string** scalar of the printed value | `INCR n` → `'1'` |
| null | `null` | `GET nope` → `null` |
| array | `[list …]` | `LRANGE l 0 -1` → `[list 'a' 'b']` |
| set | `[set …]` | `SMEMBERS s` → `[set 'p' 'q']` |
| push message | `[push …]` | — |
| map (RESP3 map or flat pair array) | `[map [<key> <value>] …]` | `HGETALL h` → `[map [f1 'x'] [f2 'y']]` |
| error reply | `CXER1120 E_REDIS: <server message>` err value | `NOSUCHCMD` → `E_REDIS: ERR unknown command 'NOSUCHCMD'` |

Map keys become element names (scalar keys rendered to text; a non-scalar map
key degrades to the literal name `key`). Blob errors map to `CXER1120` like
error replies. The client speaks RESP over plain TCP (pure-V; the V fork
carries the RESP3 null-reply fix this layer needs).

---

## §9. Transactions

There are no transaction verbs. Transactions are **plain SQL through
`sql-exec` on one handle**, honored by the engine because one handle = one
connection:

```
[$sql-exec $db 'BEGIN']
[$sql-exec $db "INSERT INTO t VALUES ('in-tx')"]
[$sql-exec $db 'ROLLBACK']   [; table count back to 0 — verified ;]
```

**[verified]** on sqlite (BEGIN/ROLLBACK round trip observed). Nothing
auto-commits or auto-rolls-back at `sql-close` beyond the engine's own
disconnect behavior; error values do not unwind transactions. A `[?tx …]`
scope form would be a spec-first addition here.

---

## §10. Columnar file I/O (`-d cx_arrow_files`) — adjacent surface

The Arrow/Parquet gate is part of the same external-engines milestone but is
**not** a CX-language verb surface. It lives at the CLI and library layer:

- `cx table dump FILE --to=parquet|arrow [--output=F]` and
  `cx table load F --from=parquet|arrow --to=cx` convert between CX `[table[…]]`
  blocks and Parquet / Arrow IPC files.
- The `cx` binary itself stays Arrow-free: it `dlopen`s `libcx_arrow`
  (resolved via `$CX_ARROW_LIB`, next to the binary, `target/`, `../lib`) only
  when parquet/arrow is requested. `libcx_arrow` must itself be built with
  `-d cx_arrow_files` (links user-supplied `libarrow`/`libparquet` via a C++
  shim; connectivity model — not bundled, same philosophy as the DB engines).
- Honest failure modes, both **[verified]**:
  - lib present but built without the flag →
    `libcx_arrow lacks native parquet support — rebuild it with -d cx_arrow_files`;
  - lib absent →
    `cannot load <lib> (set CX_ARROW_LIB or build lib-arrow-files): dlopen(…)`.

Errors here are CLI stderr + exit status, not CX err values — this surface
never enters evaluation. Full contract (C ABI, framed `data_bin` bytes, type
mapping) belongs to the columnar/table spec track (`cxstore_columnar_backend.md`
neighborhood), not this one; it is listed here so the `-d cx_arrow_files` flag
has a named owner.

---

## §11. Deviations from the approved `modules/sqlite.md`

`spec/03-approved/modules/sqlite.md` (owner-locked; **not** edited by this
draft) describes an **older, different design** that never shipped. The
conflict, crisply:

| Aspect | approved `modules/sqlite.md` | shipped (this spec) |
|---|---|---|
| Activation | `[?lib 'sqlite']` module, `sqlite:` prefix | bare builtins, no module, no import |
| Function surface | `sqlite:open/close/select/execute/prepare/bind/step/finalize/transaction` | `sql-open/sql-exec/sql-query/sql-close` (engine-neutral, scheme-dispatched) |
| Open options | flags map (`read-only`, `wal`, `foreign-keys`, `busy-timeout-ms`) | none — URL only |
| Query results | `arrow-stream` handoff (chunked Arrow C-Data), typed columns | inline CX `[rows [row [col 'text']]]`, all text |
| Prepared statements | first-class (`sqlite-stmt`, pure `bind`) | none |
| Transactions | `sqlite:transaction` wrapping verb | plain SQL `BEGIN`/`COMMIT`/`ROLLBACK` |
| Purity/effects model | per-function purity classes, `CXER0233` refusal | capability gate at open only |
| Error codes | dedicated band `CXER4200..4209`, `$err:vendor-code` | reused store/effect bands `CXER0100/0271/1100/1101/1120` |
| Threading | thread-local handles (ABI class H) | process-global registry, no thread contract |
| Conformance | `conformance/module_sqlite.txt` (never existed) | `conformance/stdlib/db.cxd` + gated V tests (§12) |

Practically nothing of the approved design shipped; the shipped layer is also
*wider* (postgres/mysql/redis) and *shallower* (no streams, no statements,
no types) than the approved one.

**Owner decision — TAKEN: (a) adopt-shipped (owner, 2026-07-11, #294):**
this spec is the normative reference for the shipped surface;
`modules/sqlite.md` is retired to a tombstone pointing here. The Arrow-stream
design it described remains available as a future typed-results follow-up
riding the existing `libcx_arrow` C-Data bridge — spec-first if pursued.
The rejected alternative, for the record, was *(b) reconcile-to-old*:
implementing the old module design (module activation, typed Arrow streams,
statement objects, a dedicated error band) — large, sqlite-only, and it would
have rebuilt a live, field-used surface to match a design that never shipped.

---

## §12. Conformance and testing

The fixture runner's gate toggle (`conformance/gates.cxd` `gate=`) is
**static** — it cannot condition a case on the `-d` flags the binary under
test was built with. So the corpus splits by build-dependence:

- **Build-independent lanes → fixtured**, `conformance/stdlib/db.cxd`
  (enforced; entry in `gates.cxd`): operand-kind `CXER0100` at
  `sql-open`/`sql-close`, arity `CXER0108` at all four SQL verbs (#305),
  unknown-handle `CXER1120` at `sql-exec`/`sql-query`,
  idempotent-null `sql-close`. These were verified to produce **identical**
  output on an engine-less build and a `-d cx_db_sqlite -d cx_db_redis` build,
  and the suite's detection power was proven red/green before landing.
- **Default-engine lanes → fixtured since #520** (`db.cxd` 010+): the gate
  compiles the suite with the default `CX_ENGINES`, so the sqlite success
  lifecycle, `sql-exec` result shape, §7.1 param binding (string success +
  non-string→`''`), the malformed-empty-path `CXER1101`, the now-deterministic
  `CXER0271` open denial, and the redis offline guard sweep (arity, operand,
  unknown-handle, denial) run as enforced fixtures. An engine-free override
  build (`CX_ENGINES=''`) is expected red on these lanes — a non-default
  configuration, like a `CX_GC` override.
- **Opt-in-engine lanes → NOT fixtured** (they would be always-red on the
  default build): pg/mysql paths, and redis success lanes (live server).
  These live in `$if`-gated V tests — `vcx/code/sql_test.v` (in-memory sqlite
  exec/query matrix) is the pattern; engine files with live-server needs
  (pg/mysql/redis) follow the store backends' env-gated live-test precedent.
- **Live evidence for this spec** (recorded 2026-07-10, worktree build
  `-d cx_db_sqlite -d cx_db_redis` + engine-less installed build): sqlite
  full lifecycle (open/create/insert-with-params/query/close), NULL→`''`,
  empty `[rows]`, verbatim expression column names, param binding incl. the
  non-string→`''` edge, BEGIN/ROLLBACK, use-after-close, capability denial
  and grant lanes, handle numbering; redis against an ephemeral local server
  (SET/GET/INCR/RPUSH+LRANGE/HSET+HGETALL/SADD+SMEMBERS, null, error reply,
  dial failure, capability denial); no-engine `CXER1100` and
  `no callable "redis-open"` on the engine-less build; both `cx table`
  parquet/arrow honest-error lanes.

The SQL-verb arity lane (`CXER0108`, §6) is fixtured in `db.cxd`
(`db-006..db-009`); the redis arity guards are fixtured in `db.cxd`
(`db-016+`) since the default build carries `-d cx_db_redis` (#520) — they
had previously been live-verified only, on the gated build alongside the
sweep (#305).
