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
| [`table_block.cx`](table_block.cx) vs [`table_block.csv`](table_block.csv) | `[table[…]]` block — typed columns declared once, positional rows | CSV has no types; YAML is awkward for many rows |

## Run any comparison

```sh
# Convert CX to every format:
cx --json typed_int.cx
cx --yaml typed_int.cx
cx --toml typed_int.cx
cx --xml  typed_int.cx
cx --md   typed_int.cx

# Tables get a first-class CSV lane and an inspection surface:
cx --csv     table_block.cx
cx table info table_block.cx

# Verify a lossless round-trip (XML lane; --lossless carries per-value types):
cx --xml --lossless typed_int.cx > /tmp/typed_int.xml
cx --from=xml --to=cx /tmp/typed_int.xml > /tmp/typed_int.rt.cx
cx eq typed_int.cx /tmp/typed_int.rt.cx   # exit 0 — data-equivalent
```

### What each export lane preserves

- **XML with `--lossless`** is the round-trip lane: per-value type
  annotations (`<cx:T>`) ride along, so `cx --from=xml --to=cx`
  reconstructs a data-equivalent CX document (`cx eq` exit 0).
- **JSON / YAML / TOML** preserve the *values* faithfully (including
  full `int64` precision — that is the point of `typed_int.cx`), but
  the output is brace-map shaped: element structure,
  attributes-vs-children, and per-value type annotations are
  flattened away. There is no `--from=json` import lane back to the
  element form, and `--lossless` is silently ignored on these lanes
  today (engine work tracked as cx-private#416).
- **CSV** is a projection of `[table[…]]` rows (plus attributed
  elements as single-row blocks) — types are consumed to render
  cells, not carried.

## Why this matters

Most format choices are forced by the lowest-common-denominator
consumer. CX preserves the source-of-truth properties and converts
**on demand** to whatever the consumer needs. The comparison files
in this directory make that concrete.

For the full feature comparison, see the rendered guide chapter
[`docs/guide/comparison.html`](../../docs/guide/comparison.html)
(built into `docs/guide/` by the publish flow).
