# CX — Ruby

Ruby binding for the [CX format library](https://github.com/cx-language/cx).
Thin FFI wrapper around `libcx` — parses, streams, and converts CX/XML/JSON/YAML/TOML/Markdown.

> **Upgrading from v3.3?** See [`MIGRATION.md`](../../../MIGRATION.md) at
> the repo root. v3.4 has two breaking changes: leading-zero integer
> literals (`02134` is now string, not int) and `loads`/`dumps` type
> fidelity (integers stay `Integer` instead of coercing to `Float` via
> `JSON.parse`).

## Canonical-form tooling (v3.4)

```ruby
src1 = "[config\n  [- comment]\n  [server host=localhost]\n]"
src2 = "[config [server host=localhost]]"
CXLib.fmt(src1)          # lossless canonical (preserves the comment)
CXLib.canonical(src1)    # strict canonical   (comment stripped)
CXLib.hash(src1)         # 64-char SHA-256 hex of strict canonical bytes
CXLib.eq(src1, src2)     # true — data-equivalent inputs
```

`fmt` is idempotent. `canonical`/`hash`/`eq` are byte-stable across
runs and bindings; the same input produces the same hash in any
language. Use for content-addressable hashing or signed config bundles.

## Requirements

- Ruby 3.1 or newer (Homebrew: `brew install ruby`)
- `ffi` gem: `gem install ffi`
- `libcx` shared library built from this repo (see Install)

## Install

**1. Build `libcx`** (requires the [V compiler](https://vlang.io)):

```sh
make build-vcx
```

This produces `vcx/target/libcx.dylib` (macOS) or `vcx/target/libcx.so` (Linux).

**2. Install the `ffi` gem:**

```sh
gem install ffi
```

**3. Add the library to your load path when running scripts:**

```sh
ruby -I lang/ruby/cxlib/lib your_script.rb
```

Or install the gem from source:

```sh
gem install --local lang/ruby/cxlib
```

`cxlib` finds `libcx` automatically via the repo-relative path. To use a
library installed elsewhere, set `LIBCX_PATH=/path/to/libcx.dylib` or
`LIBCX_LIB_DIR=/path/to/dir` before requiring the gem.

## Quick Start

### Document Model and Transform

```ruby
require 'cxlib'

cx = <<~CX
  [config version='1.0' debug=false
    [server host=localhost port=8080]
    [database url='postgres://localhost/mydb' pool=10]
    [cache enabled=true ttl=300]
  ]
CX

# 1. Parse the CX string into a Document
doc = CXLib.parse(cx)

# 2. Read: navigate to the server element and inspect attributes
server = doc.at('config/server')
puts server.attr('host')          # => "localhost"  (String)
puts server.attr('port')          # => 8080         (Integer — typed automatically)

# 3. Update: change an attribute value
server.set_attr('host', 'prod.example.com')

# 4. Create: add a child element with text content
server.append(CXLib::Element.new('timeout', items: [CXLib::TextNode.new('30')]))

# 5. Delete: remove the cache child from config (by identity)
config = doc.at('config')
config.remove(config.get('cache'))

# 6. Serialize back to CX
puts doc.to_cx
# [config version='1.0' debug=false
#   [server host=prod.example.com port=8080
#     [timeout '30']
#   ]
#   [database url=postgres://localhost/mydb pool=10]
# ]
```

### CXPath: select and transform

`select` and `select_all` evaluate CXPath expressions against a document or
element. `transform` and `transform_all` return a **new document** — the
original is unchanged.

```ruby
require 'cxlib'

cx = <<~CX
  [services
    [service name=auth  port=8080 active=true]
    [service name=api   port=9000 active=false]
    [service name=web   port=80   active=true]
  ]
CX

doc = CXLib.parse(cx)

# First match
first = doc.select('//service')
puts first.attr('name')    # => "auth"

# All active services
doc.select_all('//service[@active=true]').each do |svc|
  puts svc.attr('name')
end
# auth
# web

# Numeric comparison
high = doc.select_all('//service[@port>=8000]')
puts high.size    # => 2

# Position
second = doc.select('//service[2]')
puts second.attr('name')   # => "api"

# transform: returns a new document (original unchanged)
updated = doc.transform('services/service') { |el| el.set_attr('host', 'prod'); el }
puts updated.at('services/service').attr('host')   # => "prod"
puts doc.at('services/service').attr('host').nil?  # => true (original unchanged)

# transform_all: apply to every matching element
activated = doc.transform_all('//service') { |el| el.set_attr('active', true); el }
activated.find_all('service').each { |s| puts s.attr('active') }  # => true (all 3)

# select_all on an Element searches only its subtree
services_el = doc.get('services')
active = services_el.select_all('service[@active=true]')
puts active.size   # => 2
```

### Streaming

```ruby
require 'cxlib'

cx = <<~CX
  [config version='1.0' debug=false
    [server host=localhost port=8080]
    [database url='postgres://localhost/mydb' pool=10]
    [cache enabled=true ttl=300]
  ]
CX

CXLib.stream(cx).each do |ev|
  if ev.type == 'StartElement'
    attr_str = ev.attrs.map { |a| "#{a.name}=#{a.value.inspect}" }.join(' ')
    puts "#{ev.type}  name=#{ev.name}  #{attr_str}"
  else
    puts ev.type
  end
end
# StartDoc
# StartElement  name=config  version="1.0" debug=false
# StartElement  name=server  host="localhost" port=8080
# EndElement
# StartElement  name=database  url="postgres://localhost/mydb" pool=10
# EndElement
# StartElement  name=cache  enabled=true ttl=300
# EndElement
# EndElement
# EndDoc
```

## Run the Demo

From the repo root:

```sh
make build-vcx
ruby -I lang/ruby/cxlib/lib /tmp/cx_demo.rb
```

Where `/tmp/cx_demo.rb` contains the Document Model and Streaming examples above,
combined. You can also run the built-in example:

```sh
make example-ruby
```

Or run the test suite:

```sh
make test-ruby
```

## API Reference

### Conversion

All conversion methods accept a source string and return a string.

| Method | Input | Output |
|---|---|---|
| `CXLib.to_cx(s)` | CX | CX (canonical) |
| `CXLib.to_cx_compact(s)` | CX | CX (compact, single line) |
| `CXLib.to_xml(s)` | CX | XML |
| `CXLib.to_json(s)` | CX | JSON |
| `CXLib.to_yaml(s)` | CX | YAML |
| `CXLib.to_toml(s)` | CX | TOML |
| `CXLib.to_md(s)` | CX | Markdown |
| `CXLib.to_ast(s)` | CX | AST (JSON) |
| `CXLib.xml_to_cx(s)` | XML | CX |
| `CXLib.json_to_cx(s)` | JSON | CX |
| `CXLib.yaml_to_cx(s)` | YAML | CX |
| `CXLib.toml_to_cx(s)` | TOML | CX |
| `CXLib.md_to_cx(s)` | Markdown | CX |
| `CXLib.ast_to_cx(s)` | AST (JSON) | CX |

Cross-format variants follow the pattern `CXLib.{fmt}_to_{fmt}(s)` for all
combinations of `cx`, `xml`, `json`, `yaml`, `toml`, `md`.

### Document

| Method | Description |
|---|---|
| `CXLib.parse(cx_str)` | Parse a CX string into a `Document` |
| `CXLib.parse_xml(s)` | Parse XML into a `Document` |
| `CXLib.parse_json(s)` | Parse JSON into a `Document` |
| `CXLib.parse_yaml(s)` | Parse YAML into a `Document` |
| `CXLib.parse_toml(s)` | Parse TOML into a `Document` |
| `CXLib.parse_md(s)` | Parse Markdown into a `Document` |
| `CXLib.loads(cx_str)` | Parse CX and return a plain Ruby Hash/Array |
| `CXLib.dumps(data)` | Serialize a Ruby Hash/Array to a CX string |
| `doc.root` | First top-level `Element` |
| `doc.get(name)` | First top-level `Element` with the given name |
| `doc.at(path)` | Navigate by slash-separated path, e.g. `'config/server'` |
| `doc.find_all(name)` | All descendant `Element`s with the given name |
| `doc.find_first(name)` | First descendant `Element` with the given name (depth-first) |
| `doc.select(expr)` | First element matching a CXPath expression |
| `doc.select_all(expr)` | All elements matching a CXPath expression |
| `doc.transform(path, &f)` | Return new doc with element at path replaced by `f(el)` |
| `doc.transform_all(expr, &f)` | Return new doc with all matching elements replaced by `f(el)` |
| `doc.append(node)` | Append a node to the top-level element list |
| `doc.prepend(node)` | Prepend a node to the top-level element list |
| `doc.to_cx` | Serialize the document back to a CX string |
| `doc.to_xml` / `to_json` / `to_yaml` / `to_toml` / `to_md` | Convert to another format |

**`Element` methods:**

| Method | Description |
|---|---|
| `el.name` | Element name (`String`) |
| `el.attr(name)` | Attribute value by name; typed (`Integer`, `Float`, `true`/`false`, `nil`, `String`) |
| `el.attrs` | All attributes as `Array<Attr>` |
| `el.children` | Direct child `Element`s (excludes text/scalar nodes) |
| `el.get(name)` | First direct child `Element` with the given name |
| `el.get_all(name)` | All direct child `Element`s with the given name |
| `el.at(path)` | Navigate by slash-separated relative path |
| `el.find_all(name)` | All descendant `Element`s with the given name |
| `el.find_first(name)` | First descendant `Element` with the given name |
| `el.text` | Concatenated text content of child `TextNode`s and `ScalarNode`s |
| `el.scalar` | Value of the first `ScalarNode` child, or `nil` |
| `el.set_attr(name, value, type = nil)` | Add or update an attribute |
| `el.remove_attr(name)` | Remove an attribute by name |
| `el.append(node)` | Append a child node |
| `el.prepend(node)` | Prepend a child node |
| `el.insert(index, node)` | Insert a child node at a position |
| `el.remove(node)` | Remove a child node by object identity |
| `el.remove_at(index)` | Remove child node at a given index (no-op if out of bounds) |
| `el.remove_child(name)` | Remove all direct child `Element`s with the given name |
| `el.select(expr)` | First descendant matching a CXPath expression |
| `el.select_all(expr)` | All descendants matching a CXPath expression |
| `el.to_cx` | Serialize this element (and its subtree) to CX |

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
| `[contains(@k, 'v')]` | Attribute contains substring |
| `[starts-with(@k, 'v')]` | Attribute starts with prefix |

Attribute values auto-type: `true`/`false` → `TrueClass`/`FalseClass`, integers
→ `Integer`, decimals → `Float`, everything else → `String`. An invalid
expression raises `ArgumentError`.

**Node constructors:**

```ruby
CXLib::Element.new('name', attrs: [...], items: [...])
CXLib::Attr.new('name', value, data_type = nil)   # data_type: 'int', 'float', 'bool', 'null'
CXLib::TextNode.new('some text')
CXLib::ScalarNode.new('int', 42)
CXLib::Comment.new('comment text')
```

### Stream

| Method | Description |
|---|---|
| `CXLib.stream(cx_str)` | Return `Array<StreamEvent>` for the CX input |
| `ev.type` | Event type: `'StartDoc'`, `'EndDoc'`, `'StartElement'`, `'EndElement'`, `'Text'`, `'Scalar'`, `'Comment'`, `'PI'`, `'EntityRef'`, `'RawText'`, `'Alias'` |
| `ev.name` | Element name (set for `StartElement` and `EndElement`) |
| `ev.attrs` | `Array<Attr>` with typed values (set for `StartElement`) |
| `ev.value` | Text or scalar value (set for `Text`, `Scalar`, `EntityRef`, `Alias`, `RawText`) |
| `ev.data_type` | Type hint string, e.g. `'int'`, `'bool'` (set for `Scalar`) |
| `ev.start_element?(name = nil)` | Returns `true` if this is a `StartElement` event, optionally matching `name` |
| `ev.end_element?(name = nil)` | Returns `true` if this is an `EndElement` event, optionally matching `name` |
| `CXLib.version` | Return the `libcx` version string |

### `data_bin` one-shot conversions (v3.4)

Direct format ↔ binary AST conversions, skipping the text-CX
intermediate. Useful when a tool already produces CX-binary payloads
(or wants to consume them) and the text form would only add a
parse/emit roundtrip.

| Method | Description |
|---|---|
| `CXLib.xml_to_data_bin(s)`  | XML text → CXDB v1 framed bytes (`String`) |
| `CXLib.json_to_data_bin(s)` | JSON text → CXDB v1 framed bytes |
| `CXLib.yaml_to_data_bin(s)` | YAML text → CXDB v1 framed bytes |
| `CXLib.toml_to_data_bin(s)` | TOML text → CXDB v1 framed bytes |
| `CXLib.md_to_data_bin(s)`   | Markdown text → CXDB v1 framed bytes |
| `CXLib.data_bin_to_xml(b)`  | CXDB v1 framed bytes → XML `String` |
| `CXLib.data_bin_to_json(b)` | CXDB v1 framed bytes → JSON `String` |
| `CXLib.data_bin_to_yaml(b)` | CXDB v1 framed bytes → YAML `String` |
| `CXLib.data_bin_to_toml(b)` | CXDB v1 framed bytes → TOML `String` |
| `CXLib.data_bin_to_md(b)`   | CXDB v1 framed bytes → Markdown `String` |

The framed bytes are CX Data Binary v1 — see `spec/data_bin.md` for
the wire format. Round-trip: `CXLib.data_bin_to_x(CXLib.x_to_data_bin(s))
== s` (after canonicalization).

## 30-second quickstart

<!-- quickstart-begin: ruby -->
```ruby
require 'cxlib'

# Parse + read a typed value out
doc = CXLib.parse('[server [port :u16 8080] [host localhost]]')
puts doc.at('server/port').int_value   # 8080

# Round-trip to JSON, lossless
puts CXLib.to_json('[user [id :i64 9007199254740993]]')

# Public Table API (ADR 0018) — 17-member surface
src = <<~CX
  [users :table[name age:int]
    alice 30
    bob   25
  ]
CX
t = CXLib::Table.from_cx(src)
puts "#{t.row_count} #{t.cols}"   # 2 ["name", "age"]
t.each do |row|
  puts "#{row['name']} #{row['age']}"
end
puts t.to_csv
```
<!-- quickstart-end -->
