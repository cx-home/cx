# conformance/code gate — authoritative failure triage (v0.8.0)

The `conformance/code` eval gate (`vcx/tests/code_eval_fixtures_test.v ::
test_all_code_fixtures_evaluate`, over `conformance/code.cxd`) is **enforced**
(`conformance/gates.cxd`). World-class bar: every enforced fixture either
**passes**, is **corrected to match the current spec**, or is **explicitly
moved to `gate=pending` with a reason** — no silent whitelist.

**Status: 103 → 58.** Resolved so far:
- `[?sleep DUR mock]` bareword (`7f406a85`): −21.
- `level=visualization` render-spec fixtures skipped from eval (validated by
  `code_diagram_roundtrip_test.v`), viz-022 → pending (`6dd5b8cb`): −21.
- `[$div]` int/int → integer division per §6.5 (impl bug, fixtures were right)
  (`<this commit>`): −3.

Remaining 58 failures, triaged below (fix order: fixture-invalid →
spec-decision → impl-gap → future-pending).

---

## Bucket 1 — fixture-invalid / miscategorized (false red — fix FIRST)

### 1a. Visualization render-spec fixtures evaluated as eval fixtures (17)
`level=visualization`, `in-code == out-text` (identity render) — these assert a
**structural render** of a directive (a diagram / policy badge), NOT an
evaluation. The eval runner executes them (e.g. `[?fallback …]` → "requires
recover-with") and fails. They belong in a **visualization render harness**
(`vcx/cmd/diagram.v`), not the code-eval gate.

`program-viz-001-for-pattern-tree`, `-002-match-alternative-branches`,
`-003-for-sequential-loop`, `-004-for-par-parallel-branches`,
`-005-map-par-parallel-branches`, `-006-if-alternative-branches`,
`-007-try-catch-recovery-branch`, `-008-retry-policy-badge`,
`-009-timeout-policy-badge`, `-010-circuit-breaker-policy-badge`,
`-011-fallback-policy-badge`, `-012-rate-limit-policy-badge`,
`-013-bulkhead-policy-badge`, `-015-worker-channel-send-receive`,
`-017-async-detached-swimlane`, `-018-await-all-barrier`,
`-019-cancel-arrow-barrier`.

→ **Action:** the eval runner should SKIP `level=visualization` (they are not
eval fixtures); a render-conformance run validates them via the diagram
renderer. Until that render harness exists, mark them `gate=pending` with
reason `render-spec`. **Decision needed:** build the render harness now, or
pending-with-reason for v0.8.0?

### 1b. Unbound-variable cases (~7)
`unbound variable $url` (×3), `$users` (×2), `$x`, `$node`. Likely a fixture
setup gap (a binding the program references is never `[?let]`-bound or wired
from `in-cx`/`doc`) OR a binding-scope evaluator issue. → **Investigate each**;
fix the fixture if it omits a binding, else file an eval scope gap.

---

## Bucket 2 — spec-decision-needed (decide before implementing)

### 2a. `[$div …]` numeric result — int vs true division (3)
`program-num-div-001-element-paren-args`, `-002-element-multi-args`,
`-003-xpath-call`: impl returns `2.5`, fixtures expect `2`. The spec must pin
whether `[$div a b]` over two ints is true division (`2.5`) or
integer/truncating (`2`, with `[$idiv]` as the explicit integer form). → **Spec
decision in code.md**, then correct impl or fixtures to match.

### 2b. CXPath predicate context-bindings — v0.8.0 scope? (11)
`pred-001`…`pred-011`: predicates using `$_@attr`, `$_position`, `$_last`
(e.g. `//user[$_@age >= 18]`, `//section/p[$_position = 1]`). Parser errors
`expected ']' closing CXPath predicate`. **Decision:** does v0.8.0 commit to
predicate context-bindings? If yes → Bucket 3 (parser+eval impl). If deferred →
Bucket 4 (pending with reason).

---

## Bucket 3 — implementation gap (spec is clear; impl missing)

- **CXPath predicate bindings (11, pred-\*)** — if 2b decides in-scope: parser
  must accept `$_`/`$_@attr`/`$_position`/`$_last` inside `[ … ]` predicates,
  and eval must bind them. `vcx/code/parser.v` (predicate body), `nav.v`.
- **`program-for-*` (6)** — `-005-sort-limit` (sort+limit ordering: got Carol,
  want Alice), `-006/-009` (`name()` raising on a multi-item sequence where the
  spec expects element selection), `-011` (attribute path step on non-element),
  `-014-pipe-sugar` (got 0, want 2), `-015-named-def-reuse`.
- **async / concurrency (6, program-async-*/conc-*)** — worker/await-all
  cancel-cause chaining: got an extra nested `[cause …]` the fixture's expected
  shape omits (e.g. `program-conc-012-worker-cancel`).
- **`program-def-*` (2–3)** — def / type enforcement gaps.
- **`program-fn-010-fn-not-serializable`** — expected `CXER0291`, got a raw
  `[__cx_closure__ …]`; a function value must be non-serializable (raise) rather
  than rendering its internal closure.
- **`module-transitive`** — needs an in-memory test module for
  `github.com/example/level-a` (test-harness module registration), not a live
  fetch.

---

## Bucket 4 — future-scope pending (explicit, with reason)

- **`modify :using` lambda** — `MODIFY_USING_LAMBDA_NOT_YET_IMPLEMENTED`
  (`modify_eval.v`): deferred to a later phase per the impl note. → `gate=pending`
  with reason.
- **`program-with-error-hook-001`** — `[?with-error-hook] not in pure-functional
  evaluator subset`: effectful hook; confirm whether v0.8.0 ships it or defers.

---

## Adjacent (P1, separate from the 82 — implementation phase)

- **Capability enforcement** — wire `CXER0271` at every effect point
  (env/time/random/crypto/uuid/io/process/store/prof/test). The 156 advisory
  denial fixtures are the worklist; cap-check must precede type/domain/host
  errors. Promote modules to `enforced` as enforcement lands.
- **Capability-granted harness** — second runner mode (temp dirs, fixed env,
  mock clocks, deterministic subprocesses, local services) for the
  behavior lane (the 127 denial-only + 5 pending functions).
