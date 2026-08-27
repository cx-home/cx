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

Every formatter takes a CX value and returns a string. The four formatters differ in whitespace policy (see the §1.2 table) and, for `pretty` / `diff-friendly`, in string quoting (§2.2). They do **not** differ in the types they emit — see §2.1.

### §2.1. Round-trip fidelity is normative

For every formatter form, re-parsing the emitted text MUST yield a value structurally equal to the input, **types included**:

```
parse(format(v)) ≡ v
```

It follows that a **non-string scalar MUST NOT be quoted** by any form. Quoting one re-parses it as a string and silently changes the value's type, which is a conformance failure. Each non-string kind emits the same image the canonical form uses:

| Scalar kind | Emitted image | Not |
|---|---|---|
| `int` / `bool` / `null` | bare (`age=41`, `active=true`) | `age="41"` |
| `float` | bare, **exponent-always** (`r=1.5e0`) | `r=1.5` — that image is `decimal`'s |
| `decimal` | bare, scale preserved (`score=1.5`, `d=2.50`) | `score="1.5"` |
| `bigint` | bare (`n=123456789012345678901234567890`) | quoted |
| `atom` | `:` sigil retained (`tier=:gold`) | `tier="gold"` |
| `date` / `datetime` | bare (`on=2026-08-25`) | `on='2026-08-25'` |
| `duration` / `period` | glued annotation (`t::duration=100ms`) | `t="100ms"` |
| sized numeric / `bytes` | glued annotation (`port::u16=8080`) | annotation dropped |

The per-kind × per-position images are stated normatively once, in [`canonical.md`](../core/canonical.md) §2.6a; this table is the std-lib restatement and MUST agree with it.

The trap this rule closes: CX's runtime value model has no distinct payload for the kinds above — `decimal`, `bigint`, `atom`, `date`, `datetime`, `duration`, and `period` all park their verbatim CX image in a *string* payload and carry their type alongside it. An emitter that decides quoting from the payload alone reads every one of them as a string. Quoting MUST therefore be decided from the scalar's **type**, never its payload.

This applies in every position: attribute values, element body/content scalars, and map keys and values alike.

#### Closed deviations (#991, RULED: CO-12)

Two gaps between this requirement and the implementation survived the #978 / CO-3 fix, which covered `pretty` / `diff-friendly` only. Both are **closed**; they are recorded here because each moved a content address and the movement must stay findable:

1. **`date` / `datetime` in ATTRIBUTE position, `canonical` / `compact`.** Those forms emitted `on='2026-08-25'` (quoted), which re-parsed as a `string`. They now emit it bare, agreeing with `pretty` / `diff-friendly` and with the data emitter.
2. **`float`, all four forms.** A float emitted the bare image `1.5`, which re-parses as a `decimal` — CX types a bare fixed-point fraction as decimal — and which therefore **collided** with decimal `1.5`'s own image: two kinds, one address. All four forms now emit the CX-owned Ryū image `1.5e0`, which re-types as the float it is.

Neither was caught by the §6 round-trip pins, and the reason is worth keeping: both were **fixed points** of the emitter — re-emitting the wrongly-typed value reproduces the same text — so an image-comparison pin reported equality while the type had silently changed. The pins that close them (§6, `format-0xx-type-*`) compare scalar **types** through a parse-back, never images. Any future emitter change touching a scalar image needs a type-comparing pin for the same reason.

### §2.2. Pretty and diff-friendly always quote strings — the one deliberate divergence

`pretty` and `diff-friendly` ALWAYS quote a `string` scalar, using the quote character named by the `string-quote` option (§3.2). `canonical` and `compact` leave a string **bare whenever the bare form re-parses as that same string**, quoting only when it would otherwise auto-type:

| Value | `canonical` / `compact` | `pretty` / `diff-friendly` |
|---|---|---|
| `[user name=alice]` | `[user name=alice]` | `[user name="alice"]` |
| `[user code='007']` | `[user code='007']` | `[user code="007"]` |

Both satisfy §2.1 — the two forms simply resolve the free choice differently. Pretty keeps the string/non-string distinction visible to a human scanning indented output, which is that form's purpose; canonical minimizes bytes because it is the hash preimage.

This string-quoting difference is the **only** permitted divergence between `pretty`/`diff-friendly` and `canonical`. Any other difference in the emitted image of a scalar is a defect, and the two that existed were treated as such: the `date`/`datetime` attribute difference and the `float` image difference were both canonical's bugs to fix, not second sanctioned divergences, and #991 (RULED: CO-12) fixed them. All four forms now agree on every non-string scalar image, byte for byte.

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
| `string-quote` | `"double"` | `"double"` / `"single"` — which quote character wraps a `string` scalar (§2.2). Applies to strings only; a non-string scalar is never quoted (§2.1). |
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
- **Round-trip (§2.1):** `parse(canonical(v))`, `parse(pretty(v))`, `parse(compact(v))`, `parse(diff-friendly(v))` are structurally equal to `v` — over a witness carrying `string`, `int`, `decimal`, `bool`, and `atom` in **both** attribute and body-scalar position. Compare the *canonical images* of the two sides, not the values: `=`/`eq` atomizes a decimal or atom attribute against its string spelling, so a value-level comparison passes vacuously on exactly the kinds this pin exists to catch.
- **Type round-trip (§2.1, #991 / CO-12):** for **every** scalar kind in **every** position (attribute value, body scalar, map value, array item, sequence item), `parse(form(v))` yields a scalar of the SAME KIND, for all four forms. These pins parse back and compare the scalar's **type**, never its image — the two defects CO-12 closed were emitter *fixed points*, invisible to any image comparison. A kind that measures faithful is pinned as deliberate here, so a later change cannot silently make it lossy.
- **Kind disjointness (§2.1):** `float` and `decimal` carrying the same numeric text emit **different** canonical images (`1.5e0` vs `1.5`) and therefore different content addresses. Pinned with the pre-CO-12 colliding pair as the negative.
- **Scalar quoting (§2.1):** `pretty` emits `score=1.5`, `tier=:gold`, `port::u16=8080` — never the quoted spellings that would re-parse as strings.
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
