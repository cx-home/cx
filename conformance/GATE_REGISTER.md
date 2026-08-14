# The living gate register (Q5a re-home; #805 gate-truth batch)

Authored 2026-08-13 per the I5 adversarial audit's AF-4 finding and
the owner's Q5a ruling: the gate registry lived only in an archived
status document, so budget-bearing gates rotted invisibly for months
(gates 7/8/14/15/16/30.5, bench-eval, bench-compare, gate 4). This
register is the SINGLE in-tree map: every numbered gate → runner →
threshold → wiring → last honest verdict.

**Maintenance contract:**
- A gate repair, retirement, threshold ruling, or fresh manual verdict
  UPDATES ITS ROW IN THE SAME COMMIT.
- Wiring classes: `matrix` = runs inside `make test` (every stream
  gate exercises it — its row needs no manual freshness); `manual` =
  operator-run lane (bench-*); a manual row's verdict OLDER THAN THE
  CURRENT RELEASE is itself a red (the audit's freshness rule).
- Reds stay honest: a red row names its tracking issue, never a
  softened threshold. Skipping a gate silently is FORBIDDEN (owner
  rider, 2026-08-13): a missing tool or dead runner is a loud RED.
- Fixture-level gate toggles (enforced/advisory per module/case) are
  `conformance/gates.cxd`'s jurisdiction, not this register's.

| gate | what / budget | runner / entry | wiring | last honest verdict |
|---|---|---|---|---|
| 1–3 (spec) | code.md completeness / consistency / companion alignment | `make check-code-spec-consistency` (`scripts/check_code_spec_consistency.py`) | matrix | GREEN (every stream gate) |
| 4 (coverage) | every directive × param × CXER code covered by the corpus | `make check-code-fixtures` (`scripts/check_code_fixtures.py`) | **matrix** (wired by #805 — was orphaned + red) | GREEN 2026-08-13 (coverage ENFORCED; CXER0280/4113 = visible debt → #808) |
| 5 (resilience matrix) | 67 resilience fixtures green | `make test-vcx-resilience-matrix` (code_eval_fixtures_test.v) | matrix | GREEN (every stream gate) |
| 6 (services) | service + client round-trip fixtures | `make test-vcx-services` (code_eval_fixtures_test.v) | matrix | GREEN (every stream gate) |
| 7 (soak) | zero deadlocks / leaks; 30 s smoke default, 24 h via `GATE7_DURATION_SEC=86400` | `make bench-code-soak` (code_concurrency_soak.v) | manual | **PASS 2026-08-13** — 100,000 iters, 0 deadlocks, max iter 9–19 ms (`_gate_evidence/gate_7.log`; repaired by #805 — was unrunnable on retired spellings) |
| 8 (cancel battery) | 10 K cancellations, zero non-deterministic failures | `make bench-code-cancel` (code_async_cancel_battery.v) | manual | **PASS 2026-08-13** — 10,000/10,000, 0 hard errors (`_gate_evidence/gate_8.log`; repaired by #805 — was 10,000/10,000 hard errors) |
| 9 (diagram) | SVG/PNG/Mermaid reverse-parse equality | `make test-code-diagram` | matrix | GREEN (every stream gate) |
| 10–13 (impl) | no stubs; bindings parity; docs; installer | `make test` composite (check-no-stub-impl, binding suites, guide-check, …) | matrix | GREEN (every stream gate) |
| 14 (pattern compile) | p99 ≤ 1 ms, depth-8/32-binding, ≥ 1000 samples | `make bench-code-pattern-compile` (code_pattern_compile_bench.v) | manual | PASS 2026-08-13 (s17 W6: p99 0.3 ms; repaired off retired spellings) |
| 15 (streaming) | ≥ 200 MB/s JSON-shape eval throughput | `make bench-code-streaming` (code_streaming_throughput_bench.v) | manual | **RED (honest) → #804** — ~2 MB/s; floor stands, never trued (s17 W5/W6; #805 profile: allocation-bound) |
| 16 (HTTP service) | ≥ 10 K req/s AND p99 ≤ 10 ms, wrk c=64, 3-min steady state | `make bench-code-http` (code_http_throughput_bench.v) | manual | **PASS 2026-08-13** — 145,204 req/s, p99 2.52 ms over the FULL 180 s steady state (`_gate_evidence/gate_16.log`). Protocol OWNER-RULED (b): the spec'd wrk form stands; missing wrk = loud RED (the in-process substrate form is superseded — it measured evaluator dispatch at ~16 K rps, the real listener runs ~145 K) |
| 17 (playground) | wasm playground smoke | `make verify-playground-examples` | matrix | GREEN (browser-level verification still self-reports "pending Phase 7" — honest limitation) |
| 28.5 (Saxon parity) | XSLT/XPath byte parity | docker lane | manual | env-dead on the dev host (Docker creds hang — reference_docker_creds_hang_bypass); last verdict pre-I5 |
| 28.6 / 28.9 (binding parity) | byte-identical V/Py/Go/Rust | binding suites (`make test-python` / `test-go` / `test-rust`) | matrix | GREEN 51/51 (audit re-ran) |
| 28.11–28.14 | per-decision-record acceptance assertions for [?def]/[?lib]/[expr]/purity | — | **RETIRED (Q5a, 2026-08-13)** | EVAPORATED with the archived status doc; asserting acceptance against ARCHIVED records contradicts the spec-is-single-source model. The BEHAVIORAL surface is fully covered: gate 4 (now enforced) pins directive×error coverage; the [?def]/[?lib]/purity fixture families are enforced corpus rows. Re-assertion would need new spec-anchored (not record-anchored) criteria — file an issue if ever wanted |
| 30.5 (modify sharing) | single-set < 1 KB; 1000-match < 100 KB (scaled); sharing-ratio; identity | `make bench-code-modify-sharing` (code_modify_sharing_bench.v; envelope: `GATE305_DEPTH=8 GATE305_FANOUT=4 GATE305_ENFORCE_ABSOLUTE=1`) | manual | **RED (honest) → #803** — sharing itself is fine (spine applies = 49 KB; identity PASS); the match/render machinery busts the budget (render leg fixed in #805 — envelope single-set 291→181 MB; machinery diet in flight). Evidence `_gate_evidence/gate_30.5.log` |
| T1 (bench-eval) | evaluator-feature medians feed the regression channel | `make bench-eval` (eval_features_bench.v) | manual (feeds bench-compare) | RUNS 2026-08-13 (repaired by #805 — was panicking on retired spellings); medians in `bench/baseline.json` |
| bench-compare | ≤ 30% (default) / ≤ 10% (strict) regression vs baseline | `make bench-json` + `make bench-compare` (`scripts/run_bench_json.py --include-eval`, `compare_bench.py`) | manual | ALIVE 2026-08-13 — `bench/baseline.json` @ 88f6bea6 (12 keys); self-comparison green |
| abi §4 | conversion budgets (abi.md §4 ten-cell table) + `cx_events_next` < 1 µs | `make bench-abi-s4` (abi_s4_bench.v) | manual | **RED (honest) → #804** — first measurement in project history (#805/AF-6): six conversion cells 7.9–16.7× over; events_next PASS at ~9 ns (`_gate_evidence/abi_s4.log`) |
| feature-mask agreement | cx_features bit ⇔ shipped surface, both directions | `vcx/tests/feature_mask_agreement_test.v` | matrix (test-vcx-suite) | GREEN 2026-08-13 (authored by #805/#802) |
