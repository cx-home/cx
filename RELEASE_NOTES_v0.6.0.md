# CX v0.6.0 — Release Notes
# Date: TBD
# Branch: native-data-binding (merged → main)

The first release after the [2026-05 binding audit](spec/binding_audit_2026.md).
Closes 5 systemic findings (CB-1..CB-5) at the V core *and* across all 9
FFI bindings (Python, Go, Rust, TypeScript, Java, Kotlin, Swift, C#, Ruby).
Also adds the canonical-form tooling C ABI (cx_fmt / cx_canonical /
cx_hash / cx_eq) and propagates it through every binding.

> **TL;DR for end users:** integer types now round-trip correctly through
> `loads()` / `dumps()` and `02134` is now a string. See
> [`MIGRATION.md`](MIGRATION.md) for both BREAKING changes and the v3.4
> opt-in additions.

> **TL;DR for binding maintainers:** the audit closes 5 systemic
> shortcuts via new C ABI symbols. ~3970 LOC of duplicated CXPath code
> deleted across the 9 in-tree bindings. If you maintain a third-party
> binding, follow the per-binding checklist in [`MIGRATION.md`](MIGRATION.md) §4.

---

## Highlights

### BREAKING: leading-zero integers are now strings

Source like `[zip 02134]` parses as a string in v3.4 (was `int 2134` in
v3.3, with the leading zero silently dropped). Affects ZIP codes,
zero-padded IDs, area codes. Detection regex and migration in
[`MIGRATION.md`](MIGRATION.md) §1.

### BREAKING: `loads()` / `dumps()` preserve integer / float distinction

The v3.3 detour through `cx_to_json` + native JSON parser silently
coerced integers to floats. v3.4 routes through the new CXDB v1 binary
format, so integer-typed values stay integer-typed in every binding.

```python
# v3.3
loads(dumps({"port": 8080}))["port"]  # 8080.0  (float — wrong)

# v3.4
loads(dumps({"port": 8080}))["port"]  # 8080    (int — correct)
```

Per-binding type tables in [`MIGRATION.md`](MIGRATION.md) §2.

### NEW: canonical-form tooling (`fmt` / `canonical` / `hash` / `eq`)

Four convenience functions in every binding, plus matching CLI
subcommands on the `cx` binary:

| binding   | API                                                    |
| --------- | ------------------------------------------------------ |
| Python    | `cx.fmt(s)` / `cx.canonical(s)` / `cx.hash(s)` / `cx.eq(a, b)` |
| Go        | `cxlib.Fmt(s)` / `.Canonical(s)` / `.Hash(s)` / `.Eq(a, b)`     |
| Rust      | `cxlib::fmt(s)?` / `::canonical(s)?` / `::hash(s)?` / `::eq(a, b)?` |
| TypeScript| `fmt(s)` / `canonical(s)` / `hash(s)` / `eq(a, b)` (named exports) |
| Java      | `CxLib.fmt(s)` / `.canonical(s)` / `.hash(s)` / `.eq(a, b)` |
| Kotlin    | `CxLib.fmt(s)` / `.canonical(s)` / `.hash(s)` / `.eq(a, b)` |
| Swift     | `try CXLib.fmt(s)` / `.canonical(s)` / `.hash(s)` / `.eq(a, b)` |
| C#        | `CxLib.Fmt(s)` / `.Canonical(s)` / `.Hash(s)` / `.Eq(a, b)` |
| Ruby      | `CXLib.fmt(s)` / `.canonical(s)` / `.hash(s)` / `.eq(a, b)` |

```sh
$ cx fmt config.cx          # lossless canonical (preserves comments)
$ cx canonical config.cx    # strict canonical (data only)
$ cx hash config.cx         # 64-char SHA-256 hex
$ cx eq a.cx b.cx           # exit 0 if data-equivalent, 1 if not
```

`fmt` is idempotent. `canonical`/`hash`/`eq` are byte-stable across
runs and across bindings — the same input produces the same hash in
any language. Use cases: signed config bundles, content-addressable
storage, deduplication keyed on data not file bytes.

### Audit closure: 5 findings, 9 bindings, ~3970 LOC removed

| ID | what was wrong | core symbol(s) | per-binding LOC delta |
| -- | --------------- | --------------- | --- |
| CB-1 | `to_<fmt>` re-emit detour      | `cx_ast_bin_to_<fmt>` ×6              | (re-routed; no large LOC delta) |
| CB-2 | `parse_<fmt>` JSON-AST re-parse | `cx_<fmt>_to_ast_bin` ×5              | (re-routed) |
| CB-3 | `loads`/`dumps` JSON detour    | `cx_to_data_bin` / `cx_from_data_bin` | new CXDB codec per binding (~3500 LOC added) |
| CB-4 | fake streaming                  | `cx_events_open/next/close`           | new EventStream per binding |
| CB-5 | CXPath parser duplication       | `cx_select_all_paths`                 | **~3970 LOC removed** |

Net: parser/evaluator code in bindings is gone; type-fidelity codec
code is added; the trade is fewer drift surfaces and one place to
fix bugs (V core).

Full per-binding commit list and verification details:
[`spec/binding_audit_2026.md`](spec/binding_audit_2026.md).

### Other v3.4 grammar additions (non-breaking)

- `:table` blocks for tabular data.
- Sized scalar types: `i8`, `i16`, `i32`, `i64`, `u8`..`u64`, `f16`, `f32`, `f64`, `decimal`, `bigint`.
- Numeric underscores: `9_223_372_036_854_775_807`, `0xCAFE_BABE`.
- Boolean attribute sigils: `[user +admin -disabled name=alice]`.
- Line comments: `# to end of line`.
- logfmt mode: top-level `key=value` documents.
- Triple-quoted strings: `'''multi-line content'''`.

All of the above are documented in [`MIGRATION.md`](MIGRATION.md) §3.

---

## Compatibility

- **C ABI**: backward compatible. Every v3.3 symbol still exists. New
  symbols added: `cx_ast_bin_to_<fmt>` ×6, `cx_<fmt>_to_ast_bin` ×5,
  `cx_to_data_bin` / `cx_from_data_bin`, `cx_events_open` /
  `cx_events_next` / `cx_events_close`, `cx_select_all_paths`,
  `cx_fmt` / `cx_canonical` / `cx_hash` / `cx_eq`. Bumps ABI v1 → v2;
  see `cx_abi_version()` and `cx_features()` for runtime detection.
- **Bindings**: backward compatible at the API level. `loads()` /
  `dumps()` return type-fidelity-preserving values now (integers stay
  integer); only type-strict assertions in user code may need updates.
- **Source documents**: one BREAKING grammar change (leading-zero
  integers); see [`MIGRATION.md`](MIGRATION.md) §1.

---

## Verification

Aggregate test runs across the 9 bindings (post-v3.4 closure):

| binding    | test files                             | total | failures |
| ---------- | -------------------------------------- | ----- | -------- |
| Python     | api + cxpath + transform + immutability + stream + conformance | 275 | 0 |
| Go         | go test (parallel)                     | ok    | 0 |
| Rust       | cargo test --test-threads=1            | 105   | 0 |
| TypeScript | api_test + conformance                 | 231   | 0 |
| Java       | mvn test (ApiTest + ConformanceTest)   | 117   | 0 |
| Kotlin     | gradle test (3 suites)                 | 131   | 0 |
| Swift      | swift test (ApiTests + ConformanceTests) | 116+conformance | 0 |
| C#         | dotnet test (api_test + conformance)   | 169+conformance | 0 |
| Ruby       | test_api.rb + conformance.rb           | 113+conformance | 0 |

Plus 11 V-core suites including new `v34_select_all_paths_test.v` and
`v34_tooling_test.v`. No test was disabled, skipped, or weakened to
land any phase.

---

## Per-registry release notes

Bindings ship to:

- **PyPI** — `pip install cxlib==0.6.0`
- **crates.io** — `cargo add cxlib@0.6`
- **npm** — `npm install @cx-home/cx@0.6.0`
- **Maven Central** — `io.cxhome:cxlib:0.6.0`
- **Gradle/Kotlin** — `io.cxhome:cxlib:0.6.0` (same artifact)
- **NuGet** — `dotnet add package CX --version 0.6.0`
- **RubyGems** — `gem install cxlib -v 0.6.0`
- **Swift Package Manager** — `https://github.com/cx-home/cx`, `from: "0.6.0"`
- **Go modules** — `go get github.com/cx-home/cx/lang/go@v0.6.0`

All artifacts statically link or dynamically link `libcx.dylib` /
`libcx.so` / `libcx.dll` (per platform). `libcx` itself is shipped
through `make install` from the source repo and via OS package
managers (planned: Homebrew, apt, dnf, pacman post-v0.6.0).

See [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md) for the
multi-registry release sequence (V core first, then libcx binaries,
then bindings in dependency order).

---

## Acknowledgments

The audit was conducted by the project lead with paired review by
Claude Opus 4.7 over the `native-data-binding` branch. All commits
attributed via `Co-Authored-By:`. The systematic per-binding closure
(Phases 3, 4, 5) and the canonical-form tooling layer (Phase 6) are
the result of that review.
