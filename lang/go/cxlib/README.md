# CX — Go

Go binding for the CX format library via CGo. Parses, streams, queries, and
transforms CX documents; converts between CX, XML, JSON, YAML, and TOML
via `libcx`.

## Canonical-form tooling (v3.4)

Four convenience functions for canonical text, hashing, and equality:

```go
src1 := "[config\n  [; comment]\n  [server host=localhost]\n]"
src2 := "[config [server host=localhost]]"
cxlib.Fmt(src1)        // lossless canonical — preserves the comment
cxlib.Canonical(src1)  // strict canonical   — comment stripped
cxlib.Hash(src1)       // 64-char SHA-256 hex of strict canonical bytes
cxlib.Eq(src1, src2)   // true — data-equivalent inputs
```

`Fmt` is idempotent. `Canonical`/`Hash`/`Eq` are byte-stable across
runs and bindings; the same input produces the same hash in any
language. Use for content-addressable hashing or signed config bundles.

## Requirements

- Go 1.21+
- CGo enabled (default)
- A C compiler (clang or gcc)
- `libcx` built (see Install)

## Install / Build

Build `libcx` first, then compile the Go package:

```sh
# 1. Build the native library (from the repo root)
make build-vcx

# 2. Build the Go package
cd lang/go/cxlib
go build ./...
```

This produces `vcx/target/libcx.dylib` (macOS) or `vcx/target/libcx.so`
(Linux). The Go package's `cgo` directives point at that path automatically via
`-Wl,-rpath`, so no extra environment variables are needed.

## Quick Start

> **Required:** call `runtime.LockOSThread()` at the top of `main` before any
> cxlib call. libcx's GC panics if invoked from an unknown OS thread, and Go's
> scheduler moves goroutines between threads.

### Document Model

Parse a CX string into a `*Document`, query and mutate the tree, then
serialize back to CX.

```go
package main

import (
	"fmt"
	"runtime"

	cx "github.com/cx-home/cx/lang/go"
)

const cxStr = `[config version='1.0' debug=false
  [server host=localhost port=8080]
  [database url='postgres://localhost/mydb' pool=10]
  [cache enabled=true ttl=300]
]`

func main() {
	runtime.LockOSThread() // required: libcx GC must run on a consistent OS thread

	// 1. Parse
	doc, err := cx.Parse(cxStr)
	if err != nil {
		panic(err)
	}

	// 2. Read: get the server element and print attributes
	server := doc.At("config/server")
	fmt.Printf("server.host = %v\n", server.Attr("host"))
	fmt.Printf("server.port = %v\n", server.Attr("port"))

	// 3. Update: change host to prod address
	server.SetAttr("host", "prod.example.com", "")
	fmt.Printf("updated host = %v\n", server.Attr("host"))

	// 4. Create: append a timeout element with a text child
	timeout := &cx.Element{Name: "timeout"}
	timeout.Append(&cx.TextNode{Value: "30"})
	server.Append(timeout)

	// 5. Delete: remove the cache child from config
	config := doc.Root()
	cache := config.Get("cache")
	config.Remove(cache)

	// 6. Print the modified document as CX
	fmt.Println(doc.ToCx())
}
```

Expected output:

```
server.host = localhost
server.port = 8080
updated host = prod.example.com
[config version='1.0' debug=false
  [server host=prod.example.com port=8080
    [timeout '30']
  ]
  [database url=postgres://localhost/mydb pool=10]
]
```

### Select and transform via CX code

Selection and transformation use the unified **CX code** language
([`spec/code.md`](../../../spec/code.md)) — CXPath `//path`
value-literals for selection, `[?for]` comprehensions for
pattern-generators and projection. Common shapes:

| CXPath shape                         | Notes |
|--------------------------------------|------------------------|
| `//user`                             | All `user` elements |
| `//user[@active=true]`               | Attribute filter |
| `//service[@port>=8000]`             | Numeric predicate |
| `//user[2]`                          | Position predicate |
| transform `//service` → modify       | `[?for $s :in //service :yield (update-attr $s "active" true)]` |

```go
package main

import (
	"fmt"

	cxlib "github.com/cx-home/cx/lang/go"
)

const fleet = `[fleet
  [svc name=auth :status up]
  [svc name=web  :status up]
  [svc name=db   :status down]
]`

func main() {
	// Find every service via a CXPath path value.
	out, err := cxlib.EvalCode(fleet, `//svc`, "text")
	if err != nil {
		panic(err)
	}
	fmt.Println(out)
	// [svc name=auth :status up]
	// [svc name=web :status up]
	// [svc name=db :status down]
}
```

See [`spec/code.md`](../../../spec/code.md) for the language
reference, and `code_eval_test.go` / `conformance_code_test.go`
in this package for the test surface.

### Streaming

Use `Stream` for a one-pass pull of all events without building a tree.

```go
package main

import (
	"fmt"
	"runtime"

	cx "github.com/cx-home/cx/lang/go"
)

const cxStr = `[config version='1.0' debug=false
  [server host=localhost port=8080]
  [database url='postgres://localhost/mydb' pool=10]
  [cache enabled=true ttl=300]
]`

func main() {
	runtime.LockOSThread()

	events, err := cx.Stream(cxStr)
	if err != nil {
		panic(err)
	}
	for _, e := range events {
		fmt.Printf("type=%s", e.Type)
		if e.Type == "StartElement" {
			fmt.Printf(" name=%s", e.Name)
			for _, a := range e.Attrs {
				fmt.Printf(" %s=%v", a.Name, a.Value)
			}
		}
		fmt.Println()
	}
}
```

Expected output:

```
type=StartDoc
type=StartElement name=config version=1.0 debug=false
type=StartElement name=server host=localhost port=8080
type=EndElement
type=StartElement name=database url=postgres://localhost/mydb pool=10
type=EndElement
type=StartElement name=cache enabled=true ttl=300
type=EndElement
type=EndElement
type=EndDoc
```

### CX code: query / transform / template

CX code is CX's templating + query language — a CX program is itself a `.cx` file (same parser, same data model). `cxlib.EvalCXL(context, program, outputTarget)` runs the program against the context document. `outputTarget` is `""` (default), `"text"`, `"cx"`, or `"html"`.

```go
ctx  := "[fleet [svc name=auth +up] [svc name=web +up] [svc name=db]]"
// Each service: name + status
prog := "[?for s :in //svc :return [?= s/@name]: [?if [s/@up, ok, down]]; ]"

out, err := cxlib.EvalCXL(ctx, prog, "")
if err != nil { log.Fatal(err) }
fmt.Println(out)
// auth: ok;web: ok;db: down;
```

See [docs/CX code.md](../../../docs/CX code.md) for the full language reference (XQuery-equivalent feature set: `?for`, `?if`, `?let`, predicates, filters, output shaping).

## Run the Demo

The demos above can be placed in a standalone module that uses a `replace`
directive to point at the local source:

```sh
# go.mod
module cxdemo

go 1.21

require github.com/cx-home/cx/lang/go v0.0.0

replace github.com/cx-home/cx/lang/go => /path/to/cx/lang/go/cxlib
```

Then run it:

```sh
go run main.go
```

To run the built-in transform example from the repo:

```sh
cd lang/go/cxlib
go run ./examples/transform/
```

## API Reference

### Conversion (CX string in, string out)

| Function | Input | Output |
|---|---|---|
| `ToCx(s)` | CX | canonical CX |
| `ToCxCompact(s)` | CX | compact CX |
| `ToXml(s)` | CX | XML |
| `ToJson(s)` | CX | JSON |
| `ToYaml(s)` | CX | YAML |
| `ToToml(s)` | CX | TOML |
| `XmlToCx(s)` | XML | CX |
| `JsonToCx(s)` | JSON | CX |
| `YamlToCx(s)` | YAML | CX |
| `TomlToCx(s)` | TOML | CX |

All conversion functions return `(string, error)`. Additional cross-format
functions (`XmlToJson`, `YamlToXml`, etc.) follow the same pattern.

### Parse

| Function | Description |
|---|---|
| `Parse(s)` | Parse a CX string into a `*Document` |
| `ParseXml(s)` | Parse an XML string into a `*Document` |
| `ParseJson(s)` | Parse a JSON string into a `*Document` |
| `ParseYaml(s)` | Parse a YAML string into a `*Document` |
| `ParseToml(s)` | Parse a TOML string into a `*Document` |

### Document

| Method | Description |
|---|---|
| `doc.Root()` | Return the first top-level `*Element` |
| `doc.Get(name)` | Return the first top-level element with the given name |
| `doc.At(path)` | Navigate by slash-separated path from the root (e.g. `"config/server"`) |
| `doc.FindFirst(name)` | Return the first descendant element with the given name (depth-first) |
| `doc.FindAll(name)` | Return all descendant elements with the given name |
| `doc.Select(expr)` | Return the first `*Element` matching a CXPath expression, or `(nil, error)` |
| `doc.SelectAll(expr)` | Return all `[]*Element` matching a CXPath expression, or `(nil, error)` |
| `doc.Transform(path, fn)` | Return a new `*Document` with the element at path replaced by `fn(el)` |
| `doc.TransformAll(expr, fn)` | Return a new `*Document` with all matching elements replaced, or `(nil, error)` |
| `doc.Append(n)` | Append a top-level node |
| `doc.Prepend(n)` | Insert a top-level node at position 0 |
| `doc.ToCx()` | Serialize the document back to a CX string |
| `doc.ToXml()` | Serialize to XML via the C library |
| `doc.ToJson()` | Serialize to JSON via the C library |
| `doc.ToYaml()` | Serialize to YAML via the C library |
| `doc.ToToml()` | Serialize to TOML via the C library |

### Element

| Method | Description |
|---|---|
| `el.Get(name)` | Return the first direct child `*Element` by name |
| `el.GetAll(name)` | Return all direct child `*Element`s by name |
| `el.At(path)` | Navigate by slash-separated path from this element |
| `el.Attr(name)` | Return the value of the named attribute (`string \| int64 \| float64 \| bool \| nil`) |
| `el.Text()` | Return the concatenated text and scalar child content |
| `el.Scalar()` | Return the value of the first `ScalarNode` child |
| `el.Children()` | Return all direct child `*Element` nodes |
| `el.FindFirst(name)` | Return the first descendant element with the given name (depth-first) |
| `el.FindAll(name)` | Return all descendant elements with the given name (depth-first) |
| `el.Select(expr)` | Return the first `*Element` matching a CXPath expression, or `(nil, error)` |
| `el.SelectAll(expr)` | Return all `[]*Element` matching a CXPath expression, or `(nil, error)` |
| `el.SetAttr(name, value, dataType)` | Upsert an attribute; pass `""` for `dataType` to infer from value |
| `el.RemoveAttr(name)` | Remove an attribute by name |
| `el.Append(n)` | Append a child node |
| `el.Prepend(n)` | Insert a child node at position 0 |
| `el.Insert(i, n)` | Insert a child node at index `i` |
| `el.Remove(n)` | Remove a child node by pointer identity |
| `el.RemoveAt(i)` | Remove the child node at index `i` (no-op if out of bounds) |
| `el.RemoveChild(name)` | Remove all direct child `*Element`s with the given name |

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

Attribute values auto-type: `true`/`false` → `bool`, integers → `int64`,
decimals → `float64`, everything else → `string`. An invalid expression returns
a non-nil `error`.

### Stream

| Function | Description |
|---|---|
| `Stream(s)` | Return all events for a CX string as `([]StreamEvent, error)` |

`StreamEvent` fields:

| Field | Type | Set for |
|---|---|---|
| `Type` | `string` | all events (`StartDoc`, `EndDoc`, `StartElement`, `EndElement`, `Text`, `Scalar`, `Comment`, `PI`, `EntityRef`, `RawText`, `Alias`) |
| `Name` | `string` | `StartElement`, `EndElement` |
| `Attrs` | `[]Attr` | `StartElement` |
| `Anchor` | `*string` | `StartElement` (when present) |
| `DataType` | `*string` | `StartElement`, `Scalar` (when present) |
| `Value` | `any` | `Text`, `Scalar`, `Comment`, `RawText`, `EntityRef`, `Alias` |
| `Target` | `string` | `PI` |
| `Data` | `*string` | `PI` (when present) |

### `data_bin` one-shot conversions (v3.4)

Direct format ↔ binary AST conversions, skipping the text-CX
intermediate. Useful when a tool already produces CX-binary payloads
(or wants to consume them) and the text form would only add a
parse/emit roundtrip.

| Function | Description |
|---|---|
| `cxlib.XmlToDataBin(s)`  | XML text → CXCol v1 framed bytes |
| `cxlib.JsonToDataBin(s)` | JSON text → CXCol v1 framed bytes |
| `cxlib.YamlToDataBin(s)` | YAML text → CXCol v1 framed bytes |
| `cxlib.TomlToDataBin(s)` | TOML text → CXCol v1 framed bytes |
| `cxlib.DataBinToXml(b)`  | CXCol v1 framed bytes → XML text |
| `cxlib.DataBinToJson(b)` | CXCol v1 framed bytes → JSON text |
| `cxlib.DataBinToYaml(b)` | CXCol v1 framed bytes → YAML text |
| `cxlib.DataBinToToml(b)` | CXCol v1 framed bytes → TOML text |

The framed bytes are CX Data Binary v1 — see `spec/core/data-bin.md` for
the wire format. Round-trip: `DataBinToX(XToDataBin(s)) == s` (after
canonicalization).

## Apache Arrow C-Data interop (v0.6.0+, optional)

Bridges CXCol chunked-tables to Apache Arrow `ArrowArrayStream` via
`libcx_arrow` (`spec/abi.md §2.11`, capability bit `0x800000`). The
bridge handles all 9 v0.6.0 column types (`int`, `i8`, `i16`, `i32`,
`float`, `bool`, `string`, `date`, `bytes`); `datetime` / `decimal` /
dictionary columns are deferred and surface a clear error.

The surface is gated behind a `arrow` build tag so the default
`go build` does not pull in the apache/arrow Go module. Mirrors the
Python `pip install cxlib[arrow]` opt-in:

```sh
# build / test with the arrow tag
go build -tags arrow ./...
go test  -tags arrow ./...
make test-go-arrow         # builds libcx_arrow + runs the suite
```

```go
import (
    "github.com/cx-home/cx/lang/go/cxlib"
    "github.com/apache/arrow/go/v18/arrow"
    "github.com/apache/arrow/go/v18/arrow/array"
    "github.com/apache/arrow/go/v18/arrow/memory"
)

if cxlib.ArrowAvailable() {                       // always true under -tags arrow
    fmt.Printf("0x%x\n", cxlib.ArrowFeatures())   // 0x800000
}

// Forward — CXCol chunked-table → Arrow.
payload, _ := cxlib.ToDataBinChunked(`[points :table[name:string score:int]
  alice 91
  bob 88]`)
reader, _ := cxlib.ArrowExport(payload)           // array.RecordReader
defer reader.Release()
for reader.Next() {
    rec := reader.Record()
    // rec.Column(0).(*array.String), rec.Column(1).(*array.Int64), ...
}

// Inverse — build an Arrow record directly, drain into CXCol bytes.
schema := arrow.NewSchema([]arrow.Field{
    {Name: "name",  Type: arrow.BinaryTypes.String},
    {Name: "score", Type: arrow.PrimitiveTypes.Int64},
}, nil)
bld := array.NewRecordBuilder(memory.NewGoAllocator(), schema)
defer bld.Release()
bld.Field(0).(*array.StringBuilder).AppendValues([]string{"alice", "bob"}, nil)
bld.Field(1).(*array.Int64Builder).AppendValues([]int64{91, 88}, nil)
rec := bld.NewRecord(); defer rec.Release()
rdr, _ := array.NewRecordReader(schema, []arrow.Record{rec}); defer rdr.Release()
out, _ := cxlib.ArrowImportToDataBin(rdr)          // unframed CXCol bytes
```

Functions: `ArrowAvailable()`, `ArrowFeatures()`, `ArrowVersion()`,
`ArrowMergedFeatures()`, `ArrowExport(payload []byte) (array.RecordReader, error)`,
`ArrowImportToDataBin(reader array.RecordReader) ([]byte, error)`.
Naming uses an `Arrow*` prefix on `package cxlib` because a Go
package literally named `arrow` would shadow the apache/arrow
import path.

`ArrowExport` accepts UNFRAMED CXCol bytes — the shape
`ToDataBinChunked` returns. `ArrowImportToDataBin` returns
UNFRAMED bytes. Bytes can be re-decoded with `ArrowExport` or any
other CXCol consumer.

## Tests

```sh
make test-go               # default suite (no arrow dep)
make test-go-arrow         # adds the Arrow C-Data bridge surface
```

## 30-second quickstart

<!-- quickstart-begin: go -->
```go
package main

import (
    "fmt"
    "github.com/cx-home/cx/lang/go/cxlib"
)

func main() {
    // Parse + read a typed value out
    doc, _ := cxlib.Parse(`[server [port :u16 8080] [host localhost]]`)
    fmt.Println(doc.At("server/port").IntValue())   // 8080

    // Round-trip to JSON, lossless
    out, _ := cxlib.ToJson(`[user [id :i64 9007199254740993]]`)
    fmt.Println(out)

    // Public Table API — 17-member surface
    src := `[users :table[name age:int]
  alice 30
  bob   25
]`
    t, _ := cxlib.TableFromCx(src)
    fmt.Println(t.RowCount(), t.Cols())   // 2 [name age]
    for _, row := range t.Rows() {
        fmt.Println(row["name"], row["age"])
    }
    csv, _ := t.ToCsv(',')
    fmt.Print(csv)
}
```
<!-- quickstart-end -->
