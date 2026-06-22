# `cx-stdlib/prof` — in-program profiling

```cx
[module-meta name=prof tier=C status=current
  [standard ref='HDR Histogram' title='Latency stats']]
```

**Status:** Current

Normative reference for the `cx-stdlib/prof` sub-package.

---

## §1. Scope

`cx-stdlib/prof` provides in-program profiling: timing measurement, memory snapshots, named counters, histograms, structured trace events, and flamegraph emission — all callable directly from CX code. For cases where the program itself measures and acts on the result.

## §2. Conceptual model

Four primitives:

- **Timer** — measure elapsed wall or CPU time around a callable.
- **Counter** — named monotonic counter the program updates; readable on demand.
- **Histogram** — record a distribution of observed values; report percentiles.
- **Trace event** — structured event emitted to a buffer; flushable to an external sink.

All are impure (they observe or mutate process state).

### §2.1. Time sources

Two clocks: **wall** (calendar time elapsed) and **CPU** (process CPU time consumed; excludes blocked / sleeping intervals). Default is wall time; CPU time is selected via `time-fn`'s `$opts` (§3.1).

### §2.2. Memory snapshots

A snapshot captures process memory state:

```cx
[mem-snapshot
  rss-bytes=12345678
  timestamp="2026-05-26T14:30:00.123Z"
  heap-bytes=9876543
  gc-bytes-allocated-total=123456789
  gc-bytes-freed-total=98765432
  gc-collections-total=42]
```

Fields are tiered:

- **Required (normative).** `rss-bytes` (int) and `timestamp` (ISO 8601 string) are present on every Tier-1 binding (V / Python / Go / Rust). Portable programs MAY rely on these two being present.
- **Standardized-when-present.** `heap-bytes`, `gc-bytes-allocated-total`, `gc-bytes-freed-total`, `gc-collections-total` carry the meanings above when a binding emits them; a binding MAY omit any of them.
- **Informational.** Implementations MAY include additional binding-specific fields; consumers should not depend on them for portable behavior.

## §3. Public function surface

### §3.1. Timing

```
[?def time-fn      scope=public impure [returns element] ($label::string $thunk::any $opts={}) ...]
[?def now-ns       scope=public impure [returns int]     () ...]
[?def now-cpu-ns   scope=public impure [returns int]     () ...]
```

`time-fn` runs `thunk` (any callable per [`spec/core/code.md`](../core/code.md) §12.2) and returns `[timing label="..." elapsed-ms=12.34 result=$value]`. Default clock is wall time.

`$opts` keys:

- `clock` — `"wall"` (default) / `"cpu"`.
- `unit` — `"ms"` (default) / `"us"` / `"ns"` / `"s"`. The reported field is named for the unit (e.g. `elapsed-us`).
- `warmup-iterations` — `N` (default `0`); run the thunk `N` times before the timed run.

`now-ns` returns a monotonic-clock value in nanoseconds; `now-cpu-ns` returns the CPU-time clock value.

### §3.2. Memory

```
[?def mem-snapshot  scope=public impure [returns element] () ...]
[?def gc-trigger    scope=public impure [returns null]    () ...]
```

`mem-snapshot` always carries the required `rss-bytes` and `timestamp` fields on every Tier-1 binding (§2.2). `gc-trigger` requests a GC cycle (best-effort; the underlying GC may decline).

### §3.3. Counters

```
[?def counter-inc    scope=public impure [returns null] ($name::string) ...]
[?def counter-add    scope=public impure [returns null] ($name::string $delta::int) ...]
[?def counter-get    scope=public impure [returns int]  ($name::string) ...]
[?def counter-reset  scope=public impure [returns null] ($name::string) ...]
[?def counter-all    scope=public impure [returns map]  () ...]
```

Named process-global monotonic counters. Atomically updated (safe under concurrent `[?async]` workers per [`spec/core/code.md`](../core/code.md)). `counter-all` returns a map of `name → current-value`. Reset only via explicit `counter-reset`.

### §3.4. Histograms

```
[?def histogram-observe  scope=public impure [returns null]    ($name::string $value::float) ...]
[?def histogram-stats    scope=public impure [returns element] ($name::string) ...]
[?def histogram-reset    scope=public impure [returns null]    ($name::string) ...]
```

- `histogram-observe` records one observation, creating the histogram on first observe.
- `histogram-stats` returns:

  ```cx
  [histogram-stats
    name="request-latency-ms"
    count=10432
    p50=8.1 p95=41.7 p99=88.0
    min=0.4 max=213.5 mean=12.6]
  ```

- `histogram-reset` discards observations; the name persists.

Histograms use an HDR (High Dynamic Range) estimator: observations are bucketed into exponentially-spaced buckets at a bounded relative error, so percentile queries are O(1) over the bucket array and memory is bounded regardless of observation count. Reported percentiles are accurate to within the estimator's relative-error bound.

Process-global and atomic/concurrent-safe (same lock-free CAS path as counters). `histogram-stats` on an unobserved name returns a zero-valued stats element (`count=0`) rather than raising. An out-of-range observation (NaN / ±Inf) raises `CXER2103`. This guard handles a non-finite float arriving across the FFI boundary; it is **not** reachable from pure CX arithmetic, which raises `CXER0101` first (CX floats are finite-only — see [`code.md`](../core/code.md) §6.5).

### §3.5. Trace events

```
[?def trace           scope=public impure [returns null] ($event::string $fields::map) ...]
[?def trace-flush     scope=public impure [returns null] () ...]
[?def prof-configure  scope=public impure [returns null] ($config::map) ...]
```

`trace` emits a structured event. Common field keys: `duration-ns`, `level`, `request-id`, `caller`.

`prof`'s trace emission **reuses the sink and formatting primitives of [`spec/std-lib/log.md`](log.md)** (the log sink layer and its `"text"` / `"json-lines"` / `"logfmt"` formatters). There is one sink/format implementation in the stdlib, shared between `log` and `prof`; `prof` MUST NOT carry a divergent copy. The two modules keep distinct public surfaces because their audiences and prod-lifecycle differ (`log` runs in production; `prof/trace` is disabled in production via `prof-configure`).

`trace-flush` flushes the buffer to the configured sink. Default sink is JSON-lines to stderr.

`prof-configure` config keys:

- `trace-sink` — `"stderr"` (default), `"stdout"`, `"file"` (uses `trace-file-path`), `"none"` (disable).
- `trace-file-path` — when `trace-sink="file"`, the path to write JSON-lines.
- `trace-buffer-size` — events buffered before auto-flush (default `1024`).
- `counters-enabled` — `true` (default) / `false`.

Unsupported `trace-sink` raises `CXER2100`. A `"file"` sink that can't be opened raises `CXER2101`. A non-callable `$thunk` to `time-fn` raises `CXER2102`.

### §3.6. Time-and-trace

```
[?def time-and-trace  scope=public impure [returns element] ($event::string $thunk::any) ...]
```

Times the thunk, emits a trace event with `duration-ns` set, and returns the same `[timing …]` element `time-fn` would.

### §3.7. Flamegraph emission

```
[?def flamegraph-emit  scope=public impure [returns string] ($path="") ...]
```

Shape the buffered trace events into `flamegraph.pl`-compatible folded-stack output. With a non-empty `$path`, the folded stacks are written to that file and the empty string is returned; with default `$path=""` the text is returned directly.

Each line is a semicolon-separated stack followed by a space and an integer weight:

```
main;handle-request;db-query 1240
main;handle-request;render 380
main;background-flush 92
```

Stacks are reconstructed from buffered events using each event's name and `caller` field (and `duration-ns` as the sample weight when present, else a unit weight). Events sharing a stack prefix are folded into one line with summed weights. Emission does not clear the buffer (call `trace-flush` separately to drain to the sink).

When the trace buffer holds no events, there are no stacks to fold; the result is the empty string `""` (the natural "zero lines joined" value, with no trailing newline).

## §4. Edge cases

- **Timer precision.** Microsecond on most platforms; nanosecond on Linux. Sub-microsecond measurements are unreliable — use `warmup-iterations` for fast operations.
- **Memory snapshot cost.** `mem-snapshot` may walk the heap; expect 1–10 ms. Don't call in hot loops.
- **Counter atomicity.** Lock-free CAS; safe under `[?async]` parallelism.
- **Trace ordering.** Events are buffered and flushed in insertion order. Crash before flush loses buffered events.
- **Production toggle.** `[$prof-configure {counters-enabled=false trace-sink="none"}]` disables side effects. Operations still return values (e.g. `time-fn` still measures) but counters and traces become no-ops.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2100` | `E_PROF_TRACE_SINK_INVALID` | `prof-configure` with an unsupported `trace-sink` |
| `CXER2101` | `E_PROF_TRACE_FILE_UNWRITABLE` | `trace-flush` with `trace-sink="file"` and target unopenable |
| `CXER2102` | `E_PROF_THUNK_NOT_CALLABLE` | `time-fn` with a non-callable `$thunk` |
| `CXER2103` | `E_PROF_HISTOGRAM_VALUE_INVALID` | `histogram-observe` with a non-finite value (NaN / ±Inf) — an FFI-boundary guard; not reachable from pure CX arithmetic (code.md §6.5) |

## §6. Conformance fixtures

Under `conformance/stdlib/prof.cxd`:

- `time-fn` returns a `[timing …]` with non-negative `elapsed-ms` and the thunk's return value at `result`.
- Wall vs CPU: a thunk that sleeps reports much higher wall than CPU.
- `now-ns` is monotonic across N successive calls.
- Counter atomicity: N concurrent `counter-inc("x")` workers; final `counter-get("x")` equals N.
- Counter reset / counter-all behave as specified.
- `time-fn` with `$opts={clock="cpu"}` returns a timing element measured against the CPU clock.
- Histogram percentiles: observing the integers 1..100 yields p50/p95/p99 within the estimator's tolerance band of the true percentiles; `count` equals the observation count.
- Histogram concurrent-observe atomicity: N workers; final `count` equals the total — none lost.
- Histogram unknown name: `histogram-stats("never-observed")` returns a zero-valued stats element.
- `mem-snapshot` always carries `rss-bytes` + `timestamp` on every Tier-1 binding.
- Flamegraph: after buffering events with `caller` chains, `flamegraph-emit` returns valid folded-stack output (`frame;frame;… <integer-weight>`).
- After `trace` calls + `trace-flush`, the sink contains JSON-lines.
- `prof-configure` disabling: `counters-enabled=false` makes `counter-inc` a no-op (verified by `counter-get` returning 0).
- Unknown trace sink raises `CXER2100`.

## §7. Capabilities

Effectful functions in `cx-stdlib/prof` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Only the timing reads consult the host clock and require `clock`. Counters, histograms, memory snapshots, GC control, flamegraph/trace emission, and configuration are in-process and need no capability.

| Capability | Functions |
|---|---|
| `clock` | `now-ns`, `now-cpu-ns`, `time-fn`, `time-and-trace`, `trace` |
| (none) | `counter-*`, `histogram-*`, `mem-snapshot`, `gc-trigger`, `flamegraph-emit`, `trace-flush`, `prof-configure` |

## §8. Cross-references

- [`spec/std-lib/time.md`](time.md) — `time/instant-now` underlies the wall clock.
- [`spec/std-lib/log.md`](log.md) — sibling concern (structured event emission); `prof` reuses log's sink / format layer internally while keeping a distinct surface.
- [`spec/core/code.md`](../core/code.md) — `[?async]` parallelism (for counter / histogram concurrency claims).
