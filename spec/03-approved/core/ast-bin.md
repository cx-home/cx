# CX AST Binary Wire Format (`ast_bin`)

**Status:** Current

The **ast_bin** format is the wire-level binary serialization of a CX
parse AST. It is produced by `cx_to_ast_bin` and the per-format
`cx_*_to_ast_bin` ABI symbols (see [`abi.md` §2.3](abi.md)) and
consumed by `cx_ast_bin_to_*`. Every language binding uses ast_bin as
the marshalling format between the V core library and binding-native
AST representations.

This spec is **normative**. The byte-level layout is part of the
format-stability lock and the cap-bit commitments in
[`abi.md` §3](abi.md).

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

The version byte is **10**. Decoders MUST reject buffers
whose version byte is higher than the highest version they support.
Lower-versioned buffers are decodable in forward-compatible mode (the
decoder treats absent v(N) extensions as their default-zero values).

Producers emit the LOWEST version byte that carries the document:
**6** for the common case, **8** when a PathNode / MatchNode /
ModifyNode is present, **9** when any Element carries a `[table[…]]`
payload (the §4.8 table record), **10** when any MapNode carries a
declaration-only entry (RULED: MSS-4, #917): a declared entry `{k: ::T}`
suffixes its `key_data_type` string with `+decl:<kind>`
(`string+decl:int`) and its value node is the inert null placeholder —
the entry's value is ABSENT, never null, and readers MUST NOT surface
the placeholder as the value. A document that needs no v8/v9/v10
feature therefore produces bytes identical to the earlier layout,
and every buffer an older reader could decode is unchanged.

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
| `0x01` | Element | `String:name OptString:anchor OptString:data_type OptString:merge OptString:id OptString:body_ref u16:attr_count attrs[] u16:child_count nodes[]` |
| `0x02` | Text | `String:value` |
| `0x03` | Scalar | `String:data_type String:value` |
| `0x04` | Comment | `String:value` |
| `0x05` | RawText | `String:value` |
| `0x06` | EntityRef | `String:name` |
| `0x07` | Alias | `String:name` |
| `0x08` | PI | `String:target OptString:data` |
| `0x09` | XMLDecl | `String:version OptString:encoding OptString:standalone` |
| `0x0A` | CXDirective | `u16:attr_count attrs[]` — matches `ast.md CXDirective` shape (`attrs` only). The `[?cx …]` surface admits no AnchorDef and no body items per grammar.ebnf. |
| `0x0B` | DoctypeDecl | `String:name OptString:external_id OptString:int_subset` — `external_id` encodes the PUBLIC/SYSTEM portion (verbatim source form); `int_subset` carries the internal subset bytes verbatim when present. The in-memory AST kinds `ElementDecl`, `AttlistDecl`, `NotationDecl`, `EntityDecl`, and `ConditionalSect` (per `ast.md`) live inside the internal subset and are **NOT** carried as structured wire nodes — they round-trip as bytes within `int_subset` and are recovered by re-parsing when an in-memory AST is needed. Streaming-API events for `ElementDecl` / `AttlistDecl` (per `streaming.md §1.1`) are fabricated by re-parsing `int_subset` on the read side; the write side rejects them with `W009`. Structured wire encoding for the five DTD kinds is a future extension and would land behind a new capability bit. |
| `0x0C` | BlockContent | `u16:child_count nodes[]` |
| `0x0D` | Interpolation | `String:expr` |
| `0x0E` | EvalDirective | `String:name u16:item_count nodes[]` — encodes the `items` field of `ast.md EvalDirective`. Per `ast.md`, `items` is the directive's body items **directly** (no wrapping `ArrayNode`): `item_count` is the body-item count — `0` for an empty body (`[?Name]`), `N` otherwise — and `nodes[]` are the body items in source order. `EvalDirective` is structurally uniform with `StartElement`'s body (name + items), the reshape having retired the prior single-`ArrayNode` "ArgArray" wrapper. Attrs are NOT valid on EvalDirective (the vestigial runtime `attrs` field is always empty); wire carries no `attr_count`. Module-system directives (`?def`, `?lib`, `?const`) are carried under this tag — the structured `DefNode` / `LibNode` / `ConstNode` shapes documented in `ast.md` are recovered from `name` + the body items by the program AST layer; ast_bin has no separate tags for them. |
| `0x0F` | SequenceNode | `u16:item_count nodes[]` |
| `0x10` | ArrayNode | `u16:item_count nodes[]` |
| `0x11` | MapNode | `u16:entry_count entries[]` — see §4.3. |
| `0x12` | Atom (reserved) | Reserved for a future compact flattened atom encoding. Producers MUST NOT emit `0x12`; decoders MUST reject buffers containing `0x12`. Atoms are encoded under `0x03 Scalar` with `data_type = "atom"`. |
| `0x13` | PathNode | `u8:form OptString:binding u16:step_count steps[] u16:predicate_count nodes[]` — see §4.4. Advisory `source` / `loc` fields are NOT carried on the wire. |
| `0x14` | MatchNode | `u8:mode OptString:scrutinee u16:arm_count arms[]` — see §4.5. Advisory `source` / top-level `loc` and per-arm `arm.loc` are NOT carried on the wire. |
| `0x15` | ModifyNode | `OptString:doc OptString:focus u16:action_count actions[]` — see §4.6. Advisory `source` / top-level `loc` and per-action `action.loc` are NOT carried on the wire. |
| `0x16` | IteratorNode | `u8:source_kind u8:single_use u16:source_args_count nodes[]` — see §4.7 for the byte-ordinal table and per-source-kind argument shapes. The runtime-derived `memo` / `exhausted` fields are NOT carried on the wire; `single_use` IS. Gated by capability bit 37. |
| `0x17` | Table record | `u16:col_count cols[] u32:row_count rows[]` — see §4.8. NOT a standalone Node kind: it carries the pooled `Element.table` payload ([`ast.md` §Element "table"](ast.md)) and is valid ONLY as the **first** entry of an Element's `nodes[]` (counted in `child_count`). Format version 9; gated by capability bit 40. Decoders MUST reject `0x17` anywhere else, and in any buffer whose version byte is < 9. |
| `0x18` | HoleNode | `String:name` — the authorable VARIABLE HOLE `$name` (I1 row 9, E1 L78): a structural node kind (like AliasNode, never a scalar); canonical text spelling `$name`, XML projection `<cx:var name="…"/>`. Additive at I1. (Distinct tag SPACE from data-bin's scalar tags — data-bin `0x18` is bigint.) |
| `0xFF` | Skip / unknown | (no payload; decoder skips the node) |

**Atom encoding.** Atoms encode under the existing `0x03 Scalar` tag
with `data_type = "atom"` and `value` = the atom's UTF-8 name. Wire
byte `0x12` is reserved for a future tag-flattened compact form;
encoders MUST NOT emit `0x12`. Atom support is signaled by
capability bit 33 (`0x200000000` per [`abi.md` §3](abi.md)).

Unrecognized node-type IDs in the range `[0x18 .. 0xFE]` are
reserved; decoders MUST reject buffers containing reserved IDs.
Tag `0x16` (IteratorNode) is gated by capability bit 37
([`abi.md` §3](abi.md)); decoders without bit 37 MUST raise
`CXER0100` rather than silently degrading. The `0xFF` skip tag is
the forward-compatibility path — a producer emits `0xFF` for nodes
it chose not to encode.

### 4.2 Attribute encoding

Each `Attr` inside any node that holds `attrs[]`:

```
Attr:
 String:name
 String:value
 String:inferred_type
 u8:is_ref
 u8:node_flag    — RESERVED. MUST be 0 (attributes are scalar-only,
                   D2). The value is always carried in String:value.
```

`inferred_type` is the explicit type annotation, if present. When
absent (empty string), decoders infer the type from the value
string using CX auto-typing rules (see [`ast.md` §Scalar / Auto-typing
rule](ast.md)).

An attribute value is **always a single SCALAR** (D2; grammar [55a],
`ast.md` §Attribute, `lexicon.ebnf` §10), carried in `String:value`
with `node_flag = 0`. The forms are bare / quoted / triple-quoted, plus
`[# … #]` whose raw content is carried AS the string value
(`a=[# x,y #]` → `"x,y"`). The former node-valued encoding
(`node_flag = 1` followed by one node) is REMOVED; a decoder reading
`node_flag = 1` MUST raise `CXER0100`. Any other `[`/`{`/`(`-opened
attribute value is a parse error — there is no node-valued attribute
encoding.

### 4.3 MapNode entry encoding

Each `MapEntry` inside a MapNode's `entries[]`:

```
MapEntry:
 String:key_data_type  — one of "string", "int", "float", "bool",
                          "date", "datetime", "bytes"
                          (null is not a valid map key)
 String:key_value      — canonical-string form of the key
                          (per `canonical.md` §2.5 scalar formatting)
 Node:value            — recursive node encoding (one Node)
```

The key is encoded as a flattened scalar (type-tag + value-string)
rather than as a full `0x03 Scalar` node, to keep the entry compact.
Decoders reconstruct a Scalar AST node from `key_data_type` +
`key_value` when materializing the MapNode in their language
binding.

Bare-name keys in source (`{name: 'a'}`) encode with
`key_data_type = "string"` — the parser has normalized them to
strings by the time ast_bin is emitted.

### 4.4 PathNode encoding

PathNode (tag `0x13`) encodes the first-class Path value kind. The
payload matches the AST shape documented in [`ast.md` §PathNode](ast.md)
field-for-field, **excluding** the advisory `source` and `loc`
fields (identity-irrelevant; not carried on the canonical wire form).
Two PathNode values that compare equal under the [`ast.md` §PathNode
"Equality and hashing"](ast.md) rule MUST produce byte-identical
ast_bin payloads.

```
PathNode (tag 0x13):
  u8:form               — 0x00 descendant, 0x01 absolute,
                          0x02 relative, 0x03 binding
                          (values 0x04..0xFF reserved)
  OptString:binding     — bound identifier (without leading '$')
                          when form == 0x03; MUST be absent
                          (present=0) for form ∈ {0x00, 0x01, 0x02}
  u16 LE:step_count
  steps[step_count]     — see PathStep below
  u16 LE:predicate_count — trailing top-level predicates on the
                           whole path expression (rare; usually 0)
  nodes[predicate_count] — each entry is a recursively-encoded
                           ProgramExpr Node (§4 envelope)

PathStep:
  u8:axis               — 0x00..0x0B, see axis table below
                          (values 0x0C..0xFF reserved)
  u8:node_test_kind     — 0x00..0x07, see node-test table below
                          (values 0x08..0xFF reserved)
  String:node_test_name — when node_test_kind selects a Name /
                          PrefixedName / NamespaceWildcard / LocalWildcard
                          form (kinds 0x00, 0x02, 0x03); otherwise
                          MUST be the empty string ("" — length-0
                          UTF-8) for the four kind-test kinds
                          (0x01, 0x04, 0x05, 0x06, 0x07)
  OptString:binding     — `(bind $NCName)` peer-annotation
                          (grammar [160]). Present iff the step carries
                          a `(bind $name)` clause; stored without the
                          leading `$` sigil. The reserved `_` identifier
                          MUST NOT appear here (rejected at parse time
                          with `CXER0232`).
  u16 LE:step_pred_count
  nodes[step_pred_count] — each entry is a recursively-encoded
                           ProgramExpr Node (§4 envelope)
```

**Axis byte table** (grammar [131a], 12 XPath 3.1 axes):

| Value | Axis |
|---|---|
| `0x00` | `child` |
| `0x01` | `descendant` |
| `0x02` | `descendant-or-self` |
| `0x03` | `parent` |
| `0x04` | `ancestor` |
| `0x05` | `ancestor-or-self` |
| `0x06` | `following-sibling` |
| `0x07` | `preceding-sibling` |
| `0x08` | `following` |
| `0x09` | `preceding` |
| `0x0A` | `self` |
| `0x0B` | `attribute` |

**Node-test discriminator table** (grammar [131b]):

| Value | Node-test form | `node_test_name` payload |
|---|---|---|
| `0x00` | `Name` (plain NCName, e.g. `user`) | the NCName |
| `0x01` | `*` (universal wildcard) | `""` (empty) |
| `0x02` | `*:LocalName` (any-namespace + named local) | `LocalName` |
| `0x03` | `Prefix:*` (named namespace + any local) | `Prefix` |
| `0x04` | `node()` (any node) | `""` (empty) |
| `0x05` | `text()` (text nodes only) | `""` (empty) |
| `0x06` | `element()` (element nodes only) | `""` (empty) |
| `0x07` | `attribute()` (attribute nodes only) | `""` (empty) |

Step predicates carry the general `ProgramExpr` body per grammar
[159] (the closed `PredExpr` enumeration of the former [132a] is
RETIRED — its infix/paren surface no longer parses). The
canonical-form emit (and therefore the wire payload) materialises
every predicate as a `ProgramExpr` AST subtree, encoded under the
existing per-kind tags in §4.1; the operator-free notation atoms
(`[N]`, `[@name]`, `[@!name]`, `[name]`) keep their dedicated kinds.

**Form / binding consistency.** Producers MUST set `binding` present
iff `form == 0x03 (binding)`. Decoders MUST reject buffers where the
two disagree (binding present with non-binding form, OR binding
absent with form == 0x03). The empty-step path `$x` with no steps
remains a `ProgramBinding` (a different AST kind, encoded under its
own tag in the ProgramExpr family) — PathNode with `form=0x03`
always carries at least one step (see [`ast.md` §PathNode
"Fields"](ast.md)).

**Predicate ordering.** Top-level `predicates` is the trailing
list on the whole path expression (rare). Per-step `predicates`
attaches to each step in source order. Both lists preserve source
order on the wire — there is no canonical re-ordering (predicates
may be order-sensitive when they contain side-effect-free positional
filters like `[1]` vs `[= $_position $_last]`).

**Advisory fields elided.** The `source` snippet and `loc` `{line,
col}` fields documented on the AST shape are NOT carried on the
wire. PathNode round-trips lose source-text fidelity by design — the
canonical terse form is re-derivable from `form` + `steps`. Tooling
that needs source-locations MUST request them via the JSON projection
(`cx_to_json` with source-tracking enabled), not via ast_bin. This
matches the file-wide convention — no other node kind carries `loc`
on the wire either.

### 4.5 MatchNode encoding

MatchNode (tag `0x14`) encodes the first-class multi-arm `[?match]`
value kind (grammar [136] `MatchExpr`). The payload is defined
inline below; the advisory top-level `source` / `loc` fields and the
per-arm `arm.loc` field are excluded from the wire (identity-
irrelevant by symmetry with §4.4 PathNode). Two MatchNode values that
compare equal MUST produce byte-identical ast_bin payloads.

```
MatchNode (tag 0x14):
  u8:mode               — 0x00 scrutinee mode
                          0x01 predicate-only mode
                          (values 0x02..0xFF reserved)
  OptString:scrutinee   — verbatim source-text of the scrutinee
                          expression when mode == 0x00; MUST be
                          absent (present=0) when mode == 0x01
  u16 LE:arm_count
  arms[arm_count]       — see MatchArm below

MatchArm:
  u8:arm_kind           — 0x00 case_arm  (`[case ...]`)
                          0x01 when_arm  (`[when ...]`, SQL Searched-CASE)
                          0x02 else_arm  (`[else ...]` fallback; at most
                                          one and MUST be the last arm)
                          (values 0x03..0xFF reserved)
  OptString:pattern     — verbatim `[case ...]` pattern source-text;
                          MUST be present (present=1) when
                          arm_kind == 0x00; MUST be absent
                          (present=0) when arm_kind ∈ {0x01, 0x02}
  OptString:guard       — when arm_kind == 0x00 (case_arm): the
                          verbatim `[where ...]` guard body, OR absent
                          when the case arm has no guard;
                          when arm_kind == 0x01 (when_arm): the
                          verbatim `[when ...]` predicate body, always
                          present;
                          when arm_kind == 0x02 (else_arm): MUST
                          be absent (present=0)
  String:body           — u32 LE byte length + UTF-8 verbatim
                          source-text of the `[yield ...]` body
                          (always present for every arm kind)
```

**Arm-kind / pattern / guard consistency.** Producers MUST honour
the per-arm-kind validity rules above. Decoders MUST reject buffers
whose `arm_kind` byte is reserved (0x03..0xFF), or whose
`pattern` / `guard` presence flags disagree with the arm-kind
validity table.

**`[else ...]` ordering.** Decoders MUST reject buffers where an
`else_arm` (0x02) appears at any position other than the final arm
in the list. At most one `else_arm` is admitted per MatchNode.

**Mode / scrutinee consistency.** Producers MUST set `scrutinee`
present iff `mode == 0x00 (scrutinee)`. Decoders MUST reject buffers
where the two disagree (scrutinee present with mode `0x01`, OR
scrutinee absent with mode `0x00`). The predicate-only mode also
forbids `[case ...]` arms — decoders MUST reject buffers
where `mode == 0x01` and any `arm_kind == 0x00 (case_arm)` appears
in `arms[]`.

**Verbatim body slots.** The pattern / guard / body slots carry the
verbatim source-text snippet (mirroring the §4.4 PathNode predicate
convention). A future ProgramExpr-AST graft MAY replace these strings
with `encode_node`-dispatched node bytes; decoders MUST tolerate the
string-shape form on input.

**Advisory fields elided.** The top-level `source` / `loc` and the
per-arm `arm.loc` fields are NOT carried on the wire. The canonical
bracket-prefixed form (`[?match …]`) is re-derivable from `mode` +
`scrutinee` + `arms`. Tooling that needs source-locations MUST
request them via the JSON projection, not via ast_bin.

### 4.6 ModifyNode encoding

ModifyNode (tag `0x15`) encodes the first-class pure-functional
update value kind (grammar [141] `ModifyExpr`). The payload is
defined inline below; the advisory top-level `source` / `loc` fields
and the per-action `action.loc` field are excluded from the wire
(identity-irrelevant by symmetry with §4.4 PathNode). Two ModifyNode
values that compare equal MUST produce byte-identical ast_bin
payloads.

```
ModifyNode (tag 0x15):
  OptString:doc         — verbatim source-text of the document
                          expression (first head of [?modify DOC FOCUS
                          ACTION+]). Absent (present=0) on the
                          pipeline-implicit 1-head form
                          ([?modify FOCUS ACTION+] — pipeline LHS
                          supplies the document at eval time);
                          present (present=1) on the canonical
                          2-head form.
  OptString:focus       — verbatim source-text of the CXPath focus
                          expression (PathExpr in grammar [141]).
                          Always present on a well-formed ModifyNode;
                          absent only on partially-constructed nodes
                          rejected at parse time. The codec accepts
                          both presence values (the wire form mirrors
                          the in-memory string slot — empty focus
                          encodes as a present, length-0 OptString).
  u16 LE:action_count   — number of actions (grammar [141] mandates
                          ≥ 1, enforced at parse time; the codec
                          accepts 0 for forward-compat with
                          hand-rolled fixtures).
  actions[action_count] — see ModifyAction below

ModifyAction:
  u8:action_kind        — 0x00 set            (`[set EXPR]`)
                          0x01 delete         (`[delete]`)
                          0x02 using          (`[using EXPR]`)
                          0x03 rename         (`[rename NAME]`)
                          0x04 set-attr       (`[set-attr NAME EXPR]`)
                          0x05 delete-attr    (`[delete-attr NAME]`)
                          0x06 append         (`[append EXPR]`)
                          0x07 prepend        (`[prepend EXPR]`)
                          0x08 insert-before  (`[insert-before EXPR]`)
                          0x09 insert-after   (`[insert-after EXPR]`)
                          0x0A replace        (`[replace EXPR]`)
                          (values 0x0B..0xFF reserved)
  OptString:name        — Name token slot. Present (present=1) iff
                          action_kind ∈ {0x03 rename, 0x04 set-attr,
                          0x05 delete-attr}. MUST be absent
                          (present=0) for the other eight action
                          kinds.
  OptString:value       — ProgramExpr source-text slot. Present
                          (present=1) iff action_kind ∈ {0x00 set,
                          0x02 using, 0x04 set-attr, 0x06 append,
                          0x07 prepend, 0x08 insert-before, 0x09
                          insert-after, 0x0A replace}. MUST be absent
                          (present=0) for {0x01 delete, 0x03 rename,
                          0x05 delete-attr}.
```

**Action-kind / name / value validity matrix:**

| `action_kind` | Spelling | `name` | `value` |
|---|---|---|---|
| `0x00` | `[set EXPR]` | absent | **present** |
| `0x01` | `[delete]` | absent | absent |
| `0x02` | `[using EXPR]` | absent | **present** |
| `0x03` | `[rename NAME]` | **present** | absent |
| `0x04` | `[set-attr NAME EXPR]` | **present** | **present** |
| `0x05` | `[delete-attr NAME]` | **present** | absent |
| `0x06` | `[append EXPR]` | absent | **present** |
| `0x07` | `[prepend EXPR]` | absent | **present** |
| `0x08` | `[insert-before EXPR]` | absent | **present** |
| `0x09` | `[insert-after EXPR]` | absent | **present** |
| `0x0A` | `[replace EXPR]` | absent | **present** |

**Action-kind / name / value consistency.** Producers MUST honour
the per-action-kind validity rules above. Decoders MUST reject
buffers whose `action_kind` byte is reserved (`0x0B`..`0xFF`), or
whose `name` / `value` presence flags disagree with the
action-kind validity table.

**Verbatim slot bodies.** The `doc` / `focus` / `name` / `value`
slots carry the verbatim source-text snippet (mirroring the §4.4
PathNode and §4.5 MatchNode conventions). A future ProgramExpr-AST
graft MAY replace the `doc` / `value` strings with `encode_node`-
dispatched node bytes and the `focus` string with a nested PathNode
payload (tag `0x13` / §4.4); decoders MUST tolerate the string-shape
form on input.

**Advisory fields elided.** The top-level `source` / `loc` and the
per-action `action.loc` fields are NOT carried on the wire. The
canonical bracket-prefixed form (`[?modify …]`) is re-derivable
from `doc` + `focus` + `actions`. Tooling that needs source-
locations MUST request them via the JSON projection, not via
ast_bin.

### 4.7 IteratorNode encoding

IteratorNode (tag `0x16`) encodes the first-class CXDM Iterator value
kind (per [`cxdm.md §2.9`](cxdm.md), [`ast.md` §IteratorNode](ast.md)).
The payload mirrors the AST shape declaratively — only the source
program (kind + arguments) and the static `single_use` property are
carried. The runtime-derived `memo[]` and `exhausted` fields are NOT
carried on the wire; decoders restore a fresh iterator that
re-evaluates from source on first pull. Gated by capability bit 37
([`abi.md §3`](abi.md)).

```
IteratorNode (tag 0x16):
  u8:source_kind          — IteratorSourceKind ordinal (table below);
                            values 0x00..0x0D are defined; 0x0E..0xFF
                            reserved (decoders MUST reject)
  u8:single_use           — declarative source property:
                            0x00 = re-walkable (default)
                            0x01 = single-use (file/channel-backed
                                   source; cannot be re-walked)
                            (values 0x02..0xFF reserved)
  u16 LE:source_args_count
  nodes[source_args_count] — each entry is a recursively-encoded
                             Node per §4 envelope; per-source-kind
                             shape is fixed (table below)
```

**IteratorSourceKind byte table** (canonical 14-kind order per
[`abi.md §3`](abi.md) cap-bit-37 description):

| Value | Kind |
|---|---|
| `0x00` | `iter_range` |
| `0x01` | `iter_map` |
| `0x02` | `iter_filter` |
| `0x03` | `iter_take` |
| `0x04` | `iter_drop` |
| `0x05` | `iter_concat` |
| `0x06` | `iter_zip` |
| `0x07` | `iter_enumerate` |
| `0x08` | `iter_chunks` |
| `0x09` | `iter_cycle` |
| `0x0A` | `iter_scan` |
| `0x0B` | `iter_flatten` |
| `0x0C` | `iter_partition` |
| `0x0D` | `iter_group_by` |

Values `0x0E..0xFF` are reserved. Decoders MUST reject buffers whose
`source_kind` byte is reserved.

**Per-source-kind argument shape.** `source_args_count` and the
order/kind of entries in `nodes[]` are fixed per source kind:

| source_kind | source_args shape |
|---|---|
| `iter_range` (`0x00`) | `[start::int, stop::int, step::int]` |
| `iter_map` (`0x01`) | `[source_iter, lambda]` |
| `iter_filter` (`0x02`) | `[source_iter, predicate]` |
| `iter_take` (`0x03`) | `[source_iter, n::int]` |
| `iter_drop` (`0x04`) | `[source_iter, n::int]` |
| `iter_concat` (`0x05`) | `[source_iter1, source_iter2, ...]` (variable, ≥ 1) |
| `iter_zip` (`0x06`) | `[source_iter1, source_iter2, ...]` (variable, ≥ 1) |
| `iter_enumerate` (`0x07`) | `[source_iter]` |
| `iter_chunks` (`0x08`) | `[source_iter, chunk_size::int]` |
| `iter_cycle` (`0x09`) | `[source_iter]` |
| `iter_scan` (`0x0A`) | `[source_iter, accumulator, lambda]` |
| `iter_flatten` (`0x0B`) | `[source_iter_of_iters]` |
| `iter_partition` (`0x0C`) | `[source_iter, predicate]` |
| `iter_group_by` (`0x0D`) | `[source_iter, key_lambda]` |

`source_iter` entries are themselves IteratorNode encodings (tag
`0x16`) when the source is another iterator; they MAY be other
recursively-encoded Node kinds (e.g., an Element, an ArrayNode, a
ProgramCall yielding an iterator) when the source is a constructible
expression. Decoders MUST NOT impose a kind constraint beyond "valid
Node per §4."

**`single_use` semantics.** A declarative property of the source
program — set `0x01` for sources that cannot be re-walked
(file/channel-backed, mutable cursor, network stream). Set `0x00`
when the source is re-walkable (range, materialized collection,
in-memory array). On decode the value is restored verbatim; consumers
that re-walk a `single_use=true` iterator beyond its first
materialization MUST raise the appropriate runtime error per
[`ast.md` §IteratorNode](ast.md). The bit is NOT runtime-derived from
`memo`/`exhausted`; it travels with the program.

**Runtime fields elided.** The in-memory `memo[]` (memoisation buffer
populated on each pull) and `exhausted` (true once the source emits
no more items) fields documented on the AST shape are NOT carried on
the wire. On decode, fresh iterators are restored with `memo=[]` /
`exhausted=false` that re-evaluate from `source_kind` +
`source_args` on first pull. Round-trip preserves the iterator's
program, not its consumption state.

### 4.8 Table record encoding

The table record (tag `0x17`, format version 9) carries the pooled
`Element.table` payload — the parsed contents of a `[table[…]]` block
(grammar [29], [`ast.md` §Element "table"](ast.md)). It is **not** a
standalone Node kind: it appears ONLY as the **first** entry of a
table-bearing Element's `nodes[]` (counted in `child_count`), and the
decoder re-attaches it as the element's table payload, not as a body
item. At most one table record per Element.

The shape mirrors the AST-JSON `"table"` object introduced for the
same payload ([`ast.md` §Element "table"](ast.md), #443): declared
columns (name + canonical long type, absent = string-default) and
rows of cells, with collection cells riding the existing
collection-node encodings.

```
Table record (tag 0x17, v9+):
  u16 LE:col_count
  cols[col_count]:
    String:name          — column name
    String:type_name     — declared column type, canonical long form
                           ("int", not "i"); the EMPTY string ("") for
                           an undeclared (string-default) column,
                           mirroring the canonical CX header where an
                           untyped column is the bare name
  u32 LE:row_count       — u32, not u16: tables are the bulk-data
                           structure (cf. data-bin.md row payloads)
  rows[row_count]:
    u16 LE:cell_count    — MUST equal col_count; the decoder MUST
                           reject a mismatch (malformed-payload
                           tripwire for ragged or corrupted rows)
    cells[cell_count]    — one recursively-encoded node per cell,
                           in column order
```

**Cell encoding.** Each cell is one node per the §4 envelope,
restricted to the legal cell kinds:

- Scalar cells encode as `0x03 Scalar` with `data_type` ∈ `"int"`,
  `"float"`, `"bool"`, `"null"`, `"string"` — the cell's in-memory
  variant, NOT the declared column type. A cell in a `date`- or
  `decimal`-typed column carries its string payload as
  `Scalar{"string", …}`; the column header carries the type (exactly
  as in the AST-JSON lane, where scalar cells are JSON-native).
- Collection cells encode under the existing SequenceNode (`0x0F`) /
  ArrayNode (`0x10`) / MapNode (`0x11`) tags (§4.1/§4.3), unchanged.

Decoders MUST reject a cell whose node is any other kind (Text,
Element, Comment, …) or whose Scalar `data_type` is outside the five
base kinds — loudly, never by dropping the cell.

**Position and version rules.** Producers emit the table record only
inside a version-9 buffer, only in the first child slot of an
Element, at most once per Element. Decoders MUST reject `0x17`:

- in any buffer whose version byte is < 9 (no v1–v8 producer ever
  emitted the tag);
- anywhere other than the first entry of an Element's `nodes[]` —
  top level, prolog, a later child slot, inside a container node, or
  in cell position.

**Version discipline.** Version 9 is emitted only when a table
payload is actually present somewhere in the Document (same additive
rule as the v6 → v8 bump, §2): a table-free document keeps its
previous envelope and its exact previous bytes. In the unversioned
single-node frame (`emit_node_bin` / `node_from_bin`, used by the
cxstore content-addressed engine), the reader is primed at the
current max version; table-free subtree bytes are unchanged, and a
pre-v9 reader hitting a table record fails loud on the unknown tag
rather than misparsing.

**Runtime fields elided.** The in-memory `from_chunked` provenance
flag on TableData (set by the data_bin chunked reader,
[`streaming.md` §1.1](streaming.md)) is NOT carried on the wire;
decoded tables restore `from_chunked = false`. Round-trip preserves
the table's columns and rows, not its ingest provenance.

**Relationship to data_bin.** The DATA wire has its own table
encodings (`data-bin.md` tags `0x60` / `0x61` / `0x63`) whose cells
are self-describing DataVal records in data_bin's tag namespace. The
ast_bin table record deliberately does NOT reuse that record shape:
ast_bin cells reuse ast_bin's own node encodings, keeping each
format internally consistent (one tag namespace per format) — the
same reuse rule the AST-JSON lane follows.

---

## 5 — Example: empty document

**Input:** `[hello world]`

**Parsed:** `Document { elements: [ Element { name: "hello", items: [ Text { "world" } ] } ] }`

```
Offset Hex bytes Annotation
00 20 00 00 00 payload_size = 32 (u32 LE)
04 08 version = 8
05 00 00 prolog_count = 0 (u16 LE)
07 01 00 element_count = 1 (u16 LE)
09 01 node_type = 0x01 (Element)
0A 05 00 00 00 68 65 6C 6C 6F String "hello" (len=5)
13 00 anchor = absent
14 00 data_type = absent
15 00 merge = absent
16 00 id = absent
17 00 body_ref = absent
18 00 00 attr_count = 0 (u16 LE)
1A 01 00 child_count = 1 (u16 LE)
1C 02 node_type = 0x02 (Text)
1D 05 00 00 00 77 6F 72 6C 64 String "world" (len=5)
```

---

## 6 — Example: collection literals

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
[`canonical.md` §2.11.1](canonical.md). Producers SHOULD emit
entries in canonical order when targeting hash-stable output;
producers emitting in insertion order produce wire bytes that
round-trip semantically equal but byte-different (and therefore
hash-different).

---

## 6.5 — Example: PathNode

**Input:** `//user[= $_@active true]`

**Parsed:** `PathNode { form: "descendant", binding: null, steps: [ { axis: "child", node_test: "user", predicates: [ AttrTest{@active = true} ] } ], predicates: [] }`

The PathNode emits:

```
13                                            node_type = 0x13 (PathNode)
00                                            form = 0x00 (descendant)
00                                            binding = absent (present=0)
01 00                                         step_count = 1 (u16 LE)
00                                            step[0].axis = 0x00 (child)
00                                            step[0].node_test_kind = 0x00 (Name)
04 00 00 00 75 73 65 72                       step[0].node_test_name = "user"
00                                            step[0].binding = absent (present=0)
01 00                                         step[0].step_pred_count = 1 (u16 LE)
…                                             step[0].predicates[0]: ProgramExpr
                                              for `[= $_@active true]`, encoded
                                              under its own ProgramExpr tag
                                              (see §4.1)
00 00                                         predicate_count = 0 (top-level)
```

**Input:** `$u/email`

**Parsed:** `PathNode { form: "binding", binding: "u", steps: [ { axis: "child", node_test: "email", predicates: [] } ], predicates: [] }`

The PathNode emits:

```
13                                            node_type = 0x13 (PathNode)
03                                            form = 0x03 (binding)
01                                            binding = present (OptString)
01 00 00 00 75                                binding name "u" (len=1)
01 00                                         step_count = 1
00                                            step[0].axis = 0x00 (child)
00                                            step[0].node_test_kind = 0x00 (Name)
05 00 00 00 65 6D 61 69 6C                    step[0].node_test_name = "email"
00                                            step[0].binding = absent (present=0)
00 00                                         step[0].step_pred_count = 0
00 00                                         predicate_count = 0
```

Both shapes round-trip identity-equal under the PathNode equality
rule ([`ast.md` §PathNode "Equality and hashing"](ast.md)).
Whitespace variations in the source (`$u / email` vs `$u/email`)
collapse onto the same byte payload because the advisory `source`
field is excluded from the wire form.

---

## 6.6 — Example: MatchNode

**Input:**
```
[?match $status
  [case 200 [yield "OK"]]
  [when $status >= 400 [yield "ERR"]]
  [else [yield "UNKNOWN"]]]
```

**Parsed:** `MatchNode { scrutinee: "$status", arms: [ {kind:case, pattern:"200", body:"\"OK\""}, {kind:when, guard:"$status >= 400", body:"\"ERR\""}, {kind:else, body:"\"UNKNOWN\""} ] }`

The MatchNode emits:

```
14                                            node_type = 0x14 (MatchNode)
00                                            mode = 0x00 (scrutinee)
01                                            scrutinee = present (OptString)
07 00 00 00 24 73 74 61 74 75 73              scrutinee = "$status" (len=7)
03 00                                         arm_count = 3 (u16 LE)

00                                            arm[0].arm_kind = 0x00 (case_arm)
01                                            arm[0].pattern = present
03 00 00 00 32 30 30                          arm[0].pattern = "200" (len=3)
00                                            arm[0].guard = absent
04 00 00 00 22 4F 4B 22                       arm[0].body = "\"OK\"" (len=4)

01                                            arm[1].arm_kind = 0x01 (when_arm)
00                                            arm[1].pattern = absent
01                                            arm[1].guard = present
0E 00 00 00 24 73 74 61 74 75 73 20 3E 3D 20 34 30 30
                                              arm[1].guard = "$status >= 400" (len=14)
05 00 00 00 22 45 52 52 22                    arm[1].body = "\"ERR\"" (len=5)

02                                            arm[2].arm_kind = 0x02 (else_arm)
00                                            arm[2].pattern = absent
00                                            arm[2].guard = absent
09 00 00 00 22 55 4E 4B 4E 4F 57 4E 22        arm[2].body = "\"UNKNOWN\"" (len=9)
```

This payload exercises all three arm kinds (case + when + else) and
scrutinee mode. A predicate-only-mode example replaces the leading
`00 01 07 00 00 00 24 73 74 61 74 75 73` (mode=0x00 + scrutinee
present + "$status") with the single byte `01 00` (mode=0x01 +
scrutinee absent), and the encoded arms[] would omit any `case_arm`
entries (predicate-only mode forbids `[case ...]`).

Whitespace variations in the source form collapse onto the same
byte payload because the advisory `source` / `loc` / per-arm
`arm.loc` fields are excluded from the wire (matches the §4.4
PathNode advisory-elision convention).

---

## 6.7 — Example: ModifyNode

**Input:**
```
[?modify $doc //user[= $_@id 1]/@name [set "Alice"] [set-attr status "active"] [delete-attr stale]]
```

**Parsed:** `ModifyNode { doc: "$doc", focus: "//user[= $_@id 1]/@name", actions: [ {kind:set, value:"\"Alice\""}, {kind:set-attr, name:"status", value:"\"active\""}, {kind:delete-attr, name:"stale"} ] }`

The ModifyNode emits (canonical 2-head shape with three actions
covering an expression-only action, a Name+Expr action, and a Name-only
action — exercises all three slot-presence patterns):

```
15                                            node_type = 0x15 (ModifyNode)
01                                            doc = present (OptString)
04 00 00 00 24 64 6F 63                       doc = "$doc" (len=4)
01                                            focus = present (OptString)
17 00 00 00 2F 2F 75 73 65 72 5B 3D 20 24 5F 40 69 64 20 31 5D 2F 40 6E 61 6D 65
                                              focus = "//user[= $_@id 1]/@name" (len=23)
03 00                                         action_count = 3 (u16 LE)

00                                            action[0].action_kind = 0x00 (set)
00                                            action[0].name = absent (set has no Name slot)
01                                            action[0].value = present
07 00 00 00 22 41 6C 69 63 65 22              action[0].value = "\"Alice\"" (len=7)

04                                            action[1].action_kind = 0x04 (set-attr)
01                                            action[1].name = present
06 00 00 00 73 74 61 74 75 73                 action[1].name = "status" (len=6)
01                                            action[1].value = present
08 00 00 00 22 61 63 74 69 76 65 22           action[1].value = "\"active\"" (len=8)

05                                            action[2].action_kind = 0x05 (delete-attr)
01                                            action[2].name = present
05 00 00 00 73 74 61 6C 65                    action[2].name = "stale" (len=5)
00                                            action[2].value = absent (delete-attr has no Expr)
```

This payload exercises three of the eleven action kinds across all
three slot-presence patterns (Expr-only, Name+Expr, Name-only). A
pipeline-implicit 1-head form (`[?modify FOCUS ACTION+]`) replaces
the leading `01 04 00 00 00 24 64 6F 63` (doc present + "$doc") with
the single byte `00` (doc absent) at offset 1 — the rest of the
payload is unchanged.

Whitespace variations in the source form collapse onto the same byte
payload because the advisory `source` / `loc` / per-action
`action.loc` fields are excluded from the wire (matches the §4.4
PathNode and §4.5 MatchNode advisory-elision convention).

---

## 6.8 — Example: IteratorNode

**Input:** `iter_range(0, 10, 1)`

**Parsed:** `IteratorNode { source_kind: iter_range, single_use: false, source_args: [ Scalar{int,0}, Scalar{int,10}, Scalar{int,1} ] }`

The IteratorNode emits:

```
16                                            node_type = 0x16 (IteratorNode)
00                                            source_kind = 0x00 (iter_range)
00                                            single_use  = 0x00 (re-walkable)
03 00                                         source_args_count = 3 (u16 LE)

03                                            source_args[0]: node_type = 0x03 (Scalar)
03 00 00 00 69 6E 74                          data_type = "int" (len=3)
01 00 00 00 30                                value = "0" (len=1)

03                                            source_args[1]: node_type = 0x03 (Scalar)
03 00 00 00 69 6E 74                          data_type = "int" (len=3)
02 00 00 00 31 30                             value = "10" (len=2)

03                                            source_args[2]: node_type = 0x03 (Scalar)
03 00 00 00 69 6E 74                          data_type = "int" (len=3)
01 00 00 00 31                                value = "1" (len=1)
```

A single-use file-backed source replaces the second byte (`00`) with
`01` (`single_use = true`); the rest of the payload structure is
unchanged. Combinator sources nest IteratorNode payloads inside
`source_args[]` — e.g., `iter_map(iter_range(0,10,1), $double)`
emits `source_kind = 0x01 (iter_map)`, `source_args_count = 2`,
`source_args[0]` is a complete IteratorNode (tag `0x16`) carrying the
inner `iter_range`, and `source_args[1]` is the lambda Node.

Runtime state (`memo[]`, `exhausted`) is NOT carried on the wire —
two IteratorNode values produced from the same source program emit
byte-identical payloads regardless of how many items have been
pulled.

---

## 6.9 — Example: table record

**Input:**
```
[t [table[a b::int]]
  x 1
]
```

**Parsed:** `Element { name: "t", dataType: "table", table: TableData { cols: [{a}, {b, int}], rows: [["x", 1]] } }`

The full framed buffer (the table record starts at the element's
first child slot):

```
58 00 00 00                     payload_size = 88 (u32 LE)
09                              version = 9 (table record present)
00 00                           prolog_count = 0 (u16 LE)
01 00                           element_count = 1 (u16 LE)
01                              node_type = 0x01 (Element)
01 00 00 00 74                  name = "t" (len=1)
00                              anchor = absent
01 05 00 00 00 74 61 62 6C 65   data_type = present, "table" (len=5)
00                              merge = absent
00                              id = absent
00                              body_ref = absent
00 00                           attr_count = 0 (u16 LE)
01 00                           child_count = 1 (the table record)

17                              table record tag (0x17)
02 00                           col_count = 2 (u16 LE)
01 00 00 00 61                  col[0].name = "a" (len=1)
00 00 00 00                     col[0].type_name = "" (string-default)
01 00 00 00 62                  col[1].name = "b" (len=1)
03 00 00 00 69 6E 74            col[1].type_name = "int" (len=3)
01 00 00 00                     row_count = 1 (u32 LE)
02 00                           row[0].cell_count = 2 (MUST == col_count)
03                              cell[0]: node_type = 0x03 (Scalar)
06 00 00 00 73 74 72 69 6E 67   data_type = "string" (len=6)
01 00 00 00 78                  value = "x" (len=1)
03                              cell[1]: node_type = 0x03 (Scalar)
03 00 00 00 69 6E 74            data_type = "int" (len=3)
01 00 00 00 31                  value = "1" (len=1)
```

A header-only table (`[t [table[a b::int]]]`) replaces the
`01 00 00 00` row_count with `00 00 00 00` and carries no row bytes.
The same document WITHOUT the table (`[t]`) emits version byte `06`
and no `0x17` record — the v9 envelope appears only when a table
payload is present (§4.8 version discipline).

---

## 7 — Version compatibility

### 7.1 Forward compatibility

A v(N) decoder reading a v(M < N) buffer **MUST** decode
successfully. v(N) extensions to existing node types are gated on
the version byte at the start of the payload, and absent fields
default to their zero values (empty string, false, empty list).

### 7.2 Backward incompatibility

A v(N) decoder reading a v(M > N) buffer **MUST reject** with an
error. The version byte is checked first; if it exceeds the
decoder's max-supported version, decode aborts. Bindings surface
this via their error mechanism.

### 7.3 Capability bits

The ast_bin codec advertises support through capability bits in
[`abi.md` §3](abi.md):

| Bit | Feature |
|---|---|
| 29 (`0x20000000`) | Collection-literal kinds — SequenceNode (`0x0F`), ArrayNode (`0x10`), MapNode (`0x11`). |
| 33 (`0x200000000`) | Atom scalar kind — encoded under `0x03 Scalar` with `data_type = "atom"`. |
| 36 (`0x1000000000`) | PathNode (`0x13`), MatchNode (`0x14`), ModifyNode (`0x15`) — co-allocated within version 8. |
| 37 (`0x2000000000`) | IteratorNode (`0x16`). |
| 40 (`0x10000000000`) | Element table record (`0x17`) — version 9. |

A producer emitting a value whose kind requires a capability bit
not advertised by the binding is an internal error: the producer
MUST either implement the kind or refuse to encode the document.
There is no silent-loss path. Per the AST contract ([`ast.md`
§PathNode "Binary codec hook"](ast.md)), ast_bin emitters that
have not honoured the v8 PathNode wire slot reject PathNode values
with `CXER0290`.

---

## 8 — References

- [`ast.md`](ast.md) — parse AST description; ast_bin encodes this
  exact structure.
- [`abi.md` §2.3](abi.md) — C ABI symbols that produce/consume
  ast_bin.
- [`abi.md` §3](abi.md) — capability bitmask (bits 29 / 33 / 36 / 37
  / 40).
- [`cxdm.md` §2.5–§2.7](cxdm.md) — runtime data model for Array,
  Map, and Sequence-as-Item kinds.
- [`grammar.ebnf`](../formal/grammar.ebnf) — source-text grammar (collection
  literals [56]; `[table[…]]` blocks [29]; MatchExpr [136];
  ModifyExpr [141]; CXPath productions [131a]/[131b]/[132a]/[160]).
- [`canonical.md` §2.11.1](canonical.md) — map key ordering used by
  hash-stable producers.
- [`data-bin.md`](data-bin.md) — the DATA wire's own table encodings
  (`0x60` / `0x61` / `0x63`); deliberately NOT reused by the §4.8
  table record (one tag namespace per format).
