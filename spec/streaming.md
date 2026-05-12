# CX Streaming API Specification
# Version: 1.2 — 2026-05-10 (streaming write API added — §6 —)
# Version: 1.1 — 2026-05-09 (chunked-table events added D10)
# Original: 1.0 — 2026-04-23

The CX Streaming API provides a SAX/StAX-style event sequence for processing CX
documents without building a full in-memory tree. It is suited for large documents,
pipelines, and transformations that need only a forward pass.

---

## 1 — Event Types

There are 14 `StreamEvent` types: 11 from the original v1.0 specification, plus
3 chunked-table events added in v1.1 per
 D10.
Every parsed node produces one or more events.

### 1.1 — Event type reference

#### StartDoc
Signals the beginning of the document.

Fields: none

Ordering: always the **first** event emitted for any document.

---

#### EndDoc
Signals the end of the document.

Fields: none

Ordering: always the **last** event emitted for any document.

---

#### StartElement
Signals the opening of an element.

| Field | Type | Required | Value |
|-------------|-----------------|----------|-------|
| `name` | string | yes | Element name |
| `anchor` | string or none | no | YAML-style anchor (`&name`), absent when not present |
| `data_type` | string or none | no | Explicit type annotation (`:type`), absent when not present |
| `merge` | string or none | no | Merge directive (`<<anchor`), absent when not present |
| `attrs` | Attr[] | yes | Zero or more key-value attributes; empty list when none |

An `Attr` has:

| Field | Type | Required | Value |
|-------------|-----------------|----------|-------|
| `name` | string | yes | Attribute key |
| `value` | typed scalar | yes | Native-typed value: int, float, bool, null, or string |
| `data_type` | string or none | no | Explicit type annotation on the attribute, absent when inferred |

All attributes are emitted in document order.

---

#### EndElement
Signals the closing of an element.

| Field | Type | Required | Value |
|--------|--------|----------|-------|
| `name` | string | yes | Element name — same value as the matching StartElement |

Ordering: immediately after all events for the element's body (children, text,
etc.) have been emitted.

---

#### Text
A raw text node.

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | Raw text content (untyped string) |

A Text event is produced for quoted body content (`'hello world'`) and bare
body text (`hello world`) that does not auto-type to a scalar.

---

#### Scalar
A typed scalar value.

| Field | Type | Required | Value |
|-------------|----------------|----------|-------|
| `data_type` | string or none | no | One of: `int`, `float`, `bool`, `null`, `string`, `date`, `datetime`, `bytes`. Absent only when type is inferred as string and no explicit annotation is present. |
| `value` | string | yes | The scalar value as a raw string (e.g. `"42"`, `"true"`, `"3.14"`) |

Scalars are unquoted body values that auto-type to a non-string type, or any
body value with an explicit type annotation.

`value` is always the raw string representation. Decoders use `data_type` to
reconstruct the native typed value.

---

#### Comment
An inline comment.

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | Comment text, without the `[-` / `-]` delimiters |

---

#### PI
A processing instruction.

| Field | Type | Required | Value |
|----------|----------------|----------|-------|
| `target` | string | yes | PI target name |
| `data` | string or none | no | PI data content; absent when not present |

---

#### EntityRef
An XML entity reference.

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | Entity name without `&` and `;` (e.g. `amp`, `lt`, `nbsp`) |

---

#### RawText
A raw text block (preserves newlines and indentation).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | Full content of the raw text block, with original whitespace |

---

#### Alias
A YAML-style alias reference.

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | Anchor name being referenced (without `*` prefix) |

---

#### StartTable
Signals the opening of a chunked table (CXDB tag `0x63`, see
[`spec/data_bin.md §3.11`](data_bin.md)). Emitted in place of the
`StartElement` that would otherwise wrap a `:table` body when the
underlying wire form is chunked.

| Field | Type | Required | Value |
|------------|----------|----------|-------|
| `name` | string | yes | Element name (matches the enclosing `[<name> :table[...] ...]`) |
| `col_spec` | binary | yes | The chunked-table col-spec as `[u32 LE: count]([u32 LE: name_len]name [u8: col_type_code])*` (§3.10.1) |

Ordering: emitted instead of `StartElement` for chunked tables.
A non-chunked `0x60` table emits the existing
StartElement / per-cell-Scalar / EndElement sequence unchanged; only
chunked (`0x63`) tables produce StartTable / RowGroup / EndTable.

---

#### RowGroup
A single row group of a chunked table.

| Field | Type | Required | Value |
|-------------|------------|----------|-------|
| `row_count` | u32 | yes | Number of rows in this group |
| `payload` | binary | yes | The row-group plain-body bytes (§3.11.2): `uvarint(row_count) <col-payload>(col_count)`. Compressed groups (§3.12) are decompressed before emission so consumers see uniform plain bodies. |

Ordering: zero or more RowGroup events follow a StartTable event,
in source order, before the matching EndTable.

---

#### EndTable
Signals the close of a chunked table.

| Field | Type | Required | Value |
|--------|--------|----------|-------|
| `name` | string | yes | Element name — same value as the matching StartTable |

Ordering: closes the StartTable / RowGroup* sequence in place of
the corresponding `EndElement`.

---

### 1.2 — StreamEvent structure

In all language bindings, a single `StreamEvent` value carries all possible fields.
Fields that do not apply to a given event type carry their zero/absent value:
- Absent optional strings: `none` / `nil` / `null`
- Absent attrs: `[]` (empty list)
- Absent string fields: `""` (empty string)
- Absent binary fields: zero-length byte buffer

The `typ` / `type` field identifies the event type.

```
StreamEvent {
 typ: EventType -- one of the 14 types
 name: string -- StartElement / EndElement / StartTable / EndTable
 anchor: ?string -- StartElement (absent if none)
 data_type: ?string -- StartElement type annotation, or Scalar data type
 merge: ?string -- StartElement merge directive (absent if none)
 attrs: Attr[] -- StartElement attributes (empty if none)
 value: string -- Text, Comment, RawText, EntityRef name, Alias name, Scalar raw value
 target: string -- PI target
 data: ?string -- PI data (absent if none)
 col_spec: bytes -- StartTable column specification
 row_count: u32 -- RowGroup row count (0 for non-RowGroup events)
 payload: bytes -- RowGroup decompressed plain-body bytes
}
```

---

## 2 — Event Ordering Guarantees

The event sequence for any well-formed CX document satisfies these invariants:

1. **StartDoc is first.** No other event precedes StartDoc.
2. **EndDoc is last.** No other event follows EndDoc.
3. **Document prolog events** (XMLDecl, CXDirective, DoctypeDecl) appear after
 StartDoc and before the first StartElement for a top-level element.
4. **StartElement / EndElement are balanced.** For every StartElement with name `n`
 at nesting depth `d`, there is exactly one corresponding EndElement with name `n`
 at the same depth, and all events for the element's body appear between them.
5. **Children before siblings.** All events for an element's body appear before the
 EndElement of that element. Depth-first, document order.
6. **BlockContent is transparent.** BlockContent nodes are not emitted as events.
 Their children are emitted inline, in order, as if the BlockContent node did not exist.
7. **StartTable / RowGroup* / EndTable are balanced.** A chunked table emits
 exactly one StartTable, zero or more RowGroup events in source order, and
 exactly one matching EndTable. RowGroup events do not nest. No StartElement /
 EndElement events appear between StartTable and EndTable for the table itself;
 row-internal data lives in the RowGroup `payload` byte buffers and is decoded
 per [`spec/data_bin.md §3.11.2`](data_bin.md) by consumers that need
 row-by-row access.

**Example event sequence for:**
```cx
[doc
 [h1 Title]
 [p First line.]
]
```

```
StartDoc
StartElement { name:"doc" }
 StartElement { name:"h1" }
 Text { value:"Title" }
 EndElement { name:"h1" }
 StartElement { name:"p" }
 Text { value:"First line." }
 EndElement { name:"p" }
EndElement { name:"doc" }
EndDoc
```

---

## 3 — API Contract

### 3.1 — stream(cx_str)

Parses the CX source string and returns all events.

```
stream(cx_str) → EventSequence
```

- **Input:** a CX-format string.
- **Return:** a language-idiomatic sequence of StreamEvent. See §3.2 for per-language types.
- **Eagerness:** the current implementation is **eager** — all events are produced
 upfront and returned as a list or iterator over that list. Lazy streaming (events
 produced on demand from a live parse) is not part of v1; implementations that
 wrap an eager list with a lazy interface are conformant.
- **Error:** if the CX source is malformed, raises/throws a parse error using the
 same error convention as `parse()` (see `spec/architecture.md §3.5`). No partial
 event sequence is returned on error.
- **Reuse:** the returned sequence MAY be consumed more than once. An implementation
 that returns a list (not a one-shot iterator) is conformant and preferred.

### 3.2 — Per-language idioms

| Language | Return type | Iteration idiom |
|------------|---------------------------|-----------------|
| V | `![]StreamEvent` | `for e in events { ... }` |
| Python | `list[StreamEvent]` | `for e in stream(src): ...` |
| Go | `([]StreamEvent, error)` | `for _, e := range events { ... }` |
| Rust | `Result<Vec<StreamEvent>, CxError>` | `for e in events { ... }` |
| TypeScript | `StreamEvent[]` | `for (const e of events) { ... }` |
| C# | `IEnumerable<StreamEvent>`| `foreach (var e in events) { ... }` |
| Swift | `[StreamEvent]` | `for e in events { ... }` |
| Java | `List<StreamEvent>` | `for (StreamEvent e : events) { ... }` |
| Kotlin | `List<StreamEvent>` | `for (e in events) { ... }` |
| Ruby | `Array<StreamEvent>` | `events.each { |e| ... }` |

For languages with native streaming types (Go channels, Rust async iterators,
Swift AsyncSequence), providing an additional streaming variant is permitted but
the synchronous list return MUST be the primary conformance target.

### 3.3 — Parse errors mid-stream

Because the current implementation is eager (full parse before first event), all
parse errors are detected before any event is returned. There is no partial event
sequence. The error contract is: either return the complete event list, or raise
an error. Never return a partial list.

---

## 4 — Implementation

Streaming in non-V language bindings is implemented via the C ABI binary protocol:

1. Call `cx_to_events_bin(cx_str, err_out)`.
2. If result is NULL, raise a parse error using `*err_out`.
3. Read `payload_size` from the first 4 bytes (u32 LE).
4. Read `event_count` from bytes 4–7 of the payload (u32 LE).
5. Decode each event from the binary payload using the format in `spec/architecture.md §4.2`.
6. Call `cx_free(buffer)`.
7. Return the decoded event list.

V does not use this path. V's `stream()` walks the parsed Document directly
(see `lang/v/cxlib/stream.v`).

The binary format is fully specified in `spec/architecture.md §4.2` including a
test vector. Streaming conformance is validated against the fixtures in
`fixtures/stream/`.

---

## 5 — v1 Scope

**In scope:**
- 14 event types (the original 11 plus the chunked-table triplet
 StartTable / RowGroup / EndTable D10)
- Eager event list (full parse, then deliver all events)
- `stream(cx_str)` — CX source input only
- Binary wire protocol (`cx_to_events_bin`) for all non-V bindings
- Per-language idiomatic sequence type
- **Streaming write API** — see §6 below — symmetric event-driven
 writer; output to in-memory buffer or fd; format-targeted across
 CX / XML / JSON / YAML / TOML / MD; validation at emit time

**Deferred:**
- Lazy / pull-parser streaming on the read side (events produced
 on demand from a live parse)
- Streaming from non-CX input formats (XML, JSON, etc.)
- Random access within the event stream
- Back-pressure beyond fd write blocking
- Mid-stream cancellation beyond `cx_events_writer_close`

---

## 6 — Streaming write API

The streaming write API is the symmetric counterpart to §3 — instead
of parsing a CX source and consuming events, adopters construct an
event sequence programmatically and the writer emits format-targeted
output. Per , the
writer is handle-based, format-targeted, validation-at-emit-time, and
composes with output-shape control 
plus chunked-table writing .

### 6.1 — Goals and non-goals

**Goals:**
1. **Symmetric to the read API.** Same event vocabulary (§1), same
 handle lifecycle pattern, same error-and-diagnostic model.
2. **No full-document buffering.** Memory cost per writer is bounded.
 Large outputs (multi-GB datasets, log streams, long-lived web
 responses) don't require correspondingly large memory.
3. **Order-validating.** The writer rejects malformed event sequences
 (e.g., EndElement without matching StartElement, double StartDoc,
 content events after EndDoc) at the emit call, not silently
 producing malformed output.
4. **Format-targeted.** The same event stream can drive CX, XML,
 JSON, YAML, TOML, or Markdown emission, selected at writer-open
 time. Shape control 
 composes via `_shaped` open variants.
5. **Per-binding-wrappable.** The C ABI surface admits idiomatic
 wrappers (Python context manager, Go `defer Close()`, Rust RAII,
 etc.) without a translation tax.

**Non-goals:**
- Random access within the output stream.
- Backpressure beyond the OS-level `write(2)` blocking on fd writers.
- Mid-stream cancellation beyond `cx_events_writer_close` releasing
 resources. No "abort and don't emit anything" mode in v0.6.0.

### 6.2 — Lifecycle

A writer is opened, populated, and closed through a handle. Per
`spec/abi.md §1.5.1` the handle is **thread-local** (H-class):
one writer = one thread.

```c
typedef struct cx_events_writer cx_events_writer;

/* In-memory writer — accumulates output in a buffer returned by
 * _close_get_bytes. Suitable when the output fits in memory. */
cx_events_writer* cx_events_writer_open(
 const char* output_format, /* "cx"/"xml"/"json"/"yaml"/"toml"/"md" */
 char** err_out);

/* fd-streaming writer — each emit call writes the event's bytes to
 * the fd; no accumulation. Suitable for unbounded outputs. */
cx_events_writer* cx_events_writer_open_fd(
 const char* output_format,
 int fd,
 char** err_out);

/* Shape-aware variants (compose with ). `shape_input` is a
 * `.cxsh` byte buffer or NULL for deterministic / unshaped output.
 * In v0.6.0 the shape engine itself is not yet implemented; passing
 * a non-NULL shape returns NULL with `*err_out = "W011: shape engine
 * not yet implemented"`. The symbols themselves are part of the
 * v0.6.0 ABI lock so adopters can probe and rely on them once the
 * shape engine ships. */
cx_events_writer* cx_events_writer_open_shaped(
 const char* output_format,
 const char* shape_input, /* nullable, .cxsh bytes */
 char** err_out);

cx_events_writer* cx_events_writer_open_fd_shaped(
 const char* output_format,
 const char* shape_input,
 int fd,
 char** err_out);

/* `_with_len` siblings for the framed-binary `shape_input` —
 * mandatory per spec/abi.md §2.14. */
cx_events_writer* cx_events_writer_open_shaped_with_len(
 const char* output_format,
 const char* shape_input,
 size_t shape_len,
 char** err_out);

cx_events_writer* cx_events_writer_open_fd_shaped_with_len(
 const char* output_format,
 const char* shape_input,
 size_t shape_len,
 int fd,
 char** err_out);

/* Returns the accumulated buffer for in-memory writers; for fd
 * writers the buffer is empty (output already flushed to fd).
 * Implicitly emits EndDoc (with W004 if elements remain unclosed)
 * and releases the handle. Caller frees the returned bytes via
 * cx_free. NULL with *err_out set when the writer has reached an
 * unrecoverable error state (see §6.5). */
char* cx_events_writer_close_get_bytes(
 cx_events_writer* w,
 char** err_out);

/* Releases the handle without returning bytes. Suitable when the
 * adopter wants to abort and discard accumulated output, or when
 * using fd writers (where _close_get_bytes is equivalent). */
void cx_events_writer_close(cx_events_writer* w);
```

Total: **8 lifecycle symbols.**

The unshaped `_open` and `_open_fd` are equivalent to `_open_shaped`
and `_open_fd_shaped` with `shape_input=NULL`. They exist as
ergonomic shortcuts for the no-shape case, which is the dominant
v0.6.0 path.

### 6.3 — Event vocabulary

The writer accepts the same 14 event types defined in §1 (the 11
original plus the chunked-table triplet StartTable / RowGroup /
EndTable D10). XMLDecl / CXDirective / DoctypeDecl
nodes are AST-layer constructs, not stream events; the read side
filters them per `vcx/cx/stream.v` and the write side does not
expose them. Adopters who need to emit a CX directive or XML
declaration in the output produce it via the AST API
(`cx_to_cx`) before the streaming-write phase, not as an event.

### 6.4 — Per-event emit functions

Each event type has a typed emit function. Functions return `NULL`
on success or a heap-allocated diagnostic string in the return
value plus a UTF-8 message in `err_out` on failure (matching the
existing C ABI convention per `spec/abi.md §1.3`). The diagnostic
string carries the W-code and short message; the framed payload
(when more detail is needed) follows the format in `spec/abi.md
§2.13` with prefix byte `'W'`.

```c
char* cx_events_writer_start_doc (cx_events_writer* w, char** err_out);
char* cx_events_writer_end_doc (cx_events_writer* w, char** err_out);

char* cx_events_writer_start_element (cx_events_writer* w,
 const char* name,
 const char* anchor, /* nullable */
 const char* data_type, /* nullable */
 const char* merge, /* nullable */
 const char* attrs_payload, /* binary, length-prefixed */
 char** err_out);

char* cx_events_writer_start_element_with_len
 (cx_events_writer* w,
 const char* name,
 const char* anchor,
 const char* data_type,
 const char* merge,
 const char* attrs_payload,
 size_t attrs_len,
 char** err_out);

char* cx_events_writer_end_element (cx_events_writer* w,
 const char* name,
 char** err_out);

char* cx_events_writer_text (cx_events_writer* w,
 const char* value,
 char** err_out);

char* cx_events_writer_scalar (cx_events_writer* w,
 const char* data_type, /* nullable */
 const char* value,
 char** err_out);

char* cx_events_writer_comment (cx_events_writer* w,
 const char* value,
 char** err_out);

char* cx_events_writer_pi (cx_events_writer* w,
 const char* target,
 const char* data, /* nullable */
 char** err_out);

char* cx_events_writer_entity_ref (cx_events_writer* w,
 const char* name,
 char** err_out);

char* cx_events_writer_raw_text (cx_events_writer* w,
 const char* value,
 char** err_out);

char* cx_events_writer_alias (cx_events_writer* w,
 const char* name,
 char** err_out);

/* Chunked-table events ( D10). Compose with cx_table_writer_*
 * — see §6.8. */
char* cx_events_writer_start_table (cx_events_writer* w,
 const char* col_spec_payload, /* framed binary */
 char** err_out);

char* cx_events_writer_start_table_with_len
 (cx_events_writer* w,
 const char* col_spec_payload,
 size_t col_spec_len,
 char** err_out);

char* cx_events_writer_row_group (cx_events_writer* w,
 const char* row_group_payload, /* framed binary */
 char** err_out);

char* cx_events_writer_row_group_with_len
 (cx_events_writer* w,
 const char* row_group_payload,
 size_t row_group_len,
 char** err_out);

char* cx_events_writer_end_table (cx_events_writer* w,
 char** err_out);
```

Total: **17 emit symbols** (14 base + 3 `_with_len` siblings for the
emit functions that take framed binary inputs: `start_element`,
`start_table`, `row_group`).

**Grand total surface:** 8 lifecycle + 17 emit = **25 C ABI symbols.**

The `attrs_payload` for `start_element` uses the same length-prefixed
binary attribute format the read side uses (§1.2). Bindings construct
this from their idiomatic attribute representation and call the
`_with_len` variant.

The `col_spec_payload` for `start_table` and the `row_group_payload`
for `row_group` use the wire shapes defined in
[`spec/data_bin.md §3.11`](data_bin.md). Bindings construct these via
the same helpers used by `cx_table_writer_*` (per §6.8).

### 6.5 — Validation at emit time

The writer maintains internal state tracking nesting depth,
StartDoc-emitted, EndDoc-emitted, table-open, and per-event
preconditions. Each emit call validates against the current state
before producing any bytes:

| Event | Preconditions |
| --------------- | ------------- |
| StartDoc | EndDoc not emitted; StartDoc not already emitted |
| EndDoc | StartDoc emitted; nesting depth = 0; no table open |
| StartElement | StartDoc emitted; EndDoc not emitted; no table open |
| EndElement | matches the most-recent unclosed StartElement (LIFO); name matches |
| Text / Scalar / Comment / PI / EntityRef / RawText / Alias | StartDoc emitted; EndDoc not emitted; no table open |
| StartTable | StartDoc emitted; EndDoc not emitted; no other table currently open |
| RowGroup | matches an open StartTable (LIFO; tables don't nest in v0.6.0) |
| EndTable | matches the most-recent open StartTable |

Violations error at the emit call with W-prefix codes:

| Code | Meaning |
| ------ | ------- |
| `W001` | StartDoc emitted twice |
| `W002` | event before StartDoc |
| `W003` | event after EndDoc |
| `W004` | EndDoc with unclosed elements or open table |
| `W005` | EndElement name mismatch |
| `W006` | EndElement without matching StartElement |
| `W007` | invalid event field (e.g., empty StartElement name; malformed binary payload) |
| `W008` | invalid `data_type` value (not a recognised type tag) |
| `W009` | format-specific output error (event has no representation in the target output format) |
| `W010` | nested StartTable (tables don't nest in v0.6.0) |
| `W011` | shape engine not yet implemented (`_shaped*` open variants with non-NULL shape input) |
| `W012` | RowGroup without open StartTable |
| `W013` | EndTable name mismatch / no open StartTable |

The writer **fails closed.** An emit that produces a W-code leaves
the writer in an unrecoverable error state; subsequent emits return
the same code without effect. `_close_get_bytes` returns NULL with
the original error in `*err_out`.

### 6.6 — Format coverage

The same event stream can drive any of the six formats listed at
open time. Per-event support per format:

| Event | cx | xml | json (AST) | yaml (AST) | toml | md |
| --------------------------- | ------ | ----------- | ------------- | ------------ | ------------ | ------------ |
| StartDoc / EndDoc | ✓ | ✓ | ✓ | ✓ | `W009` | `W009` |
| StartElement / EndElement | ✓ | ✓ | ✓ | ✓ | `W009` | `W009` |
| Text | ✓ | ✓ | ✓ AST Text | ✓ AST Text | `W009` | `W009` |
| Scalar | ✓ | ✓ | ✓ AST Scalar (typed) | ✓ AST Scalar (typed) | `W009` | `W009` |
| Comment | ✓ | ✓ | ✓ AST Comment | ✓ AST Comment| `W009` | `W009` |
| PI | ✓ | ✓ | ✓ AST PI | ✓ AST PI | `W009` | `W009` |
| EntityRef | ✓ | ✓ | ✓ AST EntityRef | ✓ AST EntityRef | `W009` | `W009` |
| RawText | ✓ | as CDATA | ✓ AST RawText | ✓ AST RawText| `W009` | `W009` |
| Alias | ✓ | `W009` | ✓ AST Alias | ✓ AST Alias | `W009` | `W009` |
| StartTable / RowGroup / EndTable | ✓ | `W009` | `W009` | `W009` | `W009` | `W009` |

#### 6.6.1 — JSON / YAML output shape is the **AST shape**

The streaming-write API's JSON and YAML outputs encode the event
stream as the **AST representation** — the same canonical shape
produced by `cx_to_ast_json` (see [`spec/api.md`](api.md)) — not the
data-oriented semantic shape produced by `cx_to_json`. This is
deliberate and locked at v0.6.0 through 1.0:

- **§6.1 goal #2 (no full-document buffering) is normative.** The
 semantic shape requires per-element lookahead to decide between
 scalar / array / mapping / `"_"`-keyed-content forms (sibling
 collisions promote to arrays; "all scalars" elements collapse to
 arrays; etc.). Streaming-write cannot perform that lookahead
 without buffering, so it ships the lossless AST shape and leaves
 semantic shape to the non-streaming `cx_to_json` / `cx_to_yaml`
 surfaces.
- **Conformance-as-contract.** Every event maps to one AST node with
 no decision branches, so cross-binding byte-equivalence is
 trivial. The semantic shape's decision branches accumulate
 per-implementation drift risk.
- **Symmetric to the read API.** §3 exposes events directly; the
 symmetric write surface emits AST nodes directly.
- **Adopters who need semantic JSON / YAML output already have
 it** via the non-streaming `cx_to_json` / `cx_to_yaml` surfaces,
 which buffer the document by design.

The per-event AST shape is normatively defined in [`spec/api.md`](api.md)
(`cx_to_ast_json` documentation). In summary, every Element emits:

```json
{"type":"Element","name":NAME[,"anchor":...][,"merge":...][,"dataType":...]
 [,"attrs":[{"name":...,"value":...,"dataType":...,"isRef":...},...]]
 ,"items":[<body events>]}
```

`anchor` / `merge` / `dataType` are emitted only when present on the
StartElement event. `attrs` is emitted only when the event carries
at least one attribute. `items` is always emitted (possibly `[]`)
so that EndElement can close the element with a single `]}` regardless
of body content — this keeps the writer purely stream-local.

#### 6.6.2 — TOML / MD return `W009` for the entire format

TOML and MD streaming-write returns `W009` for every event including
StartDoc. The reason is **structural mismatch**: TOML's section-path
syntax and MD's tree-of-prose model do not admit a stream-local
encoding that is both useful and faithful. The two options
considered and rejected at the v0.6.0 spec lock:

- TOML as AST array-of-tables (`[[elements.items.items.items]]`):
 technically stream-local and faithful, but produces TOML that no
 human would author, with deep path accumulation that defeats the
 format's design intent.
- MD as AST-tree bullet list or fenced JSON-in-MD: lossy as MD (the
 parsed MD does not round-trip to AST) and useful only as a
 diagnostic transport.

Adopters who need TOML or MD output use the non-streaming
`cx_to_toml` / `cx_to_md` surfaces, which buffer the document and
produce idiomatic output. The streaming-write capability bit
(`0x8000000`, [`spec/abi.md §3`](abi.md) bit 27) covers the
streaming-write API as a whole; bindings should not infer per-format
support from the bit. Per-format support is documented in this
section (§6.6).

The TOML / MD `W009` message includes the explicit reason:
`"W009: <format> output not supported by streaming-write
(structural mismatch; use cx_to_<format> for this format)"`.

This decision is **monotonic** (same rule as the chunked-table
prohibition below): a future spec extension can lift the `W009`
rejection without breaking the v0.6.0 ABI lock. The reverse would
not be possible.

**Chunked-table events on non-CX outputs.** The streaming writer
rejects StartTable / RowGroup / EndTable with `W009` on every output
format other than `cx`. CXDB is the canonical hashable origin for
tabular data; non-CX formats reach tabular data via the
analytics-bridge (Arrow C-Data interop per
[`spec/abi.md §2.11`](abi.md), Parquet via the bridge
decision 10), not through document-format projection. Adopters who
need streamed JSON / XML / etc. of tabular data either (a) convert
their event stream to per-row StartElement / EndElement before emit,
or (b) route through the analytics-bridge — `cx_to_arrow` /
`cx_table_writer_*` produce the canonical bytes; downstream tooling
projects to JSON / Parquet / etc.

This decision is **monotonic**: a future spec extension can lift the
`W009` rejection without breaking the v0.6.0 ABI lock. The reverse
(supporting now, retracting later) would not be.

The shape-control mechanism (§6.7) optionally rewrites events at
emit time once the shape engine ships; until then, adopters
targeting a specific output shape filter their event stream
upstream.

### 6.7 — Composition with output-shape control 

Per , output-shape
control applies at emit time. The `_shaped` open variants accept a
`.cxsh` shape specification that rewrites events as they pass
through the writer. v0.6.0 ships the `_shaped` symbols as part of
the ABI lock but the shape engine itself is deferred — non-NULL
shape input returns `W011` until the engine lands.

When the shape engine ships post-v0.6.0:
- The `_shaped` symbols light up; existing adopters (who passed
 `shape_input=NULL` or used the unshaped `_open` variants)
 observe no behavioural change.
- The same event stream can produce different shaped outputs
 through different writer instances opened with different shape
 specs, without re-emitting events.
- Capability bit (TBD) signals shape-engine
 availability; bindings probe before passing non-NULL shape input.

### 6.8 — Composition with chunked-table writer 

[`spec/abi.md §2.10`](abi.md) defines `cx_table_writer_*` — a
table-only writer for adopters whose entire output is a single
chunked table. The streaming-write API (§6) covers the broader
event-driven flow: documents containing tables, multi-table
documents, mixed table-and-element output.

Both surfaces share the same wire-format primitives (data_bin §3.11
row-group framing). Internally the streaming writer's StartTable /
RowGroup / EndTable handlers delegate to the same encoder used by
`cx_table_writer_*`. Adopters choose the surface by use case:

| Adopter need | Use |
| -------------------------------------------------- | ------------------------------------ |
| "I have one table and want CXDB bytes / fd output" | `cx_table_writer_*` (§2.10) |
| "I have a document that contains tables" | `cx_events_writer_*` (§6, this section) |
| "I have multiple independent tables" | Either; streaming-write is more idiomatic if the tables share output framing |

Bytes produced by either surface are bit-equivalent for the same
input data and column spec. There is no canonicality difference.

### 6.9 — Per-binding wrapping idioms

The 25-symbol C ABI surface wraps thinly per binding:

| Binding | Idiom |
| ---------- | ----- |
| Python | `cxlib.EventWriter(format)` context manager; methods `start_element(name, **attrs)`, `end_element(name)`, `text(value)`, etc.; `__exit__` calls `cx_events_writer_close` |
| Go | `cxlib.NewEventWriter(format)` returns a writer; `defer w.Close()` releases |
| Rust | `cxlib::EventWriter::new(format)?`; RAII; `Drop` impl calls close; methods take owned strings or `&str` |
| TypeScript | `new EventWriter(format)` with async methods for the fd-write variant; sync for in-memory |
| Java | `EventWriter` implementing `AutoCloseable`; try-with-resources idiom |
| Kotlin | `EventWriter` with `use { … }` block |
| C# | `EventWriter : IDisposable` with `using` block |
| Swift | `EventWriter` with `defer w.close()` |
| Ruby | `EventWriter.new(format) { |w| … }` block form auto-closes |

Each binding's tests cover the round-trip case: read events from a
known input → forward to writer with the same output format →
produce byte-equivalent output.

### 6.10 — Diagnostic wire format

W-code diagnostics share the framed payload shape defined in
[`spec/abi.md §2.13`](abi.md) (the schema-validator wire format with
the prefix-marker byte added Phase 7.74f / commit `5531666`). The
prefix byte for streaming-write diagnostics is `'W'` (0x57). When
an emit call returns a non-NULL diagnostic string in its return
value, that string carries the human-readable form
(`"W005: EndElement 'span' does not match open 'div'"`); the framed
payload is reachable via `cx_events_writer_last_report` (TBD if
needed; v0.6.0 emit-time errors are typically single-diagnostic and
the inline string is sufficient).

### 6.11 — Error semantics summary

- **Validation errors** (W001–W008, W010, W012, W013) — adopter bug;
 recoverable by closing the writer and constructing a new one.
- **Format-coverage errors** (W009) — adopter is targeting a format
 that can't represent the event; either filter the event stream
 upstream or pick a different output format.
- **Shape-engine errors** (W011) — pre-v0.6.0 timing; adopter passed
 a non-NULL shape and the engine isn't built yet.
- **OS-level fd errors** — surfaced as `W009` with `errno`-derived
 detail in `err_out`. Rare; typically only encountered with closed
 fds, full filesystems, or aborted network sockets.

The writer's "fail closed" rule means a single error puts the writer
in a permanent error state. There is no recovery API in v0.6.0;
adopters discard the writer and start fresh on error.

### 6.12 — Capability bit

[`spec/abi.md §3`](abi.md) bit 27 (`0x8000000`) signals streaming-
write API availability. Bindings probe before exercising the
surface; libcx versions before v0.6.0 do not advertise this bit
and do not export the symbols.
