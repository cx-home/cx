# CX — Python

Python binding for the CX format library. Parses, streams, queries, and
transforms CX documents; converts between CX, XML, JSON, YAML, and TOML
via `libcx`.


## Requirements

- Python 3.10 or newer
- `libcx` built from source (one command — see Install)

## Install

```sh
# 1. Clone the repo and build libcx (requires the V compiler — ships with devbox)
git clone https://github.com/cx-lang/cx
cd cx
make build-vcx          # produces vcx/target/libcx.dylib  (or .so on Linux)

# 2. Point Python at the binding
export PYTHONPATH="$PWD/lang/python:$PYTHONPATH"
```

The binding discovers `libcx` automatically relative to its own file. No
extra environment variables are needed as long as you run from the repo root
or have `make install` installed the library to `/usr/local/lib`.

## Quick Start

### Parse and read

```python
import cxlib

src = """[config version='1.0'
  [server host=localhost port=8080]
  [database host=db.local port=5432]
]"""

doc = cxlib.parse(src)

# Navigate by path
server = doc.at('config/server')
print(server.attr('host'))   # localhost
print(server.attr('port'))   # 8080

# Find all descendants named 'server'
for el in doc.find_all('server'):
    print(el.name)
```

### Transform (immutable update)

`transform` and `transform_all` return a **new document** — the original is
unchanged.

```python
import cxlib

doc = cxlib.parse("""[config
  [server host=localhost port=8080]
  [database host=db.local port=5432]
]""")

# Replace config/server — returns a new document
def update_host(el):
    el.set_attr('host', 'prod.example.com')
    return el

updated = doc.transform('config/server', update_host)

print(updated.at('config/server').attr('host'))  # prod.example.com
print(doc.at('config/server').attr('host'))       # localhost  (original unchanged)

# Chain multiple transforms
result = (doc
    .transform('config/server',   lambda el: (el.set_attr('host', 'web.example.com') or el))
    .transform('config/database', lambda el: (el.set_attr('host', 'db.example.com')  or el)))

print(result.to_cx())
```

### CXPath: select

`select` and `select_all` evaluate CXPath expressions against a document or
element. Expressions support descendant axes (`//`), child paths (`a/b/c`),
wildcards (`*`), attribute predicates, boolean operators, position, and
string functions.

```python
import cxlib

doc = cxlib.parse("""[services
  [service name=auth  port=8080 active=true]
  [service name=api   port=9000 active=false]
  [service name=web   port=80   active=true]
]""")

# First match
first = doc.select('//service')
print(first.attr('name'))  # auth

# All active services
for svc in doc.select_all('//service[@active=true]'):
    print(svc.attr('name'))
# auth
# web

# Attribute predicate with numeric comparison
high = doc.select_all('//service[@port>=8000]')
print(len(high))  # 2

# Position
second = doc.select('//service[2]')
print(second.attr('name'))  # api

# select on an Element searches only its subtree (excludes the element itself)
services_el = doc.at('services')
for svc in services_el.select_all('service[@active=true]'):
    print(svc.attr('name'))
```

### transform_all

`transform_all` applies a function to every element matching a CXPath
expression and returns a new document.

```python
import cxlib

doc = cxlib.parse("""[services
  [service name=auth port=8080]
  [service name=api  port=9000]
]""")

def activate(el):
    el.set_attr('active', True)
    return el

updated = doc.transform_all('//service', activate)

for svc in updated.find_all('service'):
    print(svc.attr('active'))  # True
```

### Streaming

`cxlib.stream(src)` returns a `Stream` iterator over all events.

```python
import cxlib

src = """[config version='1.0'
  [server host=localhost port=8080]
]"""

for ev in cxlib.stream(src):
    if ev.is_start_element():
        attrs = '  '.join(f'{a.name}={a.value}' for a in ev.attrs)
        print(f'{ev.name}  {attrs}')
```

Output:
```
config  version=1.0
server  host=localhost  port=8080
```

### CX code: query / transform / template

CX code is CX's unified pattern / query / transform language — a CX program is itself a `.cx` file (same parser, same data model). `eval_code(input, program, output_target)` runs the program against an optional input document. `output_target` is `""` (default `"text"`), `"cx"`, `"json"`, `"yaml"`, `"xml"`, `"csv"`, or `"tsv"`.

```python
import cxlib

ctx = "[fleet [svc name=auth :status up] [svc name=web :status up] [svc name=db :status down]]"

# Find every service via a CXPath path value
prog = "//svc"

print(cxlib.eval_code(ctx, prog))
# [svc name=auth :status up]
# [svc name=web :status up]
# [svc name=db :status down]
```

See [`spec/code.md`](../../../spec/code.md) for the full language reference. `eval_code` is the eval entry point.

## Run the Examples

```sh
python lang/python/examples/transform.py
```

## API Reference

### Parse

| Function | Description |
|---|---|
| `parse(s)` | Parse a CX string into a `Document` |
| `parse_xml(s)` | Parse XML into a `Document` |
| `parse_json(s)` | Parse JSON into a `Document` |
| `parse_yaml(s)` | Parse YAML into a `Document` |
| `parse_toml(s)` | Parse TOML into a `Document` |

### Document

| Method | Description |
|---|---|
| `doc.root()` | First top-level `Element` |
| `doc.get(name)` | First top-level `Element` by name |
| `doc.at(path)` | Navigate by slash-separated path (`'config/server'`) |
| `doc.find_first(name)` | First matching descendant, depth-first |
| `doc.find_all(name)` | All matching descendants |
| `doc.select(expr)` | First element matching a CXPath expression |
| `doc.select_all(expr)` | All elements matching a CXPath expression |
| `doc.transform(path, fn)` | Return new doc with element at path replaced by `fn(el)` |
| `doc.transform_all(expr, fn)` | Return new doc with all matching elements replaced |
| `doc.append(node)` | Add a top-level node |
| `doc.prepend(node)` | Insert a top-level node at position 0 |
| `doc.to_cx()` | Emit canonical CX |
| `doc.to_xml()` | Emit XML |
| `doc.to_json()` | Emit JSON |
| `doc.to_yaml()` | Emit YAML |
| `doc.to_toml()` | Emit TOML |

### Element

| Method | Description |
|---|---|
| `el.get(name)` | First direct child `Element` by name |
| `el.get_all(name)` | All direct child `Element`s by name |
| `el.at(path)` | Navigate relative path from this element |
| `el.attr(name)` | Read an attribute value (`int`/`float`/`bool`/`str`/`None`) |
| `el.text()` | Concatenated text and scalar child content |
| `el.scalar()` | Value of the first `Scalar` child |
| `el.children()` | All direct child `Element`s |
| `el.find_first(name)` | First matching descendant |
| `el.find_all(name)` | All matching descendants |
| `el.select(expr)` | First descendant matching a CXPath expression |
| `el.select_all(expr)` | All descendants matching a CXPath expression |
| `el.set_attr(name, value)` | Set or update an attribute |
| `el.remove_attr(name)` | Remove an attribute |
| `el.append(node)` | Add a child node at the end |
| `el.prepend(node)` | Insert a child node at position 0 |
| `el.insert(index, node)` | Insert a child node at a given index |
| `el.remove(node)` | Remove a child node by identity |
| `el.remove_at(index)` | Remove child node at a given index |
| `el.remove_child(name)` | Remove all direct child `Element`s with the given name |

### CXPath expressions

| Syntax | Matches |
|---|---|
| `//name` | All descendants named `name` |
| `a/b/c` | Child path |
| `*` | Any element (wildcard) |
| `[@attr]` | Has attribute |
| `[@attr=val]` | Attribute equals value (typed) |
| `[@attr!=val]` | Attribute not equal |
| `[@attr>=val]` | Numeric comparison (`>`, `<`, `>=`, `<=`) |
| `[@a=x and @b=y]` | Boolean `and` / `or` |
| `[not(@attr)]` | Negation |
| `[childname]` | Has a direct child element named `childname` |
| `[1]`, `[2]`, `[last()]` | Position (1-based) |
| `[contains(@k, v)]` | Attribute contains substring |
| `[starts-with(@k, v)]` | Attribute starts with prefix |

Attribute values auto-type: `true`/`false` → `bool`, integers → `int`,
decimals → `float`, everything else → `str`. An invalid expression raises
`ValueError`.

### Stream

| Function / Method | Description |
|---|---|
| `stream(s)` | Return a `Stream` iterator over a CX string |
| `ev.type` | Event type string: `StartDoc` `EndDoc` `StartElement` `EndElement` `Text` `Scalar` `Comment` `PI` `EntityRef` `RawText` `Alias` |
| `ev.name` | Element name (set on `StartElement` and `EndElement`) |
| `ev.attrs` | `list[Attr]` (set on `StartElement`) |
| `ev.value` | Text / comment / scalar raw value |
| `ev.is_start_element(name)` | `True` if `StartElement`, optionally matching `name` |
| `ev.is_end_element(name)` | `True` if `EndElement`, optionally matching `name` |

### Conversion functions

| Function | Description |
|---|---|
| `to_cx(s)` | CX → canonical CX |
| `to_xml(s)` | CX → XML |
| `to_json(s)` | CX → JSON |
| `to_yaml(s)` | CX → YAML |
| `to_toml(s)` | CX → TOML |
| `xml_to_cx(s)`, `json_to_cx(s)`, … | Any format → CX |
| `loads(s)` | Parse CX into native Python types (`dict`/`list`/scalar) |
| `dumps(data)` | Serialize Python types back to CX |
| `version()` | Return the libcx version string |

### Canonical-form tooling (v3.4)

| Function | Description |
|---|---|
| `cx.fmt(s)` | Lossless canonical text — preserves comments/anchors; normalizes presentation. Idempotent: `fmt(fmt(x)) == fmt(x)`. |
| `cx.canonical(s)` | Strict canonical text — strips presentation. Two CX inputs have identical strict canonical bytes iff they encode the same data. |
| `cx.hash(s)` | SHA-256 hex (64 lowercase hex chars) of the strict canonical bytes. Use for content-addressable hashing or signed config bundles. |
| `cx.eq(a, b)` | `True` iff `strict-canonical(a) == strict-canonical(b)`. |

```py
from cxlib import cx
src1 = "[config\n  [; a comment]\n  [server host=localhost]\n]"
src2 = "[config [server host=localhost]]"
cx.fmt(src1)        # preserves the comment, normalizes whitespace
cx.canonical(src1)  # comment stripped
cx.eq(src1, src2)   # True — same data, different presentation
cx.hash(src1) == cx.hash(src2)  # True
```

### `data_bin` one-shot conversions (v3.4)

Direct format ↔ binary AST conversions, skipping the text-CX
intermediate. Useful when a tool already produces CX-binary payloads
(or wants to consume them) and the text form would only add a
parse/emit roundtrip.

| Function | Description |
|---|---|
| `cxlib.xml_to_data_bin(s)` | XML text → CXCol v1 framed bytes |
| `cxlib.json_to_data_bin(s)` | JSON text → CXCol v1 framed bytes |
| `cxlib.yaml_to_data_bin(s)` | YAML text → CXCol v1 framed bytes |
| `cxlib.toml_to_data_bin(s)` | TOML text → CXCol v1 framed bytes |
| `cxlib.data_bin_to_xml(b)` | CXCol v1 framed bytes → XML text |
| `cxlib.data_bin_to_json(b)` | CXCol v1 framed bytes → JSON text |
| `cxlib.data_bin_to_yaml(b)` | CXCol v1 framed bytes → YAML text |
| `cxlib.data_bin_to_toml(b)` | CXCol v1 framed bytes → TOML text |

The framed bytes are CX Data Binary v1 — see `spec/core/data-bin.md` for
the wire format. Round-trip: `data_bin_to_X(X_to_data_bin(s)) == s`
(after canonicalization).

### Apache Arrow C-Data interop (v0.6.0; optional)

Bridges CXCol chunked-tables to Apache Arrow's
[C-Data ABI](https://arrow.apache.org/docs/format/CDataInterface.html)
via the separate `libcx_arrow` shared library
(`make lib-arrow` → `vcx/target/libcx_arrow.dylib` / `.so`). Arrow is an
optional dependency; install with `pip install cxlib[arrow]` to pull in
PyArrow ≥ 14. With the bridge wired up CXCol becomes a canonical
hashable origin that flows zero-copy into Polars / DuckDB / Pandas via
PyArrow, and the Parquet bridge chains for free
(`pyarrow.parquet.write_table(reader.read_all(), 'file.parquet')`).

```python
import cxlib
import cxlib.arrow as cxa

# Discover capability — bit 23 (0x800000) reports libcx_arrow present
assert cxa.available()
assert cxa.merged_features() & 0x800000

# CXCol chunked-table → pyarrow.RecordBatchReader (one ArrayChunk per row group)
src = '[points :table[name:string score:int] alice 91 bob 88 carol 73]'
framed = cxlib.to_data_bin_chunked(src)
reader = cxa.export(framed)
table  = reader.read_all()        # pyarrow.Table

# Inverse: pyarrow.Table or pyarrow.RecordBatchReader → framed CXCol
import pyarrow as pa
table_in = pa.table({'name': pa.array(['alice'], type=pa.string()),
                     'score': pa.array([91], type=pa.int64())})
framed_again = cxa.import_to_data_bin(table_in)
```

Supported v0.6.0 column types (`spec/abi.md §2.11.1`):

| CXCol type        | Arrow format | PyArrow type   |
|------------------|--------------|----------------|
| `int` / `i64`    | `l`          | `int64`        |
| `i8`             | `c`          | `int8`         |
| `i16`            | `s`          | `int16`        |
| `i32`            | `i`          | `int32`        |
| `float` / `f64`  | `g`          | `float64`      |
| `bool`           | `b`          | `bool`         |
| `string`         | `u`          | `string`       |
| `date`           | `tdD`        | `date32[day]`  |
| `bytes`          | `z`          | `binary`       |

`datetime` and `decimal` columns are deferred to a follow-up phase
(`spec/abi.md §2.11.1`); they surface a clear deferred-type error at
chunked-emit time. NULL handling is also deferred (`null_count = 0`
on both sides at v0.6.0).

`cxa.available()` is `False` if either `libcx_arrow` is missing or
PyArrow is not importable; consumers can fall back to materializing
through `cxlib.data_bin_to_csv()` / `cxlib.data_bin_to_json()` for
those environments.

## Tests

```sh
make test-python
```

## 30-second quickstart

<!-- quickstart-begin: python -->
```python
import cxlib
from cxlib import Table

# Parse + read a typed value out
doc = cxlib.parse('[server [port :u16 8080] [host localhost]]')
print(doc.at('server/port').int_value())   # 8080

# Round-trip to JSON, lossless
print(cxlib.to_json('[user [id :i64 9007199254740993]]'))

# Public Table API — 17-member surface
src = """[users :table[name age:int]
  alice 30
  bob   25
]"""
t = Table.from_cx(src)
print(t.row_count, t.cols)         # 2  ['name', 'age']
for row in t:                      # iterate rows as dicts
    print(row['name'], row['age'])
print(t.column('age'))             # [30, 25]
print(t.to_csv())                  # CSV emit
```
<!-- quickstart-end -->
