# CX Per-binding Parity Matrix

- **Status:** Authoritative as of 2026-05-09 (Phase 7.74c-conformance-runner — `conformance/data_bin_arrow.txt` (14 cases, 13 active + 1 pending) now wired into V `make conform` via a dedicated runner that exercises CXDB → Arrow → CXDB round-trip identity through `libcx_arrow` for all 10 supported v0.6.0 column types. Locks the Arrow bridge into the regression net before V-core feature work resumes. Per the binding tiering decision (2026-05-09), the 4 remaining 📋 ᵈ Arrow cells (V cffi, TS, Swift, Ruby) are deferred to post-v0.6.0; per-binding rollouts paused at 7/11.)
- **Governs:** [`spec/governance.md §2`](governance.md) — *every public
 binding API must produce byte-identical canonical-form output as the
 V reference, on every fixture in the conformance suite. Drift is a
 release blocker.*
- **Closes:** 
 row "Per-binding parity matrix".

---

## 1 — Scope

This document is the *writeup* of the parity matrix that
[`spec/governance.md §2`](governance.md) makes load-bearing. Section 2
defines the rule (byte-identical canonical-form output across all
bindings on every conformance fixture); this document records the
actual state of compliance — what each binding ships, what it tests,
what's documented, and where divergences are expected.

There are two parity questions, and both are tracked here:

- **Output parity (the §2 rule).** For an identical input, every
 binding emits identical canonical-form bytes. This is the
 load-bearing property: it's the only mechanically verifiable
 definition of "no major gaps."
- **Idiomatic API parity.** The shape of the public API differs
 per language (Python uses dicts, Rust uses typed enums, Go uses
 CamelCase) but the *capability set* is uniform. A user who knows
 what `loads` / `parse` does in one binding can find the equivalent
 in any other.

The two are independent: a binding can have idiomatic API divergence
(Python `parse()` vs Go `Parse()`) and still pass output parity.
What's not allowed is *capability* divergence — a binding that lacks
CXPath, or that returns different canonical bytes for the same input.

---

## 2 — Capability matrix

Rows are capabilities; columns are the ten binding implementations.
`✓` = implemented + documented in README; `(✓)` = implemented in source
but README documentation pending; `—` = not applicable to this binding.

| capability | V (native) | V (cffi) | Python | Go | Rust | TypeScript | Java | Kotlin | Swift | C# | Ruby |
| ----------------------------------- | ---------- | -------- | ------ | ----- | ----- | ---------- | ----- | ------ | ----- | ----- | ----- |
| Parse CX text | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Parse XML / JSON / YAML / TOML / MD | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Emit canonical CX | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Emit XML / JSON / YAML / TOML / MD | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Document / Element traversal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Mutation API (set_attr / append / …)| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Immutable transform API | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CXPath — `select` / `select_all` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Streaming parse (event iterator) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `:table` block — read | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `:table` block — write (Table API) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) |
| `data_bin` one-shot loaders/dumpers | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Chunked-table one-shot (`cx_to_data_bin_chunked`, post- D1/D8) | ✓ | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) |
| Streaming Table reader / writer (post- D8) | ✓ | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) |
| Schema-driven CXDB encoding (post- D3) | ✓ | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) | (✓) |
| Arrow C-Data interop (`libcx_arrow`, post- D9) | ✓ | 📋 ᵈ | ✓ | ✓ | ✓ | 📋 ᵈ | ✓ | ✓ | 📋 ᵈ | ✓ | 📋 ᵈ |
| `fmt` (lossless canonical) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `canonical` (strict canonical) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `hash` (SHA-256 of strict) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `eq` (data equivalence) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `version()` accessor | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Native dict/list `loads` / `dumps` | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Schema validate (post-) | ✓ | 📋 | ✓ | ✓ | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |
| `cx diff` (post-) | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |
| `cx lint` (post-) | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |
| Streaming write (post-) | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |
| Namespaces (post-) | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |
| ID/IDREF (post-) | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |
| Output-shape control (post-)| 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 | 📋 |

Legend: `✓` = shipping at parity; `(✓)` = implementation present, README
update pending; `—` = not applicable; `📋` = post-design, pre-implementation
`📋 ᵈ` = explicitly deferred to post-v0.6.0 per the
binding tiering decision (2026-05-09) — see Tier 3 in
[`memory/project_binding_tiers_v0_6_0.md`] (Tier 3 covers V cffi /
TypeScript / Swift / Ruby; these catch up after the v0.6.0 tag while
Tier 1 (V/Python/Go) and Tier 2 (Rust/C#/Java) remain release-aligned
at parity).

### 2.1 Notable parity rows

- **`data_bin` one-shot loaders/dumpers.** Phase 7.28 added 10 C ABI
 symbols (`cx_<fmt>_to_data_bin` × 5 + `cx_data_bin_to_<fmt>` × 5)
 to V core. Phases 7.30–7.38 wired them through every FFI binding.
 Phase 7.45 (2026-05-08) added the `### data_bin one-shot conversions
 (v3.4)` section to all 9 binding READMEs — entry points are now
 documented for every shipping binding, naming follows each
 language's idioms (snake_case for Python/Rust/Ruby; CamelCase for
 Go/Java/Kotlin/TypeScript; PascalCase for Swift/C#).

- **Public Table API write surface.** Read-side (`get`, `cell`,
 iteration) is shipping in every binding. Write-side (`row()`,
 `column()`, `slice()`, `head()`, `tail()`, `select()`, plus the
 five conversions and four properties documented in
 `spec/table_api.md`) is still being lifted from prototype into
 shipping API. Listed `(✓)` because parts are usable; full parity
 closes in v0.6.0 per the readiness rubric §3. Phase 7.46 (2026-05-08)
 renamed the field from `columns` → `cols` (and `column_count` →
 `col_count`, `iter_columns` → `iter_cols`) in the V core and the
 spec; the rename is binding-API-level, the text grammar and CXDB
 wire format are unchanged.

- **Schema, diff, lint, streaming write, namespaces, ID/IDREF,
 output-shape control.** All marked `📋` because design is
 committed ( / 0012 / 0013 / 0011 / 0002 / 0003 / 0010
 respectively) but no binding implements them yet. The 📋 marker
 means "scheduled for v0.6.0"; ⚠ would mean "release-blocking but
 unscheduled."

- **Chunked-table one-shot / Streaming Table / Schema-driven
 encoding (post- D1/D3/D8).** V core landed Phase 7.72 /
 7.73 / 7.74a (capability bits 21 + 24); see [`spec/abi.md §2.10
 + §2.12`](abi.md). Lead-bindings rollout (Python / Go / Rust)
 shipped Phase 7.74b (2026-05-12). Phase 7.74b-cont (2026-05-13)
 added TypeScript, Java, and Kotlin. Phase 7.74b-cont-2 (2026-05-14)
 added Swift and C#. Phase 7.74b-cont-3 (2026-05-15) added Ruby and
 V cffi — **all ten bindings now ship the 21 streaming-Table +
 chunked + schema-driven symbols**. Rows above use `(✓)` (README
 parity pending; the V native column shows `✓` since the V core is
 the reference implementation, not an FFI wrapper).
 Idiomatic shapes: Python `cxlib.TableReader / TableWriter`
 (context manager + iterator); Go `cxlib.OpenTableReader /
 OpenTableWriter` (handles with `Close` / `CloseGetBytes`); Rust
 `cxlib::streaming_table::TableReader / TableWriter` (RAII via
 `Drop`, `Iterator<Item = Result<Vec<u8>, String>>`); TypeScript
 `cxlib.TableReader / TableWriter` (classes implementing
 `Symbol.iterator`); Java `cx.TableReader / cx.TableWriter`
 (`AutoCloseable` + `Iterable<byte[]>`); Kotlin
 `cx.TableReader / cx.TableWriter` (idiomatic `use { }` block
 + `Iterable<ByteArray>`); Swift `CXLib.TableReader / TableWriter`
 (`Sequence` + `IteratorProtocol`, ARC-managed `deinit`); C#
 `CX.TableReader / CX.TableWriter` (`IDisposable` +
 `IEnumerable<byte[]>`, `using var` lifetime); Ruby
 `CXLib::TableReader / CXLib::TableWriter` (`Enumerable` +
 explicit `close`, no auto-finalizer); V cffi
 `cffi.TableReader / cffi.TableWriter` (`new_table_reader` /
 `new_table_writer` factory functions returning `&TableReader` /
 `&TableWriter` with explicit `close()` — V has no RAII / IDisposable
 / context-manager equivalent).

- **Arrow C-Data interop (`libcx_arrow`, post- D9).** V core
 shipped Phase 7.74c (2026-05-09): a separate optional shared
 library `libcx_arrow.dylib` / `.so` that links against libcx +
 Apache Arrow's [C-Data ABI](https://arrow.apache.org/docs/format/CDataInterface.html).
 4 C ABI symbols per [`spec/abi.md §2.11`](abi.md):
 `cx_arrow_export_open` / `cx_arrow_export_open_fd` (CXDB chunked
 table → caller-allocated `ArrowArrayStream`),
 `cx_arrow_import_to_data_bin` / `cx_arrow_import_to_data_bin_fd`
 (Arrow stream → CXDB chunked table). Plus a libcx_arrow-only
 capability helper `cx_arrow_features` returning bit 23
 (`0x800000`) — bindings dlopen libcx_arrow separately and OR the
 bit into their merged-capability bitmask. Per the linkage decision
 for (recorded 2026-05-09 session): runtime-loaded
 plugin model — libcx ships with no Arrow symbols at all; libcx
 itself does not advertise bit 23. v0.6.0 supported column types
 after Phase 7.74c-cont-datetime-arrow (2026-05-09) — 10/10:
 `int` / `i64` (Arrow `'l'`), `i8` (`'c'`), `i16` (`'s'`), `i32`
 (`'i'`), `float` / `f64` (`'g'`), `bool` (`'b'`, bit-packed),
 `string` (`'u'`, i32 offsets + UTF-8 values), `date` / `d`
 (`'tdD'`, i32 days since 1970-01-01 — proleptic Gregorian),
 `datetime` (`'tsn:UTC'`, i64 nanoseconds LE since 1970-01-01 UTC

 wire; the 12-byte CXDB strict-cell form drops to 8 bytes in the
 Arrow buffer and back), `bytes` (`'z'`, i32 offsets + raw bytes).
 Deferred — clear `not yet supported in v0.6.0` error: `decimal`,
 dictionary / extension columns. **Python lead binding shipped Phase 7.74c-cont-bindings
 (2026-05-09):** `cxlib.arrow.export(framed) → pa.RecordBatchReader`
 + `cxlib.arrow.import_to_data_bin(table_or_reader) → bytes` via
 PyArrow's C-Data interop (`pyarrow.cffi.ffi` allocates the
 `struct ArrowArrayStream*`; `RecordBatchReader._import_from_c` /
 `_export_to_c` move the callbacks). PyArrow ≥ 14 is opt-in via
 `pip install cxlib[arrow]`; libcx_arrow is dlopened as a second
 ctypes.CDLL handle resolved relative to libcx's load path with
 graceful fallback (`cxlib.arrow.available()` reports False without
 raising). Test surface: `lang/python/test_arrow.py` — 14 cases
 covering all 10 v0.6.0 types (including datetime) + pa.Table →
 CXDB inverse + invalid-input errors. **Go binding shipped Phase
 7.74c-cont-bindings-multi-go (2026-05-09):**
 `cxlib.ArrowExport(payload) → array.RecordReader` +
 `cxlib.ArrowImportToDataBin(reader) → []byte` via the
 `github.com/apache/arrow/go/v18/arrow/cdata` package
 (`cdata.CArrowArrayStream` is C-ABI-compatible; libcx_arrow
 populates it directly, then `cdata.ImportCRecordReader` /
 `cdata.ExportRecordReader` move the callbacks). Gated behind the
 `arrow` build tag (`go build -tags arrow`) so the default Go build
 does not pull in the apache/arrow Go module — mirrors the Python
 `cxlib[arrow]` extra. Test surface: `lang/go/cxlib/arrow_test.go`

 including datetime + Go-built table → CXDB inverse + capability +
 invalid-input). **Rust binding shipped Phase
 7.74c-cont-bindings-multi-rust (2026-05-09):**
 `cxlib::arrow::export(payload) → ArrowArrayStreamReader` +
 `cxlib::arrow::import_to_data_bin(reader) → Vec<u8>` via the
 `arrow` crate v53.x (`arrow::ffi_stream::FFI_ArrowArrayStream` is
 C-ABI-compatible; libcx_arrow populates it directly, then
 `ArrowArrayStreamReader::try_new` consumes it / `FFI_ArrowArrayStream::new`
 exports a reader for the inverse direction). Gated behind the
 `arrow` Cargo feature (`cargo build --features arrow`) so the
 default Rust build does not pull in the `arrow` crate — mirrors the
 Go `-tags arrow` and Python `cxlib[arrow]` extras. Linkage to
 `libcx_arrow` is conditionally added by `build.rs` when the feature
 is enabled. Test surface: `lang/rust/cxlib/tests/arrow_test.rs` —
 13 cases mirroring the Python/Go suites (10 round-trip types
 including datetime + Rust-built record → CXDB inverse +
 capability + invalid-input). **C# binding shipped Phase
 7.74c-cont-bindings-multi-csharp (2026-05-09):**
 `CX.Arrow.CxArrow.Export(payload) → IArrowArrayStream` +
 `CX.Arrow.CxArrow.ImportToDataBin(reader) → byte[]` via the
 `Apache.Arrow.C` namespace from the `Apache.Arrow` NuGet package
 (v18; `CArrowArrayStream` is C-ABI-compatible; libcx_arrow
 populates it directly, then `CArrowArrayStreamImporter.ImportArrayStream`
 consumes it / `CArrowArrayStreamExporter.ExportArrayStream`
 exports a managed `IArrowArrayStream` for the inverse direction).
 Shipped as a separate optional assembly `CXLib.Arrow.dll`
 (`lang/csharp/cxlib_arrow/cxlib_arrow.csproj`) so the default
 `cxlib.csproj` build does not pull in the `Apache.Arrow` NuGet
 dependency — mirrors the Go `-tags arrow`, Rust `--features
 arrow`, and Python `cxlib[arrow]` opt-in patterns. Test surface:
 `lang/csharp/cxlib_arrow_test/Program.cs` — 14 cases mirroring
 the Python / Go / Rust suites (capability + version + 10
 round-trip types including datetime + C#-built table → CXDB
 inverse + Export/Import invalid-input). Per-type tests verify
 CXDB → Arrow only; the inverse direction is exercised exclusively
 via test 12 (managed-built `RecordBatch`) because the
 `Apache.Arrow.C` import path is zero-copy, so cached batches
 whose underlying buffers come from the imported stream are not
 safe to re-export after the stream's release callback fires.
 **Java binding shipped Phase 7.74c-cont-bindings-multi-java
 (2026-05-09):** `cx.Arrow.export(framed) → org.apache.arrow.vector.ipc.ArrowReader`
 + `cx.Arrow.importToDataBin(reader) → byte[]` via the
 `org.apache.arrow:arrow-c-data` Maven dependency (Apache Arrow
 Java v17; `org.apache.arrow.c.ArrowArrayStream` is C-ABI-compatible
 via `ArrowArrayStream.allocateNew(BufferAllocator)` —
 libcx_arrow populates it directly, then
 `Data.importArrayStream(allocator, stream)` consumes it /
 `Data.exportArrayStream(allocator, reader, stream)` populates it
 from a managed `ArrowReader` for the inverse direction). Gated
 behind the `arrow` Maven profile (`mvn -Parrow ...`) so the default
 `mvn package` does not pull in `arrow-c-data` / `arrow-vector` /
 `arrow-memory-netty` — mirrors the Go `-tags arrow`, Rust
 `--features arrow`, Python `cxlib[arrow]`, and C# separate-csproj
 opt-in patterns. Sources live under `src/main/java-arrow` /
 `src/test/java-arrow` and are added to the build only when the
 profile is active. A small public addition to `CxLib`,
 `public static long features()`, lets `Arrow.mergedFeatures()` OR
 the libcx and libcx_arrow capability masks without a duplicate
 per-class JNA load. Test surface:
 `lang/java/cxlib/src/test/java-arrow/cx/ArrowTest.java` — 14 cases
 mirroring the Python / Go / Rust / C# suites (capability + version
 + 10 round-trip types including datetime + Java-built table → CXDB
 inverse + Export/Import invalid-input). Both `Arrow.export` and
 `Arrow.importToDataBin` use FRAMED CXDB bytes (matching the
 existing Java `CxLib.toDataBinChunked` shape, which differs from
 C#/Go/Rust which expose UNFRAMED). Remaining 5 binding rows
 (V cffi, TS, Kotlin, Swift, Ruby) stay 📋 pending Phase
 7.74c-cont-bindings-multi.
 **Kotlin binding shipped Phase 7.74c-cont-bindings-multi-kotlin
 (2026-05-09):** `cx.Arrow.export(framed): ArrowReader` +
 `cx.Arrow.importToDataBin(reader: ArrowReader?): ByteArray` via
 the same `org.apache.arrow:arrow-c-data` JAR (Apache Arrow Java
 v17) the Java binding wired up — Kotlin's JNA-based loader
 populates `ArrowArrayStream.allocateNew(allocator).memoryAddress()`
 directly, then `org.apache.arrow.c.Data.importArrayStream(...)`
 consumes it / `Data.exportArrayStream(...)` populates it from a
 managed `ArrowReader` for the inverse direction. Gated behind a
 Gradle `arrow` source-set (`compileArrowKotlin` / `arrowTest`
 tasks) under `src/arrow/kotlin` + `src/arrowTest/kotlin` so the
 default `gradle assemble` and `gradle test` do not pull in
 `arrow-c-data` / `arrow-vector` / `arrow-memory-netty`. The
 source-set extends the main `implementation` configuration via a
 custom `arrowImplementation` configuration; runtime add-opens is
 applied to the `arrowTest` task
 (`--add-opens=java.base/java.nio=ALL-UNNAMED -Dio.netty.tryReflectionSetAccessible=true`).
 A small public addition to `CxLib`, `fun features(): Long`, lets
 `Arrow.mergedFeatures()` OR the libcx and libcx_arrow capability
 masks without a duplicate JNA load. Test surface:
 `lang/kotlin/cxlib/src/arrowTest/kotlin/cx/ArrowTest.kt` — 14
 cases mirroring the Python / Go / Rust / C# / Java suites
 (capability + version + 10 round-trip types including datetime +
 Kotlin-built table → CXDB inverse + Export/Import invalid-input).
 Like Java, both `Arrow.export` and `Arrow.importToDataBin` use
 FRAMED CXDB bytes (matching `CxLib.toDataBinChunked`). Remaining
 4 binding rows (V cffi, TS, Swift, Ruby) stay 📋 pending Phase
 7.74c-cont-bindings-multi.

---

## 3 — Output parity (the §2 rule)

For each fixture under [`conformance/`](../conformance/), every
binding produces output bytes that compare equal to the V reference's
output, byte-for-byte. The current state:

| fixture file | cases | passing in all 10 bindings |
| ------------------------- | ----: | -------------------------- |
| `conformance/core.txt` | 34 | yes |
| `conformance/extended.txt`| 39 | yes |
| `conformance/xml.txt` | 20 | yes |
| `conformance/md.txt` | 29 | yes |
| **total** | 122 | **yes** |

Every binding's `make test-<lang>` exercises the parity check by
loading each fixture, running it through the binding's API, and
comparing the result against the fixture's expected canonical
output. CI gates on byte-equality.

Cross-binding determinism (the property that all bindings produce
the same output for the same input) is verified at every PR by
running the full fixture set through every binding and asserting
agreement. There are zero allowed-divergence exceptions across the
122 cases as of 2026-05-08; no fixture is tagged `lang_specific`.

### 3.1 V-side conformance fixtures

A second class of fixtures verifies V-reference behavior on internal
formats that are not (yet) part of the byte-equality contract across
all 10 bindings. They run through `make conform` against the V core
and gate V-side regressions:

| fixture file | cases | gate |
| ------------------------------------------- | ----: | ------------------------------------- |
| `conformance/data_bin_chunked.txt` | 7 | chunked-table wire form ( D1) |
| `conformance/data_bin_compression.txt` | 5 | page-compression wrapper ( D2; some pending V impl) |
| `conformance/data_bin_schema_driven.txt` | 9 | schema-driven encoding ( D3) |
| `conformance/data_bin_arrow.txt` | 14 | Arrow C-Data round-trip ( D9; Phase 7.74c-conformance-runner) |

The Arrow fixture asserts CXDB → Arrow → CXDB round-trip identity (no
Arrow-byte assertions, since Arrow's binary form isn't stable across
versions). Per-binding wrappers reuse the same fixture file and follow
the binding tiering rollout: Tier 1 + 2 (V native, Python, Go, Rust,
C#, Java, Kotlin) target v0.6.0; Tier 3 (V cffi, TS, Swift, Ruby) is
deferred per the 📋 ᵈ legend.

---

## 4 — Capability bits (`cx_features`)

Every binding reads the `cx_features` bitmask from `libcx` at load
time and refuses to claim a capability that the loaded library
doesn't advertise. The bit assignments:

| bit | capability | implementation status (2026-05-08) |
| --: | ------------------------------------------- | ---------------------------------- |
| 0 | parse CX | ✓ shipping |
| 1 | emit canonical CX | ✓ shipping |
| 2 | XML / JSON / YAML / TOML / MD conversions | ✓ shipping |
| 3 | CXPath | ✓ shipping |
| 4 | streaming parse | ✓ shipping |
| 5 | `data_bin` one-shot loaders/dumpers | ✓ shipping (Phase 7.28–7.38) |
| 6 | CSV / delimited (post-) | 📋 design done |
| 7 | strict canonical / `fmt` / `eq` / `hash` | ✓ shipping |
| 8 | `:table` block read | ✓ shipping |
| 9 | `:table` block write (Table API) | 🚧 partial |
| 10 | logfmt mode | 🚧 partial (single synthetic) |
| 11 | `:decimal` arbitrary precision | ✓ shipping |
| 12 | `:bigint` arbitrary precision | ✓ shipping |
| 13 | boolean sigils (`+x` / `-x`) | ✓ shipping |
| 14 | `cx diff` (post-) | 📋 design done |
| 15 | `cx lint` (post-) | 📋 design done |

Bits 16+ are reserved for future capabilities (schema validate,
namespaces, ID/IDREF, streaming write, output-shape control —
exact bit assignment lands with each implementation).

The bitmask is *append-only*: a bit, once assigned a meaning, never
changes meaning. Removing a bit requires a major libcx version bump.
This is the §5 "Public ABI policy" rule from
[`governance.md`](governance.md).

---

## 5 — Idiomatic API divergence

The shape of the API differs per language by design. The capability
set is uniform; the syntax is not. Examples:

| concept | Python | Go | Rust | TypeScript | Java | Ruby |
| ------------------------ | ------------------- | ----------------- | ---------------------- | --------------------- | -------------------- | -------------- |
| parse CX → document | `parse(s)` | `Parse(s)` | `parse(s)?` | `parse(s)` | `CXDocument.parse(s)`| `Cx.parse(s)` |
| document → CX text | `doc.to_cx()` | `doc.ToCx()` | `doc.to_cx()` | `doc.toCx()` | `doc.toCx()` | `doc.to_cx` |
| parse + native types | `loads(s)` | `Loads(s)` | `loads(s)` | `loads(s)` | `CxLib.loads(s)` | `Cx.loads(s)` |
| canonical hash | `cx.hash(s)` | `cxlib.Hash(s)` | `cx::hash(s)` | `cx.hash(s)` | `CxLib.hash(s)` | `Cx.hash(s)` |
| CXPath select all | `doc.select_all(e)` | `doc.SelectAll(e)`| `doc.select_all(e)` | `doc.selectAll(e)` | `doc.selectAll(e)` | `doc.select_all(e)` |

The convention: each binding follows its language's idiomatic naming
(snake_case for Python/Rust/Ruby; CamelCase for Go/Java/TypeScript;
PascalCase entry-points for Java/C#) and idiomatic error handling
(exceptions for Python/Java/C#/Ruby/Kotlin; `Result` for Rust;
`error` returns for Go; throwing `Error` for TypeScript).

Per-binding API references with full method tables live in each
binding's `cxlib/README.md` (or `lang/<name>/cxlib/README.md`). That
is the authoritative per-language surface.

---

## 6 — Implementation-strategy declarations (`governance.md §3`)

Every binding declares which `libcx` C ABI symbols its public methods
call. The declaration lives in each binding's README under
"Implementation strategy" (or equivalent). The declarations are kept
honest by §1's "no roundtrips" rule: a public API may call exactly
one core symbol, plus a binary decode. PRs that change the
declaration require reviewer attention to keep it conformant.

The current set of declared mechanisms is consistent across all 10
bindings:

- Parse paths use `cx_to_ast_bin` (binary AST decode) — one C call.
- Emit paths use `cx_ast_bin_to_<fmt>` — one C call.
- One-shot conversions (CX → format / format → CX without exposing
 the AST) use `cx_to_data_bin` / `cx_data_bin_to_<fmt>` — one C
 call.
- CXPath uses `cx_select`.
- Streaming uses the `cx_events_*` family.

No binding routes through a host-language intermediate format. A
binding that violated this would be rejected at CI by the
"implementation-strategy diff" gate.

---

## 7 — V's two-variant binding (`governance.md §4`)

The `lang/v/` directory ships two binding variants because V is the
core's native language and gets a special privilege:

- **`lang/v/cffi/`** — the standard FFI shape, identical to the 9
 other FFI bindings. Wraps `libcx` via V's `C.cx_*` extern
 declarations. Maintained for compatibility and small-binary use.
- **`lang/v/native/`** — imports `vcx.cx` modules directly. Skips
 `libcx` entirely; no FFI on hot paths. Native types are the V
 core's own types or thin ergonomic wrappers. The single fastest
 path on the V VM/platform.

Both V variants run the parity matrix independently and must produce
byte-identical output across the full fixture set. They differ in
performance but never in correctness. The `cffi` variant runs the
same CI as the 9 other FFI bindings; the `native` variant runs an
additional CI that cross-checks against `cffi` for every fixture.

The default V import path (`cx.cxlib`) resolves to **native**. Users
opt into the FFI wrapper by importing `cx.cffi` explicitly. This
makes the high-performance path the default, matching the project's
positioning that V is the native reference implementation.

---

## 8 — Maintenance and drift detection

The matrix in §2 is kept honest by:

- **§3's parity check.** Output drift fails CI immediately.
- **§4's bit-mask check.** A binding that advertises capability bit
 N without the implementation behind it fails the binding's
 startup self-check.
- **§5's symbol-diff check.** A binding whose public API method
 list disagrees with its `cxlib/README.md` "Implementation
 strategy" table fails CI.
- **`make conform` after every binding change.** The 122 cases
 across 4 fixture files are the bottom-line verification.

Every PR that touches `lang/` must keep this matrix accurate. If a
PR adds a capability to one binding without the matching update to
the others, the rubric considers that drift; the PR is not
mergeable until the matrix is restored (either by extending the
other bindings or by explicitly marking the new capability as
post-v0.6.0 per the 📋 convention).

---

## 9 — Known gaps and future entries

Items pending implementation that will become rows in the matrix as
they ship:

- **Schema validator** — design committed in
 ; single
 largest v0.6.0 implementation item (~3–4 months).
- **Output-shape engine** — design committed in
 ; 8 new C ABI
 symbols planned, ~2–3 months total.
- **Streaming write API** — design committed in
 ; 15 new C ABI
 symbols planned, ~2–3 months total.
- **Namespaces** — design committed in
 ; ~4–6 weeks core +
 2–3 weeks per-binding.
- **ID / IDREF** — design committed in
 ; ~3–5 weeks core +
 2–3 weeks per-binding.
- **Delimited (CSV / TSV / PSV / …)** — design committed in
 ; spec rewrite
 + V core + 9-binding rollout, ~3 weeks.
- **`cx diff`** — design committed in
 ; ~5–6 weeks total.
- **`cx lint`** — design committed in
 ; ~7–8 weeks total.
- **`cx:lang` formalization** — design committed in
 [`spec/i18n.md`](i18n.md); V core + 9-binding rollout pending.
- **CSV one-shot loaders/dumpers** (capability bit 6) — separate
 from the data_bin family that landed in Phase 7.28; awaits the
 delimited spec rewrite.

Each item closes a 🚧 row in the rubric and adds a row to the matrix
in §2 above. The matrix is updated as part of the implementation PR,
not separately.

---

## References

- [`spec/governance.md §2`](governance.md) — the parity rule this
 document implements.
- [`spec/abi.md`](abi.md) — C ABI surface; symbol-by-symbol contract.
- [`spec/test_suite_v.md`](test_suite_v.md) — conformance suite
 documentation (private to `cx-private`).
- [`conformance/`](../conformance/) — fixture files (122 cases as
 of 2026-05-08).
- Each binding's `cxlib/README.md` — per-binding API reference and
 implementation-strategy declaration.
- — the
 ⚠ row this document closes.
