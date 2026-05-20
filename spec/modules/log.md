# `log:` module — structured logging

**Status:** Draft (2026-05-18). v0.7.0 deliverable per
[ADR 0023 §D10 / Amendment #1](../decisions/0023-cx-self-host-module-and-extension-interface.md).
Pulled forward from v0.8.0 Tier B (per
[`spec/basex_function_modules.md`](../basex_function_modules.md))
because operational pipelines need structured logging from the
format/API stability boundary outward, and locking the namespace at
v0.7.0 means v0.8.0 BaseX modules slot in around a settled surface.

**Authoritative refs:**
- [ADR 0023 §D10](../decisions/0023-cx-self-host-module-and-extension-interface.md) — module decision
- [`spec/v0_7_0_status.md`](../v0_7_0_status.md) §FF — implementation queue
- [`spec/eval.md` §logfmt](../eval.md) — logfmt rules `log:` emission follows
- [`spec/abi.md §1.5`](../abi.md) — capability bit

---

## §0. Module metadata

| Field | Value |
|---|---|
| `ns_prefix` | `log` |
| `version` | `0.7.0` |
| `capability_bit` | Bit 28 (subsumed — per ADR 0023 Amendment #2 R2; bit 28 widens at v0.7.0 to cover the full DD/EE/FF surface collectively) |
| `activation` | `Always` (no `[?cx use-module=log]` required) |
| `default_purity` | `SideEffect` (one ReadOnly exception — `log:level`) |

Always-on rationale: debuggability defaults matter. Forcing
adopters to declare `use-module=log` before they can write
`log:info(...)` is friction that pushes them back to `fn:trace` or
worse. The log surface is small, low-risk, and operationally
load-bearing.

---

## §1. Function surface

7 functions. Each row: signature, purity, error codes, fixture-ref.

| Fn | Signature | Purity | Errors | Fixtures |
|---|---|---|---|---|
| `log:trace` | `(message as xs:string, fields as map(*)?)` | SideEffect | — | `trace-*` |
| `log:debug` | `(message as xs:string, fields as map(*)?)` | SideEffect | — | `debug-*` |
| `log:info` | `(message as xs:string, fields as map(*)?)` | SideEffect | — | `info-*` |
| `log:warn` | `(message as xs:string, fields as map(*)?)` | SideEffect | — | `warn-*` |
| `log:error` | `(message as xs:string, fields as map(*)?)` | SideEffect | — | `error-*` |
| `log:level` | `()` → xs:string | ReadOnly | — | `level-*` |
| `log:with-context` | `(fields as map(*), body as cx-value)` → body's value | inherits body's purity | — | `with-context-*` |

**Return values.** Emitter functions (`trace` / `debug` / `info` /
`warn` / `error`) return the empty sequence — they exist for their
side effect. Use them at statement position, not value position:

```
[?for $row :in $rows :do [
  log:info("processing row", { "id": $row/@id })
  process-row($row)
]]
```

If you need a value-passthrough trace (XQuery's `fn:trace` shape),
use `fn:trace` (C17) directly — `log:` is the structured-emission
surface, `fn:trace` is the pipeline-passthrough surface. The two
coexist by design.

**`log:level()`** returns the currently-effective minimum level as
a lowercase string: `"trace"`, `"debug"`, `"info"`, `"warn"`,
`"error"`, or `"off"`. The result reflects the closest enclosing
`[?cx log-level=...]` directive (per §2.1).

**`log:with-context(fields, body)`** evaluates `body` with `fields`
merged into the ambient logging context (per §2.4) for the
duration of `body`'s evaluation. Returns `body`'s value. Context
restoration is guaranteed on both success and error exit paths.

---

## §2. Configuration directives

Three directives configure the module per document. All three are
lexically scoped (per ADR 0023 §D3 activation rules) and inherit
through `[?cx include=...]` unless the included document overrides.

### §2.1 `[?cx log-level=<level>]`

Minimum level emitted. Lower-level calls are filtered (no emission,
no allocation of the fields map). Levels in ascending order:

```
trace < debug < info < warn < error < off
```

Default: `info`. `off` suppresses all emission.

### §2.2 `[?cx log-format=<format>]`

Output format for emitted records. Two values at v0.7.0:

- `logfmt` (default) — one record per line, `key=value` pairs per
  `spec/eval.md` logfmt rules. Keys: `level`, `msg`, `ts` (ISO 8601
  UTC), plus each field from the call's fields map plus each field
  from the ambient context (per §2.4). Field values with whitespace
  or `=` are quoted; quotes inside values are escaped.

- `json` — one JSON object per line (NDJSON). Same keys as logfmt
  plus structural typing preservation (numbers, booleans, nested
  objects/arrays for nested fields).

v0.8.0+ may add formats (e.g., `cef`, `gelf`) without breaking the
v0.7.0 surface — the format key is open-extension via the registry.

### §2.3 `[?cx log-output=<sink>]`

Output sink. Three values at v0.7.0:

- `stderr` (default) — write to standard error
- `stdout` — write to standard output (use with care; conflicts
  with `[?cx output-target=stdout]` if both emit)
- `file:<path>` — append to file at `<path>`. Path resolved
  relative to the binding's working directory. File opened in
  append mode; concurrent writers serialize per OS write-atomicity
  guarantees up to the system page size.

### §2.4 Ambient context (via `log:with-context`)

Context fields are key/value pairs prepended to every record
emitted within the lexical scope of a `log:with-context` call.
Contexts nest — inner contexts merge with outer (inner keys win on
collision). Restoration is guaranteed:

```
log:with-context({ "request-id": $req-id }, [
  log:info("started")      // emits with request-id field
  process()                // process() may emit; inherits request-id
  log:info("finished")
])
// outside with-context — no request-id on subsequent emissions
```

Implementation note: contexts are evaluator-local (thread-safe in
v0.7.0's single-evaluator model). The v0.9.0+ `jobs:` module
introduces context inheritance across parallel evaluations as part
of its determinism story.

---

## §3. Purity and `pure-only`

Per ADR 0023 §D5 / D10, `log:*` emitters are `SideEffect`. Under
`[?cx pure-only]`:

- `log:trace` / `log:debug` / `log:info` / `log:warn` / `log:error`
  raise `cx-err:CXER0040 (sideeffect-under-pure-only)`
- `log:level` is `ReadOnly` and is also refused under `pure-only`
  (Pure-only enforces Pure-only, not "Pure plus ReadOnly")
- `log:with-context` is refused (even though the wrapper itself
  doesn't emit, its presence implies the body intends to emit)
- `fn:trace` is exempt from `pure-only` enforcement as a documented
  v0.7.0 exception — XQuery-standard and load-bearing for debug-
  ability of pure documents

The exemption for `fn:trace` is codified in
[`spec/eval.md §4`](../eval.md) under the C17 row.

---

## §4. Output format examples

**logfmt** (default):

```
ts=2026-05-18T14:23:01Z level=info msg="processing row" id=42 source=customers.csv
ts=2026-05-18T14:23:01Z level=warn msg="missing field" id=43 field=email source=customers.csv
ts=2026-05-18T14:23:02Z level=info msg=done count=1000 source=customers.csv
```

**json**:

```
{"ts":"2026-05-18T14:23:01Z","level":"info","msg":"processing row","id":42,"source":"customers.csv"}
{"ts":"2026-05-18T14:23:01Z","level":"warn","msg":"missing field","id":43,"field":"email","source":"customers.csv"}
{"ts":"2026-05-18T14:23:02Z","level":"info","msg":"done","count":1000,"source":"customers.csv"}
```

Cross-binding byte-identity requirement (per ADR 0023 §D7): same
input + same `log-format` produces byte-identical output across V +
Python + Go + Rust + TypeScript. Implies deterministic field
ordering (alphabetical after the three fixed-position keys `ts` /
`level` / `msg`) and a single shared timestamp format
(`yyyy-MM-dd'T'HH:mm:ssZ` ISO 8601 UTC, second precision at v0.7.0;
millisecond precision via `[?cx log-timestamp-precision=ms]` post-
v0.7.0).

For conformance fixture purposes the timestamp is stubbed to a
fixed value (`1970-01-01T00:00:00Z`) when the evaluator runs under
`[?cx test-mode=true]` — required because real timestamps are
non-deterministic and would break byte-identity fixtures.

---

## §5. Relationship to `fn:trace` and the evaluator hook

Per ADR 0023 §D11, `log:*` emitters wire through the evaluator-hook
surface (`on_value_emit`). This gives the hook signature a
non-trivial reference implementation at v0.7.0 and provides v0.8.0+
debug-adapter work a known surface to subscribe to log emission
without per-module integration.

`fn:trace` likewise wires through `on_value_emit`, marking emitted
records with the appropriate `source` field (`fn:trace` vs
`log:info`). Downstream consumers can filter on `source` to
distinguish pipeline traces from structured log records.

---

## §6. Conformance

Fixtures live at `conformance/log_module.txt`. Categories:

1. **Format byte-identity** — fixed input + fixed format produces
   byte-identical output across all 5 v0.7.0 bindings. Uses
   `test-mode=true` for timestamp stubbing per §4.
2. **Level filtering** — each level + each minimum-level combination
   produces the expected emission set.
3. **Context inheritance + restoration** — nested `with-context`
   calls compose correctly; restoration verified on both success
   and error exit.
4. **Pure-only refusal** — every `log:*` emitter refused under
   `[?cx pure-only]`.
5. **Output sink** — stderr / stdout / file outputs go to the
   correct sink; concurrent file writes serialize.

Target: ~40 fixtures (~5 per function × 7 + ~5 directive fixtures).

---

## §7. Error codes

`log:` shares the `cx-err:CXER004x` namespace for purity violations
(emitted under `pure-only`). No `log:`-specific error codes at
v0.7.0 — emission failures (write to closed file, etc.) propagate
as the underlying I/O error from the binding's runtime, not
through a cxl-level error code. v0.8.0+ may reserve a sub-range
(e.g., `cx-err:CXER0050..0059`) if log-emission needs typed error
handling (e.g., a `log:flush()` operation that can fail
synchronously).

---

## §8. Capability bit

Per ADR 0023 Amendment #2 R2, `log:` does **not** get a new
`cx_features` bit. It is subsumed under bit 28's v0.7.0 widening
(see `spec/modules/cx.md §5`). A binding setting bit 28 at v0.7.0
commits to the full FF `log:` surface alongside the DD `cx:` and
EE extension-interface surfaces.

Per-module presence in user code goes through `inspect:` at the
cxl level (DD13 / EE7) — `inspect:module-available("log")` returns
boolean.

---

## §9. Open questions

(Items deliberately not resolved at v0.7.0 — recorded for v0.7.x or
v0.8.0 follow-up.)

1. **Millisecond / nanosecond timestamp precision** — v0.7.0 ships
   second precision. Higher precision behind a directive
   (`log-timestamp-precision=ms` / `=ns`) v0.7.x.
2. **Sampling / rate-limiting** — high-frequency call sites need
   sampling. Defer to v0.8.0 `log:sample(rate, fn)` wrapper.
3. **Async / buffered emission** — synchronous emission at v0.7.0.
   Buffered + flush-on-exit considered for v0.9.0+ alongside the
   `jobs:` concurrency work.
4. **OTLP / OpenTelemetry export** — third-party-protocol export
   left to v0.8.0+ via a `log:exporter-set` hook or a dedicated
   `otel:` module.
5. **Pure-only `log:trace` carve-out** — current rule refuses all
   `log:*` under `pure-only`. Counter-proposal: carve out `log:trace`
   as exempt (parallel to `fn:trace` exemption). Held until a
   concrete pure-only pipeline use case surfaces.
