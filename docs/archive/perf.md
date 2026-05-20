# CX performance baseline discipline

**v0.7.0 — T-row + V7 + Y6 row block**

This document codifies how CX measures, baselines, and gates
performance. It's the load-bearing reference for `spec/governance.md
§6.2` (regression gate) and `spec/v0_7_0_status.md §T / §V / §Y`.

## Methodology

### Per-PR regression gate (V7)

Every PR runs `make bench-streaming` and produces `bench.json` via
`scripts/run_bench_json.py`. `scripts/compare_bench.py` then
compares the run against the published baseline at
`bench/baseline.json`:

```sh
python3 scripts/compare_bench.py bench/baseline.json bench.json
# default threshold: 30% slowdown fails the job
# --strict: 10% slowdown fails the job
```

`.github/workflows/perf.yml` invokes this on every PR with the
default threshold and uploads `bench.json` as a 90-day-retention
artifact. The job runs as `continue-on-error: true` until a
runner-stable `bench/baseline.json` is published via the
workflow_dispatch `publish-baseline` path; once published, the
job moves to fail-on-regression.

### Per-feature budgets (T2)

`spec/governance.md §6.1.1` enumerates 12 `eval.*` bench keys
covering FLWOR clauses, fn invocations, partial application,
operator-token forms, pattern matching, and the regex family.
Each key has a documented relative-cost expectation; budgets are
relative to the baseline JSON for the same key (no absolute µs
pinning — runner image / CPU vary).

### Cross-binding parity (T3)

Each binding's `eval-v0-7-0` test corpus produces matched timings
that feed into a cross-binding dashboard. The V reference sets
the baseline; binding parity flags outliers > 2× V baseline.

### Memory profiling (T4)

`make bench-memory` runs the suite under tracemalloc (Python),
pprof (Go), `cargo flamegraph` (Rust), and `--inspect-heap` (Node)
to capture peak RSS + allocator churn for closure-heavy workloads.

### Adversarial-input (T6)

`fixtures/adversarial/` carries: deep-nested CX (1000 levels),
large sequences (`1 to 1_000_000`), pathological regexes (CXER0010
ReDoS coverage per U2). `make bench-adversarial` runs each through
the V reference + each binding's eval-v0-7-0 path and confirms
cap enforcement at the U-row thresholds (max_call_depth=256,
max_sequence_len=1M, max_map_entries=1M, max_capture_size=1024).

### Streaming throughput (T5 / Y6)

`make bench-streaming` runs `vcx/tests/runners/streaming_bench.v`
against `fixtures/bench/bench_medium.cx` and reports buffered +
streaming MB/s. The Y6 500 MB/s target is for an optimised V build
path (`-prod`); current measured throughput on an unoptimised V
build is ~1.7 MB/s.

**Dependency note (Y6).** The `-prod` build path on macOS triggers
a known V/macOS hardened-runtime issue (vlang/v#27178, vlang/v#27179
— tracked in K1/K2) where Boehm GC trampolines request rwx pages
that macOS denies. The vcx Makefile workaround strips `-prod` from
PROD_CFLAGS preserving `-Os -DNDEBUG`. The 500 MB/s steady-state
measurement awaits resolution of the upstream V issues; the harness
itself is ready and produces stable numbers on the unoptimised path
for relative-regression purposes.

### Comparative benchmarks (AA1-AA6)

`scripts/bench_comparative.py` runs CX vs JSON / YAML / TOML /
MessagePack / CBOR on the bench corpus and emits JSON for the
`docs/comparative_benchmarks_v0_7_0.md` report.

---

## Baseline lifecycle

1. **Initial baseline.** Maintainer runs `make bench-streaming`
   on a pinned runner image, saves the resulting JSON as
   `bench/baseline.json`, and commits via the workflow_dispatch
   `publish-baseline` action.

2. **Regression check.** Every PR runs the bench + compares.
   `bench.json` is uploaded as an artifact regardless of outcome.

3. **Baseline refresh.** When intentional perf-improving / perf-
   reducing changes land, maintainer runs the publish-baseline
   action to rotate the baseline. The decision criterion: the
   delta has been documented in the PR description and approved
   by a maintainer; passing the gate isn't sufficient when the
   delta is structural.

4. **Threshold tightening.** Default 30% threshold is for the
   v0.7.0 stabilization window — absorbs runner variance.
   Threshold tightens to 10% (`--strict`) once cross-runner
   variance is bounded; the date for this tightening is tracked
   in `spec/v0_7_0_status.md §T7`.

---

## V4 — Per-binding native-impl tracking

`tooling/binding_native_status.json` carries the per-binding
native-implementation dashboard: which v0.7.0 features each
binding's native path covers vs which still routes through the C
ABI. At v0.7.0 all 5 active bindings (V + Python + Go + Rust + TS)
stay C-ABI-passthrough; the dashboard tracks the v0.7.x / v0.8.0
native-port roadmap.

---

## V5 — Release artifact CI

`.github/workflows/release.yml` (run on tag push) produces:

- Signed binary tarballs per OS/arch
- `dist/SHA256SUMS.txt` checked into the release
- `cx-conformance-v0.7.0.zip` bundle (per S7)
- Uploaded to GitHub Releases

Triggers: `git tag v0.7.0` from `main`.

---

## V7 — Performance regression gate (status)

Current state:
- `scripts/compare_bench.py` enforces 30% default / 10% strict
  threshold per spec/governance.md §6.2
- `.github/workflows/perf.yml` runs nightly + on workflow_dispatch
- Uploads bench.json as 90d-retention artifact
- `continue-on-error: true` for the comparison step

Gating tightens to fail-on-regression once `bench/baseline.json`
is published via the workflow_dispatch publish-baseline path.
This is a maintainer action — runtime concern, not implementation
gap.
