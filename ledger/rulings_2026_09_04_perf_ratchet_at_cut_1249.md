# Ruling record — #1249 no live perf measurement between cuts (2026-09-04)

Issue: #1249 (enhancement, area:tooling, prio:medium, perf). Process spec: `spec/03-approved/process/release-process.md` §2 (phases).

## The gap

`.github/workflows/perf.yml` runs `make bench-streaming` against `bench/baseline.json` with a 30 % threshold — on
`workflow_dispatch` only ("nightly cron removed so it stops failing red"). Nothing measures throughput between
cuts. `ledger/partition_I5_audit.md` records the consequence once already: streaming fell from 353 MB/s to ~2 MB/s
across eight releases with the 200 MB/s budget unmeasured the whole time. The two in-`make test` guards
(`bench/repr` live ratio, `bench/rowset` scaling ratios) are RATIOS by design and cannot see a constant-factor
loss. The pieces for a local ratchet already exist: `make bench-json` (scripts/run_bench_json.cx →
`bench/current.json`: the streaming pair + the eval micro set), `make bench-compare STRICT=1`
(scripts/compare_bench.cx, 10 % threshold), and a committed `bench/baseline.json` (captured 88f6bea6).

## Question 1249-Q1 — where does the throughput measurement live?

- **(a) RULED — a perf-ratchet phase in the cut itself, runner-independent.** `scripts/tag_release.sh` runs
  `make perf-ratchet` right after `make test` + `make verify-doc-links` and before the bump:
  `bench-json` → `bench-compare STRICT=1` against the committed baseline; any benchmark slower than the previous
  cut by more than 10 % ABORTS the cut (same standing as a red gate). On green, the fresh `bench/current.json`
  REPLACES `bench/baseline.json` in the bump commit, so every cut re-pins the floor to its own measurement — a
  ratchet, like `bench/repr`. The baseline records `cx_commit`; the maintainer machine (the M-series box the
  original baseline came from) is the measurement platform, stated in release-process.md. Also folds the gate-15
  `[?for]`/`[?map]` MB/s (`make bench-code-streaming`) into `run_bench_json.cx` so the number the audit lost is the
  one the ratchet watches. DELETES: nothing; perf.yml stays dispatch-only until runners exist.
- (b) re-enable the nightly cron — needs a runner that does not exist; the cron was removed for failing red on
  the hosted ones, and a nightly on a different machine measures a different floor than the cut's.
- (c) leave it to the audits — that is the eight-release gap the ledger already recorded.

Ruled (a) under the standing letter-acceptance order (campaign authority 2026-09-04). Id: **1249-Q1a**.

## Execution record

- Makefile: `perf-ratchet` target (bench-json, then bench-compare STRICT=1; prints the table; exit 1 on a
  regression) — a decision instrument the cut runs, NOT a `TEST_TARGETS` member (it is wall-clock and machine-bound;
  `make test` stays deterministic).
- `scripts/tag_release.sh`: runs `make perf-ratchet` after the gate; `--dry-run` confirms the target exists; on
  green copies `bench/current.json` → `bench/baseline.json` so the bump commit carries the new floor.
- `scripts/run_bench_json.cx`: gains `code_streaming.for_mbps` / `code_streaming.map_mbps` parsed from
  `make bench-code-streaming`; compare_bench treats a `_mbps` key as higher-is-better.
- release-process.md §2: phase "1b — Perf ratchet" row.
