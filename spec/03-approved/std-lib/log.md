# `cx-stdlib/log` — structured logging

```cx
[module-meta name=log tier=B status=current
  [standard ref='ISO 8601' title='Timestamps']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/log` sub-package.

---

## §1. Scope

`cx-stdlib/log` provides structured logging: leveled emit, arbitrary structured fields, configurable sinks (single or multi-sink fan-out with optional async / rotation / sampling), and dynamic contextual scopes via the [`[?with-scope]`](../core/code.md) language directive (§2.3). Each log event is a record of `[level $atom message $string timestamp $datetime fields $map]`.

Distinct from `cx-stdlib/test` (assertion failures, not log events), `cx-stdlib/prof/trace` (perf events), and `[?print]` / `[$io:write-line]` (unstructured writes).

## §2. Conceptual model

### §2.1. Levels

| Level | Use case |
|---|---|
| `:debug` | Verbose internals; disabled by default |
| `:info` | Normal operational milestones |
| `:warn` | Recoverable problems |
| `:error` | Failed operations |
| `:fatal` | Unrecoverable; process exit imminent |

Minimum level configurable via `[$log:configure]` (default `:info`).

### §2.2. Structured fields

Every log call accepts an optional `fields` map (named parameter, default `{}`, §3.1):

```cx
[$log:info "user created" fields={user-id 1234 email "alice@example.com" duration-ms 12.5}]
```

JSON sinks emit fields as JSON object; text sinks as `key=value` pairs.

### §2.3. Scopes

A **scope** is a thread/coroutine-local dynamic context that adds fields automatically to every log call within its dynamic extent. Scopes are established by the [`[?with-scope]`](../core/code.md) language directive (core §8.10.8), not a `cx-stdlib/log` function — establishing a dynamic context with guaranteed restore-on-exit is control flow, so it is a directive. `cx-stdlib/log` is its consumer: each `[$log:*]` call reads the active context and merges it **under** the call's own `fields` (call-site wins for shared keys).

```cx
[?with-scope {request-id "abc123" user-id 42}
  [$log:info "processing started"]
  [?http-client target=$url method="get"]
  [$log:info "processing done"]]
```

Scopes nest and merge (inner overrides outer); the dynamic context reaches transitively into called functions; the prior context is restored on scope exit, including error-unwind. Thread/coroutine-local. For introspection use `[$log:current-scope]` (§3.3).

## §3. Public function surface

### §3.1. Level-keyed emit

One function per level; positional message, optional `fields` map (named parameter, default `{}`):

```
[?def debug scope=public impure [returns null] ($message::string $fields={}) ...]
[?def info  scope=public impure [returns null] ($message::string $fields={}) ...]
[?def warn  scope=public impure [returns null] ($message::string $fields={}) ...]
[?def error scope=public impure [returns null] ($message::string $fields={}) ...]
[?def fatal scope=public impure [returns null] ($message::string $fields={}) ...]
```

Omit `fields` for a fieldless call; pass `fields={…}` to attach structured fields.

### §3.2. Generic emit

```
[?def log scope=public impure [returns null] ($level::atom $message::string $fields={}) ...]
```

For programmatic level selection.

### §3.3. Scope introspection

```
[?def current-scope scope=public impure [returns map] () ...]
```

Returns the merged active context (`{}` if none). Diagnostic only — does not modify the context. Scopes themselves are pushed by [`[?with-scope]`](../core/code.md) (core §8.10.8).

### §3.4. Configuration

```
[?def configure scope=public impure [returns null] ($config::map) ...]
```

Process-global config. Top-level keys:

| Key | Default | Values |
|---|---|---|
| `level` | `:info` | Minimum level — `:debug` / `:info` / `:warn` / `:error` / `:fatal` |
| `sink` | `"stderr"` | `"stderr"` / `"stdout"` / `"file"` / `"syslog"` / `"none"` — single-sink shorthand (§3.4.1) |
| `format` | `"text"` | `"text"` / `"json-lines"` / `"logfmt"` |
| `file-path` | (none) | Path for `sink="file"` |
| `sinks` | (none) | `[sequence sink-config]` — multi-sink fan-out (§3.4.1) |
| `include-timestamp` | `true` | bool |
| `include-level-prefix` | `true` | bool |
| `timestamp-format` | `"iso8601"` | `"iso8601"` / `"unix-ms"` |
| `async` | `false` | Async/batched emit (§3.4.3) |
| `buffer-size` | `4096` | Async ring-buffer capacity |
| `flush-interval-ms` | `1000` | Max buffer wait time |
| `on-overflow` | `:block` | `:block` / `:drop` (§3.4.3) |

#### §3.4.1. Sinks: single shorthand vs `sinks` fan-out

The flat `sink` / `format` / `file-path` keys configure exactly one sink (equivalent to a one-element `sinks` list).

`sinks` is a `[sequence sink-config]` where each entry has its own `sink` / `format` / `level` / `file-path` (plus optional `rotation` §3.4.2 and `sample-rate` §3.4.4). Every event that passes the **top-level** `level` filter is offered to each sink, which then applies its own per-sink `level` before formatting.

```cx
[$log:configure {
  level=:debug
  sinks=[
    {sink="stderr" format="text"       level=:info}
    {sink="file"   format="json-lines" file-path="/var/log/app.jsonl"
     rotation={by=:size max-bytes=10485760 max-files=5}}]}]
```

`sinks` and the flat `sink` are mutually exclusive — both present raises `CXER2403`.

#### §3.4.2. Rotation (file sinks)

A file sink-config may carry a `rotation` map:

| Key | Values | Meaning |
|---|---|---|
| `by` | `:size` / `:time` | Rotate on file size or wall-clock interval |
| `max-bytes` | int | For `by=:size` |
| `interval-ms` | int | For `by=:time` |
| `max-files` | int | Retain this many rolled files |

Active file keeps its configured `file-path`. On rotation it is renamed with a monotonically-increasing suffix (`app.jsonl.1`, `app.jsonl.2`, …) up to `max-files`; older files are deleted. `rotation` on a non-file sink, or invalid rotation map, raises `CXER2404`.

#### §3.4.3. Async / batched emit

With `async=true`, emits are enqueued to an in-process ring buffer and drained by a background flusher. Buffered events flush when the buffer fills, every `flush-interval-ms`, and on process exit (clean-shutdown hook).

- **Ordering** — FIFO; async never reorders. The same event reaches each sink in the same relative order.
- **Overflow** — `:block` (default) back-pressures the emitter; `:drop` discards and increments a dropped-event counter (surfaced via a periodic internal `:warn`).

#### §3.4.4. Sampling

A sink-config may carry `sample-rate` (float `0.0`–`1.0`): fraction of events that reach the sink, applied **after** level filtering. A per-level `sample` map (`{:debug 0.1 :info 1.0}`) is also accepted. Out-of-range raises `CXER2405`.

### §3.5. Direct sink emission

```
[?def emit-raw scope=public impure [returns null] ($record::element) ...]
```

Bypass formatting; emit a pre-shaped record directly.

### §3.6. Level check

```
[?def is-enabled scope=public pure [returns bool] ($level::atom) ...]
```

True if `level` would produce output at some sink. The internal level check short-circuits before formatting, so this guard is unnecessary for plain messages; it exists to guard expensive **field construction** at the call site:

```cx
[?if [$log:is-enabled :debug]
  [$log:debug "snapshot" fields={state=[expensive-snapshot $world]}]]
```

## §4. Edge cases and policy

### §4.1. Field key conflicts

A user-supplied field name that clashes with a built-in (e.g. `level`, `message`, `timestamp`) is preserved under a `user.` prefix (`level` → `user.level`).

### §4.2. Non-serializable field values

Values without clean serialization (e.g. an open file handle): text formatter emits a type-name; JSON formatter omits the field with a `<unsupported>` placeholder.

### §4.3. High-frequency logging

The internal level check short-circuits before formatting fields, so guarding a plain `[$log:debug "msg"]` is unnecessary. Use `is-enabled` only when the `fields` construction itself is expensive (§3.6).

### §4.4. Fatal semantics

`[$log:fatal]` does NOT terminate the process — it is just a level. Termination is the application's responsibility (`[?exit 1]` after a fatal log).

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2400` | `E_LOG_SINK_INVALID` | `configure` with unknown `sink` value |
| `CXER2401` | `E_LOG_FILE_UNWRITABLE` | `configure {sink="file"}` and file open fails |
| `CXER2402` | `E_LOG_LEVEL_INVALID` | `log` with unknown level atom |
| `CXER2403` | `E_LOG_SINK_CONFIG` | Both `sinks` and flat `sink` given; or malformed sink-config (§3.4.1) |
| `CXER2404` | `E_LOG_ROTATION_CONFIG` | Invalid `rotation` map, or `rotation` on a non-file sink (§3.4.2) |
| `CXER2405` | `E_LOG_SAMPLE_RATE` | `sample-rate` or `sample` map value outside `0.0`–`1.0` (§3.4.4) |

## §6. Conformance fixtures

Under `conformance/stdlib/log.cxd`:

- Level filter: `[$log:configure {level=:warn}]` then `[$log:info "m"]` no output; `[$log:warn "m"]` produces output.
- JSON-lines: `format="json-lines"` produces parseable JSON per line.
- logfmt: `format="logfmt"` produces `key=value`.
- Fieldless vs `fields`: `[$log:info "m"]` empty fields; `[$log:info "m" fields={a=1}]` attaches `a=1`.
- Field structural preservation.
- Scope auto-attach: inside `[?with-scope {request-id="r1"} [$log:info "m"]]` the event carries `request-id="r1"`; outside, it does not.
- Scope nest/override: inner key overrides outer for same key; outer restored on exit.
- Call-site wins: when `fields` and active scope share a key, call-site value attaches.
- `current-scope` returns merged active context (`{}` when none).
- Field-key conflict: user `level` becomes `user.level`.
- Timestamp ISO8601: `"2026-05-26T14:30:00.123Z"`.
- Timestamp `unix-ms`: integer milliseconds.
- `sink="none"`: no output regardless of level.
- Unknown sink raises `CXER2400`.
- `is-enabled` after `level=:info`: `:debug` false, `:warn` true.
- Multi-sink fan-out: one event reaches stderr text and file JSON-lines simultaneously.
- Sink ambiguity (both `sink` and `sinks`) raises `CXER2403`.
- Async + flush-on-exit: clean exit drains buffered events in enqueue order.
- Rotation: file sink rolls at threshold, retains at most `max-files`.
- Invalid rotation raises `CXER2404`.
- Sampling: `sample-rate=0.5` keeps ~50% (within tolerance), applied after level filter.
- Out-of-range sample-rate raises `CXER2405`.

## §7. Cross-references

- [`spec/core/code.md`](../core/code.md) §8.10.8 — the `[?with-scope]` directive this module reads for scope fields.
- [`spec/std-lib/prof.md`](prof.md) — sibling trace-emission (perf vs application).
- [`spec/std-lib/time.md`](time.md) — timestamps via `[$time:instant-now]`.
- [`spec/std-lib/io.md`](io.md) — file sink writes via `[$io:append-file]`.
