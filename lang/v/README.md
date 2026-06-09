# CX — V

The V binding has two implementations under this directory. They expose the
same public API and produce identical results; they differ in how they reach
the V core.

## V users

Install the pure V package — no C dependency required:

```sh
v install --git https://github.com/cx-home/cx-v
```

See [cx-home/cx-v](https://github.com/cx-home/cx-v) for the full API and docs.

---

## Two implementations

### `lang/v/native/` — native binding (default)

Imports the V core (`vcx/cx/` + `vcx/code/`) directly. No FFI on hot paths.
This is the **default** import path for V users; the fastest variant on the
V VM. Compile with `VFLAGS="-path @vlib|@vmodules|<repo>/vcx" v run ...` so
the V resolver finds the `cx` + `code` modules under `vcx/`.

```v
import native as cx      // lang/v/native exposes the Layer-1 surface
doc := cx.parse(src)!
```

### `lang/_archived/v-cffi/` — C ABI wrapper (archived)

Wraps `libcx` via the V `C.cx_*` extern declarations. Identical FFI surface
to the other 9 bindings (Python, Go, Rust, etc.). Useful for users who want a
small binary (no V runtime) and don't need the absolute lowest latency.

Also serves as the **internal C-ABI test layer** for CI: every other binding
links the same `libcx`, and `lang/v/cffi/` can verify libcx output against
the known-correct native implementation. This is the authoritative
integration test for the shared library.

```v
import cffi              // explicit opt-in to the FFI wrapper
result := cffi.to_json(src)!
```

The two implementations run the same conformance fixtures and must produce
byte-identical canonical-form output (per `spec/governance.md` §4.4).

## Implementation strategy

| Public API | Native (`lang/v/native/`) | CFFI (`lang/v/cffi/`) |
|---|---|---|
| `parse(s)` | `cx.parse(s)` direct | `cx_to_ast_bin → decode` |
| `loads(s)` | direct AST walk → `json2.Any` | `cx_to_data_bin → decode` |
| `dumps(v)` | direct → CX text via emitter | `encode → cx_from_data_bin` |
| `Document.to_xml()` | `cx.emit_xml(doc)` direct | builder → `cx_ast_bin_to_xml` |
| `select(s, expr)` | `cx.cxpath_select(...)` direct | `cx_select` |
| `Stream` | `cx.stream(...)` direct, lazy | `cx_events_open / next / close` |
| `Table` | `cx.Table` directly | binary decode of `cx_to_data_bin` table tag |

Per `spec/governance.md` §1, neither implementation roundtrips through
sibling format converters and re-parses string output. The CFFI variant uses
binary AST and binary data formats for all hot paths.

## Requirements

- V 0.5 or later (`v --version` to check).
- For CFFI: `libcx` built — run `make build-vcx` from the repo root.
- For native: `lang/v/cx/` populated (synced from `vcx/cx/` via the build).

## Running the tests

```sh
make test-v
```

This runs the conformance suite against both implementations and asserts
byte-identical canonical output for every fixture.

## Examples

```sh
v run lang/v/examples/demo.v
v run lang/v/examples/transform.v
```

## 30-second quickstart

<!-- quickstart-begin: v -->
```v
import cffi

fn main() {
    // Parse + read a typed value out
    doc := cffi.parse('[server [port :u16 8080] [host localhost]]') or { panic(err) }
    println(doc.at('server/port').int_value())   // 8080

    // Round-trip to JSON, lossless
    out := cffi.to_json('[user [id :i64 9007199254740993]]') or { panic(err) }
    println(out)

    // Public Table API — 17-member surface
    src := '[users :table[name age:int]
      alice 30
      bob   25
    ]'
    t := cffi.table_from_cx(src) or { panic(err) }
    println('${t.row_count()} ${t.cols()}')   // 2 [name, age]
    for row in t.iter_rows() {
        println('${row["name"]} ${row["age"]}')
    }
    println(t.to_csv(`,`) or { '' })
}
```
<!-- quickstart-end -->
