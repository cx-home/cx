# CX Table API

**Status:** Current

The `Table` API every binding (V native, Python, Go, Rust)
exposes when `loads` encounters a `:table` block. The API is
consistent across all bindings within unavoidable host-language naming
differences.

`:table` is a CX text construct (per
[`core/grammar.ebnf`](../formal/grammar.ebnf)) and a binary container
(per [`core/data-bin.md §3.10`](../core/data-bin.md)). It represents
row-oriented typed tabular data with declared column kinds. Every
binding's `loads` returns a `Table` instance — not a list of dicts —
when the source contains a `:table` block.

Cell values may be CXDM Items (Array, Map, Sequence-as-Item per
[`core/cxdm.md`](../core/cxdm.md)). `to_cx` emits collection-typed
cells using their canonical CX literal forms; `to_json` follows the
JSON projection rules of
[`core/conversions.md`](../core/conversions.md); `to_csv` /
`to_tsv` / `to_psv` emit collection cells as JSON-encoded strings.
`to_data_bin` carries collection-typed cells through the chunked-table
encoding per [`core/data-bin.md §3.10–§3.11`](../core/data-bin.md).

---

## 1 — Goals

- **Consistent API.** Same conceptual operations available in every
  binding (columns, rows, types, iteration).
- **Idiomatic naming.** snake_case for V / Python / Rust;
  PascalCase methods for Go.
- **Immutability.** `Table` instances are immutable values, like
  `Document`. Construction returns a new `Table`; modification
  returns a new `Table`.
- **Representation transparency** (AMENDED, stream 17 L91/L86 — the
  former "Column-oriented memory. Column-major internal layout" claim
  was false of the shipped row-major boxed representation and a
  normative internal-layout claim cannot stand): observable semantics —
  results, canonical bytes, addresses, error codes — MUST be identical
  whichever internal layout executes; the layout itself is
  quality-of-implementation (`runtime_representation.md` §2). Row maps
  are constructed on demand for iteration either way; a column-major
  in-core layout is the I5 engine work, not a spec guarantee.
- **Adapter ecosystem.** Bindings with a natural data-frame target
  (Python → pandas/polars, Rust → polars, Go → arrow-go) expose
  adapters as opt-in methods.

---

## 2 — Conceptual model

A `Table` is:

- **`cols`** — ordered sequence of column names (strings).
- **`types`** — ordered sequence of column kinds (one per column).
- **`row_count`** — number of rows.
- **`col_count`** — `== len(cols)`.
- **`rows`** — sequence of rows; each row is an ordered map from
  column name to value.

Column kinds use the CX type system per
[`core/cxdm.md §2.3`](../core/cxdm.md): `:int`, `:float`, `:string`,
`:bool`, `:date`, `:datetime`, `:bytes`, `:decimal`, `:atom`, plus
storage-precision refinements (`:f16`, `:f32`, `:i8`..`:i64`,
`:u8`..`:u64`, `:duration`, `:instant`, `:bigint`) and `nullable`
wrappers per [`core/data-bin.md §3.10.5`](../core/data-bin.md).

---

## 3 — Per-binding API surface

Methods/properties listed by their canonical names. Each binding
adapts to host idiom (see §4).

### 3.1 Properties

| Canonical | Type | Description |
|---|---|---|
| `cols` | `string[]` | Ordered column names |
| `types` | `Type[]` | Ordered column kinds (host representation) |
| `row_count` | `int` | Number of rows |
| `col_count` | `int` | Number of columns |

### 3.2 Access methods

| Canonical | Returns | Description |
|---|---|---|
| `row(i)` | ordered map | Row `i` as an ordered map. Raises out-of-bounds |
| `column(name)` | typed sequence | All values in the named column, in row order |
| `col_at(i)` | typed sequence | Same as `column` but by index |
| `cell(row, col)` | scalar | Single value; `col` may be name or index |
| `slice(start, end)` | `Table` | Rows in `[start, end)` as a new `Table` |
| `head(n)` | `Table` | First `n` rows |
| `tail(n)` | `Table` | Last `n` rows |
| `select(names)` | `Table` | New `Table` with only the named columns, in given order |

### 3.3 Iteration

Tables are iterable over rows using each host's idiom:
`for row in t:` (V, Python), `t.iter()` (Rust), `t.Iter()` (Go).
Each yielded row is an ordered map.

A separate iterator yields columns: `t.iter_cols()` returns
`(name, values)` tuples.

### 3.4 Construction

```
Table(cols: string[], types: Type[], rows: 2D-iterable | Map[])
```

Construction validates:

- `len(cols) == len(types)`.
- All column names are unique.
- Every row has exactly `col_count` values.
- Each cell's host type matches the declared column kind (or is the
  null sentinel for nullable columns).

Validation failures raise the binding's standard error type.

### 3.5 Conversion

| Canonical | Returns | Description |
|---|---|---|
| `to_cx()` | string | Canonical CX text (the `:table` block form) |
| `to_csv(delimiter)` | string | Canonical CSV (or TSV/PSV) per [`core/conversions.md`](../core/conversions.md) |
| `to_json()` | string | List of objects (semantic JSON projection per [`core/conversions.md`](../core/conversions.md)) |
| `to_data_bin()` | bytes | `cx_to_data_bin` of just this table |
| `to_dict_list()` | list-of-maps | Each row as a separate ordered map; eager copy |

Adapter methods (per binding; opt-in):

| Adapter | Bindings that ship it |
|---|---|
| `to_pandas()` | Python |
| `to_polars()` | Python, Rust |
| `to_arrow()` | Python (`pyarrow`), Rust (`arrow-rs`), Go (`arrow-go`) |
| `to_dataframe()` | Convenience picking the binding's primary frame target |

Adapter methods are not part of the conformance contract (Arrow may
not be installed; pandas is heavyweight). They are documented per
binding where present.

### 3.6 Equality

Two tables compare equal iff: same cols, same types, same row count,
and each cell compares equal under host equality. Strict-canonical
equality (per [`core/canonical.md`](../core/canonical.md)) compares
the canonical-form bytes, which is the primitive used by `cxlib.eq`.

---

## 4 — Per-binding naming

| Canonical | V | Python | Go | Rust |
|---|---|---|---|---|
| `cols` | `cols` | `cols` | `Cols()` | `cols()` |
| `types` | `types` | `types` | `Types()` | `types()` |
| `row_count` | `row_count` | `row_count` | `RowCount()` | `row_count()` |
| `col_count` | `col_count` | `col_count` | `ColCount()` | `col_count()` |
| `row(i)` | `row(i)` | `row(i)` | `Row(i)` | `row(i)` |
| `column(name)` | `column(name)` | `column(name)` | `Column(name)` | `column(name)` |
| `cell(r, c)` | `cell(r, c)` | `cell(r, c)` | `Cell(r, c)` | `cell(r, c)` |
| `slice(s, e)` | `slice(s, e)` | `slice(s, e)` | `Slice(s, e)` | `slice(s, e)` |
| `head(n)` | `head(n)` | `head(n)` | `Head(n)` | `head(n)` |
| `tail(n)` | `tail(n)` | `tail(n)` | `Tail(n)` | `tail(n)` |
| `select(ns)` | `select(ns)` | `select(*names)` | `Select(names...)` | `select(&[..])` |
| iter (rows) | `for row in t` | `for row in t` | `t.Iter()` | `t.iter()` |
| `iter_cols` | `iter_cols()` | `iter_cols()` | `IterCols()` | `iter_cols()` |
| `to_cx` | `to_cx()` | `to_cx()` | `ToCX()` | `to_cx()` |
| `to_csv` | `to_csv(d)` | `to_csv(delim=',')` | `ToCSV(d)` | `to_csv(d)` |
| `to_data_bin` | `to_data_bin()` | `to_data_bin()` | `ToDataBin()` | `to_data_bin()` |
| `to_dict_list` | `to_maps()` | `to_dict_list()` | `ToMaps()` | `to_maps()` |

Naming follows host conventions deliberately. The conformance suite
asserts behavior, not naming.

---

## 5 — Construction examples

### 5.1 Python

```python
from cxlib import Table, types

t = Table(
    cols=['name', 'age', 'active'],
    types=[types.STRING, types.INT, types.BOOL],
    rows=[
        ['alice', 30, True],
        ['bob', 25, False],
    ],
)
print(t.to_cx())
```

### 5.2 V (native)

```v
import cx.cxlib as cx

t := cx.Table.new(
    cols: ['name', 'age', 'active']
    types: [cx.t_string, cx.t_int, cx.t_bool]
    rows: [
        ['alice', 30, true]
        ['bob', 25, false]
    ]
) or { panic(err) }
println(t.to_cx())
```

### 5.3 Rust

```rust
use cxlib::{Table, Type, Value};

let t = Table::new(
    vec!["name".to_string(), "age".to_string(), "active".to_string()],
    vec![Type::String, Type::Int, Type::Bool],
    vec![
        vec![Value::String("alice".into()), Value::Int(30), Value::Bool(true)],
        vec![Value::String("bob".into()), Value::Int(25), Value::Bool(false)],
    ],
)?;
println!("{}", t.to_cx()?);
```

### 5.4 Go

```go
import "github.com/cxformat/cxlib"

t, err := cxlib.NewTable(
    []string{"name", "age", "active"},
    []cxlib.Type{cxlib.String, cxlib.Int, cxlib.Bool},
    [][]any{
        {"alice", int64(30), true},
        {"bob", int64(25), false},
    },
)
if err != nil { panic(err) }
fmt.Println(t.ToCX())
```

---

## 6 — Iteration examples

### 6.1 Python

```python
for row in t:
    print(row['name'], row['age'])

for name, values in t.iter_cols():
    print(name, list(values))
```

### 6.2 V

```v
for row in t {
    println('${row['name']} ${row['age']}')
}

for name, values in t.iter_cols() {
    println('${name}: ${values}')
}
```

### 6.3 Rust

```rust
for row in t.iter() {
    println!("{} {}", row["name"], row["age"]);
}

for (name, values) in t.iter_cols() {
    println!("{}: {:?}", name, values);
}
```

### 6.4 Go

```go
for row := range t.Iter() {
    fmt.Println(row["name"], row["age"])
}

for col := range t.IterCols() {
    fmt.Println(col.Name, col.Values)
}
```

---

## 7 — Adapter examples

```python
df = t.to_pandas()    # returns pandas.DataFrame; dtypes derived from t.types
```

```rust
let df = t.to_polars()?;       // polars::DataFrame
let batch = t.to_arrow()?;     // arrow::array::RecordBatch
```

```go
batch := t.ToArrow()           // *array.Record
```

Adapter implementations follow [`misc/type-mapping.md`](type-mapping.md):

- CX `:int` family maps to Arrow `Int8/16/32/64`.
- `:date` → Arrow `Date32` (days since epoch).
- `:datetime` → Arrow `Timestamp(Nanoseconds, UTC)` for strict
  canonical or with offset for lossless.
- `:duration` → Arrow `Duration(Nanoseconds)`.
- `:instant` → Arrow `Timestamp(Nanoseconds, UTC)`.
- `:decimal` → Arrow `Decimal128` / `Decimal256` based on coefficient
  magnitude.
- Bit-packed bool columns map directly to Arrow `BooleanArray`.

The conformance suite includes an opt-in round-trip:
`CX → Table → Arrow → Table → CX` produces byte-identical canonical
CX. CI runs it only where Arrow is present.

---

## 8 — Performance expectations

### 8.1 Memory

(AMENDED, stream 17 W6 — L91/L86: the former "column-oriented
internally / ~32 MB" claim was false of the shipped bindings, whose
`Table` holds row-major boxed cells — e.g. the Python binding's
`rows: list[list[Any]]` — and a normative internal-layout claim
cannot stand.) In-memory `Table` layout is quality-of-implementation
(`runtime_representation.md` §2): a binding MAY store columns
(typed, compact) or rows (boxed); observable semantics MUST be
identical either way. What IS guaranteed compact is the **wire**: the
CXCol §3.10.3 typed column payloads carry no per-cell tags, bools
bit-pack (§3.10.4), repetitive/atom columns dictionary-encode
(§3.10.2) — so a 1M-row × 4-column numeric table rides as ~32 MB of
column bytes regardless of how either endpoint's `Table` stores it in
memory.

### 8.2 Latency

Per [`core/abi.md §4`](../core/abi.md), `cx_to_data_bin` for a 100 MB
tabular input completes in under 3 seconds. `Table` materialization in
the host adds typically <50% overhead over the raw data_bin time. The
binary format is column-major with typed payloads (data-bin §3.10.3):
fixed-width numeric columns are contiguous and can be bulk-copied (or
aliased) per column; variable-length columns (string / bytes / decimal
/ bigint / atom), bit-packed bool, dictionary (§3.10.2) and nullable
(§3.10.5) payloads decode per cell — "one allocation per column" holds
for the fixed-width lanes only.

### 8.3 Iteration cost

Iterating rows constructs an ordered map per row. Cost is `O(c)` per
row where `c` is column count. Bindings needing higher throughput
should use `iter_cols` and zip externally to avoid per-row
allocation.

---

## 9 — Conformance fixtures

Per [`misc/parity-matrix.md`](parity-matrix.md):

```
conformance/table/
  001-basic-3x3/
    input.cx                       the source :table block
    expected.canonical.cx          canonical text form
    expected.canonical.json        JSON projection
    expected.data.bin              CXCol strict canonical bytes
    expected.csv                   CSV projection
    expected.tsv                   TSV projection
    expected.row_iteration.json    sequence of maps in iteration order
    expected.column_iteration.json sequence of (name, values) pairs
  002-empty-table/ ...
  003-with-nullable-column/ ...
  004-with-dict-encoded-column/ ...
  005-mixed-types/ ...
  006-arrow-roundtrip/             (opt-in)
  007-large-1m-rows/               (perf SLA, opt-in)
```

---

## 10 — Open questions

Deferred to future minor revisions:

- **Mutation API.** `Table.with_row(...)`, `Table.with_column(...)`
  returning a new `Table`. Useful but not blocking.
- **Column-typed scan.** ~~Deferred to a query API alongside CXPath
  enhancements.~~ **Delivered in-language (#404):** a `:table`-bearing
  element atomizes to its row sequence — one ordered map per row, the
  same row shape as §2 — so `[?for [in $r $t] [where …] [yield …]]`
  is the scan surface and `$t[*, "name"]` / `$t[2, *]` / label ranges
  are the projection surface (see [`core/code.md`](../core/code.md)
  §6.6 D22/D13 and §7 "Table sources"). CXPath deliberately does not
  navigate into rows. A *bindings-side* scan API remains out of scope
  (hosts use the `to_*` adapters).
- **Sort, group, join.** Out of scope for the bindings API; bindings
  users wanting analytical operations should convert to their host
  data-frame library via the `to_*` adapters. (In-language, `[?for]`
  `[order-by]` / `[group-by]` over the row sequence covers sort/group —
  `core/code.md` §7.)
- **Streaming table reads / writes.** `Table` is a materialised value;
  very large tables use the handle-based streaming-table API
  (`cx_table_reader_*` / `cx_table_writer_*`) per
  [`core/abi.md §2.10`](../core/abi.md), which pulls/pushes one row
  group at a time with bounded memory. The streaming events API
  ([`core/abi.md §2.8`](../core/abi.md)) is the document-level
  alternative for mixed table-and-element documents. A future minor
  may add an idiomatic per-binding `iter_table_rows` wrapper over the
  C ABI handle.
