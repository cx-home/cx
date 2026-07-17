# CX Document API

**Status:** Current

The Document API is the uniform host-language interface for navigating,
reading, and modifying a parsed CX tree. Every binding (V
native, Python, Go, Rust) implements it with case-adjusted names and
identical semantics. The API operates over the CXDM value model
defined in [`core/cxdm.md`](../core/cxdm.md); selection and mutation
delegate to the CXPath / `[?modify]` semantics defined in
[`core/code.md`](../core/code.md).

---

## 1 — Mental model

A CX document is a tree of **Elements**. Each Element has a name, zero
or more attributes (typed key-value pairs per
[`core/cxdm.md §2.4`](../core/cxdm.md)), and zero or more child Items
(Elements, Scalars, Arrays, Maps, etc.).

```cx
[config
  [server host="localhost" port=8080 debug=false]
  [database host="db.local" port=5432]]
```

```
Document
 └─ Element "config"
     ├─ Element "server" attrs: host="localhost", port=8080, debug=false
     └─ Element "database" attrs: host="db.local", port=5432
```

### 1.1 Immutability

Documents are immutable values. Modifying a document returns a new
document; the original is unchanged. Unchanged nodes are shared between
the old and new document — only the nodes on the path from root to the
changed locus are copied (`O(depth)`, not `O(total)`). Documents are
safe to share across threads with no locks.

---

## 2 — Find

All find methods are available on both Document and Element. On
Document they search from the top level; on Element they search within
that subtree.

### 2.1 `at(path)`

`/`-separated chain of element names; each segment is a direct-child
lookup.

```
doc.at("config/server")          # Element "server"
doc.at("config/server/timeout")  # Element "timeout"
doc.at("config/missing")         # none
el.at("head/title")              # relative navigation from el
```

Returns the element at the path, or none if any step is missing.
Never raises on a missing path. Empty or redundant slashes are
ignored: `"/config/"` is the same as `"config"`.

### 2.2 `get(name)`

Returns the first direct child Element with the given name, or none.

### 2.3 `get_all(name)`

Returns all direct child Elements with the given name, in document
order. Returns `[]` if none match.

### 2.4 `children()`

Returns all direct child Elements, in document order. Excludes
non-Element Items.

### 2.5 `find_first(name)`

Depth-first search of the entire subtree; returns the first matching
Element or none. Does not include the receiver.

### 2.6 `find_all(name)`

Depth-first search of the entire subtree; returns all matching
Elements in encounter order. Returns `[]` if none match.

### 2.7 `select(cxpath)` / `select_all(cxpath)`

Evaluates a CXPath expression per [`core/code.md §5.5`](../core/code.md).
`select_all` returns a sequence of matches; `select` returns the first
match (or none). The string is parsed and evaluated by libcx, so
semantics are identical across bindings.

```
doc.select_all("//user[= $_@active true]/@email")
doc.select("//config/server")
```

### 2.8 `root()`

Returns the first top-level Element in the document, or none on empty
input. Available on Document only.

---

## 3 — Extract

Extraction methods read content from a single Element.

### 3.1 `attr(name)`

Returns the value of the named attribute, typed per the host mapping
of [`misc/type-mapping.md`](type-mapping.md), or none if absent.

```cx
[server host="localhost" port=8080 debug=false]
```

```
el.attr("host")   # "localhost" (string)
el.attr("port")   # 8080 (int)
el.attr("debug")  # false (bool)
el.attr("nope")   # none
```

### 3.2 `attrs()`

Returns all attributes as an ordered map (insertion order preserved
per [`core/canonical.md`](../core/canonical.md)).

### 3.3 `text()`

Returns the element's body content as a single string. Joins adjacent
Text and Scalar children with a single space. Returns `""` if the
body has no text or scalar content.

### 3.4 `scalar()`

Returns the typed value of the first Scalar child, or none. Use this
when an element holds a single typed value.

```cx
[count 42]      # el.scalar() == 42 (int)
[active true]   # el.scalar() == true (bool)
[ratio 1.5]     # el.scalar() == 1.5 (float)
[label Hello]   # el.scalar() == none (Text node, not Scalar)
```

### 3.5 `name()` / `kind()`

`name()` returns the element name as a string. `kind()` returns the
CXDM kind label per [`core/cxdm.md §2`](../core/cxdm.md): one of
`element`, `scalar`, `array`, `map`, `sequence`, `path`, `iterator`.

---

## 4 — Mutate

Two mutation modes; using the wrong one for the wrong context is the
most common source of bugs.

### 4.1 Build mode (in-place, on elements you own)

In-place methods mutate `mut` Element values directly. Use these when
constructing new elements before inserting them into a document.

```v
// V
mut el := cxlib.Element{ name: 'server' }
el.set_attr('host', cxlib.ScalarVal('localhost'))
el.set_attr('port', cxlib.ScalarVal(i64(8080)))
el.append(cxlib.Node(cxlib.Element{ name: 'timeout' }))
doc.append(cxlib.Node(el))
```

```python
# Python
el = Element("server")
el.set_attr("host", "localhost")
el.set_attr("port", 8080)
el.append(Element("timeout"))
doc.append(el)
```

```rust
// Rust
let mut el = Element::new("server");
el.set_attr("host", "localhost");
el.set_attr("port", 8080);
el.append(Element::new("timeout"));
doc.append(el);
```

**Build-mode methods on Element:**

| Method | Effect |
|---|---|
| `set_attr(name, value)` | Set or update an attribute. Preserves order for existing attrs; appends new ones. |
| `remove_attr(name)` | Remove an attribute by name. No-op if absent. |
| `append(node)` | Add a child node at the end. |
| `prepend(node)` | Insert a child node at the start. |
| `insert(index, node)` | Insert at position. Index 0 equals `prepend`; out-of-range clamps to end. |
| `remove_at(index)` | Remove the node at this position. No-op if out of range. |
| `remove_child(name)` | Remove all direct child Elements with this name. No-op if none match. |

Build-mode mutations do not propagate back into a Document. An
Element extracted via `at()` / `find_first()` / etc. is a value copy;
mutating it does not change the document. To update a document, use
`modify`.

### 4.2 Transform mode — `modify(focus, action)`

`modify` applies one or more actions to the elements selected by a
CXPath focus expression and returns a **new Document**. The original
document is unchanged; only the path from root to each match is
copied. Backed by `[?modify]` per
[`core/code.md §8.10`](../core/code.md).

```v
// V
updated := doc.modify('config/server', cx.Set(cx.element('server',
    cx.attrs({'host': 'newhost'}))))
// doc is unchanged. updated is a new Document.
```

```python
# Python
updated = doc.modify("config/server", cx.SetAttr("host", "newhost"))
```

```rust
// Rust
let updated = doc.modify("config/server",
    cx.set_attr("host", "newhost"))?;
```

If the focus matches no nodes, `modify` returns the original document
unchanged.

**Action vocabulary** — one per row, mirrors the eleven clause-child
forms of [`core/code.md §8.10`](../core/code.md):

| Action | Python constructor | Effect |
|---|---|---|
| `[set V]` | `cx.Set(value)` | Replace value at focus |
| `[delete]` | `cx.Delete()` | Remove matched node / attribute |
| `[using FN]` | `cx.Using(callable)` | Lambda return replaces focus |
| `[rename NAME]` | `cx.Rename(name)` | Rename element |
| `[set-attr NAME V]` | `cx.SetAttr(name, value)` | Add / overwrite attribute |
| `[delete-attr NAME]` | `cx.DeleteAttr(name)` | Remove attribute |
| `[append V]` | `cx.Append(value)` | Add child at end of body |
| `[prepend V]` | `cx.Prepend(value)` | Add child at start of body |
| `[insert-before V]` | `cx.InsertBefore(value)` | New sibling before focus |
| `[insert-after V]` | `cx.InsertAfter(value)` | New sibling after focus |
| `[replace V]` | `cx.Replace(value)` | Replace entire focus node |

`cx.Using` accepts a host callable; the binding wraps it as a CX
`[?fn]` lambda crossing the C ABI. The callable receives a Node and
returns a value (any kind, including kind-shift per
[`core/code.md §8.10`](../core/code.md)). Failure to produce a value
raises `cx-err:CXER0104`.

Multiple actions on one `modify` apply left-to-right to each match.

### 4.3 Document-level append and prepend

`Document.append(node)` and `Document.prepend(node)` follow build-mode
semantics: they mutate the document in place. Use these during initial
document construction. For adding top-level elements to an existing
document, use `modify` with `[append]` on the root.

---

## 5 — Missing-value contract

A missing result is always the host's nullish sentinel —
**never an error**. Parse errors are the only thing that can fail;
navigation and extraction are always safe to call.

| Method | Missing returns |
|---|---|
| `root()` | none |
| `get(name)` | none |
| `at(path)` | none |
| `find_first(name)` | none |
| `select(cxpath)` | none |
| `attr(name)` | none |
| `scalar()` | none |
| `get_all(name)` | `[]` |
| `find_all(name)` | `[]` |
| `select_all(cxpath)` | `[]` |
| `children()` | `[]` |
| `text()` | `""` |

`modify` called with a focus that selects nothing returns the original
document unchanged — not an error.

---

## 6 — Direct children vs descendants

| Method | Scope |
|---|---|
| `get(name)` | Direct children only |
| `get_all(name)` | Direct children only |
| `children()` | Direct children only |
| `at(path)` | Chain of direct-child `get` calls |
| `find_first(name)` | All descendants, depth-first |
| `find_all(name)` | All descendants, depth-first |
| `select(cxpath)` / `select_all(cxpath)` | Per CXPath expression |

Use `get` / `get_all` / `at` when the structure is known. Use
`find_first` / `find_all` for variable-depth structure where the
element name suffices. Use `select` / `select_all` when predicates or
axis navigation are required.

---

## 7 — Parallel safety

Documents are immutable values. Any number of threads may call
`select`, `select_all`, `find_all`, `at`, and all extract methods on
the same Document simultaneously with no synchronisation.

`modify` returns a new Document. Threads that transform the same
source document produce independent output values without interfering
with each other or with threads still reading the original.

```v
// V — parallel transforms over the same source document
results := parallels.map(regions, fn(region string) cxlib.Document {
    return doc.modify('//service[= $_@region ${region}]',
        cx.set_attr('active', true))
})
```

Threading registration follows [`core/abi.md §1.5.5`](../core/abi.md):
bindings call `cx_init` once at module load and
`cx_thread_register` on each host-spawned worker thread before any
other `cx_*` call.

---

## 8 — API surface by receiver

| Method | Document | Element | Returns |
|---|---|---|---|
| `root()` | ✓ | | Element or none |
| `get(name)` | ✓ | ✓ | Element or none |
| `get_all(name)` | | ✓ | Element[] |
| `at(path)` | ✓ | ✓ | Element or none |
| `find_first(name)` | ✓ | ✓ | Element or none |
| `find_all(name)` | ✓ | ✓ | Element[] |
| `select(cxpath)` | ✓ | ✓ | Node or none |
| `select_all(cxpath)` | ✓ | ✓ | Node[] |
| `children()` | | ✓ | Element[] |
| `attr(name)` | | ✓ | value or none |
| `attrs()` | | ✓ | ordered map |
| `text()` | | ✓ | string |
| `scalar()` | | ✓ | value or none |
| `name()` | | ✓ | string |
| `kind()` | | ✓ | string |
| `set_attr(name, val)` | | ✓ | — (build mode) |
| `remove_attr(name)` | | ✓ | — (build mode) |
| `append(node)` | ✓ | ✓ | — (build mode) |
| `prepend(node)` | ✓ | ✓ | — (build mode) |
| `insert(i, node)` | | ✓ | — (build mode) |
| `remove_at(i)` | | ✓ | — (build mode) |
| `remove_child(name)` | | ✓ | — (build mode) |
| `modify(focus, action)` | ✓ | | Document |

---

## 9 — Errors

All API methods raise host-native exceptions on error. The exception
carries the `cx-err:CXERnnnn` code per
[`core/code.md §9`](../core/code.md) and
[`core/abi.md §2.16.1`](../core/abi.md), a human-readable message,
and a position when applicable. Tests assert on the code, not on the
message.

```python
try:
    doc.select_all("//user[")    # malformed CXPath
except cx.CxError as e:
    assert e.code == "cx-err:CXER0100"
```
