# `cx-stdlib/format` — canonical-form emission and pretty-print

```cx
[module-meta name=format tier=A status=current]
```

**Status:** Current

Normative reference for the `cx-stdlib/format` sub-package.

---

## §1. Scope

`cx-stdlib/format` emits CX values back to CX text:

- **Canonical** — byte-stable canonical form per [`spec/core/canonical.md`](../core/canonical.md). Used for hashing, diffing, content addressing.
- **Pretty** — human-readable with indentation and line wrapping.
- **Compact** — minimum-whitespace form for transport.
- **Diff-friendly** — version-stable, one-element-per-line form for snapshots and version control.

CX-to-CX text only; cross-format conversion lives in [`cx-stdlib/json`](json.md), [`cx-stdlib/csv`](csv.md), etc. Round-trip property: `parse(format-X(value))` is structurally equal to the original for any X.

### §1.1. Canonical is the single source of truth for the hash input

`format/canonical` emits exactly the canonical form normatively defined in [`spec/core/canonical.md`](../core/canonical.md). Layer-1 `hash(node)` ([`spec/misc/bindings.md §2.1`](../misc/bindings.md)) hashes those bytes: the canonical text **is** the hash preimage. One canonical form, three consumers:

1. This module (`format/canonical`) emits it.
2. [`cx-stdlib/hash`](hash.md) and ID/IDREF identity (per [`spec/core/cxdm.md`](../core/cxdm.md)) hash it for content addressing and value identity.
3. [`cx-stdlib/store`](store.md) hashes it to compute document IDs.

Any divergence between `format/canonical`'s output and the hash-canonical form is a **conformance failure**.

### §1.2. Stability tiers

| Formatter | Stability | Use case |
|---|---|---|
| `canonical` | Byte-stable forever (hash preimage) | Hashing, equality, content addressing |
| `diff-friendly` | Stable across CX versions | Snapshots, version control, stable diffs |
| `pretty` | NOT version-stable | Human reading, debugging |
| `compact` | Mostly stable | Transport over text channels |

Do **not** snapshot-test or diff against `pretty` output. Use `diff-friendly` (stable across versions) or `canonical` (byte-stable forever).

## §2. Conceptual model

Every formatter takes a CX value and returns a string. The four formatters differ only in whitespace policy (see §1.2 table).

## §3. Public function surface

### §3.1. Single-shot formatters

```
[?def canonical  scope=public pure [returns string] ($value::any) ...]
[?def pretty     scope=public pure [returns string] ($value::any) ...]
[?def compact    scope=public pure [returns string] ($value::any) ...]
```

Each accepts any CX value (scalar, element, sequence, array, map) and returns the formatted text.

### §3.2. Pretty-print options

```
[?def pretty-with-opts scope=public pure [returns string] ($value::any $opts::map) ...]
```

| Key | Default | Semantics |
|---|---|---|
| `indent` | `"  "` (two spaces) | Indentation unit |
| `line-width` | `80` | Target maximum line length |
| `attribute-alignment` | `"none"` | `"none"` / `"colon"` / `"value"` |
| `sort-attributes` | `false` | Sort attribute names alphabetically |
| `max-depth` | `0` | 0 = unlimited; positive value limits emission depth |
| `max-depth-policy` | `"truncate"` | `"truncate"` (emit `…`) or `"error"` (raise `CXER2701`) |
| `string-quote` | `"double"` | `"double"` / `"single"` |
| `include-anchors` | `true` | Whether to render `&anchor` / `*alias` references |

### §3.3. Canonical with derived statistics

```
[?def canonical-with-context scope=public pure [returns element] ($value::any) ...]
```

Returns `[canonical-result text="..." hash=$bytes length=$int tokens=$int]`. Useful when callers want both the canonical text and its hash without two separate calls.

### §3.4. Diff-friendly emission

```
[?def diff-friendly scope=public pure [returns string] ($value::any) ...]
```

One element per line, sorted attributes, consistent indentation. Stable across CX versions.

### §3.5. Streaming emission

```
[?def emit-stream scope=public pure [returns [sequence string]] ($value::any $opts::map) ...]
```

Return a sequence of chunks (typically one line each). Concatenation equals `pretty-with-opts(value, opts)`.

## §4. Edge cases

- **Canonical determinism.** `canonical` MUST be byte-for-byte deterministic per [`spec/core/canonical.md`](../core/canonical.md). Load-bearing for content addressing.
- **DAG termination.** CXDM values are DAGs (acyclic except via explicit `&anchor` / `*alias`). All formatters render references deterministically — anchor at first occurrence, alias on every subsequent one — and are guaranteed to terminate.
- **Large values.** Use `emit-stream` for memory-bounded emission.
- **Bytes scalars** emit as `0x<hex>` (short) or `b"<base64>"` (long) per canonical rules.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2700` | `E_FORMAT_UNSUPPORTED_VALUE` | Formatter on a value kind it can't emit (safety net) |
| `CXER2701` | `E_FORMAT_DEPTH_EXCEEDED` | `pretty-with-opts` with `max-depth-policy="error"` and depth exceeded |
| `CXER2702` | `E_FORMAT_INVALID_OPT` | Unknown key or invalid value in opts map |

## §6. Conformance fixtures

Under `conformance/stdlib/format.cxd`:

- **Canonical determinism:** same input emits byte-identical output across runs and bindings (V/Python/Go/Rust).
- **Canonical = hash input:** `hash/sha256(bytes-of(format/canonical(v)))` equals Layer-1 `hash(v)` for arbitrary `v`.
- **Round-trip:** `parse(canonical(v))`, `parse(pretty(v))`, `parse(compact(v))`, `parse(diff-friendly(v))` are structurally equal to `v`.
- **Pretty options:** custom `indent` respected; `sort-attributes=true` emits attributes alphabetically; lines respect `line-width` (modulo unbreakable tokens).
- **Max-depth:** `max-depth=2` with default `"truncate"` emits `…` at the limit; with `"error"` raises `CXER2701`.
- **Streaming:** `string-concat(emit-stream(v, opts))` equals `pretty-with-opts(v, opts)`.
- **Anchor / alias:** for a DAG value, anchor emits at first occurrence and alias at each subsequent occurrence in document order; round-trip preserves structure.
- **Termination:** every formatter terminates on every well-formed CXDM value.

## §7. Cross-references

- [`spec/core/canonical.md`](../core/canonical.md) — normative canonical-form rules this module emits.
- [`spec/misc/bindings.md §2.1`](../misc/bindings.md) — Layer-1 `hash(node)` hashes `format/canonical`'s bytes.
- [`spec/core/cxdm.md`](../core/cxdm.md) — value identity (ID/IDREF) hashes the canonical form.
- [`spec/std-lib/hash.md`](hash.md), [`spec/std-lib/store.md`](store.md) — additional consumers of the canonical form.
- [`spec/std-lib/json.md`](json.md), [`spec/std-lib/csv.md`](csv.md) — cross-format converters (CX ↔ other); this module is CX-to-CX.
