# CX vs alternatives — side-by-side comparisons

These files show the same data shape in CX and in each common
alternative format, with notes on what each format costs you.

The thesis of CX is **one format that doesn't make you trade off**
type fidelity, comments, structure, and lossless round-trip. Each
file in this directory is a worked example of where one of the
alternatives forces a trade-off.

## File index

| File | Demonstrates | Trade-off that CX avoids |
| ---- | ------------ | ------------------------ |
| [`typed_int.cx`](typed_int.cx) vs [`typed_int.json`](typed_int.json) / [`typed_int.yaml`](typed_int.yaml) | `int64` precision | JS `Number` floats numbers > 2⁵³ |
| [`commented_config.cx`](commented_config.cx) vs [`commented_config.json`](commented_config.json) | Comments alongside types | JSON has no comments at all |
| [`table_block.cx`](table_block.cx) vs [`table_block.csv`](table_block.csv) | Tabular data with typed columns | CSV has no types; YAML is awkward for many rows |

## Run any comparison

```sh
# Convert CX to every format losslessly:
cx --json typed_int.cx
cx --yaml typed_int.cx
cx --toml typed_int.cx
cx --xml  typed_int.cx
cx --md   typed_int.cx

# Verify round-trip:
cx eq typed_int.cx <(cx --json typed_int.cx | cx --from=json)
```

## Why this matters

Most format choices are forced by the lowest-common-denominator
consumer. CX preserves the source-of-truth properties and converts
losslessly **on demand** to whatever the consumer needs. The
comparison files in this directory make that concrete.

For the full feature comparison, see [`docs/COMPARISON.md`](../../docs/COMPARISON.md).
