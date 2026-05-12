# CX Table API Specification
# Version: 1.1
# Date: 2026-05-11

This document specifies the `Table` API that every CX binding exposes
when `loads` encounters a `:table` block. The API is consistent across
all 10 bindings to within unavoidable host-language naming and idiom
differences.

### What's new in v1.1 (2026-05-11)

Per :

- **Cell values may be CXDM v1.1 collection-literal Items** (Array,
 Map, Sequence-as-Item per `spec/cxdm.md §2.4–§2.6`). The 17-member
 API surface is unchanged; only the cell value type space expands.
- **`to_cx()`** emits collection-typed cells using their canonical CX
 literal forms per [`spec/canonical.md §2.11`](canonical.md) /
 (`[a, b, c]`, `{k: v}`, `(a, b, c)`).
- **`to_json()`** emits collection-typed cells per
 [`spec/conversions.md §2.2`](conversions.md): Array → JSON array,
 Map → JSON object (keys coerced to strings, lex-sorted), Sequence
 → JSON array (post-flatten).
- **`to_csv()` / `to_tsv()` / `to_psv()`** emit collection cells as
 JSON-encoded strings per [`spec/conversions.md §8.4`](conversions.md)
 / D7 amendment.
- **`to_data_bin()`** carries collection-typed cells through the
 chunked-table encoding without lossy serialization; the cell's
 data_bin tag space accommodates the new container kinds via the
 ast_bin v6 / CXDB v1.1 alignment (per `spec/data_bin.md` future
 amendment).
- **** (slot reserved) will ratify this API as a public
 v0.6.0 deliverable within ~2 weeks of ratification.

`:table` is a CX text construct (see `spec/grammar.ebnf`) and a binary
container (see `spec/data_bin.md` §3.10). It represents row-oriented
typed tabular data with declared column types. Every binding's `loads`
returns a `Table` instance — not a list of dicts — when the source
contains a `:table` block.

---

## 1 — Goals

- **Consistent API**: same conceptual operations available in every
 binding (columns, rows, types, iteration).
- **Idiomatic naming**: snake_case for Python / Ruby; camelCase for
 JavaScript / TypeScript; PascalCase for C# methods; lowercase for V /
 Go where idiomatic.
- **Immutability**: `Table` instances are immutable values, like
 `Document`. Construction is via `cxlib.Table(cols=..., types=...,
 rows=...)`; modification returns a new `Table`.
- **Optimal memory**: column-oriented internal layout where the host
 language allows; row dicts are constructed on demand for iteration.
- **Adapter ecosystem**: bindings that have a natural data-frame target
 (Python → pandas/polars, Rust → polars, Go → arrow-go, TS → Arrow JS)
 expose adapters as opt-in methods.

---

## 2 — Conceptual model

A `Table` is:

- **`cols`** — ordered sequence of column names (strings). Renamed
 from `columns` in v3.4 (Phase 7.46) to match the V core's
 `TableData.cols` field; the shorter form reads better in the
 common access patterns (`t.cols.len`, `t.cols[0]`) and pairs
 symmetrically with `rows`.
- **`types`** — ordered sequence of column types (one per column).
- **`row_count`** — number of rows.
- **`col_count`** — `== len(cols)`.
- **`rows`** — sequence of rows; each row is an ordered map from
 column name to value.

Column types use the CX type system: `:int`, `:float`, `:string`,
`:bool`, `:date`, `:datetime`, `:bytes`, `:decimal`, `:f16`, `:f32`,
`:i8`..`:i64`, `:u8`..`:u64`, plus `nullable` wrappers (per
`spec/data_bin.md` §3.10.5).

---

## 3 — Per-binding API surface

Methods/properties listed by their canonical names. Each binding adapts
the names to host idiom (see §4).

### 3.1 Properties

| Canonical | Type | Description |
|---|---|---|
| `cols` | `string[]` | Ordered column names. |
| `types` | `Type[]` | Ordered column types (host representation). |
| `row_count` | `int` | Number of rows. |
| `col_count` | `int` | Number of columns. |

### 3.2 Access methods

| Canonical | Returns | Description |
|---|---|---|
| `row(i)` | ordered map | Row `i` as an ordered map (column name → value). Raises out-of-bounds. |
| `column(name)` | typed sequence | All values in the named column, in row order. |
| `col_at(i)` | typed sequence | Same as `column` but by column index. |
| `cell(row, col)` | scalar | Single value. `col` may be name or index. |
| `slice(start, end)` | `Table` | Rows in `[start, end)` as a new `Table`. |
| `head(n)` | `Table` | First `n` rows. |
| `tail(n)` | `Table` | Last `n` rows. |
| `select(names)` | `Table` | New `Table` with only the named columns, in given order. |

### 3.3 Iteration

Tables are iterable over rows. The exact iteration protocol uses each
host's idiom: `for row in t:` (Python, Ruby, V), `for (row of t)`
(JS/TS), `t.iter()` (Rust), `t.range()` (Go), `for (row : t)` (Java),
etc. Each yielded row is an ordered map.

A separate iterator yields columns: `t.iter_cols()` returns
`(name, values)` tuples.

### 3.4 Construction

```
Table(cols: string[], types: Type[], rows: 2D-iterable | Map[])
```

Construction validates that:

- `len(cols) == len(types)`.
- All column names are unique.
- Every row has exactly `col_count` values.
- Each cell's host type matches the declared column type (or is the
 null sentinel for nullable columns).

Validation failures raise the binding's standard error type.

### 3.5 Conversion

| Canonical | Returns | Description |
|---|---|---|
| `to_cx()` | string | Canonical CX text (the `:table` block form). |
| `to_csv(delimiter)` | string | Canonical CSV (or TSV/PSV). |
| `to_json()` | string | List of objects (semantic JSON projection). |
| `to_data_bin()` | bytes | `cx_to_data_bin` of just this table. |
| `to_dict_list()` | list-of-maps | Each row as a separate ordered map; eager copy. |

Adapter methods (per binding; opt-in):

| Adapter | Bindings that ship it |
|---|---|
| `to_pandas()` | Python |
| `to_polars()` | Python, Rust |
| `to_arrow()` | Python (`pyarrow`), Rust (`arrow-rs`), Go (`arrow-go`), TS (`apache-arrow`), Java (`arrow-java`) |
| `to_dataframe()` | Convenience that picks the binding's primary frame target |

The adapter methods are not part of the conformance contract (Arrow may
not be installed; pandas is heavyweight). They are documented per binding
where present.

### 3.6 Equality

Two tables compare equal iff: same cols, same types, same row count,
and each cell compares equal under host equality. Strict-canonical
equality (per `spec/canonical.md`) compares the canonical-form bytes,
which is the primitive used by `cxlib.eq`.

---

## 4 — Per-binding naming

| Canonical | V | Python | Go | Rust | TS/JS | Java | Kotlin | C# | Swift | Ruby |
|---|---|---|---|---|---|---|---|---|---|---|
| `cols` | `cols` | `cols` | `Cols()` | `cols()` | `cols` | `getCols()` | `cols` (val) | `Cols` | `cols` | `cols` |
| `types` | `types` | `types` | `Types()` | `types()` | `types` | `getTypes()` | `types` | `Types` | `types` | `types` |
| `row_count` | `row_count` | `row_count` | `RowCount()` | `row_count()` | `rowCount` | `getRowCount()` | `rowCount` | `RowCount` | `rowCount` | `row_count` |
| `col_count` | `col_count` | `col_count` | `ColCount()` | `col_count()` | `colCount` | `getColCount()` | `colCount` | `ColCount` | `colCount` | `col_count` |
| `row(i)` | `row(i)` | `row(i)` | `Row(i)` | `row(i)` | `row(i)` | `row(int)` | `row(i)` | `Row(i)` | `row(at:)` | `row(i)` |
| `column(name)` | `column(name)` | `column(name)` | `Column(name)` | `column(name)` | `column(name)` | `column(String)` | `column(name)` | `Column(name)` | `column(_:)` | `column(name)` |
| `cell(r, c)` | `cell(r, c)` | `cell(r, c)` | `Cell(r, c)` | `cell(r, c)` | `cell(r, c)` | `cell(int, ...)` | `cell(r, c)` | `Cell(r, c)` | `cell(_:_:)` | `cell(r, c)` |
| `slice(s, e)` | `slice(s, e)` | `slice(s, e)` | `Slice(s, e)` | `slice(s, e)` | `slice(s, e)` | `slice(int, int)` | `slice(s, e)` | `Slice(s, e)` | `slice(_:_:)` | `slice(s, e)` |
| `head(n)` | `head(n)` | `head(n)` | `Head(n)` | `head(n)` | `head(n)` | `head(int)` | `head(n)` | `Head(n)` | `head(_:)` | `head(n)` |
| `tail(n)` | `tail(n)` | `tail(n)` | `Tail(n)` | `tail(n)` | `tail(n)` | `tail(int)` | `tail(n)` | `Tail(n)` | `tail(_:)` | `tail(n)` |
| `select(ns)` | `select(ns)` | `select(*names)` | `Select(names...)` | `select(&[..])` | `select(...)` | `select(String...)` | `select(vararg)` | `Select(params)` | `select(_:)` | `select(*names)` |
| `iter`(rows) | `for row in t` | `iter(t)` / `for row in t` | `t.Iter()` (yields chan) | `t.iter()` | `t[Symbol.iterator]` | `t.iterator()` | `t.iterator()` | `t.GetEnumerator()` | `t.makeIterator()` | `t.each` |
| `iter_cols` | `iter_cols()` | `iter_cols()` | `IterCols()` | `iter_cols()` | `iterCols()` | `iterCols()` | `iterCols()` | `IterCols()` | `iterCols()` | `each_col` |
| `to_cx` | `to_cx()` | `to_cx()` | `ToCX()` | `to_cx()` | `toCx()` | `toCx()` | `toCx()` | `ToCx()` | `toCx()` | `to_cx` |
| `to_csv` | `to_csv(d)` | `to_csv(delim=',')` | `ToCSV(d)` | `to_csv(d)` | `toCsv(d)` | `toCsv(char)` | `toCsv(d)` | `ToCsv(d)` | `toCsv(_:)` | `to_csv(d)` |
| `to_data_bin` | `to_data_bin()` | `to_data_bin()` | `ToDataBin()` | `to_data_bin()` | `toDataBin()` | `toDataBin()` | `toDataBin()` | `ToDataBin()` | `toDataBin()` | `to_data_bin` |
| `to_dict_list` | `to_maps()` | `to_dict_list()` | `ToMaps()` | `to_maps()` | `toDictList()` | `toMapList()` | `toMapList()` | `ToDictList()` | `toMapList()` | `to_a` |

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

### 5.2 V (native binding)

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

### 5.5 TypeScript

```typescript
import { Table, Type } from 'cxlib';

const t = new Table({
 cols: ['name', 'age', 'active'],
 types: [Type.String, Type.Int, Type.Bool],
 rows: [
 ['alice', 30, true],
 ['bob', 25, false],
 ],
});
console.log(t.toCx());
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

### 6.5 TypeScript

```typescript
for (const row of t) {
 console.log(row.name, row.age);
}

for (const [name, values] of t.iterCols()) {
 console.log(name, values);
}
```

---

## 7 — Adapter examples

### 7.1 Python → pandas

```python
df = t.to_pandas() # returns pandas.DataFrame with dtypes derived from t.types
```

### 7.2 Rust → polars

```rust
let df = t.to_polars()?; // returns polars::DataFrame
```

### 7.3 Multi-binding → Arrow

```python
batch = t.to_arrow() # pyarrow.RecordBatch
```

```rust
let batch = t.to_arrow()?; // arrow::array::RecordBatch
```

```go
batch := t.ToArrow() // *array.Record
```

```typescript
const batch = t.toApacheArrow(); // apache-arrow.RecordBatch
```

Adapter implementations:

- Map CX `:int` family to Arrow's `Int8/16/32/64` types per
 `spec/type_mapping.md`.
- Map `:date` to Arrow `Date32` (days since epoch).
- Map `:datetime` to Arrow `Timestamp(Nanoseconds, UTC)` for strict
 canonical or with offset for lossless.
- Map `:decimal` to Arrow `Decimal128` / `Decimal256` based on coefficient
 magnitude.
- Bit-packed bool columns map directly to Arrow's `BooleanArray`.

The conformance suite includes a `:table` round-trip test:
`CX → Table → Arrow → Table → CX` produces byte-identical canonical CX.
This is opt-in (CI only runs it where Arrow is present).

---

## 8 — Performance expectations

### 8.1 Memory

`Table` storage is column-oriented internally. For a 1M-row × 4-column
typed table:

- Naive list-of-dicts: ~150 MB (host pointers + per-row dicts).
- `cxlib.Table`: ~32 MB (4 typed columns × 8 bytes/value × 1M).
- 4-5× compactness; ~10× when columns include bit-packed bools or
 dict-encoded categoricals.

### 8.2 Latency

Per `spec/abi.md` §4, `cx_to_data_bin` for a 100 MB tabular input
should complete in under 3 seconds. `Table` materialization in the host
language adds typically <50% overhead over the raw data_bin time, since
the binary format is column-major and the host can copy or alias each
column with one allocation.

### 8.3 Iteration cost

Iterating rows constructs an ordered map per row. Cost is `O(c)` per row
where `c` is column count. Bindings that need higher throughput should
use `iter_cols` and zip externally, which avoids per-row allocation.

---

## 9 — Conformance fixtures

Per the parity matrix (`spec/architecture.md` §Conformance):

```
conformance/table/
 001-basic-3x3/
 input.cx the source :table block
 expected.canonical.cx canonical text form
 expected.canonical.json JSON projection
 expected.data.bin CXDB v1 strict canonical bytes
 expected.csv CSV projection
 expected.tsv TSV projection
 expected.row_iteration.json sequence of dicts in iteration order
 expected.column_iteration.json sequence of (name, values) pairs
 002-empty-table/ ...
 003-with-nullable-column/ ...
 004-with-dict-encoded-column/ ...
 005-mixed-types/ ...
 006-arrow-roundtrip/ (opt-in)
 007-large-1m-rows/ (perf SLA test, opt-in)
```

---

## 10 — Open questions

The following are deferred to future minor revisions:

- **Mutation API**: `Table.with_row(...)`, `Table.with_column(...)`
 returning a new `Table`. Useful but not blocking. Defer.
- **Column-typed scan** (analogous to SQL `SELECT WHERE`): defer to a
 query API that may be added alongside CXPath enhancements.
- **Sort, group, join**: out of scope. Bindings users wanting analytical
 operations should convert to their host's data-frame library via
 the `to_*` adapters.
- **Streaming table reads**: `Table` is a value; very large tables use
 the `cx_events_*` streaming API instead. Future minor may add
 `iter_table_rows` that streams without materializing.
