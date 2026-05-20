# CX C ABI Specification (libcx)
# Version: 2.0
# Date: 2026-05-06

This document specifies the public C ABI exposed by `libcx` (built from
`vcx/cx/cabi.v`). All non-V language bindings consume CX through this
ABI. The native V binding (`lang/v/native/`) is the only consumer that
imports `vcx.cx` directly and bypasses this ABI; all 9 FFI bindings
(Python, Go, Rust, TypeScript, Java, Kotlin, C#, Swift, Ruby) link
against `libcx.dylib` / `libcx.so` / `libcx.dll` and call these symbols.

ABI version 2 introduces:

- Symmetric binary AST input / output for non-CX formats (closes audit
 findings CB-1 and CB-2).
- `cx_to_data_bin` / `cx_from_data_bin` plus one-shot loaders / dumpers
 (closes CB-3).
- CXPath C ABI (closes CB-5; ~5000 LOC of host-language duplication
 deletable).
- Real streaming via `cx_events_open` / `cx_events_next` / `cx_events_close`
 (closes CB-4).
- `cx_fmt` / `cx_canonical` / `cx_hash` / `cx_eq` for canonical-form
 consumers.
- CSV / TSV / PSV one-shot symbols.
- `cx_features` capability bitmask for runtime detection.

ABI v1 symbols are preserved unchanged; v1 callers continue to work
against a v2 library. This is enforced by conformance.

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

Error messages include the file position when applicable (`line:col` or
`byte_offset`) and an error code prefix (`E001:`, `E002:`, ...). Codes
are stable across versions; messages may be improved.

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
| **(S) stateless** | Pure function of its inputs. Concurrent calls on disjoint inputs are safe without external synchronization. Concurrent calls on the *same* input buffer are also safe — the input is not mutated. | All §2.2 conversion symbols; §2.3 binary-AST symbols; §2.4 data_bin symbols; §2.5 CSV symbols; §2.6 canonical-form symbols; §2.7 CXPath symbols; §2.1 `cx_version` / `cx_abi_version` / `cx_features` |
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
| `cx_select`, `cx_select_all` (§2.7) | S | |
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
ecosystem rubric row and ship in each
binding's README at v0.6.0.

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

This test suite is part of the v0.6.0 implementation work for §15
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
| `cx_init()` | once, at binding module load | enables host-thread registration in libcx's GC. Idempotent — safe to call any number of times. Returns 0. |
| `cx_thread_register()` | first thing a host-spawned worker thread does, before any other `cx_*` call | registers the calling thread with libcx's GC. Idempotent (duplicate registration returns 0). Returns 0 on success or duplicate; -1 on real failure. |
| `cx_thread_unregister()` | optional, on host-thread exit | un-registers the calling thread. Bindings without thread-exit hooks may rely on libgc's process-exit cleanup instead. Returns 0 on success; -1 on failure. |

**Mandatory for every binding.** All bindings must call `cx_init()`
once at module load. The cost is negligible (a single store to a libgc
flag).

**`cx_thread_register()` is mandatory only for non-V-spawned host
threads.** Calling it on threads that don't need it (V-spawned
threads, Python's GIL-protected interpreter thread, Go's
cgo-serialised goroutine pool) is harmless — libgc returns
`GC_DUPLICATE` which the wrapper translates to 0. Bindings should
treat the call as cheap and unconditional rather than gating it on
host-runtime detection.

Per-binding obligations:

- **V (native, `lang/v/native/`)**: `cx_init()` only. Threads spawned
 by V's `spawn`/`go` are already libgc-aware.
- **Python (`lang/python/`)**: `cx_init()` on import. Per-thread
 registration only matters for `threading`-module worker threads
 that hold the GIL across libcx calls; in practice a single
 `cx_thread_register()` call inside the binding's call-into-libcx
 helper covers all paths.
- **Go (`lang/go/`)**: `cx_init()` in a `func init()` block.
 cgo serialises calls into C; per-thread registration is harmless
 but not strictly required.
- **Rust (`lang/rust/cxlib/`)**: `cx_init()` once via
 `std::sync::Once`; `cx_thread_register()` once per OS worker thread
 (cargo's test harness spawns its own thread pool). This is the
 minimum that takes `make test-rust` from SIGABRT to green.
- **C# / Java**: same model as Rust — task-pool / JNI worker threads
 must each register before their first `cx_*` call.
- **Ruby / Kotlin / Swift / TS**: `cx_init()` only at v0.6.0; the
 per-thread contract is documented in each binding's README and
 catches up with the binding's concurrency story.

**Capability bit 26 advertises this ABI.** Bindings that depend on the
thread-init handshake check `cx_features() & (1 << 26)` at load. v0.5.x
libcx returns the bit unset; bindings linking against it must either
refuse to load or fall back to single-threaded operation.

**Ordering rule.** `cx_init()` must complete before any thread (other
than the calling thread) calls `cx_thread_register()`. The natural
binding-load order — module-init `cx_init()`, then test/worker threads
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

These symbols are inherited from ABI v1 unchanged. Conversion among
{cx, xml, json, yaml, toml, md} as text formats:

```
cx_to_cx cx_to_cx_compact cx_to_xml
cx_to_json cx_to_yaml cx_to_toml
cx_to_md cx_to_ast cx_ast_to_cx

cx_xml_to_cx cx_xml_to_xml cx_xml_to_json
cx_xml_to_yaml cx_xml_to_toml cx_xml_to_md
cx_xml_to_ast

cx_json_to_cx cx_json_to_xml cx_json_to_json
cx_json_to_yaml cx_json_to_toml cx_json_to_md
cx_json_to_ast

cx_yaml_to_cx cx_yaml_to_xml cx_yaml_to_json
cx_yaml_to_yaml cx_yaml_to_toml cx_yaml_to_md
cx_yaml_to_ast

cx_toml_to_cx cx_toml_to_xml cx_toml_to_json
cx_toml_to_yaml cx_toml_to_toml cx_toml_to_md
cx_toml_to_ast

cx_md_to_cx cx_md_to_xml cx_md_to_json
cx_md_to_yaml cx_md_to_toml cx_md_to_md
cx_md_to_ast
```

All take `(const char* input, char** err_out)` and return `char*`
(NUL-terminated text). All errors via `err_out` per §1.3.

### 2.3 Symmetric binary AST (NEW in v2)

Closes audit findings **CB-1** and **CB-2**. Bindings consume non-CX
inputs once (no JSON re-parse) and emit non-CX outputs from a binary
AST in memory (no CX-text round-trip).

#### Input → binary AST

```c
char* cx_xml_to_ast_bin (const char* input, char** err_out);
char* cx_json_to_ast_bin(const char* input, char** err_out);
char* cx_yaml_to_ast_bin(const char* input, char** err_out);
char* cx_toml_to_ast_bin(const char* input, char** err_out);
char* cx_md_to_ast_bin (const char* input, char** err_out);
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
char* cx_ast_bin_to_md (const char* ast_bin, char** err_out);
```

`ast_bin` is a `[u32 LE: size][payload]` buffer (the format produced by
`cx_*_to_ast_bin`). The function reads the size header and consumes the
declared payload. Buffers larger than the declared size are an error.

These six symbols enable bindings to convert in-memory documents to
target formats without round-tripping through CX text. This was the
single largest performance and correctness gap in the v1 ABI.

### 2.4 Data binding — `cx_to_data_bin` family (NEW in v2)

Closes audit finding **CB-3**. The strict-canonical binary data format
defined in `spec/data_bin.md`. Bindings deserialize the binary data
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
char* cx_md_to_data_bin (const char* input, char** err_out);
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
char* cx_data_bin_to_md (const char* data_bin, char** err_out);
char* cx_data_bin_to_csv (const char* data_bin, char** err_out);
char* cx_data_bin_to_tsv (const char* data_bin, char** err_out);
char* cx_data_bin_to_psv (const char* data_bin, char** err_out);
```

The csv / tsv / psv loaders and dumpers above use the named delimiter
variant; arbitrary single-char callers compose `cx_to_delimited` /
`cx_from_delimited` (§2.5) with `cx_to_data_bin` / `cx_from_data_bin`.

### 2.5 Delimited — CSV / TSV / PSV / arbitrary single-char (NEW in v2; expanded in v2.1)

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
`\\` is accepted ( D6). The named aliases bind `,` / `\t` /
`|` respectively.

Behavior is well-defined and reasonable, not lossless. Emit shape is
auto-detected (`:table` / repeated-row / dotted-path); parse accepts
double-quote, single-quote, and bare fields with six universal escape
sequences; type recovery via auto-typing or caller schema.

Full normative contract: [`spec/conversions.md §8`](conversions.md).
Design: recorded internally.
V core implementation: `vcx/cx/delimited.v`.

### 2.6 Canonical-form operations (NEW in v2)

```c
char* cx_fmt (const char* input, char** err_out); /* lossless canonical text */
char* cx_canonical (const char* input, char** err_out); /* strict canonical text */
char* cx_hash (const char* input, char** err_out); /* SHA-256 hex of strict canonical bytes */
char* cx_eq (const char* a, const char* b, char** err_out); /* "1" iff strict-canonical(a) == strict-canonical(b) */
```

All defined per `spec/canonical.md`.

### 2.7 CXPath (NEW in v2)

Closes audit finding **CB-5**. Replaces ~5000 LOC of host-language
CXPath duplication with two C ABI symbols. The host bindings retain
ergonomic wrappers (a few hundred lines each) that thunk to these.

```c
char* cx_select (const char* input, const char* expr, char** err_out);
char* cx_select_all(const char* input, const char* expr, char** err_out);
```

`cx_select` returns the first matching element as `[u32 LE: size][AST
payload]` (compatible with `cx_ast_bin_to_*`). Returns `NULL` with no
error if no match.

`cx_select_all` returns an array of matching elements as a single AST
payload encoding a synthetic array element (top-level node is an
Element with name `cx:results` containing all matches as children).

CXPath grammar is defined in `spec/cxpath.md` and is unchanged from v1.

### 2.8 Streaming (NEW in v2)

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
small buffer (default 64 KB; configurable in a future minor revision).

`cx_events_next` returns the next event as a binary buffer
(`[u32 LE: size][event payload]` per the existing event format) or
`NULL` with `*err_out == NULL` to signal EOF.

`cx_events_close` releases all resources owned by the handle. Safe to
call on `NULL`. Required for any handle returned from `cx_events_open*`.

Existing `cx_to_events` and `cx_to_events_bin` remain available for
small inputs and tooling. The streaming API is for inputs that exceed
available memory or where event-driven processing is preferable.

### 2.9 Reserved / removed

ABI v2 does not remove any v1 symbols. Future ABI majors (v3+) may
deprecate v1 conversion symbols once the binary AST path is universally
adopted by bindings, but no removal is planned for the foreseeable
future.

### 2.10 Streaming Table reader / writer (NEW in v0.6.0)

Per.
Handle-based streaming over the chunked-table wire format
([`spec/data_bin.md §3.11`](data_bin.md)). The reader pulls one row
group at a time; the writer pushes one row group at a time. Memory
use is bounded by the largest single row group.

```c
typedef struct cx_table_reader cx_table_reader;
typedef struct cx_table_writer cx_table_writer;

/* Reader: opens over a chunked-table data_bin buffer or fd. */
cx_table_reader* cx_table_reader_open (const char* data_bin,
 char** err_out);
cx_table_reader* cx_table_reader_open_fd (int fd, char** err_out);

/* Returns the table's col-spec as ast_bin (Element with one Attribute
 * per column carrying name + :type). Inspectable before the first
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
[§1.5.1](#151-per-symbol-thread-safety-classes). Capability bit 21
(`0x200000`) signals reader / writer support; bindings that ship the
streaming Table API set this bit.

### 2.11 Apache Arrow C-Data interop (NEW in v0.6.0; separate library)

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
| Go | `github.com/apache/arrow/go/v18` v18.0.0 |
| Rust | `arrow` crate ≥ 50.0 (the `arrow::ffi_stream` module) |
| TypeScript | `apache-arrow` JS — bridge via Arrow IPC bytes; C Data Interface bridge is not feasible from V8 |

Compatibility window: any Arrow library that implements the Arrow
C Data Interface spec is compatible. If a future Arrow spec
revision changes the struct layout, cx will bump the
`libcx_arrow` shared-library SONAME and document the break here.

```c
/* Export: CXDB chunked-table → Arrow ArrowArrayStream.
 * arrow_array_stream_out points at a caller-allocated
 * ArrowArrayStream struct (see Arrow C-Data ABI); the function
 * populates it with a stream that pulls from libcx. */
char* cx_arrow_export_open (const char* data_bin,
 void* arrow_array_stream_out,
 char** err_out);
char* cx_arrow_export_open_fd (int fd,
 void* arrow_array_stream_out,
 char** err_out);

/* Import: Arrow ArrowArrayStream → CXDB chunked-table.
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
equivalent. The Parquet bridge (per) chains Arrow
export → `pyarrow.parquet.write_table` (or equivalent for the
host language); no direct Parquet C++ dependency lives in
core libcx.

#### 2.11.1 Type mapping

CXDB chunked-table column types ↔ Arrow C-Data ABI format strings.
Wire shapes are byte-identical where possible (numeric / bool /
utf8); date and bytes go through small projections.

| CXDB type | Arrow format | Width / shape |
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
algorithm; the round-trip range is the intersection of CXDB's i16
year domain and Arrow date32's i32 day domain — i.e. roughly
year [-32768, +32767], comfortably exceeding pyarrow's date32
documented range. No Julian-cutoff handling.

Deferred to a follow-up phase (each surfaces a clear
`arrow: column type 'X' not yet supported in v0.6.0` /
`arrow: format 'F' not yet supported in v0.6.0` error):

- `datetime`: blocked on chunked-table strict-cell wire form (the
 column-major encoder in `data_bin_chunked.v::encode_strict_cell`
 does not yet dispatch on `tag_datetime`).
- `decimal`: pending the v0.6.0 `:decimal` type's column-major
 encoding.
- Dictionary / extension columns: tracked under Phase 7.74d.

Validity bitmaps are NULL on both sides at v0.6.0 (`null_count = 0`).
CXDB strict-spec column-major encoding has no in-band null
representation; bindings that need NULL must defer to a later
phase or pre-mask through a sentinel layer.

### 2.12 Schema-driven encoding (NEW in v0.6.0)

Per
and [`spec/data_bin.md §3.13`](data_bin.md). Schema-driven encoding
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
 /* one per format: cx, xml, json, yaml, toml, md, csv, tsv, psv */

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
support. A v0.6.0 libcx that implements bit 24 also implements
bits 21 (chunked tables) and 22 (page compression) — schema-driven
encoding composes naturally with the streaming Table API for
billion-row schema-bound datasets.

### 2.13 Schema validator (NEW in v0.6.0)

Per and
[`spec/schema.md §10`](schema.md). Two C ABI symbols expose the
validator; bindings call them from their own `validate(doc, schema)`
wrapper. The diagnostic wire format is normative (`schema.md §10.2`):

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
 * attribute values inserted (per spec/schema.md §11) to
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

The `prefix` byte was added at v0.6.0 lock-in (Phase 7.74f) so
that future diagnostic-emitting subsystems (streaming-write `W`,
data validator `D`, plus any others) can share this wire format
without a further ABI bump. Bindings MUST read the prefix byte
and render diagnostic codes as `<prefix-char><error_code zero-
padded to 3 digits>` (e.g. `"S006"`, `"W001"`); when the prefix
byte is `0x00`, bindings render the numeric code only.

Capability bit 25 (`0x2000000`) signals schema-validator support.
RE2 backs the `:pat=` constraint (rule S008); see §3 capability-25
notes for the cross-binding determinism guarantee. The validator
ships with the v0.6.0 bootstrap rule set: S002 / S003 / S004 /
S005 / S008 / S017 implemented end-to-end; S001 / S006 / S007 /
S009 / S010 / S011 / S012 / S013 / S014 / S015 / S016 / S018 /
S019 / S020 implemented in Phase 7.74d before the v0.6.0 tag.

### 2.14 Explicit-length C ABI variants (v0.6.0 hardening)

Every C ABI symbol that takes framed CXDB bytes as `const char*`
has a companion `_with_len` variant that validates a caller-supplied
`size_t` length against the embedded size header before reading.
The implicit-length forms (which trust the 4-byte size header on
arbitrary input) trigger an OOB read when handed non-CXDB bytes —
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
4 = total). New bindings landing post-v0.6.0 SHOULD prefer the
`_with_len` forms; the implicit-length originals stay through 1.0
per §1.1 versioning policy and are removed at 2.0. New
format-specific decoders (cx_from_data_bin_xml_with_len,
cx_from_data_bin_json_with_len, etc.) follow the same naming
convention when added.

### 2.15 Streaming-write API (NEW in v0.6.0)

Per and
[`spec/streaming.md §6`](streaming.md). The streaming-write API is
the symmetric counterpart to §2.8 (read-side streaming): adopters
construct an event sequence programmatically and the writer emits
format-targeted bytes, with validation at emit time and no
full-document buffering.

**Surface:** 21 C ABI symbols total — 4 lifecycle + 17 emit. Per
H-class (§1.5.1) the writer handle is thread-local; one writer =
one thread.

(History: the original v0.6.0 lock included 4 `_shaped` open
variants for composition (`cx_events_writer_open_shaped`,
`_open_fd_shaped`, `_open_shaped_with_len`,
`_open_fd_shaped_with_len`). was superseded by

on 2026-05-10; the `_shaped` variants are removed and the lifecycle
surface shrinks from 8 → 4 (total 25 → 21 symbols). CXL is the
only output-shape mechanism — see §2.16.)

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

**Validation rules and W001-W013 codes** are normative in
[`spec/streaming.md §6.5`](streaming.md). Format coverage per
event × output format is normative in §6.6; chunked-table events
on non-CX outputs return `W009` (rejection is monotonic — a future
spec extension can lift the rejection without breaking the v0.6.0
ABI lock).

Capability bit 27 was originally allocated for streaming-write +
 `_shaped` composition. was superseded by 
(2026-05-10); `_shaped` variants and the W011 stub paths are
removed. **Capability bit 27 remains allocated for the streaming-write
surface itself** — it now signals the 21-symbol surface (4 lifecycle
+ 17 emit) without the shape variants. Bit 27 stays at `0x8000000`;
no reassignment.

### 2.16 CXL evaluator (NEW in v0.6.0; CXL 1.0 evaluator pulled forward 2026-05-10)

Per .
v0.6.0 ships both the **ABI surface** and the **CXL 1.0 evaluator**
implementation (the latter pulled forward from v0.7.0 in the
2026-05-10 amendment to — CXL became the sole output-shape
mechanism when was superseded). Subsequent CXL versions
(CXL 3.1, CXL 4.0) ship at later CX releases §10 and
target eventual XQuery 4.0 feature equivalence. At v0.6.0, the
three symbols below are fully implemented and return evaluated
output (or `W012` for v0.6.0-out-of-scope CXL 3.1+ syntax,
0016 R4).

```c
/* One-shot: evaluate a CXL program against a CX input, return output bytes. */
char* cx_eval (const char* cx_input,
 const char* cxl_program,
 const char* output_target,
 char** err_out);

char* cx_eval_with_len (const char* cx_input, size_t cx_len,
 const char* cxl_program, size_t prog_len,
 const char* output_target,
 char** err_out);

/* Streaming: evaluate incrementally into a caller-supplied write callback.
 * Composes with the chunked-table reader (§2.10) and the streaming-write
 * API (§2.15) for memory-bounded evaluation of multi-GB inputs. */
typedef int (*cx_eval_write_cb)(const char* bytes, size_t n, void* user);

char* cx_eval_streaming (const char* cx_input,
 const char* cxl_program,
 const char* output_target,
 cx_eval_write_cb write_cb,
 void* user,
 char** err_out);
```

`cx_input` is a CX document; `cxl_program` is a CXL program (a CX
document parsed under grammar v3.5 with Interpolation [58] and
EvalDirective [59] productions). `output_target` is one of `text`,
`html`, `markdown`, `json`, `yaml`, `xml`, `cx`, `csv`, `tsv` (or
NULL/empty to use the program's own `[?cx output-target=…]`
declaration). The return value is the evaluated output, or NULL with
`*err_out` set on error. The error-message wire format reuses the
W-code prefix convention from §2.13 / §2.15.

W-codes defined for the CXL surface:

| Code | Meaning |
|-------|---------|
| `W012`| CXL evaluator not implemented (v0.6.0 stub return) |
| `W013-W019` | Reserved for the CXL 1.0 evaluator (unbound variable, bad CXPath inside program, type mismatch, recursive include, future-CXL-version EvalName at older evaluator, etc.); finalized in `spec/eval.md §2.5` at CX release v0.6.0 |

Three symbols total (2 one-shot + 1 streaming). All three are class
**P** (pure, thread-safe) per [§1.5.1](#151-per-symbol-thread-safety-classes)
— they consume immutable input buffers and produce a new heap-allocated
output.

Capability bit 28 (`0x10000000`) signals the evaluator is implemented.
**v0.6.0 V reference libcx sets bit 28** (CXL 1.0 evaluator pulled
forward per the 2026-05-10 amendment to ). Pre-v0.6.0 libcx
versions export the symbols but leave the bit unset. Bindings MUST
query the bit before invoking the symbols and surface "CXL evaluator
not available" to callers when the bit is unset (e.g., older libcx
loaded by a newer binding).

**v0.7.0 widening (EE3 per [ADR 0023](decisions/0023-cx-self-host-module-and-extension-interface.md)
Amendment #2 R2).** At v0.7.0 the semantics of bit 28 are widened
from "CXL 1.0 evaluator present" to "full DD/EE/FF self-host surface
present." A v0.7.0+ libcx that sets bit 28 commits to **all** of the
following, exhaustively:

- The 23-function `cx:` module per [`spec/modules/cx.md`](modules/cx.md) (DD1–DD22)
- The 7-function `log:` module per [`spec/modules/log.md`](modules/log.md) (FF1–FF7) plus its three `[?cx log-*=...]` directives
- The `ModuleSpec` catalog (EE1) exposed through `inspect:module-available` / `inspect:module-version` / `inspect:functions`
- The `[?cx use-module=...]` activation directive (EE2)
- The Pure / ReadOnly / SideEffect classification with `[?cx pure-only]` enforcement (EE4)
- The five `cx:eval` mitigations (M1–M5 per ADR 0023 §D6) with the
  `cx-err:CXER0040..0044` error codes
- The `EvaluatorHook` signature (EE7) reserved for v0.8.0+ debug
  adapters (signature stability through 1.0; no external registration
  surface yet)

A binding that ships *some but not all* of DD/EE/FF leaves bit 28
clear and routes through the v0.6.0 compatibility shim path. There
is no partial-credit advertisement at v0.7.0 — bit 28 is the all-or-
nothing surface commitment. The bit-budget rationale for not
allocating per-module bits is in ADR 0023 §D4-revised: per-module
discovery happens at the cxl level via the `inspect:` surface, which
gives v0.8.0 BaseX-class modules a discovery story without burning
ABI bits.

---

## 3 — Capability bitmask (`cx_features`)

`cx_features` returns a NUL-terminated lowercase hex string encoding a
64-bit capability bitmask. Bindings call this on load and refuse to use
features the loaded library does not implement.

| Bit | Hex | Capability |
|---|---|---|
| 0 | 0x0001 | ABI v1 conversion symbols (always 1 in any v1+ libcx) |
| 1 | 0x0002 | Binary AST (cx_to_ast_bin) — always 1 in v1+ |
| 2 | 0x0004 | Binary events (cx_to_events_bin) — always 1 in v1+ |
| 3 | 0x0008 | Symmetric binary AST (CB-1, CB-2 fixes) — v2+ |
| 4 | 0x0010 | data_bin core (cx_to_data_bin / cx_from_data_bin) — v2+ |
| 5 | 0x0020 | data_bin one-shot loaders / dumpers — v2+ |
| 6 | 0x0040 | Delimited (CSV / TSV / PSV / arbitrary single-char) — v2.1+ |
| 7 | 0x0080 | Canonical form (cx_fmt / cx_canonical / cx_hash / cx_eq) — v2+ |
| 8 | 0x0100 | CXPath C ABI — v2+ |
| 9 | 0x0200 | Real streaming (cx_events_open / next / close) — v2+ |
| 10 | 0x0400 | `:table` block in grammar — v2+ |
| 11 | 0x0800 | `:decimal` type — v2+ |
| 12 | 0x1000 | `:f16` type — v2+ |
| 13 | 0x2000 | Boolean attribute sigils (+/-) — v2+ |
| 14 | 0x4000 | Line comments (#) — v2+ |
| 15 | 0x8000 | Logfmt mode (top-level bare attributes) — v2+ |
| 16 | 0x10000 | Numeric underscores — v2+ |
| 17 | 0x20000 | RESERVED — superseded by bit 23 ; originally allocated for "Apache Arrow C-Data interop" in v2.0; no v2.0.x libcx shipped Arrow under this bit. v2.x libcx may keep bit 17 set for back-compat but bindings SHOULD query bit 23. |
| 18 | 0x40000 | `cx_diff` (semantic diff) — v2.1+ |
| 19 | 0x80000 | `cx_lint` (style + correctness warnings) — v2.1+ |
| 20 | 0x100000 | ID / IDREF C ABI (`cx_id_lookup` / `cx_resolve_ref` / `cx_node_id`) — v2.1+ |
| 21 | 0x200000 | Chunked-table format (tag `0x63`, [`spec/data_bin.md §3.11`](data_bin.md)) plus the streaming Table reader / writer C ABI ([§2.10](#210-streaming-table-reader--writer-new-in-v060)) — v0.6.0+ D7 |
| 22 | 0x400000 | Page-compression wrapper (tag `0x90`, zstd v1, [`spec/data_bin.md §3.12`](data_bin.md)) — v0.6.0+ D7 |
| 23 | 0x800000 | Apache Arrow C-Data interop (`libcx_arrow`, [§2.11](#211-apache-arrow-c-data-interop-new-in-v060-separate-library)) — v0.6.0+ D7. Canonical Arrow capability bit going forward; supersedes bit 17. |
| 24 | 0x1000000 | Schema-driven encoding (header flag bit 1, [`spec/data_bin.md §3.13`](data_bin.md)) plus [§2.12](#212-schema-driven-encoding-new-in-v060) entry points — v0.6.0+ D7 |
| 25 | 0x2000000 | Schema validator (`cx_validate` / `cx_validate_apply_defaults` plus `_with_len` variants per [§2.13](#213-schema-validator-new-in-v060), + [`spec/schema.md §10`](schema.md)) — v0.6.0+. Includes RE2-backed `:pat=` pattern matching (S008 rule); pattern-engine semantics are normative cross-binding because every binding routes through `cx_validate`. |
| 26 | 0x4000000 | Thread-init handshake ([§1.5.5](#155-thread-init-handshake)): `cx_init` / `cx_thread_register` / `cx_thread_unregister` — v0.6.0+. Required for bindings whose host runtime spawns OS threads outside V's control (Rust, C#, Java); cheap and harmless on every other binding. |
| 27 | 0x8000000 | Streaming-write API (`cx_events_writer_*` per [§2.15](#215-streaming-write-api-new-in-v060), [`spec/streaming.md §6`](streaming.md), ) — v0.6.0+. 21 C ABI symbols (4 lifecycle + 17 emit) covering 14 stream events × 6 output formats with emit-time validation. (Originally 25 symbols including 4 `_shaped` open variants for composition; the `_shaped` variants and the W011 stub paths were removed 2026-05-10 when was superseded by . CXL is the only output-shape mechanism — see bit 28 / §2.16.) |
| 28 | 0x10000000 | CXL evaluator (`cx_eval` + `cx_eval_with_len` + `cx_eval_streaming` per [§2.16](#216-cxl-evaluator-new-in-v060-cxl-10-evaluator-pulled-forward-2026-05-10), [`spec/eval.md`](cxl.md), ) — v0.6.0+. The CX parser recognizes the `[?=EXPR]` Interpolation form, the `[?Name ...]` EvalDirective form, and `BracketBody` attribute values D3. The CXL 1.0 evaluator was pulled forward from v0.7.0 in the 2026-05-10 amendment to when it became the sole output-shape mechanism. A v0.6.0 libcx that ships the CXL 1.0 evaluator sets this bit to 1. **v0.7.0 widens semantics** (EE3 per [ADR 0023](decisions/0023-cx-self-host-module-and-extension-interface.md) Amendment #2 R2): bit 28 set on a v0.7.0+ libcx commits to the full DD/EE/FF self-host surface — 23-function `cx:` module ([`spec/modules/cx.md`](modules/cx.md)), 7-function `log:` module ([`spec/modules/log.md`](modules/log.md)) plus three `[?cx log-*=...]` directives, `ModuleSpec` catalog exposed through `inspect:`, `[?cx use-module=...]` activation, `[?cx pure-only]` Pure/ReadOnly/SideEffect enforcement, `cx:eval` five-mitigation enforcement (M1–M5 with `cx-err:CXER0040..0044`), and `EvaluatorHook` signature reservation. Partial-DD/EE/FF bindings leave bit 28 clear. Per-module presence in user code goes through `inspect:` at the cxl level, not separate ABI bits — see §1.5 narrative for the bit-budget rationale. |
| 29 | 0x20000000 | Collection literals + CXDM v1.1 — v0.6.0+. Signals support for the three new container Item kinds (Array `[a, b, c]`, Map `{k: v}`, Sequence `(a, b, c)`) across parser ([`spec/grammar.ebnf §[56]`](grammar.ebnf)), AST ([`spec/ast.md`](ast.md)), ast_bin v6 ([`spec/ast_bin.md`](ast_bin.md)), all six emitters §D12, CXL evaluator under refactored directive syntax §D7, CXPath union / array indexing / map key access §D13, and schema validator under `seq[T]` / `arr[T]` / `map[K, V]` productions §D15. ** §D23–D25 (labeled directive form) is parser-only and signaled by this same bit 29** — no separate capability is needed since the AST / ast_bin / canonical / evaluator are unchanged by labeled-form parsing (it desugars to the same positional AST). The bit is set only when ALL of the surface components are implemented; partial implementations leave the bit clear. v0.6.0 libcx sets bit 29 once the Phase 2–4 implementation lands (per §Migration plan); v0.5.x libcx must leave it clear and reject any ast_bin payload with version byte ≥ 6. |
| 30 | 0x40000000 | Parameterized templates — v0.6.0+. Signals **evaluator-side** support for `?def`'s 3-slot positional form `[?def [name, params, body]]` (per §D7 amendment 2026-05-12) and the labeled-form `:params` slot §D23. Required behavior: lexical-scope evaluator frames binding parameter names within the `body` slot; positional invocation `[?template-name arg1 arg2]` binds args to params; W018 emission on argument-count mismatch; legacy 2-slot `[?def [name, body]]` auto-expanded to 3-slot with `params=[]` at parse time. **No ast_bin or AST shape change** — params lives in the existing ArgArray slot 1 as a regular ArrayNode of identifiers; v6.0 wire format round-trips it natively. Independent of bit 29: a binding may advertise bit 29 (collection literals + §D7 + §D23 parser) without bit 30 (parameter-binding evaluator). Such a binding parses the 3-slot `?def` form (and `:params` desugars to slot 1) but errors at evaluation when params is non-empty (W018-adjacent runtime error). v0.6.0 libcx sets bit 30 once Phase B–D land (V evaluator + 10-binding fan-out + conformance fixtures pass). |
| 31-63 | reserved | (set to 0) |

A v2.0.0 libcx returns `cx_features() == "3ffff"` (bits 0-17 all set);
v2.1+ libcx returns bits 18 and 19 set (`cx_diff` Phase 7.47,
`cx_lint` Phase 7.49) plus bit 20 set (`cx_id_lookup` /
`cx_resolve_ref` / `cx_node_id` Phase 7.65). v0.6.0 libcx adds bits
21 / 22 / 24 / 25 / 26 / 27 / 28 / **29** unconditionally (chunked tables +
page compression + schema-driven encoding + schema validator +
thread-init handshake + streaming-write API + CXL 1.0 evaluator +
collection literals are core-library features) and bit 23
conditionally (set iff `libcx_arrow` is linked into the runtime).
Bit 29 is added once the Phase 2–4 implementation
completes; v0.6.0 ships will not be tagged until then.

**v0.7.0 reuses bits 28 and 30 with widened semantics** rather than
allocating new bits. Bit 28 widens from "CXL 1.0 evaluator" to "full
DD/EE/FF self-host surface" per the §2.16 narrative above (EE3 / ADR
0023 Amendment #2 R2). Bit 30 already covers parameterized templates;
the v0.7.0 first-class function value type (A19 / A20 / A21 `?fn`)
ships under the same bit because parameter-binding semantics are the
load-bearing surface for both — a binding that sets bit 30 at v0.7.0
commits to both the `?def`-with-params shape and the `?fn` value
shape. v0.7.0 adds no new capability bits at v0.7.0 tag time; the
~32 bits remaining (31 plus 32–63) stay reserved for v0.8.0+ module
families (per ADR 0023 §D4-revised, per-module presence is queried
at the cxl level via `inspect:`, not at the ABI level).

**Pattern-engine centralisation (bit 25).** The schema validator's
`:pat=` constraint (S008) routes every match decision through
libcx-vendored RE2. Bindings do **not** run their own regex engines
for schema validation; they call `cx_validate` and receive identical
match results. This is normative — diverging from libcx's regex
flavor would break cross-binding determinism for every schema in
the wild. v0.6.0 ships with a system RE2 dependency (Homebrew `re2`
on macOS; `libre2-dev` / `libre2-X` on Debian/Ubuntu); a vendored
submodule pin lands post-tag for source-version determinism, with
no API or wire-format change.

Bindings examine the bitmask at load time and may degrade gracefully
(or refuse to load) when required capabilities are absent. Required
capability sets are documented per binding.

---

## 4 — Performance budgets

The following are guideline performance targets for ABI v2; not contract
requirements but enforced via the perf-regression suite (see
`spec/architecture.md` §Conformance).

| Operation | 1 KB input | 1 MB input | 100 MB input |
|---|---|---|---|
| `cx_to_ast_bin` | < 50 µs | < 30 ms | < 3 s |
| `cx_to_data_bin` | < 50 µs | < 30 ms | < 3 s |
| `cx_to_json` | < 100 µs | < 60 ms | < 6 s |
| `cx_select` | < 100 µs | < 60 ms | < 6 s |
| `cx_events_next` per event | < 1 µs | — | — |

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
/* libcx C ABI — auto-generated from spec/abi.md */
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
 string output (see `spec/architecture.md` native-implementation rule).

---

## 8 — Migration from ABI v1

ABI v2 is fully backward-compatible. v1 callers continue to work.

Recommended migration for binding maintainers:

1. **Phase A — adopt symmetric binary AST.** Replace each
 `parse_<format>` that did `cx_<format>_to_ast → JSON re-parse` with
 `cx_<format>_to_ast_bin → binary decode`. Replace each
 `Document.to_<format>` that did CX-text round-trip with
 `serialize document → ast_bin → cx_ast_bin_to_<format>`.
2. **Phase B — adopt `cx_to_data_bin`.** Replace each `loads` /
 `dumps` JSON-bridge with `cx_to_data_bin` / `cx_from_data_bin`.
3. **Phase C — adopt CXPath C ABI.** Delete the host-language CXPath
 implementation; replace with thin wrappers over `cx_select` /
 `cx_select_all`.
4. **Phase D — adopt streaming.** Replace `Stream` (which buffered) with
 handle-based iteration over `cx_events_next`.
5. **Phase E — adopt new types and syntax.** Surface `:table`,
 `:decimal`, `:f16` to native types per `spec/type_mapping.md`.

Each phase is independently testable against the v2 conformance suite.
