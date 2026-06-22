# `cx-stdlib/csv` — CSV / TSV parse and emit

```cx
[module-meta name=csv tier=A status=current
  [standard ref='RFC 4180' title='CSV']]
```

**Status:** Current

Normative reference for the `cx-stdlib/csv` sub-package.

---

## §1. Scope

`cx-stdlib/csv` provides RFC 4180 + Excel-pragmatic CSV/TSV parsing and emission. The module round-trips between strings and **sequences of record rows** in CXDM — a row is a CXDM **map** (header form) or **array** (positional / headerless). Dialect handling covers delimiter, quote, escape, and line-terminator.

Distinct from [`spec/core/conversions.md §8`](../core/conversions.md) (the cross-format CLI / Document-level conversion path) — this module is the in-program library form.

## §2. Conceptual model

### §2.1. Rows as records

A CSV row maps to a CXDM map (with header) or positional array (headerless). Never a synthesized element — this mirrors [`cx-stdlib/json`](json.md): data records map to CXDM maps/arrays, not elements.

With header — each row parses to a map whose keys are the header strings **verbatim**:

```cx
{"email": "alice@example.com",
 "first_name": "Alice",
 "score": "87"}
```

Any string is a valid map key, so header names are used verbatim — no normalization. CXDM maps are insertion-ordered. All cell values are strings; type coercion is opt-in via `parse-with-schema`.

Without header — each row parses to a positional array:

```cx
["alice@example.com", "Alice", "Smith", "87"]
```

### §2.2. Dialect

A dialect is an element describing tokenization rules:

```cx
[dialect
  [delimiter ","]
  [quote-char "\""]
  [escape "double"]            ; "double" (RFC 4180) | "backslash"
  [line-terminator "auto"]     ; "auto" | "crlf" | "lf"
  [header true]
  [skip-empty-lines true]
  [trim-whitespace false]
  [on-error "raise"]]           ; "raise" (default) | "collect"
```

**Validity.** A dialect element supplied to `parse-with-dialect` / `emit-with-dialect` MUST be validatable into a complete dialect: the resolved dialect requires `delimiter`, `quote-char`, `escape`, and `line-terminator`. A fully-specified element supplies them directly; a name reference (`[dialect [name "tsv"]]`) inherits them from the named built-in; any field absent from both the element and the resolved built-in inherits the `csv` defaults shown above. The resolved `delimiter` MUST be a single character — the empty string and any multi-character string are invalid. An element that resolves to a missing required field, or to an invalid `delimiter`, is rejected with `CXER1502 E_CSV_DIALECT_INVALID`. Validation runs identically and completely before any parsing or emission work begins.

Built-in dialects via `[$csv:dialects-builtin]`:

| Dialect | delimiter | quote | escape | line-terminator | header | description |
|---|---|---|---|---|---|---|
| `csv` (default) | `,` | `"` | `double` | `auto` | `true` | RFC 4180 |
| `tsv` | `\t` | `"` | `double` | `auto` | `true` | Tab-separated |
| `psv` | `\|` | `"` | `double` | `auto` | `true` | Pipe-separated |
| `excel` | `,` | `"` | `double` | `crlf` | `true` | Excel default |
| `excel-tab` | `\t` | `"` | `double` | `crlf` | `true` | Excel TSV |
| `unix` | `,` | `"` | `double` | `lf` | `true` | Unix CSV |
| `headless` | `,` | `"` | `double` | `auto` | `false` | RFC 4180 without header |

## §3. Public function surface

### §3.1. Parsing

```
[?def parse              scope=public pure [returns [sequence any]] ($s::string) ...]
[?def parse-with-dialect scope=public pure [returns [sequence any]] ($s::string $dialect::element) ...]
[?def parse-with-schema  scope=public pure [returns [sequence any]] ($s::string $schema::map) ...]
```

- `parse` — default dialect (`csv`, with header). Returns `[sequence map]` keyed by header strings; cell values are strings. Empty input → empty sequence. Strict mode raises `CXER1500 E_CSV_MALFORMED` with row+column diagnostics.
- `parse-with-dialect` — dialect element may name a built-in (`[dialect [name "tsv"]]`) or be fully-specified; missing fields inherit `csv` defaults. Shape follows `header`: with header → `[sequence map]`; without → `[sequence array]`.
- `parse-with-schema` — `schema` maps column-name → type atom (`:int` / `:float` / `:bool` / `:string` / `:date` / `:datetime`). Cells in the schema are coerced; absent columns stay strings. Coercion failure raises `CXER1504 E_CSV_COERCION_FAILED` (strict) or is collected (lenient). Types are never auto-inferred without a schema.

CSV is never auto-typed — leading-zero IDs, ZIP codes, and ambiguous dates make inference a footgun.

The `[returns [sequence any]]` clause covers both cases since the element shape depends on `header`.

**Lenient mode.** A dialect `[on-error "collect"]` (default `"raise"`) returns a `[csv-result …]` element instead of raising:

```cx
[csv-result
  [rows [sequence …]]
  [errors [sequence
    [error row=12 message="unterminated quoted field"]
    [error row=40 message="score: cannot coerce \"n/a\" to :int"]]]]
```

### §3.2. Emitting

```
[?def emit              scope=public pure [returns string] ($rows::[sequence any]) ...]
[?def emit-with-dialect scope=public pure [returns string] ($rows::[sequence any] $dialect::element) ...]
```

For map rows the column set is the **union of all rows' keys, in first-seen order**; a row missing a column emits empty string (heterogeneous rows are not an error). For array rows columns are positional; ragged arrays pad to the longest row. Cells containing the delimiter, quote, or newline are quoted-and-escaped per RFC 4180.

Pin column set/order via `[columns [sequence …]]` inside the dialect element. Listed-only keys are emitted; unlisted keys are dropped.

### §3.3. Built-in dialects

```
[?def dialects-builtin scope=public pure [returns map] () ...]
```

Returns the seven built-in dialects keyed by name:

```cx
[?let [= $dialects [$csv:dialects-builtin]]
      [= $tsv-dialect $dialects/tsv]
  [$csv:parse-with-dialect $bytes $tsv-dialect]]
```

## §4. Edge cases

- **Quoting** — fields containing the delimiter, quote, or newline MUST be quoted on emit. Doubled-quote escape is the default (`"He said ""hi"""`); backslash escape is opt-in via `escape: "backslash"`.
- **Line terminators** — `"auto"` accepts CRLF/LF/CR on input and emits LF; `"crlf"` and `"lf"` are strict. Trailing newline optional on input; always present on output.
- **Whitespace** — preserved by default in unquoted fields. `trim-whitespace: true` strips. Quoted fields are never trimmed.
- **Empty lines and rows** — `skip-empty-lines: true` (default) ignores blank lines; a row of only delimiters is non-empty with empty cells.
- **Unicode** — UTF-8 throughout. BOM at input start is silently consumed; output never emits BOM.
- **Header names verbatim** — `"First Name"` becomes the map key `"First Name"`; no normalization.
- **Type coercion** — strings by default; typed cells opt-in via `parse-with-schema`. Coercion failure raises `CXER1504` (strict) or is collected (lenient).

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1500` | `E_CSV_MALFORMED` | `parse` / `parse-with-dialect` on unparseable input (strict mode) |
| `CXER1501` | — | Reserved for future CSV encoding-class error (e.g. invalid UTF-8) |
| `CXER1502` | `E_CSV_DIALECT_INVALID` | `parse-with-dialect` / `emit-with-dialect` when the supplied dialect resolves to a missing required field (`delimiter`, `quote-char`, `escape`, `line-terminator`) or to an invalid `delimiter` (empty string, or more than one character) — see §2.2 *Validity*. Validation runs identically before any parse or emit work. |
| `CXER1503` | `E_CSV_FIELD_COUNT_MISMATCH` | row has different field count than header |
| `CXER1504` | `E_CSV_COERCION_FAILED` | `parse-with-schema` cell coercion failure (strict mode) |

Under `[on-error "collect"]`, `CXER1500` / `CXER1504` are collected into the `[csv-result]` error list instead of raised.

## §6. Conformance fixtures

Under `conformance/stdlib/csv.cxd`:

- RFC 4180 §2 round-trip across 10 example shapes.
- With-header round-trip: `parse` of headered input yields `[sequence map]` keyed by header strings.
- Headerless round-trip: `header:false` yields `[sequence array]` of positional cells.
- Quoted fields with delimiter, newline, and doubled-quote / backslash-quote escape.
- TSV / PSV / Excel-CRLF dialect parsing.
- Header verbatim: `"First Name"` and `"e-mail"` survive as exact map keys.
- Union-of-keys emit: heterogeneous map rows infer columns first-seen-union; missing columns emit empty cell.
- Ragged headerless arrays pad to longest row.
- Pinned `[columns [sequence …]]` uses exact column set/order.
- Schema-typed parse coerces `:int` / `:float` / `:bool` / `:date`; uncoercible raises `CXER1504` (strict) or collects (lenient).
- Strict raises `CXER1500`; `[on-error "collect"]` yields `[csv-result [rows …] [errors …]]`.
- BOM stripping; empty input → empty sequence; trailing newline optional.

## §7. Cross-references

- [`spec/core/conversions.md §8`](../core/conversions.md) — cross-format CSV conversion (CLI / Document-level); this module is the in-program library form.
- [`spec/std-lib/README.md`](README.md) — sub-package surface enumeration.
- RFC 4180 — CSV format.
