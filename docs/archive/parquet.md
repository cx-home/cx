# CX ↔ Parquet round-trip cookbook (v0.7.0)

Apache Parquet is the column-store wire format used across the
analytics stack. The cxlib bindings expose Parquet through the same
Arrow IPC bridge they use for Arrow C-Data Interface — Parquet is
read/written via each binding's host Arrow library, then converted
to/from CXDB chunked tables.

This document covers:

1. [Quickstart per binding](#quickstart-per-binding)
2. [CLI subcommand (`cx table dump --to=parquet`)](#cli-subcommand)
3. [Round-trip semantics + schema preservation (X7)](#round-trip-semantics)
4. [Cross-binding byte-identity (X8)](#cross-binding-byte-identity)
5. [Performance baseline (X9)](#performance-baseline)
6. [Troubleshooting](#troubleshooting)

---

## Quickstart per binding

### Python

```python
import cxlib
import cxlib.parquet as cxp

# CX → Parquet
framed = cxlib.to_data_bin_chunked(
    "[points :table[name:string score:int] alice 91 bob 88]")
cxp.write_table(framed, "out.parquet")

# Parquet → CX
framed_back = cxp.read_table("out.parquet")
cx_text = cxlib.from_data_bin_chunked(framed_back)
```

### Go

```go
import "github.com/cx-home/cx/lang/go/cxlib"

// CX → Parquet via cxlib.ArrowExport → arrow-go parquet writer
data, _ := cxlib.ToDataBinChunked(`[points :table[name:string score:int]
  alice 91
  bob 88
]`)
reader, _ := cxlib.ArrowExport(data)
defer reader.Release()
// caller uses parquet-go to write reader to file
```

### Rust

```rust
use cxlib::{to_data_bin_chunked, arrow as cxa};
use std::fs::File;
use parquet::arrow::ArrowWriter;

let framed = to_data_bin_chunked(/* cx_text */)?;
let mut reader = cxa::export(&framed)?;
let file = File::create("out.parquet")?;
let mut writer = ArrowWriter::try_new(file, reader.schema(), None)?;
while let Some(batch) = reader.next() {
    writer.write(&batch?)?;
}
writer.close()?;
```

### TypeScript

```typescript
import * as cxlib from '@cx-home/cx';
// requires `npm install parquet-wasm` (peer dependency)

// Parquet → Arrow Table → CX (via apache-arrow JS pipeline)
const table = await cxlib.parquet.tableFromParquetFile('input.parquet');
// The cxlib TS binding can convert apache-arrow Tables to CXDB
// via its Arrow IPC bridge; CXDB → CX text via cxlib.decodeDataBin.
```

---

## CLI subcommand

The V CLI's `cx table` subcommand surfaces Parquet/Arrow round-trip
by shelling out to the Python binding's `cxlib.parquet` and
`cxlib.arrow` module CLIs. Python with pyarrow installed is
required when these formats are invoked; the V binary itself stays
free of Parquet/Arrow linkage.

```sh
# CX → Parquet
cx table dump input.cx --to=parquet --output=out.parquet

# Parquet → CX
cx table load input.parquet --to=cx --output=out.cx
```

Exit codes:
- `0` — success
- `1` — Python helper failed (pyarrow missing, file IO, schema)
- `2` — CLI usage error (unknown flag)
- `3` — reserved

---

## Round-trip semantics

CX → Parquet preserves the cx-table column schema:

| CX column type             | Parquet logical type    |
|---|---|
| `:int` / `:i64`            | INT64                   |
| `:i32`                     | INT32                   |
| `:i16` / `:i8`             | INT32 (no narrower Parquet primitive) |
| `:float` / `:f64`          | DOUBLE                  |
| `:bool`                    | BOOLEAN                 |
| `:string`                  | BYTE_ARRAY (UTF-8)      |
| `:date`                    | INT32 logical date      |
| `:datetime`                | INT64 logical ts[ns,UTC]|
| `:bytes`                   | BYTE_ARRAY              |
| `:decimal128[P,S]` (v0.7.0)| FIXED_LEN_BYTE_ARRAY(16) decimal(P,S) |
| `:timestamp[unit, tz]` (v0.7.0) | INT64 logical ts[unit, tz] |
| `:fixed-size-binary[N]` (v0.7.0) | FIXED_LEN_BYTE_ARRAY(N) |

**Column origin hashes (X7):** when the input CX carries `cx-table`
origin metadata, the Parquet writer preserves it as Parquet KV
metadata under key `cx.origin.<column-name>`. The reader restores
the metadata on round-trip. This satisfies the X7 schema-preservation
contract and is verified by `conformance/data_bin_arrow.txt` fixtures
under Python/Go/Rust bindings.

---

## Cross-binding byte-identity

The X8 contract: the same CX input produces byte-identical Parquet
bytes across Python / Go / Rust bindings. Achieved by:

- Fixed compression: NONE (default at v0.7.0 — gzip / snappy
  configurable but byte-identity only holds for matching settings)
- Fixed encoding: PLAIN for primitives; PLAIN_DICTIONARY for strings
  when adoption signal arrives (v0.7.x)
- Fixed row-group size: 1024 (overridable per call but identical
  across bindings for shared-corpus fixture tests)
- Stable schema-metadata ordering: alphabetical by key

The TypeScript binding inherits byte-identity via parquet-wasm's
deterministic writer when invoked with matching `writerProps`.

---

## Performance baseline

X9 contract: read throughput > 100 MB/s per binding. Measured on
the `fixtures/bench/` corpus via `make bench-parquet`:

| Binding   | Read MB/s | Write MB/s | Notes                          |
|-----------|-----------|------------|--------------------------------|
| Python    | ~250      | ~180       | pyarrow native C++ kernels     |
| Go        | ~220      | ~160       | apache/arrow/go v18 parquet    |
| Rust      | ~310      | ~210       | parquet-rs, fastest native     |
| TypeScript| ~95       | ~70        | parquet-wasm; below baseline   |

The TypeScript binding falls short of the 100 MB/s baseline on the
read side at v0.7.0 because parquet-wasm trades raw throughput for
compatibility; this is documented but does not block X9 for the
core (Python/Go/Rust) bindings.

---

## Troubleshooting

**"pyarrow required" error.** Install via
`pip install cxlib[parquet]` or `pip install pyarrow`. The V CLI
shells out to the Python binding for Parquet IO; without pyarrow
the `cx table dump --to=parquet` and `cx table load --from=parquet`
commands fail.

**"libcx_arrow not available" error.** The Python binding's Parquet
support composes with `cxlib.arrow` for the Arrow IPC bridge. Build
libcx_arrow alongside libcx via `make build-lib-arrow`.

**Schema mismatch after round-trip.** Check the CX source for the
`:type` annotation column-by-column. CX→Parquet uses the explicit
type annotation; Parquet→CX recovers it. If your CX source omits
the annotation, the round-trip uses string columns by default
(losing typing).

**Empty `cx table dump --to=parquet` output.** The CX input must
contain a `:table` block. Plain CX documents without table blocks
have no row-major data to project to Parquet; use `cx table info
FILE` to inspect what blocks the input carries.

**Cross-binding byte-identity failures.** Verify all bindings use
the same compression / encoding / row-group settings. The
`make test-cross-binding-parquet` target enforces this on the
conformance corpus.

---

## Related

- [`spec/v0_7_0_status.md §X`](../spec/v0_7_0_status.md) — Parquet
  row block status
- [`docs/arrow.md`](arrow.md) — sibling document for the Arrow
  C-Data Interface bridge
- [`conformance/data_bin_arrow.txt`](../conformance/data_bin_arrow.txt)
  — 14 byte-identity fixtures covering scalar + parametric types
