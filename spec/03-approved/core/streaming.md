# CX Streaming API Specification

**Status:** Current for v0.8.0

The CX Streaming API provides a SAX/StAX-style event sequence for processing CX
documents without building a full in-memory tree. It is suited for large documents,
pipelines, and transformations that need only a forward pass.

---

## 1 — Event Types

The CX Streaming API operates in **lossless mode** on the read side:
every parsed AST node produces one or more events; no node kind is
filtered. This matches CX's "AST is the source of truth" architecture
and enables byte-identical round-trip of source documents through the
event stream.

There are **32 `StreamEvent` types** organised into six groups:

- **Lifecycle (2):** StartDoc, EndDoc
- **Prolog & markup (5):** XMLDecl, CXDirective, DoctypeDecl, ElementDecl, AttlistDecl
- **Element + body (12):** StartElement, EndElement, Text, Scalar, Comment,
  LineComment, PI, EntityRef, RawText, Alias, StartBlock, EndBlock
- **Collection literals + first-class kinds (8):** StartArray, EndArray,
  StartMap, EndMap, StartSequenceAsItem, EndSequenceAsItem, Path, Iterator
- **Programmable surface (2):** Interpolation, EvalDirective
- **Chunked-table triplet (3):** StartTable, RowGroup, EndTable

(Totals: 2 + 5 + 12 + 8 + 2 + 3 = 32. The full set is the read-side
vocabulary; the write-side surface in §6 covers a 14-event subset at
v0.8.0 — see §6.3 and §6.6 for the subset and the `W009` rejection
applied to the other 18 at emit time.)

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
| `anchor` | string or none | no | AnchorDef (`&name` per grammar [60]), absent when not present |
| `data_type` | string or none | no | Explicit type annotation (`::T`), absent when not present |
| `merge` | string or none | no | MergeRef (`*name` per grammar [61]), absent when not present |
| `attrs` | Attr[] | yes | Zero or more key-value attributes; empty list when none |

An `Attr` has:

| Field | Type | Required | Value |
|-------------|-----------------|----------|-------|
| `name` | string | yes | Attribute key |
| `value` | typed scalar | yes | Native-typed value: int, float, bool, null, or string |
| `data_type` | string or none | no | Explicit type annotation on the attribute (`name::T` per grammar [26]), absent when inferred |

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
| `data_type` | string or none | no | One of the 23 TypeNames defined in `grammar.ebnf [26a]`: the 9 semantic kinds (`int`, `float`, `bool`, `null`, `string`, `date`, `datetime`, `bytes`, `atom`) plus 14 storage-precision refinements (`decimal`, `bigint`, `i8`..`i64`, `u8`..`u64`, `f16`/`f32`/`f64`, `duration`, `instant`). Absent only when type is inferred as string and no explicit annotation is present. |
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
| `name` | string | yes | Entity name without `&` and `;` (e.g. `amp`, `lt`, `nbsp`). Matches the AST shape (`ast.md` EntityRef.`name`) and the wire shape (`ast-bin.md §4.1` tag `0x06`). |

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
| `name` | string | yes | Anchor name being referenced (without `*` prefix). Matches the AST shape (`ast.md` Alias.`name`) and the wire shape (`ast-bin.md §4.1` tag `0x07`). |

---

#### XMLDecl
An XML declaration directive (`[?xml version=1.0 ...]`).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `version` | string | yes | The XML version (typically `"1.0"`) |
| `encoding` | string or none | no | Document encoding |
| `standalone` | string or none | no | The standalone declaration (`"yes"` or `"no"`, per XML 1.0 grammar) |

Ordering: when present, MUST be the first event after StartDoc.

---

#### CXDirective
A CX directive (`[?cx include=foo.cx]`, `[?cx schema=...]`,
`[?cx allow-eval=true]`, etc.).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `attrs` | Attr[] | yes | Directive attributes; same Attr shape as StartElement |

Ordering: prolog CXDirective events appear after StartDoc/XMLDecl and
before the first StartElement at the top level. CXDirective events
embedded in body positions appear at their source-order location.

---

#### DoctypeDecl
A DOCTYPE declaration (`[!DOCTYPE name PUBLIC|SYSTEM ...]`).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `name` | string | yes | The root element name being typed |
| `external_id` | string or none | no | The external-ID portion (PUBLIC/SYSTEM) |
| `int_subset` | string or none | no | The internal subset, if present |

Ordering: when present, appears in document prolog between any
CXDirective events and the first StartElement.

---

#### ElementDecl / AttlistDecl
DTD element/attribute declarations (`[!ELEMENT ...]`, `[!ATTLIST ...]`).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | The raw declaration body (verbatim source text) |

Both events appear inside the DOCTYPE internal subset and round-trip
verbatim. Consumers that don't care about DTD content MAY skip them.

**Event-layer shape is verbatim-only.** The streaming event carries
the verbatim source-text only — the structured `contentspec` field
(ElementDecl) and `defs[]` list (AttlistDecl) defined on the AST
shape (`ast.md` §ElementDecl / §AttlistDecl) are intentionally NOT
decomposed at the event layer. Consumers needing structured access
re-parse the DOCTYPE internal subset themselves. This matches the
M5 asymmetry already documented in `ast-bin.md §4.1` tag `0x0B`: the
ast_bin wire form carries the internal subset as verbatim bytes
inside `DoctypeDecl.int_subset`, and the streaming-read API
fabricates ElementDecl / AttlistDecl events by re-parsing those bytes
into verbatim per-declaration strings — never into the structured
AST shape.

---

#### LineComment
A `# ...` line comment (CX Extended, grammar [30b]).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `value` | string | yes | Comment text without the leading `#` |

Distinct from Comment (`[- ... ]`) by source surface; both round-trip.

**Event-layer distinction only.** LineComment is an event-layer
distinction maintained for round-trip fidelity from the `# ...`
source form. There is no separate `LineComment` AST kind
(`ast.md` says LineComment parses to a `Comment` AST node — the AST
carries a single Comment kind) and no separate `LineComment`
ast_bin tag (`ast-bin.md §4.1` lists only `0x04 Comment`). The
streaming reader recovers the LineComment event from the Comment
node's source-text shape (presence of the leading `#` marker
preserved alongside the comment body); lossless emit re-renders the
event as the original `# ...` form. Strict-canonical consumers MAY
collapse LineComment to Comment.

---

#### StartBlock / EndBlock
BlockContent markers (`[| ... ]`, grammar [28]).

`StartBlock` carries no fields. `EndBlock` carries no fields. The body
between them is the literal-newline-preserved content emitted as
ordinary Text / Scalar / Element child events.

Ordering: balanced like StartElement/EndElement. Strict-canonical
consumers (per `canonical.md §2.10`) MAY filter out the markers,
inlining the contents.

---

#### Interpolation
A `[?=EXPR]` interpolation directive (grammar [58]).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `expr` | string | yes | The raw expression source text |

---

#### EvalDirective
A `[?Name args... [clause-child ...] ...]` eval directive (grammar [59]).
`Name` is one of the closed directive set per `code.md §4.1`.

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `name` | string | yes | The EvalName (e.g. `for`, `match`, `let`) |
| `args` | binary | yes | The directive's body items encoded per `ast-bin.md` (positional + clause-child entries, directly — no ArrayNode wrapper) |

Ordering: emitted at the directive's source-order position. Body of
the directive is not recursed into at the event level — consumers
that need to walk the directive's args parse the `args` payload.

---

#### StartArray / EndArray
CXDM Array Item container markers (`[a, b, c]`, grammar [56]).

Both events carry no fields. Between them, ordinary Scalar / Text /
Element / nested-container events emit per CXDM order.

Ordering: balanced like StartElement/EndElement. The empty Array
emits a `StartArray` immediately followed by `EndArray` with no
body events between them.

---

#### StartMap / EndMap
CXDM Map Item container markers (`{k: v, ...}`, grammar [56]).

`StartMap` and `EndMap` carry no fields. Each map entry between them
emits as a `key-tag value-events ...` pair: the key event carries the
key (a Scalar of one of the seven atomic kinds permitted by
`cxdm.md §2.6`), followed by the value event(s).

---

#### StartSequenceAsItem / EndSequenceAsItem
CXDM Sequence-as-Item container markers (`(a, b, c)` in body position
inside an Array or Map, grammar [56]).

Both events carry no fields. Distinct from StartArray/EndArray per
`cxdm.md §2.7`'s requirement to preserve the Sequence-as-Item vs Array
distinction across round-trip.

---

#### Path
A first-class CXPath value (per `cxdm.md §2.8`).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `payload` | binary | yes | PathNode wire payload per `ast-bin.md §4.4` |

Atomic event — Path is a leaf value, not a container.

---

#### Iterator
A first-class CXDM Iterator value (per `cxdm.md §2.9`).

| Field | Type | Required | Value |
|---------|--------|----------|-------|
| `payload` | binary | yes | IteratorNode wire payload per `ast-bin.md §4.1` tag `0x16` (`source_kind` + `single_use` + `source_args`; runtime-derived `memo`/`exhausted` NOT carried) |

Atomic event — Iterator is a leaf value, not a container. Consumers
that pull the iterator's elements drive evaluation themselves; the
event stream emits the Iterator value itself, not its materialized
elements.

---

#### StartTable
Signals the opening of a chunked table (CXCol tag `0x63`, see
[`core/data-bin.md §3.11`](data-bin.md)). Emitted in place of the
`StartElement` that would otherwise wrap a `[table …]` body when the
underlying wire form is chunked.

| Field | Type | Required | Value |
|------------|----------|----------|-------|
| `name` | string | yes | Element name (matches the enclosing `[name [table [cols]] rows]` per grammar [29]) |
| `col_spec` | binary | yes | The chunked-table col-spec as `uvarint(count) (string-tag name) (col-type-tag)*` per `data-bin.md §3.10.1` — column entries use uvarint count + tagged strings + scalar-type tag, NOT raw u32 LE |

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
 typ: EventType -- one of the 32 types (see §1.3)
 name: string -- StartElement / EndElement / StartTable / EndTable /
                       DoctypeDecl / EvalDirective / EntityRef / Alias
 anchor: ?string -- StartElement AnchorDef &name (absent if none)
 data_type: ?string -- StartElement glued ::T, or Scalar data type
 merge: ?string -- StartElement MergeRef *name (absent if none)
 attrs: Attr[] -- StartElement / CXDirective attributes (empty if none)
 value: string -- Text, Comment, LineComment, RawText, Scalar raw value,
                       ElementDecl / AttlistDecl verbatim source-text
 target: string -- PI target
 data: ?string -- PI data (absent if none)
 version: ?string -- XMLDecl version
 encoding: ?string -- XMLDecl encoding
 standalone: ?string -- XMLDecl standalone ("yes" / "no")
 external_id: ?string -- DoctypeDecl external-ID portion
 int_subset: ?string -- DoctypeDecl internal subset
 expr: ?string -- Interpolation raw expression
 col_spec: bytes -- StartTable column specification
 row_count: u32 -- RowGroup row count (0 for non-RowGroup events)
 payload: bytes -- RowGroup row-group bytes, EvalDirective args,
                       Path payload, or Iterator payload
}
```

The `name` slot carries the entity-name for EntityRef and the
anchor-name for Alias (matching the AST and wire field names per
`ast.md` and `ast-bin.md §4.1` tags `0x06` / `0x07`); the `value` slot
is unused for those two events. Per-event-type field mapping is the
binding contract — implementations populate exactly the slots their
event-type's field table (§1.1) lists, and leave all other slots at
their zero/absent value.

### 1.3 — Event type discriminator

The 32-entry closed event-type set:

| Group | Event types |
|---|---|
| Lifecycle | `StartDoc`, `EndDoc` |
| Prolog & markup | `XMLDecl`, `CXDirective`, `DoctypeDecl`, `ElementDecl`, `AttlistDecl` |
| Element & body | `StartElement`, `EndElement`, `Text`, `Scalar`, `Comment`, `LineComment`, `PI`, `EntityRef`, `RawText`, `Alias`, `StartBlock`, `EndBlock` |
| Collection literals & first-class kinds | `StartArray`, `EndArray`, `StartMap`, `EndMap`, `StartSequenceAsItem`, `EndSequenceAsItem`, `Path`, `Iterator` |
| Programmable surface | `Interpolation`, `EvalDirective` |
| Chunked table | `StartTable`, `RowGroup`, `EndTable` |

Implementations enumerate this set as a sealed enum / tagged union /
discriminated type per language idiom. Decoders that encounter an
unknown discriminator MUST raise `cx-err:W014 E_UNKNOWN_EVENT_TYPE`.

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
6. **BlockContent emits start/end markers.** A BlockContent node produces
 a `StartBlock` event followed by all child events in document order followed
 by a matching `EndBlock` event. Consumers that need strict-canonical
 semantics (which inlines BlockContent per `canonical.md §2.10`) MAY filter
 out StartBlock/EndBlock; lossless consumers preserve them.
7. **StartTable / RowGroup* / EndTable are balanced.** A chunked table emits
 exactly one StartTable, zero or more RowGroup events in source order, and
 exactly one matching EndTable. RowGroup events do not nest. No StartElement /
 EndElement events appear between StartTable and EndTable for the table itself;
 row-internal data lives in the RowGroup `payload` byte buffers and is decoded
 per [`core/data-bin.md §3.11.2`](data-bin.md) by consumers that need
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
 same error convention as the core C ABI (per `core/abi.md §1.3`). No partial
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

1. Call `cx_to_events_bin(cx_str, err_out)` for one-shot, or `cx_events_open*` +
 `cx_events_next` for pull-iteration (per `core/abi.md §2.8`).
2. If result is NULL with `*err_out` set, raise a parse error.
3. For the one-shot path: read `payload_size` (u32 LE), then `event_count`
 (u32 LE), then decode each event from the binary payload.
4. For the pull path: each `cx_events_next` call returns one framed event
 `[u32 LE: size][event payload]`; NULL with `*err_out == NULL` signals EOF.
5. Call `cx_free(buffer)` on each returned buffer.
6. Return the decoded event list (or iterator).

V does not use this path. V's `stream()` walks the parsed Document directly
without a binary protocol.

Streaming conformance is validated against the fixtures in `fixtures/stream/`.

---

## 5 — Scope

**In scope:**
- **Read side:** 32 event types per §1 (lossless — every parsed AST
 node produces one or more events)
- **Write side:** 14-event subset per §6.3 (StartDoc, EndDoc,
 StartElement, EndElement, Text, Scalar, Comment, PI, EntityRef,
 RawText, Alias, StartTable, RowGroup, EndTable). The other 18 event
 types reject with `W009` at emit time — see §6.3 and §6.6.
- Eager event list (full parse, then deliver all events) plus
 handle-based pull iteration per `core/abi.md §2.8`
- `stream(cx_str)` — CX source input only
- Binary wire protocol (`cx_to_events_bin` / `cx_events_next`) for
 all non-V bindings
- Per-language idiomatic sequence type
- **Streaming write API** — see §6 below — symmetric event-driven
 writer; output to in-memory buffer or fd; format-targeted across
 CX / XML / JSON / YAML / TOML; validation at emit time

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
output. The writer is handle-based, format-targeted, validation-at-
emit-time, and composes with chunked-table writing (per
`core/abi.md §2.10`).

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
 JSON, YAML, or TOML emission, selected at writer-open
 time.
5. **Per-binding-wrappable.** The C ABI surface admits idiomatic
 wrappers (Python context manager, Go `defer Close()`, Rust RAII,
 etc.) without a translation tax.

**Non-goals:**
- Random access within the output stream.
- Backpressure beyond the OS-level `write(2)` blocking on fd writers.
- Mid-stream cancellation beyond `cx_events_writer_close` releasing
 resources. No "abort and don't emit anything" mode.

### 6.2 — Lifecycle

A writer is opened, populated, and closed through a handle. Per
`core/abi.md §1.5.1` the handle is **thread-local** (H-class):
one writer = one thread.

```c
typedef struct cx_events_writer cx_events_writer;

/* In-memory writer — accumulates output in a buffer returned by
 * _close_get_bytes. Suitable when the output fits in memory. */
cx_events_writer* cx_events_writer_open(
 const char* output_format, /* "cx"/"xml"/"ast-json"/"ast-yaml"/"toml" */
 char** err_out);

/* fd-streaming writer — each emit call writes the event's bytes to
 * the fd; no accumulation. Suitable for unbounded outputs. */
cx_events_writer* cx_events_writer_open_fd(
 const char* output_format,
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

Total: **4 lifecycle symbols.**

### 6.3 — Event vocabulary

The writer accepts a **14-event subset** of the 32-event read-side
vocabulary defined in §1. At v0.8.0 the subset is:

- **Lifecycle:** StartDoc, EndDoc
- **Element + body:** StartElement, EndElement, Text, Scalar,
  Comment, PI, EntityRef, RawText, Alias
- **Chunked-table triplet:** StartTable, RowGroup, EndTable

The other 18 event types (XMLDecl, CXDirective, DoctypeDecl,
ElementDecl, AttlistDecl, LineComment, StartBlock, EndBlock,
Interpolation, EvalDirective, StartArray, EndArray, StartMap, EndMap,
StartSequenceAsItem, EndSequenceAsItem, Path, Iterator) have no
emit entry point at v0.8.0 and MUST reject with `W009` at emit time
(see §6.6). The read/write asymmetry is deliberate — see §6.6.1 / §6.6.2
for the structural-mismatch rationale on JSON/YAML/TOML formats and
the analogous reasoning that gates the other 18 events.

Adopters who need a faithful event-round-trip use the non-streaming
`cx_to_*` surfaces (which buffer the document by design) or extend
their write pipeline once an emit symbol lands in a future v0.8.x.

### 6.4 — Per-event emit functions

Each event type has a typed emit function. Functions return `NULL`
on success or a heap-allocated diagnostic string in the return
value plus a UTF-8 message in `err_out` on failure (matching the
existing C ABI convention per `core/abi.md §1.3`). The diagnostic
string carries the W-code and short message; the framed payload
(when more detail is needed) follows the format in `core/abi.md
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

/* Chunked-table events. Compose with cx_table_writer_*
 * — see §6.7. */
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

**Grand total surface:** 4 lifecycle + 17 emit = **21 C ABI symbols.**

The `attrs_payload` for `start_element` uses the same length-prefixed
binary attribute format the read side uses (§1.2). Bindings construct
this from their idiomatic attribute representation and call the
`_with_len` variant.

The `col_spec_payload` for `start_table` and the `row_group_payload`
for `row_group` use the wire shapes defined in
[`core/data-bin.md §3.11`](data-bin.md). Bindings construct these via
the same helpers used by `cx_table_writer_*` (per §6.7).

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
| RowGroup | matches an open StartTable (LIFO; tables don't nest) |
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
| `W010` | nested StartTable (tables don't nest) |
| `W012` | RowGroup without open StartTable |
| `W013` | EndTable name mismatch / no open StartTable |

(W011 is reserved — was previously allocated for the now-removed
`_shaped` open variants.)

The writer **fails closed.** An emit that produces a W-code leaves
the writer in an unrecoverable error state; subsequent emits return
the same code without effect. `_close_get_bytes` returns NULL with
the original error in `*err_out`.

### 6.6 — Format coverage

The same event stream can drive any of the five formats listed at
open time. Per-event support per format:

| Event | cx | xml | json (AST) | yaml (AST) | toml |
| --------------------------- | ------ | ----------- | ------------- | ------------ | ------------ |
| StartDoc / EndDoc | ✓ | ✓ | ✓ | ✓ | `W009` |
| StartElement / EndElement | ✓ | ✓ | ✓ | ✓ | `W009` |
| Text | ✓ | ✓ | ✓ AST Text | ✓ AST Text | `W009` |
| Scalar | ✓ | ✓ | ✓ AST Scalar (typed) | ✓ AST Scalar (typed) | `W009` |
| Comment | ✓ | ✓ | ✓ AST Comment | ✓ AST Comment| `W009` |
| PI | ✓ | ✓ | ✓ AST PI | ✓ AST PI | `W009` |
| EntityRef | ✓ | ✓ | ✓ AST EntityRef | ✓ AST EntityRef | `W009` |
| RawText | ✓ | as CDATA | ✓ AST RawText | ✓ AST RawText| `W009` |
| Alias | ✓ | `W009` | ✓ AST Alias | ✓ AST Alias | `W009` |
| StartTable / RowGroup / EndTable | ✓ | `W009` | `W009` | `W009` | `W009` |
| All other 18 event types (XMLDecl, CXDirective, DoctypeDecl, ElementDecl, AttlistDecl, LineComment, StartBlock, EndBlock, Interpolation, EvalDirective, StartArray, EndArray, StartMap, EndMap, StartSequenceAsItem, EndSequenceAsItem, Path, Iterator) | `W009` | `W009` | `W009` | `W009` | `W009` |

#### 6.6.1 — JSON / YAML output shape is the **AST shape**

The streaming-write API's JSON and YAML outputs encode the event
stream as the **AST representation** — the lossless one-event-per-AST-
node shape, not the data-oriented semantic shape produced by
`cx_to_json` / `cx_to_yaml`. This is deliberate and locked through 1.0:

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

Every Element emits:

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

#### 6.6.2 — TOML returns `W009` for the entire format

TOML streaming-write returns `W009` for every event including
StartDoc. The reason is **structural mismatch**: TOML's section-path
syntax does not admit a stream-local encoding that is both useful and
faithful. The option considered and rejected:

- TOML as AST array-of-tables (`[[elements.items.items.items]]`):
 technically stream-local and faithful, but produces TOML that no
 human would author, with deep path accumulation that defeats the
 format's design intent.

(Markdown is not a CX format at all — ruling D-B; there is no `md`
streaming-write target.)

Adopters who need TOML output use the non-streaming
`cx_to_toml` surface, which buffers the document and
produces idiomatic output. The streaming-write capability bit
(`0x8000000`, [`core/abi.md §3`](abi.md) bit 27) covers the
streaming-write API as a whole; bindings should not infer per-format
support from the bit. Per-format support is documented in this
section (§6.6).

The TOML `W009` message includes the explicit reason:
`"W009: <format> output not supported by streaming-write
(structural mismatch; use cx_to_<format> for this format)"`.

This decision is **monotonic** (same rule as the chunked-table
prohibition below): a future spec extension can lift the `W009`
rejection without breaking the ABI lock. The reverse would
not be possible.

**Chunked-table events on non-CX outputs.** The streaming writer
rejects StartTable / RowGroup / EndTable with `W009` on every output
format other than `cx`. CXCol is the canonical hashable origin for
tabular data; non-CX formats reach tabular data via the
analytics-bridge (Arrow C-Data interop per
[`core/abi.md §2.11`](abi.md), Parquet via the analytics bridge),
not through document-format projection. Adopters who
need streamed JSON / XML / etc. of tabular data either (a) convert
their event stream to per-row StartElement / EndElement before emit,
or (b) route through the analytics-bridge — `cx_to_arrow` /
`cx_table_writer_*` produce the canonical bytes; downstream tooling
projects to JSON / Parquet / etc.

This decision is **monotonic**: a future spec extension can lift the
`W009` rejection without breaking the ABI lock. The reverse
(supporting now, retracting later) would not be.

### 6.7 — Composition with chunked-table writer

[`core/abi.md §2.10`](abi.md) defines `cx_table_writer_*` — a
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
| "I have one table and want CXCol bytes / fd output" | `cx_table_writer_*` (§2.10) |
| "I have a document that contains tables" | `cx_events_writer_*` (§6, this section) |
| "I have multiple independent tables" | Either; streaming-write is more idiomatic if the tables share output framing |

Bytes produced by either surface are bit-equivalent for the same
input data and column spec. There is no canonicality difference.

### 6.8 — Per-binding wrapping idioms

The 21-symbol C ABI surface wraps thinly per binding:

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

### 6.9 — Diagnostic wire format

W-code diagnostics share the framed payload shape defined in
[`core/abi.md §2.13`](abi.md). The prefix byte for streaming-write
diagnostics is `'W'` (0x57). When an emit call returns a non-NULL
diagnostic string in its return value, that string carries the
human-readable form (`"W005: EndElement 'span' does not match open
'div'"`); emit-time errors are typically single-diagnostic and the
inline string is sufficient.

### 6.10 — Error semantics summary

- **Validation errors** (W001–W008, W010, W012, W013) — adopter bug;
 recoverable by closing the writer and constructing a new one.
- **Format-coverage errors** (W009) — adopter is targeting a format
 that can't represent the event; either filter the event stream
 upstream or pick a different output format.
- **OS-level fd errors** — surfaced as `W009` with `errno`-derived
 detail in `err_out`. Rare; typically only encountered with closed
 fds, full filesystems, or aborted network sockets.

The writer's "fail closed" rule means a single error puts the writer
in a permanent error state. There is no recovery API; adopters
discard the writer and start fresh on error.

### 6.11 — Capability bit

[`core/abi.md §3`](abi.md) bit 27 (`0x8000000`) signals streaming-
write API availability. Bindings probe before exercising the
surface; libcx builds that do not advertise this bit do not export
the symbols.
