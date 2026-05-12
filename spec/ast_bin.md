# CX AST Binary Wire Format (`ast_bin`)
# Version: 6
# Date: 2026-05-11

The **ast_bin** format is the wire-level binary serialization of a CX
parse AST. It is produced by `cx_to_ast_bin` and the per-format
`cx_*_to_ast_bin` ABI symbols (see [`spec/abi.md §2.3`](abi.md)) and
consumed by `cx_ast_bin_to_*`. Every language binding uses ast_bin as
the marshalling format between the V core library and binding-native
AST representations.

This spec is **normative**. The byte-level layout is part of the
v0.6.0 format-stability lock
and the cap-bit-29 commitment in [`spec/abi.md`](abi.md).

---

## 1 — Buffer envelope

```
[u32 LE: payload_size]
[payload_size bytes: payload]
```

- `payload_size` is the byte length of the payload **excluding** the
 4-byte size header.
- The buffer is opaque binary data, not a null-terminated string.
- Bindings may pass the full size-prefixed buffer or strip the header
 before passing to native code; the size header is recommended for
 C-ABI round-trip.

---

## 2 — Payload structure

```
[u8: version]
[u16 LE: prolog_count]
[prolog_count nodes]
[u16 LE: element_count]
[element_count nodes]
```

The version byte is checked first. Decoders MUST reject buffers whose
version byte is higher than the highest version they support.
Lower-versioned buffers are decodable in forward-compatible mode (the
decoder treats absent v(N) extensions as their default-zero values).

### 2.1 Version history

| Version | Date | Changes |
|---|---|---|
| 1 | pre-2026-05 | Original layout. |
| 2 | 2026-05-08 | : Element gains `optstr:id` after `merge`; Attribute gains `u8:is_ref` after `inferred_type`. |
| 3 | 2026-05-08 |: Element gains `optstr:body_ref` after `id` (carries `[ref @<name>]`). |
| 4 | 2026-05-09 | v0.6.0 schema fragments (`spec/schema.md §8`): CXDirective gains `optstr:anchor` + `u16:item_count` + `items[]` after `attrs[]`. |
| 5 | 2026-05-10 | / grammar v3.5: new tags `0x0D` (Interpolation), `0x0E` (EvalDirective); Attribute encoding gains body tail (`u8:body_flag` + optional `u16:body_count` + `nodes[]`). |
| **6** | **2026-05-11** | **** / grammar v3.6: new tags `0x0F` (SequenceNode), `0x10` (ArrayNode), `0x11` (MapNode). Three new container-Item node kinds per [`spec/cxdm.md §2.4–§2.6`](cxdm.md). Signaled by capability bit 29. EvalDirective (`0x0E`) payload reinterpreted under §D7 — `attrs[]` becomes empty (no more `:then=` / `:else=` attribute slots), `items[]` carries the positional argument array. Labeled form ( §D23) desugars at parse time to the same `items[]` layout; binary form is unchanged. **`?def` becomes 3-slot `[name, params, body]`** §D7 amendment 2026-05-12 + §D4 — params is an Array in slot 1 of the EvalDirective's ArgArray. Backward-compat: legacy 2-slot `[?def [name, body]]` auto-expands to 3-slot at parse with empty params. Wire format unchanged from v6.0 — params is just another ArrayNode item. |

---

## 3 — Primitive encodings

### String

```
String: [u32 LE: byte_len] [byte_len bytes: UTF-8] (no null terminator)
OptString: [u8: present (0 = absent, 1 = present)] [String if present]
```

### Bytes

```
Bytes: [u32 LE: byte_len] [byte_len bytes: raw binary]
```

---

## 4 — Node encoding

Each node is recursively encoded as:

```
[u8: node_type_id]
[payload per type]
```

### 4.1 Node type IDs

| ID | Node type | Payload |
|---|---|---|
| `0x01` | Element | `String:name OptString:anchor OptString:data_type OptString:merge OptString:id (v2+) OptString:body_ref (v3+) u16:attr_count attrs[] u16:child_count nodes[]` |
| `0x02` | Text | `String:value` |
| `0x03` | Scalar | `String:data_type String:value` |
| `0x04` | Comment | `String:value` |
| `0x05` | RawText | `String:value` |
| `0x06` | EntityRef | `String:name` |
| `0x07` | Alias | `String:name` |
| `0x08` | PI | `String:target OptString:data` |
| `0x09` | XMLDecl | `String:version OptString:encoding OptString:standalone` |
| `0x0A` | CXDirective | `u16:attr_count attrs[] OptString:anchor (v4+) u16:item_count (v4+) nodes[] (v4+)` |
| `0x0B` | DoctypeDecl | `String:content` |
| `0x0C` | BlockContent | `u16:child_count nodes[]` |
| `0x0D` | Interpolation (v5+) | `String:expr` |
| `0x0E` | EvalDirective (v5+) | `String:name u16:attr_count attrs[] u16:item_count nodes[]` (v6+: `?def` `items[0]` is a 3-slot ArrayNode `[name, params, body]` where params is itself an ArrayNode of bare identifiers — no wire-format change from v6.0 since params is a regular ArrayNode item) |
| **`0x0F`** | **SequenceNode (v6+)** | `u16:item_count nodes[]` |
| **`0x10`** | **ArrayNode (v6+)** | `u16:item_count nodes[]` |
| **`0x11`** | **MapNode (v6+)** | `u16:entry_count entries[]` |
| `0xFF` | Skip / unknown | (no payload; decoder skips the node) |

Unrecognized node-type IDs in the range `[0x12 .. 0xFE]` are
reserved; v6 decoders MUST reject buffers containing reserved IDs.
The `0xFF` skip tag is the migration path for cross-version
forward compatibility — v(N) producers emit `0xFF` for nodes they
chose not to encode.

### 4.2 Attribute encoding

Each `Attr` inside any node that holds `attrs[]`:

```
Attr:
 String:name
 String:value
 String:inferred_type
 u8:is_ref (v2+)
 u8:body_flag (v5+) — 0 = absent (no further bytes)
 1 = present, followed by:
 u16:body_count
 nodes[body_count]
```

`inferred_type` is the explicit type annotation, if present. When
absent (empty string), decoders infer the type from the value
string using CX auto-typing rules (see [`spec/ast.md §Auto-typing`](ast.md)).

The body tail carries grammar [55c] BracketBody attribute values
(per / v5). v1–v4 decoders never see the tail because
v1–v4 producers never emit it.

### 4.3 MapNode entry encoding *(v6+)*

Each `MapEntry` inside a MapNode's `entries[]`:

```
MapEntry:
 String:key_data_type — "string", "int", "float", "bool",
 "date", "datetime", "bytes" (no "null"

 String:key_value — canonical-string form of the key
 (per spec/canonical.md §scalar
 formatting)
 Node:value — recursive node encoding (one Node)
```

The key is encoded as a flattened scalar (type-tag + value-string)
rather than as a full `0x03 Scalar` node, to keep the entry compact.
Decoders reconstruct a Scalar AST node from `key_data_type` +
`key_value` when materializing the MapNode in their language
binding.

Bare-name keys in source (`{name: 'a'}`) encode with
`key_data_type = "string"` — the parser has normalized them to
strings by the time ast_bin is emitted.

---

## 5 — Example: empty document

**Input:** `[hello world]`

**Parsed:** `Document { elements: [ Element { name: "hello", items: [ Text { "world" } ] } ] }`

```
Offset Hex bytes Annotation
00 20 00 00 00 payload_size = 32 (u32 LE)
04 06 version = 6
05 00 00 prolog_count = 0 (u16 LE)
07 01 00 element_count = 1 (u16 LE)
09 01 node_type = 0x01 (Element)
0A 05 00 00 00 68 65 6C 6C 6F String "hello" (len=5)
13 00 anchor = absent
14 00 data_type = absent
15 00 merge = absent
16 00 id = absent (v2+)
17 00 body_ref = absent (v3+)
18 00 00 attr_count = 0 (u16 LE)
1A 01 00 child_count = 1 (u16 LE)
1C 02 node_type = 0x02 (Text)
1D 05 00 00 00 77 6F 72 6C 64 String "world" (len=5)
```

---

## 6 — Example: collection literals *(v6+)*

**Input:** `[tags [web, api]]`

**Parsed:** `Element { name: "tags", items: [ ArrayNode { items: [ Text{"web"}, Text{"api"} ] } ] }`

The ArrayNode emits:

```
10 node_type = 0x10 (ArrayNode)
02 00 item_count = 2
02 node_type = 0x02 (Text)
03 00 00 00 77 65 62 String "web" (len=3)
02 node_type = 0x02 (Text)
03 00 00 00 61 70 69 String "api" (len=3)
```

**Input:** `[stats {region: 'us-west', servers: 12}]`

**Parsed:** `Element { name: "stats", items: [ MapNode { entries: [(region, "us-west"), (servers, 12)] } ] }`

The MapNode emits (canonical order: `region` before `servers`
lexicographically; both keys are strings, values typed per entry):

```
11 node_type = 0x11 (MapNode)
02 00 entry_count = 2

06 00 00 00 73 74 72 69 6E 67 entry[0].key_data_type = "string"
06 00 00 00 72 65 67 69 6F 6E entry[0].key_value = "region"
02 entry[0].value: node_type = 0x02 (Text)
07 00 00 00 75 73 2D 77 65 73 74 String "us-west"

06 00 00 00 73 74 72 69 6E 67 entry[1].key_data_type = "string"
07 00 00 00 73 65 72 76 65 72 73 entry[1].key_value = "servers"
03 entry[1].value: node_type = 0x03 (Scalar)
03 00 00 00 69 6E 74 Scalar data_type = "int"
02 00 00 00 31 32 Scalar value = "12"
```

**Map-entry ordering on the wire.** Canonical-form emit sorts map
keys lexicographically by canonical-string form per
[`spec/canonical.md`](canonical.md) §D14. Producers SHOULD emit
entries in canonical order when targeting hash-stable output;
producers emitting in insertion order produce wire bytes that
round-trip semantically equal but byte-different (and therefore
hash-different).

---

## 7 — Version compatibility

### 7.1 Forward compatibility

A v(N) decoder reading a v(M < N) buffer **MUST** decode
successfully. v(N) extensions to existing node types (Element's
new optional fields, Attribute's body tail) are gated on the
version byte read at the start of the payload, and absent
fields default to their zero values (empty string, false, empty
list).

### 7.2 Backward incompatibility

A v(N) decoder reading a v(M > N) buffer **MUST reject** with an
error. The version byte is checked first; if it exceeds the
decoder's max-supported version, decode aborts. Bindings surface
this via their error mechanism.

### 7.3 Cap-bit-29 (v6 collection-literal support)

Capability bit **29** (`0x20000000` per [`spec/abi.md §1.5`](abi.md))
signals that the binding's ast_bin codec supports v6 — i.e., the
three new container Item kinds (SequenceNode, ArrayNode, MapNode)
and the wire-format encoding above. Bindings without cap-bit-29
clear are v5-or-earlier and **MUST reject** any ast_bin buffer
whose payload version byte is ≥ 6.

A v5 producer emitting a CX document that contains a collection-
literal Item type is an internal error: the producer MUST either
upgrade to v6 or refuse to encode the document. There is no
silent-loss path.

---

## 8 — Migration plan

Per:

- Phase 0 — V core ast_bin codec updates to v6 (lexer + parser +
 ast.md + ast_bin.md amendments land; tag-byte branches added to
 V's `binary.v` encoder/decoder).
- Phase 1 — Cap-bit-29 reserved in `spec/abi.md`; producers gate
 emission on bit-set; consumers gate decoding on bit-set.
- Phase 2–4 — 10-binding fan-out: per-binding ast_bin v6
 decoder + encoder. Estimated ~0.5 day per binding (mechanical:
 add three tag-byte branches to decode + three serialization arms
 to encode; one entry-loop for MapNode keys).

The version-byte gate is the single safe-decode invariant; bindings
that don't yet ship v6 simply leave cap-bit-29 clear and reject any
v6 payload. The format-stability lock applies to v6 once the
phase 4 rollout completes.

---

## 9 — References

- [`spec/ast.md`](ast.md) — parse AST description; ast_bin encodes
 this exact structure.
- [`spec/abi.md §2.3`](abi.md) — C ABI symbols that produce/consume
 ast_bin.
- [`spec/abi.md §1.5`](abi.md) — capability bit table (bit 29).
- [`spec/cxdm.md §2.4–§2.6`](cxdm.md) — runtime data model for the
 new container Item kinds.
- [`spec/grammar.ebnf`](grammar.ebnf) — source-text grammar for
 collection literals (v3.6 productions [56]).
- [`spec/canonical.md`](canonical.md) — canonical-form rules used
 for MapNode key ordering.

 — v5 / grammar v3.5 driver.

 — v6 / grammar v3.6 driver.
