# CX Bindings — Two-Layer Surface

**Status:** Current for v0.8.0

The v0.8.0 binding surface is two layers per binding. Layer 1 is the
canonical CX surface — identical method names + semantics across V,
Python, Go, Rust. Layer 2 is per-language idiom packs that desugar to
Layer 1. Layer 1 is the conformance contract; Layer 2 is opt-in sugar.

In-scope bindings: V (native reference), Python, Go, Rust.

Companion specs: [`core/abi.md`](../core/abi.md) (C ABI),
[`core/code.md`](../core/code.md) (program surface),
[`misc/api.md`](api.md) (Document API),
[`misc/parity-matrix.md`](parity-matrix.md) (per-binding gates).

---

## 1 — Two-layer model

Two audiences:

- **CX-native developers** know CXPath, multi-arm `[?match]`,
  `[?modify]` — they want the same vocabulary in every host. Layer 1
  delivers that.
- **Host-native developers** know list comprehensions, filter chains,
  iterator combinators — they want their language's idioms without
  losing CX semantics. Layer 2 delivers that.

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 2 — host idioms (Pythonic, Go, Rust)                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │ [u for u in  │ │ doc.Users()  │ │ doc.iter::<User>()   │  │
│  │  doc if ...] │ │   .Where()   │ │   .filter(...)       │  │
│  └──────┬───────┘ └──────┬───────┘ └────────┬─────────────┘  │
└─────────┼────────────────┼──────────────────┼────────────────┘
          │ compiles to    │ compiles to      │ compiles to
          ▼                ▼                  ▼
┌──────────────────────────────────────────────────────────────┐
│  Layer 1 — canonical (identical across all bindings)         │
│         doc.select_all("//user[@active=true]")               │
└──────────────────────────┬───────────────────────────────────┘
                           │ C ABI
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  libcx — CX evaluator (V native)                             │
└──────────────────────────────────────────────────────────────┘
```

### 1.1 Method-name discipline

| Surface | Convention | Example |
|---|---|---|
| Layer 1 (V) | snake_case, native syntax | `doc.select_all('//user')` |
| Layer 1 (Python) | snake_case | `doc.select_all('//user')` |
| Layer 1 (Go) | PascalCase per Go style | `doc.SelectAll("//user")` |
| Layer 1 (Rust) | snake_case per Rust style | `doc.select_all("//user")` |
| Layer 2 | idiomatic to host language | varies (see §3) |

Naming differences across Layer 1 are case-style adjustments mandated
by host conventions; method count, argument order, and semantics are
identical.

---

## 2 — Layer 1 — canonical surface

Layer 1 is the conformance contract. Every binding implements
identical method names (case-adjusted) and identical semantics.
`conformance/binding_api.txt` runs identical input/output fixtures
against every binding; drift on any fixture blocks the release.

### 2.1 Canonical method set

| Method | Returns | Description |
|---|---|---|
| `parse(bytes)` | Doc | Parse canonical CX bytes into a Doc value |
| `Doc.bytes()` | bytes | Serialize Doc to canonical CX |
| `Doc.hash()` | hex string | SHA-256 of canonical bytes |
| `Doc.equals(other)` | bool | Canonical-bytes equality |
| `Doc.eval(code)` | Value | Evaluate CX code against this doc (wraps `cx_code_eval`) |
| `Doc.select_all(cxpath)` | sequence | CXPath path-value evaluation |
| `Doc.select(cxpath)` | optional Node | First match of `select_all` |
| `Doc.modify(focus, action)` | Doc | Pure-functional update per [`core/code.md §8.10`](../core/code.md) |
| `Doc.diff(other)` | Doc | Structured semantic diff document (wraps `cx_diff`, see [`core/abi.md §2.17`](../core/abi.md)) |
| `Doc.lint(ruleset=None)` | Doc | Structured diagnostics document (wraps `cx_lint`, see [`core/abi.md §2.18`](../core/abi.md)); `ruleset` is an optional `.cxs` Document for custom rules |
| `Doc.find_first(name)` | optional Node | Name-only convenience (no CXPath parse); first match |
| `Doc.find_all(name)` | sequence | Name-only convenience (no CXPath parse); all matches |
| `Doc.root()` | Node | Root element |
| `Node.name()` | string | Element name |
| `Node.attr(name)` | optional value | Attribute value |
| `Node.attrs()` | ordered map | All attributes |
| `Node.children()` | sequence | Direct children |
| `Node.body()` | value | Element body |
| `Node.kind()` | string | `element` / `scalar` / `array` / `map` / `sequence` / `path` |

**19 methods total.** Bindings MAY expose additional methods strictly
above this set (typed projections, streaming helpers, etc.) but the
19 above MUST be present with identical names and semantics. The
in-place build-mode methods (`set_attr`, `append`, etc.) are
specified in [`misc/api.md §4.1`](api.md).

### 2.2 CXPath strings as selector vocabulary

All Layer 1 selection methods take CXPath strings. The string is
parsed and evaluated by libcx, not by the binding. Semantics are
identical across hosts and `cx_code_eval` caching works
cross-binding.

```python
# Python — Layer 1
emails = doc.select_all("//user[@active=true]/@email")
```

```go
// Go — Layer 1
emails, _ := doc.SelectAll("//user[@active=true]/@email")
```

```rust
// Rust — Layer 1
let emails = doc.select_all("//user[@active=true]/@email")?;
```

```v
// V — Layer 1
emails := doc.select_all('//user[@active=true]/@email')!
```

The bytes returned across the C ABI are identical across bindings.

### 2.3 `Doc.modify` — pure-functional update

`Doc.modify(focus_cxpath, action)` returns a new Doc; the original is
unchanged. Action is a typed struct (per host language) encoding one
of the eleven actions of
[`core/code.md §8.10`](../core/code.md).

| Action | Python constructor |
|---|---|
| `[set V]` | `cx.Set(value)` |
| `[delete]` | `cx.Delete()` |
| `[using FN]` | `cx.Using(callable)` |
| `[rename NAME]` | `cx.Rename(name)` |
| `[set-attr NAME V]` | `cx.SetAttr(name, value)` |
| `[delete-attr NAME]` | `cx.DeleteAttr(name)` |
| `[append V]` | `cx.Append(value)` |
| `[prepend V]` | `cx.Prepend(value)` |
| `[insert-before V]` | `cx.InsertBefore(value)` |
| `[insert-after V]` | `cx.InsertAfter(value)` |
| `[replace V]` | `cx.Replace(value)` |

```python
new_doc = doc.modify("//user[@id=1]/@name", cx.Set("Alice"))
new_doc = doc.modify("//user[@banned=true]", cx.Delete())
new_doc = doc.modify("//price", cx.Using(lambda p: float(p) * 1.1))
```

`cx.Using` accepts a host callable; the binding wraps it as a CX
`[?fn]` lambda crossing the C ABI. Failure to produce a value raises
`cx-err:CXER0104`. Legitimate kind-shift (returning a value of a
different kind than the focus) is allowed per
[`core/code.md §8.10`](../core/code.md) and does not raise.

### 2.4 Error handling

All Layer 1 methods raise host-native exceptions on error carrying:

- `code` — CX error code (`cx-err:CXERnnnn` per
  [`core/code.md §9`](../core/code.md) and
  [`core/abi.md §2.16.1`](../core/abi.md))
- `message` — human-readable
- `position` — file / line / column when applicable

The error code set is identical across bindings. Tests assert on
`code`, not on `message`.

```python
try:
    doc.select_all("//user[")    # malformed CXPath
except cx.CxError as e:
    assert e.code == "cx-err:CXER0100"
```

---

## 3 — Layer 2 — host idiom packs

Layer 2 is opt-in sugar. Importing it pulls in host-idiomatic
wrappers that compile to Layer 1 calls at the boundary. The
compilation is deterministic and inspectable; every Layer-2
expression has a single documented Layer-1 desugaring.

### 3.1 Python — `cxlib.idioms`

```python
from cxlib import Doc
from cxlib.idioms import *   # opt-in

doc = Doc.parse(open("users.cx", "rb").read())

# List comprehension over Nodes — desugars to select_all
active_users = [u for u in doc if u.tag == "user" and u.attr("active") == True]
# ≡ doc.select_all("//user[@active=true]")

# Subscript with CXPath string
new_doc = doc.copy()
new_doc["//user[@id=1]/@name"] = "Alice"
# ≡ doc = doc.modify("//user[@id=1]/@name", cx.Set("Alice"))

# Generator over a relative path
for email in doc / "//user/@email":
    print(email)
# ≡ for email in doc.select_all("//user/@email"):
```

`cxlib.idioms.explain(expr)` returns the equivalent Layer-1 call for
any Layer-2 expression (used in fixtures and LSP hovers).

### 3.2 Go — `cxlib/idioms`

```go
import "cx/cxlib"
import . "cx/cxlib/idioms"

doc, _ := cxlib.Parse(data)

// Builder chain compiles to CXPath
emails := doc.Filter("user").Where("@active=true").Get("/@email")
// ≡ doc.SelectAll("//user[@active=true]/@email")

// Typed projection
type User struct {
    ID    int    `cx:"@id"`
    Email string `cx:"@email"`
}
users := Project[User](doc.Filter("user").Where("@active=true"))
// ≡ doc.SelectAll("//user[@active=true]") + struct mapping
```

### 3.3 Rust — `cxlib::idioms`

```rust
use cxlib::Doc;
use cxlib::idioms::*;

let doc = Doc::parse(&data)?;

// Iterator combinators compile to CXPath
let emails: Vec<_> = doc.iter_users()
    .filter(|u| u.active())
    .map(|u| u.email())
    .collect();
// ≡ doc.select_all("//user[@active=true]/@email")?

// Typed via #[derive(CxData)]
#[derive(CxData)]
struct User { id: u32, email: String, #[cx(attr)] active: bool }

let users: Vec<User> = doc.collect::<User>("//user[@active=true]")?;
```

### 3.4 V — Layer 2 is Layer 1

V is the native reference implementation; CX vocabulary is already
idiomatic V. No separate Layer 2 wrapper. Layer 1 IS the V surface.

```v
doc := cx.parse(data)!
for user in doc.select_all('//user[@active=true]') {
    println(user.attr('email') or { '<no email>' })
}
new_doc := doc.modify('//user[@id=1]/@name', cx.Set('Alice'))!
```

---

## 4 — Conformance contract

### 4.1 `conformance/binding_api.txt`

Each fixture specifies:

- `--- in_cx` — input document (canonical CX)
- `--- call` — Layer-1 method invocation in a binding-agnostic
  mini-syntax
- `--- out_text` or `--- out_err` — expected result

Every binding runs the same fixtures through a thin harness. The
Layer-1 contract is byte-identical results across V, Python, Go,
Rust.

```
=== test: binding-api-001-select-all-basic
--- in_cx
[users [user @id=1 @email="a@x.com"] [user @id=2 @email="b@x.com"]]
--- call
doc.select_all("//user/@email")
--- out_text
"a@x.com"
"b@x.com"

=== test: binding-api-002-modify-set-attr
--- in_cx
[users [user @id=1 @name="A"]]
--- call
doc.modify("//user[@id=1]/@name", cx.Set("Alice")).bytes()
--- out_text
[users [user @id=1 @name="Alice"]]
```

### 4.2 Layer 2 is binding-private

Layer 2 idiom packs are not conformance-tested at the API level
(different bindings have different idioms; the surface differs by
design). They ARE tested via their Layer-1 desugaring — every Layer-2
example in the per-binding quickstart docs must produce identical
Layer-1 output to the documented desugaring.

### 4.3 Layer-1 parity gate

A release gate. All four bindings (V, Python, Go, Rust) MUST pass
`conformance/binding_api.txt` byte-identically. Drift on any fixture
blocks the release. Tracked in
[`misc/parity-matrix.md`](parity-matrix.md).

---

## 5 — Init + thread registration

Bindings MUST call `cx_init()` once at module load (idempotent).
Host-spawned threads MUST call `cx_thread_register()` before any
other `cx_*` call. Full details in
[`core/abi.md §1.5.5`](../core/abi.md); this spec defers to it.

| Binding | `cx_init` site | `cx_thread_register` site |
|---|---|---|
| V (native) | core lib init | not needed (V-spawned threads inherit) |
| Python | module import | per-thread guard in FFI chokepoints |
| Go | `func init()` | cgo helper at every Layer-1 entry |
| Rust | `std::sync::Once` | per-OS-thread guard via `LazyLock` |

---

## 6 — Versioning

Each binding tracks the parent CX version. `Cargo.toml`,
`pyproject.toml`, `go.mod`, V version constant all read `0.8.0` at
the v0.8.0 tag. ABI cap bits (from `cx_features()`, per
[`core/abi.md §3`](../core/abi.md)) provide forward compatibility — a
Layer-1 binding can advertise that it understands cap bit N and fall
back gracefully if a newer libcx adds cap bit N+1.

---

## 7 — Wire-format negotiation

CX itself does not mandate a transport-level format-negotiation
protocol; the language is host-agnostic and treats wire-format choice
as a host concern. The following conventions apply when a binding is
exposed across an IPC or HTTP boundary.

### 7.1 Producer / consumer obligations

- A producer MUST emit one of the named formats in
  [`core/conversions.md`](../core/conversions.md) (`cx`, `xml`, `json`,
  `yaml`, `toml`, `csv`, `tsv`, `psv`, `md`) or one of the binary wire
  formats (`ast_bin`, `data_bin`, events).
- A consumer MUST accept any format whose tag it advertises through its
  capability surface; rejecting an advertised format is a conformance
  failure.
- Format detection from byte sniffing is not normative — peers MUST
  negotiate explicitly, not heuristically.

### 7.2 HTTP context — suggested Content-Types

The following media-type strings are SUGGESTED for HTTP transports.
They are not IANA-registered at v0.8.0; consumers MAY also accept the
generic `application/octet-stream` for binary wire formats.

| Wire format | Suggested Content-Type |
|---|---|
| CX text | `application/cx` |
| CX strict canonical | `application/cx` + `; profile=canonical` |
| AST binary (`ast_bin`) | `application/cx-ast` |
| Data binary (`data_bin`) | `application/cx-data` |
| Event stream (`events`, `events_bin`) | `application/cx-events` |
| XML | `application/xml` |
| JSON | `application/json` |
| YAML | `application/yaml` |
| TOML | `application/toml` |
| CSV | `text/csv` |

CSRP (`cxstore-remote-protocol.md`) uses `application/cx` and
`application/cx-data` for its request/response bodies and is the
reference for HTTP-level CX content negotiation.

### 7.3 Native IPC

For native (in-process, shared-memory, or pipe) IPC, peers negotiate
the wire format at handshake by exchanging the capability bitmask
returned by `cx_features()`. The handshake protocol is binding- and
transport-specific; what is normative is that both peers agree on a
format whose cap bit is set in BOTH bitmasks before any payload is
sent.
