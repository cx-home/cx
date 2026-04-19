# CX

CX is a bracket-based document and configuration format that unifies markup and
structured data in one coherent syntax. It reads like XML, types like YAML, and
converts losslessly to and from JSON, YAML, TOML, and XML.

```cx
[article lang=en
  [-author note: written 2026-04-19]
  [head
    [title Getting Started with CX]
    [tags :string[] tutorial beginner]
  ]
  [body
    [h1 What is CX?]
    [p CX is [em compact] and [strong human-friendly].]
    [pre [# [server [host localhost] [port :int 8080]] #]]
  ]
]
```

---

## Contents

- [Install](#install)
- [CLI](#cli)
- [Syntax](#syntax)
  - [Elements](#elements)
  - [Attributes](#attributes)
  - [Text and quoting](#text-and-quoting)
  - [Comments](#comments)
  - [Scalars and auto-typing](#scalars-and-auto-typing)
  - [Explicit type annotations](#explicit-type-annotations)
  - [Typed arrays](#typed-arrays)
  - [Mixed content](#mixed-content)
  - [Raw text blocks](#raw-text-blocks)
  - [Entity and character references](#entity-and-character-references)
  - [Anchors, merges, and aliases](#anchors-merges-and-aliases)
  - [Processing instructions](#processing-instructions)
  - [Multi-document streams](#multi-document-streams)
- [Corner cases](#corner-cases)
- [Format conversion](#format-conversion)
- [Language bindings](#language-bindings)
- [Building from source](#building-from-source)

---

## Install

**Prerequisites:** Rust toolchain (`cargo`). No other dependencies.

```sh
git clone https://github.com/your-org/cx
cd cx
make build
```

This builds the `cx` CLI binary at `rust/target/release/cx` and the shared
library `libcx.dylib` / `libcx.so`.

Add the binary to your PATH:

```sh
export PATH="$PATH:$(pwd)/rust/target/release"
```

---

## CLI

```
cx [--from cx|xml|json|yaml|toml] [--cx|--xml|--ast|--json|--yaml|--toml] [file]
```

Input format is auto-detected from the file extension (`.cx`, `.xml`, `.json`,
`.yaml`, `.yml`, `.toml`) or overridden with `--from`. Default output is `--cx`.

```sh
cx file.cx                    # CX → CX  (canonical round-trip)
cx --json file.cx             # CX → semantic JSON
cx --yaml file.cx             # CX → YAML
cx --toml file.cx             # CX → TOML
cx --xml  file.cx             # CX → XML
cx --ast  file.cx             # CX → full AST as JSON (for tooling)

cx --from xml  file.xml       # XML  → CX
cx --from json file.json      # JSON → CX
cx --from yaml file.yaml      # YAML → CX
cx --from toml file.toml      # TOML → CX

cat file.cx | cx --json       # read from stdin
```

---

## Syntax

Every construct in CX is a bracket pair `[...]`. There are no closing tags to
repeat, no mandatory quoting, and no indentation rules.

### Elements

```cx
[br]                          # empty element
[p Hello]                     # element with text
[p Hello World]               # multi-word text (whitespace normalized)
[div
  [p First]
  [p Second]
]                             # nested elements
```

XML equivalent:
```xml
<br/>
<p>Hello</p>
<p>Hello World</p>
<div>
  <p>First</p>
  <p>Second</p>
</div>
```

A document can have **multiple root elements** — no wrapper element required:

```cx
[title Hello]
[body
  [p World]
]
```

### Attributes

Attributes use `name=value` with no surrounding quotes needed for most values.
`[`, `]`, `=`, `'`, `"`, and whitespace terminate an unquoted value.

```cx
[input type=text name=q placeholder='Search...']
[a href=https://example.com/path?id=1 Visit us]
[img src=/images/logo.png alt='Company logo' width=120 height=40]
```

XML equivalent:
```xml
<input type="text" name="q" placeholder="Search..."/>
<a href="https://example.com/path?id=1">Visit us</a>
<img src="/images/logo.png" alt="Company logo" width="120" height="40"/>
```

> **Note:** URL characters including `/`, `?`, `#`, `@`, `:`, `+`, and `&` are
> all valid in unquoted attribute values. `href=https://example.com/a?b=1&c=2`
> works without quotes.

> **Note:** Attribute values are **always stored as strings** in the AST.
> Auto-typing does not apply to attributes. `port=8080` stores the string `"8080"`,
> not an integer. Use child elements for typed values: `[port :int 8080]`.

### Text and quoting

Unquoted text is whitespace-normalized: consecutive spaces and newlines collapse
to a single space. Use single quotes to preserve whitespace exactly:

```cx
[p   extra   spaces   ]       # stored as "extra spaces" (normalized)
[pre '  indented  ']          # stored as "  indented  " (preserved)
[p 'first line\nsecond line'] # \n escape inside quotes
```

Quotes are required when a value would otherwise be auto-typed (see below):

```cx
[status 'true']               # string "true",  not bool true
[version '3.0']               # string "3.0",   not float 3.0
[zip :string 90210]           # explicit :string type annotation also works
```

### Comments

Comments use the `[-` opener:

```cx
[-this is a comment]

[config
  [-database settings]
  [host localhost]
  [port :int 5432]
]
```

XML equivalent: `<!--this is a comment-->` / `<!--database settings-->`

Comments are preserved in the AST and round-trip through all formats. JSON
(which has no comment syntax) discards them during conversion.

### Scalars and auto-typing

When an element body is a **single unquoted token** with **no child elements**,
the value is auto-typed:

| Pattern | Type | Example |
|---|---|---|
| Digits only | `int` | `[age 30]` |
| `0x` prefix | `int` (hex) | `[flags 0xFF]` → 255 |
| Digits with `.` or `e` | `float` | `[price 3.14]`, `[scale 1e-3]` |
| `true` or `false` | `bool` | `[debug true]` |
| `null` | `null` | `[value null]` |
| `YYYY-MM-DD` | `date` | `[born 2026-04-19]` |
| ISO 8601 datetime | `datetime` | `[created 2026-04-19T14:30:00Z]` |
| Anything else | `Text` | `[name Alice]`, `[msg hello world]` |

```cx
[server
  [host localhost]              # Text "localhost"
  [port 8080]                   # int 8080
  [ratio 0.75]                  # float 0.75
  [debug false]                 # bool false
  [secret null]                 # null
  [launched 2026-04-19]        # date
  [updated 2026-04-19T09:00:00Z] # datetime
]
```

Auto-typing fires **only** on a single bare token. Multiple tokens or any child
element suppress it:

```cx
[p Version 3.0]               # Text "Version 3.0" — two tokens, no typing
[p 3.0]                       # float 3.0 — single token
[root 42 [x]]                 # Text "42 " — has a child element, no typing
```

### Explicit type annotations

Use `:type` after the element name to override auto-typing or force a specific
type. This is the `ElementMeta` position — before any attributes or body:

```cx
[port :int 8080]              # explicitly int (same as auto here)
[zip :string 90210]           # force string — without :string this would be int
[ratio :float 1]              # force float — without :float this would be int
[payload :bytes SGVsbG8=]     # base64-encoded bytes
[count :int -1]               # negative int
```

In XML output, explicit annotations appear as `cx:type`:

```xml
<port cx:type="int">8080</port>
<zip cx:type="string">90210</zip>
```

### Typed arrays

`:type[]` turns the element body into a sequence of items of that type:

```cx
[tags :string[] admin user guest]
[scores :int[] 10 20 30]
[primes :int[] 2 3 5 7 11]
[origins :string[] https://example.com https://app.example.com]
```

In JSON / YAML / TOML output:

```json
{"tags": ["admin", "user", "guest"], "scores": [10, 20, 30]}
```

In XML output, each item becomes an `<item>` element:

```xml
<tags cx:type="string[]"><item>admin</item><item>user</item><item>guest</item></tags>
```

### Mixed content

Text and child elements can be freely interleaved — like HTML prose:

```cx
[p
  For help, visit our [a href=https://example.com/faq FAQ page]
  or [a href=mailto:support@example.com contact us].
]

[p The result is [code x + y] where [em x] and [em y] are integers.]
```

XML equivalent:
```xml
<p>
  For help, visit our <a href="https://example.com/faq">FAQ page</a>
  or <a href="mailto:support@example.com">contact us</a>.
</p>
```

In the AST, each text run and element is a separate node. Auto-typing is
**suppressed** in mixed-content bodies — all bare tokens are `Text`, never
`Scalar`, regardless of their value:

```cx
[p The answer is 42 and it is true]
#                  ^^ Text, not int
#                           ^^^^ Text, not bool
```

### Raw text blocks

`[# ... #]` contains raw text where brackets are not parsed — equivalent to
XML CDATA sections:

```cx
[script [# if (x < y) { return [1, 2]; } #]]
[css    [# .nav > a[href^="https"] { color: blue; } #]]
[pre    [# [server [host localhost]] #]]
```

XML equivalent:
```xml
<script><![CDATA[ if (x < y) { return [1, 2]; } ]]></script>
```

The terminator is `#]`. A bare `]` is allowed inside raw text. To embed a
literal `#]` you must split it across two adjacent raw blocks.

### Entity and character references

Standard XML entity references require a semicolon:

```cx
[p Copyright &copy; 2026 &mdash; all rights reserved.]
[p Use &amp; for ampersands and &lt; for less-than signs.]
[p Predefined: &amp; &lt; &gt; &apos; &quot;]
```

The five predefined XML entities (`amp`, `lt`, `gt`, `apos`, `quot`) are
resolved to their characters in the semantic JSON output. Others (like `&copy;`,
`&mdash;`) are preserved as `EntityRef` nodes and passed through.

Character references are always resolved to Unicode:

```cx
[p &#169; 2026]               # © 2026
[p &#x1F600;]                 # 😀
[p &#8212; em dash]           # — em dash
```

> **Anchor vs EntityRef disambiguation:** `&name` without a semicolon is an
> _anchor definition_ (Extended). `&name;` with a semicolon is an _entity
> reference_ (Core). The parser uses semicolon lookahead to disambiguate.

### Anchors, merges, and aliases

Anchors name an element for later reuse. Merges inherit another element's
attributes. Useful for DRY configuration:

```cx
[-define shared defaults with &anchor]
[defaults &base timeout=30 retries=3 log_level=info ssl=false]

[-each environment merges base and overrides only what changes]
[dev     *base host=localhost         port=8080 debug=true]
[staging *base host=staging.acme.com  port=443  ssl=true]
[prod    *base host=acme.com          port=443  ssl=true  retries=5]
```

An **alias element** `[*name]` is a full stand-in for the anchored element:

```cx
[defaults &def timeout=30 retries=3]
[service1 *def host=svc1.internal]
[*def]                        # alias — expands to the full defaults element
```

Canonical meta order is: anchor `&` → merge `*` → type `:` → attributes.
Parsers accept any order; emitters produce canonical order.

In XML output:
```xml
<defaults cx:anchor="base" timeout="30" retries="3" log_level="info" ssl="false"/>
<dev cx:merge="base" host="localhost" port="8080" debug="true"/>
```

### Processing instructions

```cx
[?xml version=1.0 encoding=UTF-8]    # XML declaration (must be first)
[?cx include=base.cx]                 # CX directive
[?php echo $greeting; ]              # arbitrary PI
```

XML equivalent: `<?xml version="1.0" encoding="UTF-8"?>` / `<?php echo $greeting; ?>`

`[?xml ...]` and `[?cx ...]` are structured (parsed as key=value pairs).
All other `[?target data]` PIs store their data as a raw string.

### Multi-document streams

Separate documents with `---` on its own line:

```cx
[config
  [env production]
  [port :int 443]
]
---
[secrets
  [db_password :string 's3cr3t']
  [api_key :string abc123]
]
```

The CLI and all language bindings return a `Multi` result for multi-doc files.
YAML is the other common format that supports multi-document streams.

---

## Corner cases

### Auto-typing is single-token only

```cx
[n 42]                        # int 42
[n 42.0]                      # float 42.0
[n 42 items]                  # Text "42 items" — two tokens
[n -1]                        # int -1  (minus sign attached to digit)
[n - 1]                       # Text "- 1" — space separates minus from digit
```

### Quoting to prevent auto-typing

```cx
[active true]                 # bool true
[active 'true']               # Text "true" — quoted suppresses auto-typing
[version 3.0]                 # float 3.0
[version '3.0']               # Text "3.0"
[port 8080]                   # int 8080
[port :string 8080]           # Text "8080" — explicit :string annotation
```

### Attribute values are always strings

Auto-typing never applies to attribute values. They are always `Text` in the AST:

```cx
[server port=8080]            # attr "port" = string "8080"
[server port='8080']          # identical — quoting is redundant here
```

For a typed value use child element form:
```cx
[server [port :int 8080]]     # child element with int scalar
```

### Whitespace normalization

Unquoted body text collapses whitespace. Quoted text preserves it:

```cx
[p hello    world]            # stored as "hello world" (one space)
[p 'hello    world']          # stored as "hello    world" (preserved)
[p
  first line
  second line
]                             # stored as "first line second line"
```

### Whitespace in mixed content needs quoting

When text adjacent to child elements has significant leading or trailing spaces,
quote it:

```cx
[p [b bold] text after]       # "text after" — no leading space captured
[p [b bold] ' text after']    # " text after" — leading space preserved
[p 'before ' [b bold] after]  # "before " then bold then "after"
```

The CX emitter automatically adds quotes when a text run would lose whitespace
on round-trip.

### Mixed content suppresses scalar auto-typing

Any child element in the body suppresses auto-typing for all bare tokens:

```cx
[root 42 [x]]                 # "42 " is Text, not int — child element present
[root 42]                     # int 42 — no child elements
[root :int 42 [x]]            # explicit annotation still forces int scalar
```

### Hex integer normalization

Hex literals are stored as their decimal integer value:

```cx
[mask 0xFF]                   # stored as int 255
[offset 0x1A3F]               # stored as int 6719
```

Round-tripping through CX emits decimal: `[mask 255]`.

### `&` disambiguation: anchor vs entity ref

Inside element meta position (no semicolon) → anchor definition:
```cx
[node &myanchor attr=val]     # defines anchor named "myanchor"
```

Inside body or attribute (with semicolon) → entity reference:
```cx
[p Tom &amp; Jerry]           # EntityRef "amp"
[p &copy; 2026]               # EntityRef "copy"
```

### Raw text terminator

`#]` terminates a raw text block. A single `]` is safe inside:

```cx
[p [# arrays use ] notation #]]   # OK — bare ] is fine
[p [# end: #]]                    # OK — terminates at #]
```

To include a literal `#]` sequence, split into two adjacent raw blocks:
```cx
[p [# first part: #][# ] rest #]]  # produces: first part: #] rest
```

### Multi-document `---` separator

`---` must not appear as content inside an element — it is only meaningful at
the top level between documents. Inside a body it is text:

```cx
[p ---]                       # Text "---" inside an element, not a separator
---
[next-doc]                    # this IS a separator — top-level between docs
```

### Entity refs need whitespace separation in body text

An `&name;` sequence is only parsed as an entity reference when separated from
surrounding text by whitespace. Without whitespace it is treated as plain text:

```cx
[p Tom &amp; Jerry]          # EntityRef "amp" — spaces around &amp;
[p a&amp;b]                  # Text "a&amp;b"  — no spaces, treated as bare text
```

This means URLs containing `&` work unquoted in both attribute and body
positions — no quoting needed:

```cx
[a href=https://example.com/search?q=hello&lang=en Click]   # attribute — fine
[p Visit https://example.com/search?q=hello&lang=en today.] # body — also fine
```

The `&lang=en` segment is never mistaken for an entity ref because there is no
whitespace before `&`.

---

## Format conversion

CX converts losslessly between CX, XML, JSON, YAML, and TOML.

### All five formats from one source

```sh
cx --cx   examples/config.cx   # canonical CX
cx --xml  examples/config.cx   # XML with cx: namespace for type metadata
cx --json examples/config.cx   # semantic JSON (collapsed data values)
cx --yaml examples/config.cx   # YAML
cx --toml examples/config.cx   # TOML
```

### Reading any format as CX

```sh
cx --from xml  examples/books.xml
cx --from json examples/config.json
cx --from yaml examples/config.yaml
cx --from toml examples/config.toml
```

### JSON output — semantic vs AST

`--json` emits **semantic JSON**: collapsed data values as plain JSON, useful
for data pipelines.

`--ast` emits the **full AST** as JSON: every node type, attribute, and scalar
preserved, useful for tooling and debugging.

```sh
cx --json examples/config.cx   # {"server": {"host": "localhost", "port": 8080, ...}}
cx --ast  examples/config.cx   # {"type":"Document","elements":[{"type":"Element",...}]}
```

### Semantic JSON rules

| CX construct | JSON output |
|---|---|
| `[port :int 8080]` | `"port": 8080` (native int) |
| `[debug false]` | `"debug": false` (native bool) |
| `[name Alice]` | `"name": "Alice"` (string) |
| `[value null]` | `"value": null` |
| `[tags :string[] a b c]` | `"tags": ["a", "b", "c"]` |
| `[book ...]` repeated | `"book": [{...}, {...}]` (auto-array) |
| `[p text [em bold] more]` | `"p": {"_": "text  more", "em": "bold"}` |
| `[-comment]` | _(discarded)_ |

Repeated elements with the same name automatically collect into a JSON array:

```cx
[library
  [book [title Dune] [year :int 1965]]
  [book [title Neuromancer] [year :int 1984]]
]
```
```json
{"library": {"book": [{"title": "Dune", "year": 1965}, {"title": "Neuromancer", "year": 1984}]}}
```

### XML round-trip

CX uses the `cx:` namespace to preserve CX-specific metadata in XML output:

```xml
<!-- cx:type preserves scalar type annotations -->
<port cx:type="int">8080</port>
<tags cx:type="string[]"><item>admin</item><item>user</item></tags>

<!-- cx:anchor and cx:merge preserve anchor/merge relationships -->
<defaults cx:anchor="base" timeout="30" retries="3"/>
<dev cx:merge="base" host="localhost" port="8080"/>
```

---

## Language bindings

All language bindings wrap the same Rust implementation via the C ABI
(`libcx.dylib` / `libcx.so`). Every binding exposes the same 30 functions
covering all 5×5 input/output format combinations.

### Python

**Requires:** `libcx` built (`make build`). No pip packages needed.

```python
import sys
sys.path.insert(0, 'python')
import cxlib

# CX input
result = cxlib.to_json('[server [host localhost] [port :int 8080]]')
print(result)
# {"server": {"host": "localhost", "port": 8080}}

# XML input
cx_src = cxlib.xml_to_cx('<server><host>localhost</host></server>')

# JSON input
cx_src = cxlib.json_to_cx('{"server": {"host": "localhost"}}')

# YAML input
cx_src = cxlib.yaml_to_cx('server:\n  host: localhost')

# TOML input
cx_src = cxlib.toml_to_cx('[server]\nhost = "localhost"')

# Any of 5 inputs × 5 outputs
cxlib.yaml_to_toml(yaml_src)   # YAML → TOML
cxlib.toml_to_xml(toml_src)    # TOML → XML
cxlib.xml_to_yaml(xml_src)     # XML  → YAML
```

Errors raise `RuntimeError` with the parser message:

```python
try:
    cxlib.to_json('[unclosed')
except RuntimeError as e:
    print(e)   # 1:9: unexpected end of input
```

Run the full example:
```sh
python python/examples/transform.py
```

### V

**Requires:** V 0.5.1+, `libcx` built (`make build`).

```v
import cxlib

fn main() {
    result := cxlib.to_json('[server [host localhost] [port :int 8080]]') or {
        eprintln(err)
        return
    }
    println(result)
    // {"server": {"host": "localhost", "port": 8080}}

    cx_src := cxlib.yaml_to_cx('server:\n  host: localhost') or { panic(err) }
    println(cx_src)
}
```

All functions return `!string` — use `or { ... }` for error handling.

Run the full example:
```sh
cd vlang && v run examples/transform.v
```

---

## Building from source

```sh
# Build CLI binary + shared library
make build

# Run conformance tests
make test

# Install shared library and header to dist/
make dist
```

After `make dist`:
```
dist/
  lib/libcx.dylib     # (or libcx.so on Linux)
  include/cx.h        # C header with all 30 function declarations
```

### C ABI

The shared library exposes 30 `#[no_mangle]` functions — all 5 input formats ×
5 output formats, plus `cx_free`:

```c
#include "cx.h"

char* result = cx_to_json("[port :int 8080]", NULL);
// result → "{\"port\": 8080}"
cx_free(result);

// with error handling
char* err = NULL;
char* out = cx_yaml_to_toml(yaml_src, &err);
if (!out) {
    fprintf(stderr, "error: %s\n", err);
    cx_free(err);
}
```

All returned strings are heap-allocated and must be released with `cx_free()`.

### Conformance tests

The conformance suite lives in `conformance/` and covers:
- `core.txt` — documents, elements, comments, raw text, entity refs, PIs, DTD
- `extended.txt` — scalars, type annotations, arrays, anchors, merges, multi-doc
- `xml.txt` — XML input parsing round-trips

```sh
cd rust && cargo test
```
