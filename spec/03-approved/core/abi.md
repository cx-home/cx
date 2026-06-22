# CX C ABI Specification (libcx)

**Status:** Current.

This document specifies the public C ABI exposed by `libcx` (built from
`vcx/cx/cabi.v`). All non-V language bindings consume CX through this
ABI. The native V binding (`lang/v/native/`) is the only consumer that
imports `vcx.cx` directly and bypasses this ABI; FFI bindings link
against `libcx.dylib` / `libcx.so` / `libcx.dll` and call these symbols.
**Conformance-active bindings** are V (native), Python, Go,
and Rust per [`misc/parity-matrix.md`](../misc/parity-matrix.md);
additional FFI bindings (TypeScript, Java, Kotlin, C#, Swift, Ruby)
exist and consume the ABI but are outside the current conformance set.

The ABI surface covers: text-format conversions, binary AST round-trip,
data-binding (`cx_to_data_bin` / `cx_from_data_bin`), CX-code
evaluation (`cx_code_eval*` — the sole CXPath / query / transform
entry-point family), canonical form (`cx_fmt` / `cx_canonical` /
`cx_hash` / `cx_eq`), semantic diff (`cx_diff`), programmatic lint
(`cx_lint`), CSV/TSV/PSV one-shot symbols, streaming via events, table
reader/writer handles, schema validation, and a capability bitmask
(`cx_features`) for runtime feature detection.

---

## 1 — Calling conventions

### 1.1 Symbol prefix and visibility

All public symbols are prefixed `cx_`. All other symbols in `libcx` are
internal and hidden from the dynamic symbol table (via `__attribute__((visibility("hidden")))`
on Linux / macOS, equivalent on Windows). Bindings must not depend on
unprefixed or hidden symbols.

### 1.2 Return types

| Returned data | Convention |
|---|---|
| Text (UTF-8 string) | `char*`, NUL-terminated. Caller frees with `cx_free`. |
| Binary | `char*` pointing to `[u32 LE: payload_size][payload]`. Caller reads size from the first 4 bytes, then payload. Caller frees the whole buffer with `cx_free`. |
| Boolean | `char*` containing `"0"` or `"1"` (NUL-terminated). Caller frees. |
| Handle | Opaque pointer (`cx_handle*`); caller passes back to subsequent calls and closes via the type's `close` function. |

The binary framing convention (`[u32 LE: payload_size][payload]`) was
established in ABI v1 (`cx_to_ast_bin`, `cx_to_events_bin`) and is retained
unchanged.

### 1.3 Error reporting

All conversion functions take a final `char** err_out` parameter:

- On success: `*err_out` is unset; the function returns the result.
- On error: `*err_out` is set to a NUL-terminated error message string;
 the function returns `NULL`.
- Caller must free `*err_out` with `cx_free` after reading.

Error messages include the file position as `line:col` (1-based, never a byte
offset) and an error code prefix in the data-parse `E`-prefix namespace
(`E<nnn>:`). The normative registry of these codes is
[`core/cxdm.md`](cxdm.md) §11. Codes and positions are stable across versions;
the PROSE of site-specific catch-all messages may be improved, but the fixed
canonical messages of [`core/code.md`](code.md) §9.5.1 are byte-stable.

```c
char* err = NULL;
char* result = cx_to_json(input, &err);
if (err) {
 fprintf(stderr, "%s\n", err);
 cx_free(err);
} else {
 /* use result */
 cx_free(result);
}
```

### 1.4 Memory ownership

| Allocator | Owner | Free function |
|---|---|---|
| Caller allocates input strings | Caller | Caller's allocator |
| `libcx` returns `char*` (any kind) | Caller | `cx_free(ptr)` |
| `libcx` returns handle | Caller | type-specific `close` |

`cx_free` is a single function for all returned pointers regardless of
kind (text, binary, error, boolean). It must always be called on
non-`NULL` returns to avoid leaks.

`cx_free(NULL)` is a no-op.

### 1.5 Thread safety

`libcx` is designed for concurrent use. There is no global mutable
state and no internal locks; concurrency comes from each public symbol
being either stateless or operating on caller-owned state.

#### 1.5.1 Per-symbol thread-safety classes

Every public C ABI symbol falls into one of three classes:

| class | meaning | examples |
| ----- | ------- | -------- |
| **(S) stateless** | Pure function of its inputs. Concurrent calls on disjoint inputs are safe without external synchronization. Concurrent calls on the *same* input buffer are also safe — the input is not mutated. | All §2.2 conversion symbols; §2.3 binary-AST symbols; §2.4 data_bin symbols; §2.5 CSV symbols; §2.6 canonical-form symbols; §2.16.1 evaluator symbols (subsumes the retired §2.7 CXPath surface); §2.17 `cx_diff`; §2.18 `cx_lint`; §2.1 `cx_version` / `cx_abi_version` / `cx_features` |
| **(H) handle-thread-local** | Operates on a caller-owned handle that must be used by a single thread for its entire lifetime. Concurrent calls on different handles are safe; concurrent calls on the *same* handle are undefined behavior. | All §2.8 streaming symbols (`cx_events_open*`, `cx_events_next`, `cx_events_close`) |
| **(F) free** | Releases memory the library allocated. Thread-safe for distinct allocations; a single allocation must be freed exactly once by exactly one thread. | §2.1 `cx_free` |

Per-symbol classification:

| symbol | class | notes |
| ------ | ----- | ----- |
| `cx_version`, `cx_abi_version`, `cx_features` | S | idempotent; safe to memoize |
| `cx_free` | F | must be the unique free for an allocation |
| `cx_to_*` / `cx_*_to_*` (text → text, all of §2.2) | S | |
| `cx_*_to_ast_bin`, `cx_ast_bin_to_*` (§2.3) | S | |
| `cx_to_data_bin`, `cx_from_data_bin`, `cx_*_to_data_bin`, `cx_data_bin_to_*` (§2.4) | S | |
| `cx_to_delimited`, `cx_from_delimited`, `cx_to_csv`/`cx_from_csv`/`cx_to_tsv`/`cx_from_tsv`/`cx_to_psv`/`cx_from_psv`, `cx_csv_to_data_bin`/`cx_tsv_to_data_bin`/`cx_psv_to_data_bin`, `cx_data_bin_to_csv`/`cx_data_bin_to_tsv`/`cx_data_bin_to_psv` (§2.5) | S | |
| `cx_fmt`, `cx_canonical`, `cx_hash`, `cx_eq` (§2.6) | S | |
| `cx_code_eval`, `cx_code_eval_with_len`, `cx_code_eval_streaming`, `cx_code_eval_caps` (§2.16.1) | S | CX code evaluator (production). Sole CXPath / query / transform entry-point family; the narrow §2.7 CXPath C ABI is retired (see §2.7). `cx_code_eval_caps` adds a capability-set parameter (bit 38, security.md); the param-less members run pure-only (empty default) — additive, non-breaking |
| `cx_to_ast_bin`, `cx_to_ast_bin_with_len`, `cx_to_events_bin`, `cx_to_events_bin_with_len`, `cx_to_events` (§2.0) | S | ABI v1 carry-over family; cap bits 1 / 2 (always set) |
| `cx_diff`, `cx_diff_with_len` (§2.17) | S | semantic diff over strict canonical bytes; cap bit 18 |
| `cx_lint`, `cx_lint_with_len` (§2.18) | S | programmatic lint with default / custom ruleset; cap bit 19 |
| `cx_id_lookup`, `cx_resolve_ref` (§2.9) | S | syntactic-ID navigation; cap bit 20 |
| `cx_code_diagram` (§2.16.2) | S | visualization C ABI (re-framed per D1 / D6 — bit 31); renders a CX program to Mermaid text (browser-safe). Stateless function of (source_text, format); identical bytes returned for identical inputs. |
| `cx_code_tree` (§2.16.3) | S | tree-projection C ABI per D2 / D6 (bit 32); returns a JSON projection of the parsed source with `{kind, name?, value?, loc:{start,end}, children?}` per node. Stateless function of `source`; identical bytes returned for identical inputs. |
| `cx_events_open`, `cx_events_open_fd`, `cx_events_next`, `cx_events_close` (§2.8) | H | handle is created by `_open*`, advanced by `_next`, released by `_close`; lifetime confined to one thread |
| `cx_table_reader_open`, `cx_table_reader_open_fd`, `cx_table_reader_schema`, `cx_table_reader_next`, `cx_table_reader_close` (§2.10) | H | reader handle is thread-local for its full lifetime |
| `cx_table_writer_open`, `cx_table_writer_open_fd`, `cx_table_writer_emit_row_group`, `cx_table_writer_close_get_bytes`, `cx_table_writer_close` (§2.10) | H | writer handle is thread-local for its full lifetime |
| `cx_arrow_export_open`, `cx_arrow_export_open_fd`, `cx_arrow_import_to_data_bin`, `cx_arrow_import_to_data_bin_fd` (§2.11; in `libcx_arrow`) | H | the populated ArrowArrayStream is thread-local; thread-safety of Arrow consumers is per the Arrow C-Data ABI contract |
| `cx_to_data_bin_schema_driven`, `cx_<fmt>_to_data_bin_schema_driven`, `cx_from_data_bin_schema_driven` (§2.12) | S | schema-driven entry points are stateless functions of (input, schema, [hint]) |
| `cx_init`, `cx_thread_register`, `cx_thread_unregister` (§1.5.5) | S | idempotent process-/thread-state mutators; concurrent calls are safe under libgc's own internal locking |

The streaming API's thread-locality requirement is documented per-symbol
in §2.8 and is the only thread-locality constraint in the entire ABI.

#### 1.5.2 Memory-model contract

`libcx` does not impose its own memory model. It relies on the host
language's / process's memory model for cross-thread visibility of
returned pointers and their content.

Concretely, when a stateless symbol returns an allocated buffer:

- The allocation is fully initialized before the symbol returns
 (the library does not return references to in-flight writes).
- The caller may pass the returned pointer to another thread using
 any standard synchronization mechanism the host language provides
 (mutex release/acquire, atomic store/load, channel send/receive,
 thread-pool job posting). The synchronization establishes the
 happens-before relationship; libcx adds nothing beyond that.
- Two threads reading the same returned buffer concurrently is
 safe — buffers are immutable from the library's perspective once
 returned.

For handle-based operations:

- A handle returned from `cx_events_open*` is the exclusive property
 of the calling thread until `cx_events_close` is called. Transfer
 to another thread requires the caller to synchronize the
 pointer's value *and* ensure the original thread no longer
 references the handle.

This is the same posture every well-behaved C library takes. Adopters
familiar with libxml2, libcurl, or sqlite's threading model will find
no surprises here.

#### 1.5.3 Per-binding concurrency stories

Each language binding's README declares how this contract surfaces in
the binding's idioms:

- **Python**: GIL implications — `loads`/`dumps` release the GIL
 during the libcx call; multiple threads benefit from parallel
 parse on multi-core hosts.
- **Go**: goroutine safety — every `cxlib.*` function maps to a
 `(S)`-class symbol and is goroutine-safe.
- **Rust**: `Send`/`Sync` bounds — the binding's types implement
 both for the stateless symbols; streaming handles implement
 `Send` but not `Sync`.
- **Java / Kotlin**: JVM monitor model — bindings do not introduce
 monitors; concurrent calls on independent inputs are safe.
- **TypeScript / Node.js**: Worker-thread safety — koffi calls
 release the JS event loop; multiple Workers can call
 concurrently.
- **Swift**: actor isolation — `cxlib.*` functions are
 `Sendable`-compatible.
- **C#**: Task safety — bindings are thread-safe per the (S) class.
- **Ruby**: GVL implications — similar to Python's GIL.

These per-binding declarations are part of the §11 multi-language
ecosystem rubric row and ship in each binding's `cxlib/README.md`.

#### 1.5.4 Conformance test expectations

A binding is concurrency-conformant iff it ships a test that:

1. Runs N (≥ 4) concurrent worker threads / goroutines / tasks.
2. Each worker calls a representative mix of (S)-class symbols on
 independent inputs.
3. Each (H)-class handle is created and closed within a single
 worker.
4. Race-detector tooling is enabled where the toolchain supports it
 (Go race, ThreadSanitizer for V/C, Helgrind for libcx itself).
5. The test passes with zero races and zero failures.

This test suite is part of the implementation work for §15
of the rubric; the contract above is the spec it conforms against.

#### 1.5.5 Thread-init handshake

`libcx` is built against Boehm GC. Boehm's default mode is unaware of
threads spawned outside V's runtime — when a non-V host thread (a Rust
cargo worker, a C# task pool worker, a Java JNI thread) calls into
`libcx` and the GC subsequently triggers a collection, libgc aborts
with `Collecting from unknown thread`. The contract below is the
binding-facing protocol that prevents this; it is the **only**
mandatory protocol step beyond the per-symbol contracts above.

The protocol is a process-level handshake plus a per-thread
registration:

| symbol | when to call | semantics |
| ------ | ------------ | --------- |
| `cx_init` | once, at binding module load | enables host-thread registration in libcx's GC. Idempotent — safe to call any number of times. Returns 0. |
| `cx_thread_register` | first thing a host-spawned worker thread does, before any other `cx_*` call | registers the calling thread with libcx's GC. Idempotent (duplicate registration returns 0). Returns 0 on success or duplicate; -1 on real failure. |
| `cx_thread_unregister` | optional, on host-thread exit | un-registers the calling thread. Bindings without thread-exit hooks may rely on libgc's process-exit cleanup instead. Returns 0 on success; -1 on failure. |

**Mandatory for every binding.** All bindings must call `cx_init`
once at module load. The cost is negligible (a single store to a libgc
flag).

**`cx_thread_register` is mandatory only for non-V-spawned host
threads.** Calling it on threads that don't need it (V-spawned
threads, Python's GIL-protected interpreter thread, Go's
cgo-serialised goroutine pool) is harmless — libgc returns
`GC_DUPLICATE` which the wrapper translates to 0. Bindings should
treat the call as cheap and unconditional rather than gating it on
host-runtime detection.

Per-binding obligations:

- **V (native, `lang/v/native/`)**: `cx_init` only. Threads spawned
 by V's `spawn`/`go` are already libgc-aware.
- **Python (`lang/python/`)**: `cx_init` on import. Per-thread
 registration only matters for `threading`-module worker threads
 that hold the GIL across libcx calls; in practice a single
 `cx_thread_register` call inside the binding's call-into-libcx
 helper covers all paths.
- **Go (`lang/go/`)**: `cx_init` in a `func init` block.
 cgo serialises calls into C; per-thread registration is harmless
 but not strictly required.
- **Rust (`lang/rust/cxlib/`)**: `cx_init` once via
 `std::sync::Once`; `cx_thread_register` once per OS worker thread
 (cargo's test harness spawns its own thread pool). This is the
 minimum that takes `make test-rust` from SIGABRT to green.
- **C# / Java**: same model as Rust — task-pool / JNI worker threads
 must each register before their first `cx_*` call.
- **Ruby / Kotlin / Swift / TS**: `cx_init` only at module load; the
 per-thread contract is documented in each binding's README and
 catches up with the binding's concurrency story.

**Capability bit 26 advertises this ABI.** Bindings that depend on the
thread-init handshake check `cx_features & (1 << 26)` at load. A
libcx that returns the bit unset does not implement the handshake;
bindings linking against it must either refuse to load or fall back to
single-threaded operation.

**Ordering rule.** `cx_init` must complete before any thread (other
than the calling thread) calls `cx_thread_register`. The natural
binding-load order — module-init `cx_init`, then test/worker threads
register themselves later — satisfies this trivially.

### 1.6 Locale independence

All numeric parsing and formatting in `libcx` uses C/POSIX locale rules
regardless of the calling process's `setlocale` configuration. Decimal
separator is always `.`; thousands separators are never emitted; date
parsing follows ISO 8601 strictly.

### 1.7 Unicode handling

All string inputs and outputs are UTF-8. `libcx` does not perform
Unicode normalization on parse (input bytes are preserved). NFC
normalization is applied for duplicate-key comparison only, never to
stored strings.

Invalid UTF-8 in any input is an error.

### 1.8 Hash randomization

`libcx` uses a per-process random hash seed for all internal hash maps
(set on library load via OS entropy). This mitigates hash-flooding DoS
attacks on map deserialization. The seed is not exposed to bindings.

---

## 2 — Symbol catalog

The ABI v2 surface is grouped below. Each subsection lists the symbols,
their signatures, and behavior.

### 2.0 ABI v1 carry-over symbols

These three families were introduced in ABI v1 and remain unchanged at
ABI v2. They are documented here so this spec is standalone-authoritative;
bindings no longer need to consult `include/cx.h` v1 documentation for
their signatures.

```c
/* CX text → ast_bin payload, framed as [u32 LE: size][payload]. */
char* cx_to_ast_bin          (const char* input, char** err_out);
char* cx_to_ast_bin_with_len (const char* input, size_t input_len,
                              char** err_out);

/* CX text → events payload (binary event stream), framed as
 * [u32 LE: size][payload]. */
char* cx_to_events_bin          (const char* input, char** err_out);
char* cx_to_events_bin_with_len (const char* input, size_t input_len,
                                 char** err_out);

/* CX text → human-readable event-trace text (one event per line).
 * Intended for tooling / diagnostics; binary callers use
 * cx_to_events_bin. */
char* cx_to_events           (const char* input, char** err_out);
```

For all five symbols:

- **Return shape.** `cx_to_ast_bin` / `cx_to_events_bin` return a
 binary buffer in `[u32 LE: payload_size][payload]` form per §1.2;
 `cx_to_events` returns NUL-terminated UTF-8 text.
- **Memory.** Caller frees the return buffer with `cx_free`.
- **Thread class.** All five are class **S** (stateless) per §1.5.1.
- **Capability bits.** `cx_to_ast_bin*` is gated by bit 1 (`0x0002`);
 `cx_to_events_bin*` and `cx_to_events` are gated by bit 2 (`0x0004`).
 Both bits are always set on conforming libcx builds (always 1).
- **Cross-references.** ast_bin payload shape: `core/ast-bin.md`.
 Events payload shape: `core/streaming.md`.

### 2.1 Lifecycle and metadata

```c
void cx_free(char* ptr);
char* cx_version(void); /* "2.0.0" */
char* cx_features(void); /* hex bitmask string, see §3 */
char* cx_abi_version(void); /* "2.0" — distinct from cx_version */
```

`cx_version` returns the library version (e.g., `"2.0.0"`).
`cx_abi_version` returns the ABI version (`"2.0"`) — bindings load this
on initialization and refuse mismatched majors.
`cx_features` returns a hex string encoding the capability bitmask; see
§3 for bit assignments.

### 2.2 Format conversion (string → string)

Conversion among {cx, xml, json, yaml, toml} as text formats, plus the AST-JSON
text projections `cx_to_ast` / `cx_ast_to_cx` (and the per-format
`cx_<fmt>_to_ast` siblings). The `md` text format and the `cx_*_to_md` /
`cx_md_to_*` symbols were **removed** (ruling D-B — CX has no markdown syntax
and no CX↔Markdown conversion layer; markdown is opaque `[#…#]` raw payload).

```c
/* CX text -> other text formats. */
char* cx_to_cx         (const char* input, char** err_out);
char* cx_to_cx_compact (const char* input, char** err_out);
char* cx_to_xml        (const char* input, char** err_out);
char* cx_to_json       (const char* input, char** err_out);
char* cx_to_yaml       (const char* input, char** err_out);
char* cx_to_toml       (const char* input, char** err_out);

/* CX text -> AST-JSON text projection (debug / tooling surface);
 * cx_ast_to_cx is its inverse. */
char* cx_to_ast    (const char* input,  char** err_out);
char* cx_ast_to_cx (const char* ast_in, char** err_out);

/* XML -> other text formats. */
char* cx_xml_to_cx   (const char* input, char** err_out);
char* cx_xml_to_xml  (const char* input, char** err_out);
char* cx_xml_to_json (const char* input, char** err_out);
char* cx_xml_to_yaml (const char* input, char** err_out);
char* cx_xml_to_toml (const char* input, char** err_out);
char* cx_xml_to_ast  (const char* input, char** err_out);

/* JSON -> other text formats. */
char* cx_json_to_cx   (const char* input, char** err_out);
char* cx_json_to_xml  (const char* input, char** err_out);
char* cx_json_to_json (const char* input, char** err_out);
char* cx_json_to_yaml (const char* input, char** err_out);
char* cx_json_to_toml (const char* input, char** err_out);
char* cx_json_to_ast  (const char* input, char** err_out);

/* YAML -> other text formats. */
char* cx_yaml_to_cx   (const char* input, char** err_out);
char* cx_yaml_to_xml  (const char* input, char** err_out);
char* cx_yaml_to_json (const char* input, char** err_out);
char* cx_yaml_to_yaml (const char* input, char** err_out);
char* cx_yaml_to_toml (const char* input, char** err_out);
char* cx_yaml_to_ast  (const char* input, char** err_out);

/* TOML -> other text formats. */
char* cx_toml_to_cx   (const char* input, char** err_out);
char* cx_toml_to_xml  (const char* input, char** err_out);
char* cx_toml_to_json (const char* input, char** err_out);
char* cx_toml_to_yaml (const char* input, char** err_out);
char* cx_toml_to_toml (const char* input, char** err_out);
char* cx_toml_to_ast  (const char* input, char** err_out);
```

All take `(const char* input, char** err_out)` and return `char*`
(NUL-terminated text). All errors via `err_out` per §1.3. All are
class **S** (stateless) per §1.5.1; caller frees the return with
`cx_free` per §1.4.

`cx_to_ast` emits the AST-JSON projection per
[`vcx/cx/emitter_json.v`](../vcx/cx/emitter_json.v); `cx_ast_to_cx`
parses that projection and re-emits canonical CX text. The pair is the
text-only AST-projection complement to the binary `cx_to_ast_bin` /
`cx_ast_bin_to_cx` family of §2.3.

### 2.3 Symmetric binary AST

Closes audit findings **CB-1** and **CB-2**. Bindings consume non-CX
inputs once (no JSON re-parse) and emit non-CX outputs from a binary
AST in memory (no CX-text round-trip).

#### Input → binary AST

```c
char* cx_xml_to_ast_bin (const char* input, char** err_out);
char* cx_json_to_ast_bin(const char* input, char** err_out);
char* cx_yaml_to_ast_bin(const char* input, char** err_out);
char* cx_toml_to_ast_bin(const char* input, char** err_out);
```

(In addition to existing `cx_to_ast_bin` for CX input.)

Returns binary buffer in `[u32 LE: size][AST payload]` format. AST
payload is identical in shape to `cx_to_ast_bin` (see `include/cx.h`
v1 documentation).

#### Binary AST → output format

```c
char* cx_ast_bin_to_cx (const char* ast_bin, char** err_out);
char* cx_ast_bin_to_xml (const char* ast_bin, char** err_out);
char* cx_ast_bin_to_json(const char* ast_bin, char** err_out);
char* cx_ast_bin_to_yaml(const char* ast_bin, char** err_out);
char* cx_ast_bin_to_toml(const char* ast_bin, char** err_out);
```

`ast_bin` is a `[u32 LE: size][payload]` buffer (the format produced by
`cx_*_to_ast_bin`). The function reads the size header and consumes the
declared payload. Buffers larger than the declared size are an error.

These symbols enable bindings to convert in-memory documents to
target formats without round-tripping through CX text. This was the
single largest performance and correctness gap in the v1 ABI.

### 2.4 Data binding — `cx_to_data_bin` family

Closes audit finding **CB-3**. The strict-canonical binary data format
defined in `data-bin.md`. Bindings deserialize the binary data
directly into native types.

#### Core

```c
char* cx_to_data_bin (const char* input, char** err_out); /* CX → data_bin */
char* cx_from_data_bin (const char* data_bin, char** err_out); /* data_bin → CX text (canonical) */
```

#### One-shot loaders (input format → data_bin)

```c
char* cx_xml_to_data_bin (const char* input, char** err_out);
char* cx_json_to_data_bin(const char* input, char** err_out);
char* cx_yaml_to_data_bin(const char* input, char** err_out);
char* cx_toml_to_data_bin(const char* input, char** err_out);
char* cx_csv_to_data_bin (const char* input, char** err_out);
char* cx_tsv_to_data_bin (const char* input, char** err_out);
char* cx_psv_to_data_bin (const char* input, char** err_out);
```

#### One-shot dumpers (data_bin → output format)

```c
char* cx_data_bin_to_cx (const char* data_bin, char** err_out);
char* cx_data_bin_to_xml (const char* data_bin, char** err_out);
char* cx_data_bin_to_json(const char* data_bin, char** err_out);
char* cx_data_bin_to_yaml(const char* data_bin, char** err_out);
char* cx_data_bin_to_toml(const char* data_bin, char** err_out);
char* cx_data_bin_to_csv (const char* data_bin, char** err_out);
char* cx_data_bin_to_tsv (const char* data_bin, char** err_out);
char* cx_data_bin_to_psv (const char* data_bin, char** err_out);
```

The csv / tsv / psv loaders and dumpers above use the named delimiter
variant; arbitrary single-char callers compose `cx_to_delimited` /
`cx_from_delimited` (§2.5) with `cx_to_data_bin` / `cx_from_data_bin`.

### 2.5 Delimited — CSV / TSV / PSV / arbitrary single-char

```c
char* cx_to_delimited (const char* input, char delim, char** err_out);
char* cx_from_delimited(const char* input, char delim, char** err_out);

/* Named-delimiter aliases */
char* cx_to_csv (const char* input, char** err_out);
char* cx_from_csv(const char* input, char** err_out);
char* cx_to_tsv (const char* input, char** err_out);
char* cx_from_tsv(const char* input, char** err_out);
char* cx_to_psv (const char* input, char** err_out);
char* cx_from_psv(const char* input, char** err_out);
```

`delim` is a single byte; any byte except `\r`, `\n`, `"`, `'`, or
`\\` is accepted. The named aliases bind `,` / `\t` / `|`
respectively.

Behavior is well-defined and reasonable, not lossless. Emit shape is
auto-detected (`:table` / repeated-row / dotted-path); parse accepts
double-quote, single-quote, and bare fields with six universal escape
sequences; type recovery via auto-typing or caller schema.

Full normative contract: `conversions.md`.
Design: recorded internally.
V core implementation: `vcx/cx/delimited.v`.

### 2.6 Canonical-form operations

```c
char* cx_fmt (const char* input, char** err_out); /* lossless canonical text */
char* cx_canonical (const char* input, char** err_out); /* strict canonical text */
char* cx_hash (const char* input, char** err_out); /* SHA-256 hex of strict canonical bytes */
char* cx_eq (const char* a, const char* b, char** err_out); /* "1" iff strict-canonical(a) == strict-canonical(b) */
```

All defined per `canonical.md`.

### 2.7 CXPath — retired

The standalone CXPath C ABI (`cx_select` / `cx_select_all`, audit
finding **CB-5**) is retired. CXPath path-value expressions
now evaluate through `cx_code_eval` (§2.16.1) — bindings call the
unified evaluator with the path expression as the `program` argument
(e.g. `//user[@active=true]/@email`). Layer-1 binding wrappers
(`Doc.select` / `Doc.select_all`, see
[`misc/bindings.md §2.1`](../misc/bindings.md)) are retained and route
through `cx_code_eval` internally. Capability bit 8 (the former
`cx_select` advertisement) is RESERVED; see §3.

CXPath grammar remains normative in [`code.md` §5.5](code.md); only the
dedicated C ABI symbol pair is retired.

### 2.8 Streaming

Closes audit finding **CB-4**. Real streaming via handle-based pull
iteration; the parser does not buffer the entire input.

```c
typedef struct cx_events_handle cx_events_handle;

cx_events_handle* cx_events_open (const char* input, char** err_out);
cx_events_handle* cx_events_open_fd(int fd, char** err_out);
char* cx_events_next (cx_events_handle* h, char** err_out);
void cx_events_close(cx_events_handle* h);
```

`cx_events_open` opens a handle over an in-memory string.
`cx_events_open_fd` opens over an OS file descriptor; the handle reads
incrementally without buffering the whole input. The parser maintains a
small buffer (default 64 KB).

`cx_events_next` returns the next event as a binary buffer
(`[u32 LE: size][event payload]` per the existing event format) or
`NULL` with `*err_out == NULL` to signal EOF.

`cx_events_close` releases all resources owned by the handle. Safe to
call on `NULL`. Required for any handle returned from `cx_events_open*`.

Existing `cx_to_events` and `cx_to_events_bin` remain available for
small inputs and tooling. The streaming API is for inputs that exceed
available memory or where event-driven processing is preferable.

### 2.9 ID / IDREF lookup

Per `cxdm.md §4` (Identity) and grammar [51a/b] IdDecl. Two C ABI
symbols expose syntactic-ID navigation against a parsed CX document:

```c
/* Look up an element by its #id declaration. Returns ast_bin
 * payload of the matching element, or NULL if no element has the
 * given ID. Caller frees with cx_free. */
char* cx_id_lookup(const char* input, const char* id, char** err_out);

/* Resolve an @id IDREF. Given an input document and an attribute
 * value of the form "@id", returns the ast_bin payload of the
 * element with that ID. Equivalent to cx_id_lookup with the leading
 * '@' stripped. Returns NULL if no element has the given ID. */
char* cx_resolve_ref(const char* input, const char* ref, char** err_out);
```

Both symbols are class **S** (stateless). They support the document-
local ID/IDREF mechanism defined by `cxdm.md §4` independently of the
general CXPath / CX-code evaluator surfaces.

Capability bit 20 advertises this ABI. Lookup is O(N) on first call
per document; bindings MAY cache the document's ID index across
multiple lookups against the same input.

### 2.10 Streaming Table reader / writer

Handle-based streaming over the chunked-table wire format (per
`data-bin.md`). The reader pulls one row group at a time; the writer
pushes one row group at a time. Memory use is bounded by the largest
single row group.

```c
typedef struct cx_table_reader cx_table_reader;
typedef struct cx_table_writer cx_table_writer;

/* Reader: opens over a chunked-table data_bin buffer or fd. */
cx_table_reader* cx_table_reader_open (const char* data_bin,
 char** err_out);
cx_table_reader* cx_table_reader_open_fd (int fd, char** err_out);

/* Returns the table's col-spec as ast_bin (Element with one Attribute
 * per column carrying name + `::T` type annotation). Inspectable before the first
 * row-group read. */
char* cx_table_reader_schema (cx_table_reader* r, char** err_out);

/* Returns the next row group as binary [u32 LE: size][body bytes],
 * where body is the §3.11.2 plain-body format (uvarint(row_count)
 * + col-payload[col_count]); compressed groups are decompressed
 * before return. NULL with *err_out == NULL signals end-of-table. */
char* cx_table_reader_next (cx_table_reader* r, char** err_out);

void cx_table_reader_close (cx_table_reader* r);

/* Writer: opens with caller-supplied col-spec (same ast_bin shape
 * cx_table_reader_schema returns). _open accumulates in memory;
 * _open_fd writes incrementally to the fd. */
cx_table_writer* cx_table_writer_open (const char* col_spec_payload,
 char** err_out);
cx_table_writer* cx_table_writer_open_fd (const char* col_spec_payload,
 int fd, char** err_out);

/* Emits one row group. row_group_payload is the §3.11.2 plain-body
 * format. The writer chooses whether to wrap in §3.12 zstd
 * compression based on a default policy (compress if uncompressed
 * body > 64 KiB and compresses below 0.85 of original size); future
 * minor revisions may expose explicit codec selection. */
char* cx_table_writer_emit_row_group (cx_table_writer* w,
 const char* row_group_payload,
 char** err_out);

/* In-memory writers: emit the end-of-table marker, then return the
 * complete chunked-table data_bin buffer. fd writers: NULL return,
 * use _close. */
char* cx_table_writer_close_get_bytes (cx_table_writer* w,
 char** err_out);
void cx_table_writer_close (cx_table_writer* w);
```

All ten symbols are class **H** (handle thread-local) per
§1.5.1. Capability bit 21
(`0x200000`) signals reader / writer support; bindings that ship the
streaming Table API set this bit.

### 2.11 Apache Arrow C-Data interop

**`libcx_arrow`** is a separate dynamic library that links against
both `libcx` and the Arrow C-Data ABI. Core `libcx` remains
Arrow-free; consumers without Arrow needs do not pay the dependency
cost.

**Arrow C Data Interface version targeted.** cx implements the
Arrow C Data Interface as specified at
<https://arrow.apache.org/docs/format/CDataInterface.html>. The
struct layout (`ArrowSchema`, `ArrowArray`, `ArrowArrayStream`) has
been stable since Arrow 4.0 (2021); cx targets that ABI contract,
not any particular Arrow library release. The four shipped bindings
have been tested against:

| Binding | Arrow library + version |
|---|---|
| Python | `pyarrow` ≥ 10.0 (via `cffi` C-Data bridge) |
| Go | `github.com/apache/arrow/go/v18` (v18.x) |
| Rust | `arrow` crate ≥ 50.0 (the `arrow::ffi_stream` module) |
| TypeScript | `apache-arrow` JS — bridge via Arrow IPC bytes; C Data Interface bridge is not feasible from V8 |

Compatibility window: any Arrow library that implements the Arrow
C Data Interface spec is compatible. If a future Arrow spec
revision changes the struct layout, cx will bump the
`libcx_arrow` shared-library SONAME and document the break here.

```c
/* Export: CXCol chunked-table → Arrow ArrowArrayStream.
 * arrow_array_stream_out points at a caller-allocated
 * ArrowArrayStream struct (see Arrow C-Data ABI); the function
 * populates it with a stream that pulls from libcx. */
char* cx_arrow_export_open (const char* data_bin,
 void* arrow_array_stream_out,
 char** err_out);
char* cx_arrow_export_open_fd (int fd,
 void* arrow_array_stream_out,
 char** err_out);

/* Import: Arrow ArrowArrayStream → CXCol chunked-table.
 * The function consumes the stream and returns either an in-memory
 * data_bin buffer or writes incrementally to the supplied fd. */
char* cx_arrow_import_to_data_bin (void* arrow_array_stream_in,
 char** err_out);
char* cx_arrow_import_to_data_bin_fd (void* arrow_array_stream_in,
 int fd_out,
 char** err_out);
```

Capability bit 23 (`0x800000`) signals `libcx_arrow` availability.
Bindings without Arrow integration declare bit 23 unset and fall
back to materializing data through `cx_data_bin_to_csv` or
equivalent. The Parquet bridge chains Arrow export →
`pyarrow.parquet.write_table` (or the equivalent in the host
language); no direct Parquet C++ dependency lives in core libcx.

#### 2.11.1 Type mapping

CXCol chunked-table column types ↔ Arrow C-Data ABI format strings.
Wire shapes are byte-identical where possible (numeric / bool /
utf8); date and bytes go through small projections.

| CXCol type | Arrow format | Width / shape |
|------------------|--------------|-------------------------------------------------------|
| `int` / `i64` | `l` | int64, 8 bytes/row (LE) |
| `i8` | `c` | int8, 1 byte/row |
| `i16` | `s` | int16, 2 bytes/row (LE) |
| `i32` | `i` | int32, 4 bytes/row (LE) |
| `float` / `f64` | `g` | float64, 8 bytes/row |
| `bool` | `b` | bool, bit-packed, ceil(N/8) bytes |
| `string` | `u` | utf8, i32 offsets buffer + UTF-8 values buffer |
| `date` / `d` | `tdD` | date32, i32 days since 1970-01-01 (proleptic Gregorian) |
| `bytes` | `z` | binary, i32 offsets buffer + raw bytes values buffer |

Date conversion uses Howard Hinnant's proleptic Gregorian
algorithm; the round-trip range is the intersection of CXCol's i16
year domain and Arrow date32's i32 day domain — i.e. roughly
year [-32768, +32767], comfortably exceeding pyarrow's date32
documented range. No Julian-cutoff handling.

Deferred to a follow-up phase (each surfaces a clear
`arrow: column type 'X' not yet supported in ` /
`arrow: format 'F' not yet supported in ` error):

- `datetime`: blocked on chunked-table strict-cell wire form (the
 column-major encoder in `data_bin_chunked.v::encode_strict_cell`
 does not yet dispatch on `tag_datetime`).
- `decimal`: pending the `:decimal` type's column-major
 encoding.
- Dictionary / extension columns: deferred to a follow-up phase.

Validity bitmaps are NULL on both sides (`null_count = 0`).
CXCol strict-spec column-major encoding has no in-band null
representation; bindings that need NULL must defer to a later
phase or pre-mask through a sentinel layer.

### 2.12 Schema-driven encoding

Per
and `data-bin.md`. Schema-driven encoding
is opt-in via new variants of the data_bin entry points:

```c
/* Schema-driven CX → data_bin. schema_input is the schema as CX
 * text; the writer parses it, computes its content-hash, embeds
 * the schema reference per §3.13.1, and emits the root value
 * with per-field tag-omission per §3.13.2. */
char* cx_to_data_bin_schema_driven (const char* input,
 const char* schema_input,
 char** err_out);

char* cx_<fmt>_to_data_bin_schema_driven (const char* input,
 const char* schema_input,
 char** err_out);
 /* one per format: cx, xml, json, yaml, toml, csv, tsv, psv */

/* Schema-driven data_bin → CX. The reader extracts the schema
 * reference from the header; if it is content-hash-only and not
 * resolvable from the consumer's content-addressable store, the
 * caller MAY supply the schema bytes via the optional
 * schema_hint parameter (NULL for "use embedded resolution"). */
char* cx_from_data_bin_schema_driven (const char* data_bin,
 const char* schema_hint,
 char** err_out);
```

Capability bit 24 (`0x1000000`) signals schema-driven encoding
support. A libcx that implements bit 24 also implements
bits 21 (chunked tables) and 22 (page compression) — schema-driven
encoding composes naturally with the streaming Table API for
billion-row schema-bound datasets.

### 2.13 Schema validator

Per `schema.md`. Two C ABI symbols expose the validator; bindings call
them from their own `validate(doc, schema)` wrapper. The diagnostic
wire format is normative (`schema.md §10.2`):

```c
/* Validate `doc_input` against `schema_input` (`.cxs` source).
 * Returns a framed [u32 LE size][diag_count][diag*] payload; freed
 * by the caller via cx_free. NULL with *err_out set on schema-load
 * or document-parse failure. A doc with zero diagnostics returns a
 * non-NULL buffer with diag_count=0 (distinguishes "validated
 * cleanly" from "couldn't validate"). */
char* cx_validate(const char* doc_input,
 const char* schema_input,
 char** err_out);

/* Same, but additionally writes the document with schema-default
 * attribute values inserted (per schema.md §11) to
 * *modified_doc_out as canonical CX text. Caller frees both
 * outputs with cx_free. */
char* cx_validate_apply_defaults(const char* doc_input,
 const char* schema_input,
 char** modified_doc_out,
 char** err_out);
```

Each diagnostic in the payload is:

```
[u32 LE line] 0 if unavailable
[u32 LE col] 0 if unavailable
[u8 prefix] ASCII rule-code namespace letter:
 'S' (0x53) = schema validator
 'W' (0x57) = streaming-write writer
 'D' (0x44) = data validator (reserved)
 0x00 = unspecified (no prefix rendered)
[u32 LE error_code] numeric form of the prefixed code
 ("S002" → 2, "W001" → 1)
[u8 severity] 0=info, 1=warn, 2=error
[u32 LE message_len]
[message_utf8]
```

The `prefix` byte was added at the wire-format lock-in so that future
diagnostic-emitting subsystems (streaming-write `W`, data validator
`D`, plus any others) can share this wire format without a further ABI
bump. Bindings MUST read the prefix byte
and render diagnostic codes as `<prefix-char><error_code zero-
padded to 3 digits>` (e.g. `"S006"`, `"W001"`); when the prefix
byte is `0x00`, bindings render the numeric code only.

Capability bit 25 (`0x2000000`) signals schema-validator support.
RE2 backs the `[pattern …]` constraint (rule S008); see §3 capability-25
notes for the cross-binding determinism guarantee. The validator
ships with the bootstrap rule set: S002 / S003 / S004 /
S005 / S008 / S017 implemented end-to-end; S001 / S006 / S007 /
S009 / S010 / S011 / S012 / S013 / S014 / S015 / S016 / S018 /
S019 / S020 implemented end-to-end.

### 2.14 Explicit-length C ABI variants (hardening)

Every C ABI symbol that takes framed CXCol bytes as `const char*`
has a companion `_with_len` variant that validates a caller-supplied
`size_t` length against the embedded size header before reading.
The implicit-length forms (which trust the 4-byte size header on
arbitrary input) trigger an OOB read when handed non-CXCol bytes —
e.g. a NUL-terminated C string, a raw text document, or a buffer
shorter than the header claims.

```c
char* cx_from_data_bin_with_len (const char* input,
 size_t total_len,
 char** err_out);
void* cx_table_reader_open_with_len (const char* data_bin,
 size_t total_len,
 char** err_out);
void* cx_table_writer_open_with_len (const char* col_spec_payload,
 size_t total_len,
 char** err_out);
void* cx_table_writer_open_fd_with_len (const char* col_spec_payload,
 size_t total_len,
 int fd,
 char** err_out);
char* cx_table_writer_emit_row_group_with_len
 (void* handle,
 const char* row_group_payload,
 size_t total_len,
 char** err_out);
char* cx_validate_with_len (const char* doc_input,
 size_t doc_len,
 const char* schema_input,
 size_t schema_len,
 char** err_out);
char* cx_validate_apply_defaults_with_len (const char* doc_input,
 size_t doc_len,
 const char* schema_input,
 size_t schema_len,
 char** modified_doc_out,
 char** err_out);
```

The `_with_len` symbols return an error when the embedded
`[u32 LE size]` header disagrees with `total_len` (where header +
4 = total). New bindings SHOULD prefer the `_with_len` forms; the
implicit-length originals stay through 1.0 per §1.1 versioning policy
and are removed at 2.0. New
format-specific decoders (cx_from_data_bin_xml_with_len,
cx_from_data_bin_json_with_len, etc.) follow the same naming
convention when added.

### 2.15 Streaming-write API

Per `streaming.md`. The streaming-write API is the symmetric
counterpart to §2.8 (read-side streaming): adopters construct an event
sequence programmatically and the writer emits format-targeted bytes,
with validation at emit time and no full-document buffering.

**Surface:** 21 C ABI symbols total — 4 lifecycle + 17 emit. Per
H-class (§1.5.1) the writer handle is thread-local; one writer =
one thread. CX code is the only output-shape mechanism — see §2.16
for the evaluator surface.

```c
typedef struct cx_events_writer cx_events_writer;

/* Lifecycle (4 symbols) */
cx_events_writer* cx_events_writer_open (const char* output_format, char** err_out);
cx_events_writer* cx_events_writer_open_fd (const char* output_format, int fd, char** err_out);
char* cx_events_writer_close_get_bytes (cx_events_writer* w, char** err_out);
void cx_events_writer_close (cx_events_writer* w);

/* Emit (17 symbols — 14 base events + 3 _with_len siblings) */
char* cx_events_writer_start_doc (cx_events_writer* w, char** err_out);
char* cx_events_writer_end_doc (cx_events_writer* w, char** err_out);
char* cx_events_writer_start_element (cx_events_writer* w, const char* name, const char* anchor, const char* data_type, const char* merge, const char* attrs_payload, char** err_out);
char* cx_events_writer_start_element_with_len (cx_events_writer* w, const char* name, const char* anchor, const char* data_type, const char* merge, const char* attrs_payload, size_t attrs_len, char** err_out);
char* cx_events_writer_end_element (cx_events_writer* w, const char* name, char** err_out);
char* cx_events_writer_text (cx_events_writer* w, const char* value, char** err_out);
char* cx_events_writer_scalar (cx_events_writer* w, const char* data_type, const char* value, char** err_out);
char* cx_events_writer_comment (cx_events_writer* w, const char* value, char** err_out);
char* cx_events_writer_pi (cx_events_writer* w, const char* target, const char* data, char** err_out);
char* cx_events_writer_entity_ref (cx_events_writer* w, const char* name, char** err_out);
char* cx_events_writer_raw_text (cx_events_writer* w, const char* value, char** err_out);
char* cx_events_writer_alias (cx_events_writer* w, const char* name, char** err_out);
char* cx_events_writer_start_table (cx_events_writer* w, const char* col_spec_payload, char** err_out);
char* cx_events_writer_start_table_with_len (cx_events_writer* w, const char* col_spec_payload, size_t col_spec_len, char** err_out);
char* cx_events_writer_row_group (cx_events_writer* w, const char* row_group_payload, char** err_out);
char* cx_events_writer_row_group_with_len (cx_events_writer* w, const char* row_group_payload, size_t row_group_len, char** err_out);
char* cx_events_writer_end_table (cx_events_writer* w, char** err_out);
```

Each emit returns NULL on success or a heap-allocated diagnostic
string in the return value plus a UTF-8 message in `err_out` on
failure. Diagnostic codes use the `W` namespace per the
prefix-marker convention in §2.13 (`'W'` = 0x57). The writer fails
closed: a single error puts it in an unrecoverable state.

**Validation rules and W001-W014 codes** are normative in
`streaming.md` (W014 is the read-side unknown-discriminator code). Format coverage per
event × output format is normative in §6.6; chunked-table events
on non-CX outputs return `W009` (rejection is monotonic — a future
spec extension can lift the rejection without breaking the ABI lock).

Capability bit 27 signals the streaming-write surface — 21 symbols
(4 lifecycle + 17 emit). Bit 27 stays at `0x8000000`;
no reassignment.

### 2.16 CX-code evaluator

The CX-code evaluator entry points are documented under §2.16.1
`cx_code_eval*` below.

#### 2.16.1 `cx_code_eval*` family

`cx_code_eval` / `cx_code_eval_with_len` /
`cx_code_eval_streaming` are the entry points for the unified CX code
evaluator (`code.md`). This family is the sole CXPath /
query / transform surface; the standalone CXPath C ABI (`cx_select` /
`cx_select_all`, formerly §2.7) is retired — see §2.7.

```c
/* One-shot evaluator (NUL-terminated). */
char* cx_code_eval
 (const char* input,
 const char* program,
 const char* output_target,
 char** err_out);

/* One-shot evaluator (explicit-length; binary-safe per §2.14). */
char* cx_code_eval_with_len
 (const char* input, size_t input_len,
 const char* program, size_t program_len,
 const char* output_target,
 char** err_out);

/* Streaming evaluator. write_cb returning non-zero aborts. */
typedef int (*cx_code_write_cb)(const char* bytes,
 size_t n,
 void* user);

char* cx_code_eval_streaming
 (const char* input, size_t input_len,
 const char* program, size_t program_len,
 const char* output_target,
 cx_code_write_cb write_cb,
 void* user,
 char** err_out);
```

**Parameters.**

- `input` is a CX document. `NULL` or empty (length 0) means the
 program does not consume an implicit `$doc` binding —
 `[?for [in $i (1, 2, 3)] [yield $i]]` is legal with `input == NULL`.
- `program` MUST be non-NULL and non-empty. CX program source per
 `code.md`.
- `output_target` is one of `text` (default when NULL/empty), `cx`,
 `json`, `ast-json`, `yaml`, `xml`, `csv`, `tsv`; `html`, `markdown`, `svg`,
 `mermaid` (Phase-4-gated — currently return `CXER0001:output
 target '<t>' requires the reference renderer ; not yet
 implemented`). `json` emits the AST-JSON shape per
 [`vcx/cx/emitter_json.v`](../vcx/cx/emitter_json.v); `yaml` and
 `xml` route through the canonical `cx.emit_yaml` / `cx.emit_xml`
 emitters after wrapping the result in a `cx.Document`; `csv` /
 `tsv` emit one header line plus one row per record when the
 result is a uniform sequence of records (same element name, same
 attribute schema across rows), returning `CXER0100` with a
 descriptive shape-mismatch message otherwise — no silent
 best-effort fallbacks.

**Error wire format.** `CXERnnnn:msg` per `core/code.md §9`. The
`cx-err:` namespace prefix is stripped — that prefix is reserved for
value-form errors *inside* programs (`[err :code "cx-err:CXER…"]`).
Bindings parse the `<prefix>:<message>` shape uniformly with the
`Wnnn:msg` convention used by older surfaces (§1.3).

**Soft-error vs hard-error.** Errors the program recovers
(`[?match]`, `[?else]`, `[?retry]`, `[?fallback]`) flow as `[err]`
*values* inside the program — they do NOT surface through
`err_out`. Only parse errors (`CXER0100`), unbound bindings
(`CXER0001`), and `!`-postfix escalations fill `err_out`. This
mirrors the soft-error contract specified in `core/code.md §9`.

**Thread-safety.** All three symbols are class **S** (stateless,
thread-safe per §1.5.1).
The cooperative scheduler the evaluator uses internally
(`vcx/code/scheduler.v`) confines its V-thread fan-out to a
single call's stack; no thread state escapes. Concurrent calls on
disjoint inputs are safe by construction.

**Streaming flush boundary.** At the streaming variant
single-flushes the rendered output to `write_cb`; concatenated
output is byte-equivalent to the one-shot variant per the §3.3
contract. Per-iteration / per-line incremental flush lands with
the §11.6 gate 15 throughput work — the binding-facing contract
does not change.

**Capability bit.** Bit 28 (`0x10000000`) advertises the CX code
surface. `cx_code_eval*` is the sole evaluator entry-point
family. Bindings probing bit 28 commit to the full §4.1 directive
registry in `code.md`.

#### 2.16.2 `cx_code_diagram`

`cx_code_diagram` is the visualization C ABI entry point. It is the
wasm-callable surface behind the playground Source-pane Visualize
affordance and the reference renderer's Mermaid output.
SVG and PNG outputs go through the CLI / server tier (graphviz
shell-out per gate 12) and are intentionally not exposed at this
ABI — the wasm build does not link graphviz.

```c
/* Render a CX program to a diagram representation. */
char* cx_code_diagram
 (const char* source, size_t source_len,
 const char* format, size_t format_len);
```

**Parameters.**

- `source` is the CX program source text. MUST be non-NULL and
 non-empty (length 0 yields `CXER0100`). Program-source surface is
 CX-only per `code.md` — JSON / XML
 / YAML / TOML are output projections of program *results* and not
 accepted as input here.
- `format` is one of `mermaid` (the only format exposed via this
 ABI); SVG / PNG render formats are CLI-only per gate 12. Other
 format values yield `CXER0100`.

**Return.** A NUL-terminated UTF-8 string containing the rendered
output, malloc'd by the library and freed by the caller via
`cx_free`. The returned text round-trips per gate 9: it carries the
original `source` bytes as a leading `%%cx:<base64>%%` comment that
`code.reverse_parse_diagram` recovers verbatim.

**Error wire format.** `CXERnnnn:msg` per §2.16.1. Errors are
returned in-band as a `CXERnnnn:msg`-prefixed string (rather than
the `err_out` channel used by `cx_code_eval*`) because the
single-output diagram path has no semantically distinct soft-error
channel — every failure is terminal. Callers detect by checking the
`CXER` prefix.

**Thread-safety.** Class **S** (stateless) per §1.5.1.
Concurrent calls on disjoint inputs are safe by construction; the
renderer does not retain state across calls.

**Capability bit.** Bit 31 (`0x80000000`) advertises this entry
point. Source kind is auto-detected on the parsed AST: `flowchart TD`
for code sources, `erDiagram` for data sources. See `§3` capability
table for the full bit allocation.

#### 2.16.3 `cx_code_tree`

`cx_code_tree` is the tree-projection C ABI entry point. It is the
wasm-callable surface behind the playground Output-pane Tree View
affordance and unblocks the bidirectional selection bridge between the
source pane and the tree pane without further ABI plumbing (the
per-node `loc` carries byte offsets into the original source).

```c
/* Project a CX program source to a tree JSON. */
char* cx_code_tree
 (const char* source, size_t source_len,
 size_t* out_len);
```

**Parameters.**

- `source` is the CX program source text. MUST be non-NULL and
 non-empty (length 0 yields `CXER0100`). Program-source surface is
 CX-only per `code.md`; JSON / XML / YAML
 / TOML are output projections of program *results* and not
 accepted as input here.
- `out_len` (optional, may be NULL) receives the byte length of the
 returned UTF-8 string excluding the trailing NUL.

**Return.** A NUL-terminated UTF-8 JSON string, malloc'd by the
library and freed by the caller via `cx_free`. The JSON conforms to
the D2 contract: every node carries
`{kind, name?, value?, loc:{start,end}, children?}` where `loc.start`
and `loc.end` are byte offsets (not codepoint offsets) into `source`
and resolve to a valid UTF-8 substring. The `kind` discriminator
covers element / attribute / text / directive / scalar / path per
the D2 vocabulary.

**Error wire format.** `CXERnnnn:msg` per §2.16.1 — returned in-band
as a `CXERnnnn:msg`-prefixed string (the tree-projection path has no
semantically distinct soft-error channel; every failure is terminal).
Callers detect by checking the `CXER` prefix.

**Thread-safety.** Class **S** (stateless) per §1.5.1.
Concurrent calls on disjoint inputs are safe by construction; the
projector does not retain state across calls.

**Capability bit.** Bit 32 (`0x100000000`) advertises this entry
point. Independent of bit 31 — a binding MAY
advertise `cx_code_tree` without `cx_code_diagram`, or vice versa,
or both. See `§3` capability table for the full bit allocation.

### 2.17 `cx_diff` — programmatic semantic diff

`cx_diff` computes a semantic diff between two CX documents and
returns a structured CX diff document. The diff is computed over
**strict canonical bytes** per `core/canonical.md §1.2`: cosmetic
differences (whitespace, comment churn, presentation-only directives,
attribute reorderings that the strict-canonical form normalizes) are
excluded; only semantic changes appear in the output.

```c
char* cx_diff          (const char* before,
                        const char* after,
                        char** err_out);
char* cx_diff_with_len (const char* before, size_t before_len,
                        const char* after,  size_t after_len,
                        char** err_out);
```

**Parameters.**

- `before`, `after` — CX document source text. Either may be empty
 (zero-length) — an empty-vs-non-empty pair surfaces as a single
 top-level `add` or `remove` action.

**Return.** A NUL-terminated UTF-8 string containing a CX-formatted
diff document. The four action kinds are `add` / `remove` / `change`
/ `move`:

```cx
[diff
  [change [path "//user[#u-1]/@email"] [from "old@x.com"] [to "new@x.com"]]
  [add    [path "//users"] [value [user #u-3 name="carol"]]]
  [remove [path "//users/user[2]"] [value [user #u-2 name="bob"]]]
  [move   [from "//users/user[3]"] [to "//archived/user[1]"]]]
```

Each action carries a `[path …]` location: for `change` / `add` /
`remove` it is the surviving path; for `move` the location is split
into `[from …]` + `[to …]`. `add` carries `[value …]` with the
inserted subtree; `remove` carries `[value …]` with the removed
subtree; `change` carries `[from …]` + `[to …]` with the scalar /
atom / typed values. Semantically equal inputs return the empty
diff `[diff]`.

**Error wire format.** On parse failure of either input, returns
`NULL` with `*err_out` set to a NUL-terminated `CXERnnnn:msg` string
per §2.16.1. The caller frees `*err_out` with `cx_free`.

**Memory.** Caller frees the return buffer with `cx_free` per §1.4.

**Thread-safety.** Class **S** (stateless) per §1.5.1. Concurrent
calls on disjoint inputs are safe by construction.

**Capability bit.** Bit 18 (`0x40000`) advertises this entry point.
See §3.

### 2.18 `cx_lint` — programmatic linting

`cx_lint` runs lint rules against a CX document and returns a
structured diagnostics document. Callers MAY supply a custom
`.cxs`-shaped CX ruleset; passing `NULL` for `ruleset` selects the
built-in default ruleset (`L001`-`L007`, table below).

```c
char* cx_lint          (const char* input,
                        const char* ruleset,
                        char** err_out);
char* cx_lint_with_len (const char* input,   size_t input_len,
                        const char* ruleset, size_t ruleset_len,
                        char** err_out);
```

**Parameters.**

- `input` — CX document source text. MUST be non-NULL and non-empty.
- `ruleset` — optional `.cxs`-shaped CX document describing custom
 lint rules. `NULL` (and `ruleset_len == 0` for the `_with_len`
 form) selects the built-in default ruleset.

**Return.** A NUL-terminated UTF-8 string containing a CX-formatted
diagnostics document:

```cx
[diagnostics
  [diagnostic
    [severity warn]
    [code "L004"]
    [path "//user[#u-1]"]
    [message "Element has anchor but is never referenced"]
    [loc [line 12] [col 4]]]
  [diagnostic
    [severity error]
    [code "L007"]
    [path "//user/@email"]
    [message "Empty required attribute"]
    [loc [line 18] [col 16]]]]
```

A clean lint pass returns the empty diagnostics document
`[diagnostics]`.

**Default ruleset.** When `ruleset == NULL`, `cx_lint` runs the
following minimum:

| Code | Severity | Rule |
|---|---|---|
| L001 | error | Unresolved `@id` IDREF (per `core/cxdm.md §4.2`) |
| L002 | warn  | Anchor declared but never aliased |
| L003 | warn  | Element with `merge` ref to a nonexistent anchor |
| L004 | warn  | Attribute declared but never read (only when a schema is supplied in `ruleset`) |
| L005 | error | Schema violation (delegates to `cx_validate` semantics; surfaces `S001..S020` codes per `core/schema.md`) |
| L006 | warn  | Deprecated directive form (e.g., earlier-revision surfaces) |
| L007 | warn  | Empty string for a `pattern=`-constrained attribute |

Lint codes are registered in `core/code.md §9.4` / `§9.5` (the
`L001..L020` range). `L005` delegates to `cx_validate` semantics
but uses its own code namespace so consumers can filter lint output
by code prefix.

**Error wire format.** On parse failure of `input`, or on malformed
`ruleset`, returns `NULL` with `*err_out` set to a NUL-terminated
`CXERnnnn:msg` string per §2.16.1. The caller frees `*err_out` with
`cx_free`. Diagnostic-level lint findings appear inside the returned
document, not through `err_out` — only parse / load failures escalate.

**Memory.** Caller frees the return buffer with `cx_free` per §1.4.

**Thread-safety.** Class **S** (stateless) per §1.5.1. Concurrent
calls on disjoint inputs are safe by construction.

**Capability bit.** Bit 19 (`0x80000`) advertises this entry point.
See §3.

---

## 3 — Capability bitmask (`cx_features`)

`cx_features` returns a NUL-terminated lowercase hex string encoding a
64-bit capability bitmask. Bindings call this on load and refuse to use
features the loaded library does not implement.

| Bit | Hex | Capability |
|---|---|---|
| 0 | 0x0001 | ABI core conversion symbols (always 1) |
| 1 | 0x0002 | Binary AST (cx_to_ast_bin) (always 1) |
| 2 | 0x0004 | Binary events (cx_to_events_bin) (always 1) |
| 3 | 0x0008 | Symmetric binary AST (CB-1, CB-2 fixes)|
| 4 | 0x0010 | data_bin core (cx_to_data_bin / cx_from_data_bin)|
| 5 | 0x0020 | data_bin one-shot loaders / dumpers|
| 6 | 0x0040 | Delimited (CSV / TSV / PSV / arbitrary single-char) |
| 7 | 0x0080 | Canonical form (cx_fmt / cx_canonical / cx_hash / cx_eq)|
| 8 | 0x0100 | RESERVED — formerly CXPath C ABI (`cx_select` / `cx_select_all`). CXPath queries now route through `cx_code_eval` (§2.16.1) with a path-value expression; the dedicated symbol pair is retired (§2.7). New libcx builds leave bit 8 clear. |
| 9 | 0x0200 | Real streaming (cx_events_open / next / close)|
| 10 | 0x0400 | `[table[ … ]` table block in grammar |
| 11 | 0x0800 | `::decimal` type |
| 12 | 0x1000 | `::f16` type |
| 13 | 0x2000 | RESERVED (was: Boolean attribute sigils +/-). BoolSigilAttr removed per grammar [55b]; new libcx leaves it clear. |
| 14 | 0x4000 | Line comments (`#`) |
| 15 | 0x8000 | Logfmt mode (top-level bare attributes) |
| 16 | 0x10000 | Numeric underscores |
| 17 | 0x20000 | RESERVED — superseded by bit 23. Bindings SHOULD query bit 23 for Arrow C-Data interop. |
| 18 | 0x40000 | `cx_diff` — programmatic semantic diff (§2.17). Computes diff over **strict canonical bytes** per `core/canonical.md §1.2`; returns a structured CX diff document with `add` / `remove` / `change` / `move` actions. Cosmetic differences (whitespace, comment churn, presentation-only directives) are excluded. |
| 19 | 0x80000 | `cx_lint` — programmatic linting (§2.18). Returns a structured CX diagnostics document. Accepts an optional caller-supplied `.cxs`-shaped ruleset; the built-in default ruleset is `L001`-`L007` (codes registered in `core/code.md §9.4` / `§9.5`). |
| 20 | 0x100000 | ID / IDREF C ABI (`cx_id_lookup` / `cx_resolve_ref`) |
| 21 | 0x200000 | Chunked-table format (tag `0x63`, `data-bin.md`) plus the streaming Table reader / writer C ABI |
| 22 | 0x400000 | Page-compression wrapper (tag `0x90`, zstd v1, `data-bin.md`)|
| 23 | 0x800000 | Apache Arrow C-Data interop (`libcx_arrow`, §2.11). Canonical Arrow capability bit going forward; supersedes bit 17. |
| 24 | 0x1000000 | Schema-driven encoding (header flag bit 1, `data-bin.md`) plus §2.12 entry points|
| 25 | 0x2000000 | Schema validator (`cx_validate` / `cx_validate_apply_defaults` plus `_with_len` variants per §2.13, + `schema.md`) Includes RE2-backed `[pattern …]` matching (S008 rule); pattern-engine semantics are normative cross-binding because every binding routes through `cx_validate`. |
| 26 | 0x4000000 | Thread-init handshake : `cx_init` / `cx_thread_register` / `cx_thread_unregister` Required for bindings whose host runtime spawns OS threads outside V's control (Rust, C#, Java); cheap and harmless on every other binding. |
| 27 | 0x8000000 | Streaming-write API (`cx_events_writer_*` per §2.15, `streaming.md`. 21 C ABI symbols (4 lifecycle + 17 emit) covering 14 stream events × 6 output formats with emit-time validation.|
| 28 | 0x10000000 | CX code evaluator (`cx_code_eval` + `cx_code_eval_with_len` + `cx_code_eval_streaming` per §2.16.1) A libcx setting this bit commits to the CX code evaluator with its full §4.1 directive registry — see `code.md`. |
| 29 | 0x20000000 | Collection literals — Array `[a, b, c]`, Map `{k: v}`, Sequence `(a, b, c)` container Item kinds (per `cxdm.md §2.5–§2.7`, grammar [56]) round-trip through parser, AST (`ast.md`), ast_bin v6 (`ast-bin.md`), all six emitters (`conversions.md`), evaluator, CXPath, and schema validator. Set only when ALL surface components implement; partial implementations leave clear. Decoders without bit 29 MUST reject ast_bin payloads with version byte ≥ 6. |
| 30 | 0x40000000 | First-class function values — `[?fn (params) body]` per `code.md §12.7` (anonymous function literals, lexical-scope closure capture, higher-order programming). Parameter-binding evaluator infrastructure is shared with bit 34 `[?def]`; W018 on argument-count mismatch. Independent of bit 34: a binding may advertise `[?fn]` without module-level `[?def]`. |
| 31 | 0x80000000 | CX program diagram renderer (`cx_code_diagram`) — Mermaid text emit via the wasm-safe path. `cx_code_diagram` auto-detects source kind on the parsed AST (top-level program with EvalDirective → `flowchart TD`). SVG / PNG render formats are CLI-only (graphviz shell-out) and not advertised by this bit. Set when `cx_code_diagram` is callable and round-trips. |
| 32 | 0x100000000 | CX code tree (`cx_code_tree`) — JSON projection of the parsed source; each node carries `{kind, name?, value?, loc:{start,end}, children?}` with byte offsets enabling bidirectional source/tree selection. Independent of bit 31. |
| 33 | 0x200000000 | Atom scalar kind — surface `:NAME` per `cxdm.md §2.3` across lexer (grammar [122b]), parser, AST (`ast.md` Scalar `dataType="atom"`), CXDM equality (atom↔string disjoint), ast_bin v7 wire (`ast-bin.md` `0x03 Scalar`), identity-hash domains, and the C ABI scalar-type tag. Reserved names `:true` / `:false` / `:null` are forbidden at lex time (CXER0100). |
| 34 | 0x400000000 | `[?def]` module-level functions — end-to-end support for the directive specified in `code.md §12.2` (grammar [152]–[153f]): parser, `ast.md` DefNode + TypeExprNode, evaluator (module-scope closure, no overloading, bare-name reference, mutual recursion via two-pass load), type-expression grammar, dev-strict validation (`--strict` / `CX_STRICT_TYPES=1` enforcing `[returns T]` + `name::T` annotations; CXER0206 / CXER0207). Errors CXER0204 / CXER0205 required. Independent of bit 35. |
| 35 | 0x800000000 | `[?lib]` module loading — module-system surface specified in `code.md §12.1`: `[?lib RESOLVER [as ALIAS] [only (a b)]]` with three resolver shapes (file path, registered name, HTTPS URL); `[?const]` constants (`code.md §12.3`) with eager/lazy evaluation; `scope public` visibility on `[?def]` and `[?const]`; two-pass module load; `cx.lock` lockfile + SRI integrity; HTTPS-only transport with TLS verification; transitive cycle detection (CXER0210); bundled `cx-stdlib` reachable via `[?lib 'cx-stdlib/...']`. Errors CXER0208..CXER0215 required. Zip-package runtime extraction is design-locked but not implementation-gated by this bit. |
| 36 | 0x1000000000 | PathNode / MatchNode / ModifyNode wire format (ast_bin v8) — three first-class AST kinds gated jointly by this bit: PathNode (tag `0x13`, `ast.md` PathNode), MatchNode (tag `0x14`, `ast.md` MatchNode), ModifyNode (tag `0x15`, `ast.md` ModifyNode). Wire payloads per `ast-bin.md §§4.4–4.6`. ast_bin v8 version byte. Advisory `source` / `loc` AST fields are excluded from all three wire payloads. v7 readers MUST reject v8 files. Independent of bits 33 / 34 / 35. Companion CXER0290 raised by emitters that have not yet honoured the v8 wire format. |
| 37 | 0x2000000000 | Iterator wire format — IteratorNode AST kind (tag `0x16`, `ast-bin.md`). Wire payload carries `source_kind` (`IteratorSourceKind` ordinal: `iter_range` / `iter_map` / `iter_filter` / `iter_take` / `iter_drop` / `iter_concat` / `iter_zip` / `iter_enumerate` / `iter_chunks` / `iter_cycle` / `iter_scan` / `iter_flatten` / `iter_partition` / `iter_group_by`). Runtime-derived `memo` and `exhausted` are NOT carried; decoders restore a fresh iterator that re-evaluates from source on first pull. Decoders without bit 37 MUST raise CXER0100 on tag `0x16`. Independent of bit 36. |
| 38 | 0x4000000000 | Capability-based security — deny-by-default capability set per `core/security.md`. `cx_code_eval*` accept a capability-set parameter (default empty ⇒ pure-only); a denied effect raises `cx-err:CXER0271` (E_CAP_DENIED). The `[?with-caps]` narrowing directive is gated by this bit. |
| 39 | 0x8000000000 | Debugging — local + remote debug surface per `misc/debug.md` (breakpoints, stepping, `eval`-in-frame, DAP adapter, record-replay). Off by default; remote attach requires a token. |
| 40-63 | reserved | (set to 0) |

---

## 4 — Performance budgets

The following are guideline performance targets for ABI v2; not contract
requirements but enforced via the perf-regression suite (see
`architecture.md` §Conformance).

| Operation | 1 KB input | 1 MB input | 100 MB input |
|---|---|---|---|
| `cx_to_ast_bin` | < 50 µs | < 30 ms | < 3 s |
| `cx_to_data_bin` | < 50 µs | < 30 ms | < 3 s |
| `cx_to_json` | < 100 µs | < 60 ms | < 6 s |
| `cx_events_next` per event | < 1 µs | | |

(Selection is covered by `cx_code_eval` with a CXPath path expression
(e.g. `//user[@active=true]`); the gate-15 performance budget in
`code.md` §11.4.4 applies.)

Measured on Apple M-class or x86_64 ≥3 GHz. CI tracks regressions
against these targets per binding.

---

## 5 — Symbol versioning

Symbols introduced in ABI v2 are versioned via the symbol name (no GNU
versioned-symbols attribute, since macOS doesn't support it natively).
A future v3 with breaking changes to existing symbols will introduce
new symbols (e.g., `cx_to_data_bin_v3`) and retain the v2 names with
v2 semantics.

Bindings should:

1. Call `cx_abi_version` on load.
2. Check that the major version matches what the binding was built
 against. Mismatch is an error; load fails.
3. Call `cx_features` to confirm required capabilities.
4. Cache the feature bitmask for the lifetime of the loaded library.

---

## 6 — `include/cx.h` integration

The C header `include/cx.h` is auto-generated from this spec at build
time. Bindings using `cgo`, `ctypes`, `koffi`, JNA, P/Invoke, FFI
crates, or direct `dlopen` consume the header. The header is part of
the library distribution and must match the linked `libcx`.

Header file structure:

```c
/* SPDX-License-Identifier: ... */
/* libcx C ABI — auto-generated from abi.md */
#ifndef CX_H
#define CX_H
#ifdef __cplusplus
extern "C" {
#endif

/* §2.1 Lifecycle and metadata */
void cx_free(char* ptr);
char* cx_version(void);
char* cx_abi_version(void);
char* cx_features(void);

/* §2.2 — §2.8 ... */

#ifdef __cplusplus
}
#endif
#endif /* CX_H */
```

---

## 7 — Conformance

A conforming `libcx`:

1. Exports every symbol listed in §2 with the declared signature.
2. Hides every other symbol from the dynamic symbol table.
3. Returns the correct `cx_features` bitmask for its capabilities.
4. Honors the memory ownership rules in §1.4.
5. Is reentrant and thread-safe per §1.5.
6. Locale-independent per §1.6.

A conforming binding:

1. Calls `cx_abi_version` on load and verifies major-version match.
2. Calls `cx_features` and either degrades or refuses to load on
 missing required capabilities.
3. Frees every returned pointer with `cx_free`.
4. Closes every handle via the type-specific `close` function.
5. Does not depend on any unprefixed or hidden symbol.
6. Does not call sibling public binding functions and re-parse their
 string output (see `architecture.md` native-implementation rule).

---

## 8 — Migration from ABI v1

ABI v2 is fully backward-compatible. v1 callers continue to work.

Recommended migration for binding maintainers:

1. **Adopt symmetric binary AST.** Replace each `parse_<format>` that
 did `cx_<format>_to_ast → JSON re-parse` with
 `cx_<format>_to_ast_bin → binary decode`. Replace each
 `Document.to_<format>` that did CX-text round-trip with
 `serialize document → ast_bin → cx_ast_bin_to_<format>`.
2. **Adopt `cx_to_data_bin`.** Replace each `loads` / `dumps`
 JSON-bridge with `cx_to_data_bin` / `cx_from_data_bin`.
3. **Adopt the CX-code evaluator surface.** CXPath expressions evaluate
 via the `cx_code_eval*` family (§2.16.1) — e.g.
 `//user[@active=true]` (CXPath value-kind expression per grammar [130]).
4. **Adopt streaming.** Replace buffering `Stream` with handle-based
 iteration over `cx_events_next`.
5. **Adopt new types and syntax.** Surface `[table[ … ]`,
 `::decimal`, `::f16` to native types per
 `../misc/type-mapping.md`.

Each phase is independently testable against the conformance suite.
