# `cx-stdlib/test` — assertion and fixture helpers

```cx
[module-meta name=test tier=C status=current]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/test` sub-package.

---

## §1. Scope

`cx-stdlib/test` provides authoring primitives for unit-test-style programs written in CX: assertions, fixtures, lifecycle hooks, structured reporting. This is the vocabulary application authors use when writing test programs of their own (e.g. `test/order_processing.cx`); it is **not** the conformance harness ([`spec/core/code.md`](../core/code.md) §11), which is the implementer's harness for verifying the spec.

## §2. Conceptual model

### §2.1. Assertions

Assertions check predicates and report failures with an optional label.

```cx
[?def test-user-creation
  ()
  [?let [= $u [$user:create "alice" "alice@example.com"]]
    [$test:assert [= $u/email "alice@example.com"] $label="email round-trip"]
    [$test:assert-equal $u/name "alice"]
    [$test:assert-shape $u $LEAD_SCHEMA]]]
```

Failure raises `CXER2200 E_TEST_ASSERTION_FAILED` (default) or accumulates per `configure` (§3.4).

### §2.2. Fixtures

Fixtures are named, lazy test values:

```cx
[?const $ALICE [$test:fixture "alice"
  [user id=1 email="alice@example.com" name="Alice"]]]
```

### §2.3. Test discovery

The module defines the **vocabulary**; the test runner is the CLI's job (`cx test`). Functions matching `test-*` are discovered. A test passes if it returns without raising.

### §2.4. Parameterized tests

A `test-*` function may carry a `$cases` parameter whose value is a sequence of `[case …]` elements; each `[case]` binds the test's positional parameters for one run:

```cx
[?def test-normalize
  ($cases=[sequence
    [case "Alice"  "alice"]
    [case "  bob " "bob"]
    [case "CAROL"  "carol"]])
  ($input::string $expected::string)
  [$test:assert-equal [$normalize $input] $expected]]
```

The runner reports **one result per case** (`test-normalize[0]`, `test-normalize[1]`, …). Lifecycle hooks fire per case: `before-each` → case → `after-each`.

## §3. Public function surface

### §3.1. Assertions

```
[?def assert            scope=public impure [returns null] ($predicate::bool $label="") ...]
[?def assert-equal      scope=public impure [returns null] ($actual::any $expected::any) ...]
[?def assert-not-equal  scope=public impure [returns null] ($actual::any $not-expected::any) ...]
[?def assert-shape      scope=public impure [returns null] ($value::any $schema::element) ...]
[?def assert-throws     scope=public impure [returns null] ($thunk::any $err-code::string) ...]
[?def assert-near       scope=public impure [returns null] ($actual::float $expected::float $epsilon::float) ...]
[?def assert-contains   scope=public impure [returns null] ($haystack::any $needle::any) ...]
[?def assert-match      scope=public impure [returns null] ($value::any $pattern::element) ...]
[?def assert-snapshot   scope=public impure [returns null] ($value::any $snapshot-key="") ...]
[?def fail              scope=public impure [returns null] ($message::string) ...]
[?def skip              scope=public impure [returns null] ($reason::string) ...]
```

- `assert` — fail if `$predicate` is false; `$label` appears in the failure message.
- `assert-equal` / `assert-not-equal` — CXDM structural equality (per [`spec/core/cxdm.md`](../core/cxdm.md)).
- `assert-shape` — fail if `[$validate:validate-shape $value $schema]` returns `[err …]`.
- `assert-throws` — fail unless `$thunk` raises an error with `$err-code`.
- `assert-near` — fail if `|$actual - $expected| > $epsilon`.
- `assert-contains` — substring (string), element membership (sequence/array), key presence (map).
- `assert-match` — fail unless `$value` matches the CX pattern (per `[?match]`).
- `assert-snapshot` — compare `$value` against a recorded snapshot under `__snapshots__/` (resolved relative to the test program, or `$snapshot-dir` from §3.4). Update mode is engaged via `CX_TEST_UPDATE_SNAPSHOTS=1`: first-run records and passes; subsequent runs compare and raise `CXER2203 E_TEST_SNAPSHOT_MISMATCH` on divergence with a recorded-vs-actual diff. Snapshots are stored in canonical CX-data form.
- `fail` — unconditional failure.
- `skip` — mark current test skipped; reported separately from pass/fail.

### §3.2. Fixtures

```
[?def fixture       scope=public pure   [returns element] ($name::string $rest::any) ...]
[?def fixture-load  scope=public impure [returns any]     ($path::string) ...]
```

`fixture` collects the trailing body elements as a sequence value tagged with `$name` for reporting. `fixture-load` loads from a path resolved against `$fixture-dir` (§3.4) or the test program's location.

### §3.3. Lifecycle hooks

```
[?def before-each scope=public impure [returns null] ($thunk::any) ...]
[?def after-each  scope=public impure [returns null] ($thunk::any) ...]
[?def before-all  scope=public impure [returns null] ($thunk::any) ...]
[?def after-all   scope=public impure [returns null] ($thunk::any) ...]
```

Runner order: `before-all` once per module → for each test (or each case under §2.4): `before-each` → test → `after-each` → `after-all` once per module.

### §3.4. Configuration

```
[?def configure scope=public impure [returns null] ($config::map) ...]
```

Keys (all optional):

| Key | Default | Effect |
|---|---|---|
| `on-fail` | `"raise"` | `"raise"` aborts the test on first failure; `"collect"` accumulates and reports at end. |
| `reporter` | `"plain"` | One of `"tap"` / `"junit"` / `"json"` / `"plain"`. |
| `fixture-dir` | test-program dir | Base path for `fixture-load`. |
| `snapshot-dir` | `__snapshots__/` next to the test program | Base path for `assert-snapshot`. |

### §3.5. Mocking

Mocking external effects is done with the **per-directive `$mock` flag**: effectful directives (`[?http-client]`, `cx-stdlib/io` file operations, time sources per [`spec/std-lib/time.md`](time.md)) accept a `$mock` flag plus a mock specification that substitutes a recorded response for the real effect.

## §4. Edge cases

- **Float comparison** — `assert-equal` uses exact equality; use `assert-near` for floats.
- **Sequence with floats** — element-wise `assert-equal` will use exact float equality; iterate with `assert-near`.
- **Map equality** — `assert-equal` on maps is set-of-pairs equality; convert to a sequence to assert insertion order.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2200` | `E_TEST_ASSERTION_FAILED` | Any assertion failing |
| `CXER2201` | `E_TEST_FIXTURE_LOAD` | `fixture-load` on missing or unparseable file |
| `CXER2202` | `E_TEST_SKIPPED` | `skip` (catchable by the runner) |
| `CXER2203` | `E_TEST_SNAPSHOT_MISMATCH` | `assert-snapshot` divergence outside update mode |

## §6. Conformance fixtures

Under `conformance/stdlib/test.cxd`:

- `assert(true)` returns; `assert(false)` raises `CXER2200`.
- `assert(false $label="round-trip")` includes the label in the failure message.
- `assert-equal` failure message contains both `$actual` and `$expected`.
- `assert-near(1.0001 1.0 0.001)` passes; `assert-near(1.01 1.0 0.001)` fails.
- `assert-throws` positive and negative paths.
- `assert-contains` for substring and element membership.
- `assert-shape` integrates with `[$validate:validate-shape]`.
- `assert-snapshot` first-run records and passes; second-run matches; third-run with mismatched value raises `CXER2203`.
- Parameterized: `test-*` with `$cases` runs once per case and reports per-case results.
- `fixture-load` loads from a sibling file.
- `before-each` / `after-each` invoked in declared order.
- `configure({on-fail "collect"})` accumulates failures.
- `skip("not on windows")` propagates `CXER2202`.

## §7. Open follow-ups

- **Property-based testing.** Generator + shrinking engine; deferred.
- **Unified mock-test layer.** Centralized mock registry over the per-directive `$mock` capability; deferred.
- **Coverage reporting.** Instrumentation surface; deferred.

## §8. Capabilities

Effectful functions in `cx-stdlib/test` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Assertions and lifecycle hooks operate on in-memory test state and need no capability. Only loading a fixture from disk requires `read`.

| Capability | Functions |
|---|---|
| `read` | `fixture-load` |
| (none) | `assert*`, `before-*`, `after-*`, `fail`, `skip`, `configure` |

## §9. Cross-references

- [`spec/std-lib/validate.md`](validate.md) — `assert-shape` integrates with `validate-shape`.
- [`spec/core/code.md`](../core/code.md) §11 — conformance harness (distinct from this module).
- [`spec/std-lib/prof.md`](prof.md) — sibling measurement module.
