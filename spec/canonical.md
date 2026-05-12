# CX Canonical Form Specification
# Version: 1.1
# Date: 2026-05-11

This document defines canonical forms for CX across every output format. Two
implementations are conformant if and only if they produce byte-identical
canonical output for any valid input. Canonical form is the basis for the
cross-binding parity matrix (see `spec/architecture.md`), content-addressable
hashing, signed configuration bundles, and stable diffs.

### What's new in v1.1 (2026-05-11)

Per §D14:

- **§2.11 collection literals (new)** — canonical-form rules for
 Sequence `(a, b, c)`, Array `[a, b, c]`, and Map `{k: v}` source
 syntax (per CXDM v1.1 / grammar v3.6 / §D14).
- **§2.11.1 map key ordering** — canonical maps emit keys in
 lexicographic Unicode order of the canonical-key serialization;
 runtime maps preserve insertion order (per Q6).
- **§2.11.2 trailing commas** — input accepts trailing commas;
 canonical form omits them (per Q7).
- **§2.11.3 multiline indentation** — when a collection spans
 multiple source lines, contents align with the current attribute-
 block indentation convention from §2.2 (per Q4 /
 D17 #4).
- **§5 JSON canonical** — map-key ordering updated: JSON canonical
 emit sorts string-coerced keys lexicographically (override of
 §5's "insertion order" rule for v1.1 Map values; element-attr
 insertion order still applies). See §5 for details.

This spec is normative. Where it conflicts with format-specific specs
(`grammar.ebnf`, `conversions.md`), this document wins for canonical-mode
output; format-specific specs govern non-canonical output.

---

## 1 — Two canonical forms

CX defines two canonical forms, intended for different use cases. Tools and
APIs must clearly distinguish which form they produce.

### 1.1 Lossless canonical

Preserves every node in the source: comments, anchors, aliases, merges,
CXDirectives, BlockContent, RawText, processing instructions. Normalizes only
*presentation*: whitespace, indent, quoting, number formatting, attribute
ordering within their declared category.

Use cases:
- `cx fmt` — opinionated formatter for source files.
- Diff stability across edits that don't change data.
- Code review: reviewers see only meaningful changes.

Property: `fmt(fmt(x)) == fmt(x)` for any valid `x` (idempotent).

### 1.2 Strict canonical

Reduces input to *data-equivalence form*. Strips comments, expands anchors and
aliases, resolves merges, removes presentation-only directives, normalizes
date offsets to UTC. Two CX documents have identical strict canonical bytes if
and only if they encode the same data.

Use cases:
- `cx hash` — content-addressable hashing (SHA-256 of strict canonical bytes).
- Signed configuration: sign the strict canonical bytes; verify after canonicalizing.
- Deduplication keyed on data, not file bytes.
- Equality check (`cx eq a.cx b.cx`).

Property: lossy by design. Canonical form preserves data; presentation is
discarded. Recovery from strict canonical form to original source is not
possible.

### 1.3 Validity precondition

Canonical form is defined only on *valid* CX input. A document containing NaN,
Inf, duplicate keys, integer overflow for the declared type, or other
spec-defined errors has no canonical form — canonicalization fails with an
error. See `spec/architecture.md` §Error policies.

---

## 2 — Text CX canonical (lossless)

The `cx fmt` command produces lossless canonical text CX. All rules below
apply.

### 2.1 Element ordering

| Aspect | Rule |
|---|---|
| Top-level node order | Source order; never reordered. |
| Children of an element | Source order; never reordered. |
| ElementMeta order within an element | `AnchorDef? MergeRef? TypeAnnotation? Attribute*` (per grammar [301]). |
| Attribute order within `Attribute*` | Source insertion order; never sorted. |
| Multi-document order | Source order; never reordered. |

Source order is preserved because order carries semantics in CX. Reordering
would change meaning.

### 2.2 Whitespace

| Aspect | Rule |
|---|---|
| Indent | Two ASCII spaces per nesting level. No tabs. |
| Inter-attribute whitespace | Exactly one ASCII space. |
| Whitespace around `=` in attributes | None: `name=value`, never `name = value`. |
| Whitespace before `]` | None when body inline; one newline + correct indent when body multi-line. |
| Element-with-children layout | Newline after element open; one child per line; closing `]` on its own line at parent indent. |
| Element-with-inline-body layout | When body is a single Scalar, single Text token, or short array (< 80 chars total line length), keep on one line. |
| Trailing whitespace on any line | None. |
| Blank lines between top-level elements | Preserved if present in source (lossless); collapsed to single blank if multiple. |
| Trailing newline at file end | Exactly one LF. |

### 2.3 Quoting

| Aspect | Rule |
|---|---|
| Bare strings | Used when value is BareChar-eligible (no whitespace, `[`, `]`, `=`, `'`, `"`) AND does not match an auto-typing literal (number, bool, null, date, datetime, hex). |
| Quoted strings | Single-quote `'...'`. Double quotes are not used. |
| Triple-quoted | Used when value contains literal newlines OR consecutive whitespace OR a `'` that would force escaping. |
| Empty string | `''`. |
| String containing only `'` | Triple-quoted: `'''''''` is invalid; use `'\''`. |

### 2.4 Escape sequences

Within quoted text, only the following escapes are emitted:

| Char | Escape |
|---|---|
| `\` | `\\` |
| `'` | `\'` |
| LF (U+000A) | `\n` |
| CR (U+000D) | `\r` |
| Tab (U+0009) | `\t` |
| Other C0 controls (U+0000–U+001F except above) | `\u00XX` |
| DEL (U+007F) | `` |
| Other characters (including all printable Unicode) | Verbatim, as UTF-8. |

`/` is never escaped. `\u` and `\U` escapes are used only when no shorter form
exists.

### 2.5 Numbers

| Aspect | Rule |
|---|---|
| Integer | Shortest decimal form. No leading zeros (except for `0` itself). No `+`. No underscores in canonical output (underscores in source are stripped). |
| Negative integer | `-` immediately before digits, no space. |
| Hex integer | Lowercase `0x` prefix. Lowercase hex digits. Used in canonical output only if source used hex form (lossless preserves intent); strict canonical converts all integers to decimal. |
| Float | Shortest round-trip decimal representation per Ryū algorithm. Always includes a decimal point: `1.0`, never `1.` or `1`. |
| Float scientific notation | Used only when shorter than fixed form. Lowercase `e`. No `+` after exponent. Mantissa includes `.` (e.g., `1.5e10`, `2.0e-7`). Single-digit mantissa with zero fraction allowed: `1e10` is valid only as input; canonical emits `1.0e10`. |
| Negative zero (float) | `-0.0`, distinct from `0.0`. |
| Subnormal floats | Preserved bit-exact via Ryū. |
| NaN, +Inf, -Inf | Rejected (no canonical form). |

### 2.6 Booleans, null, dates

| Type | Canonical form |
|---|---|
| Boolean | `true` or `false` (lowercase). |
| Null | `null` (lowercase). |
| Date | `YYYY-MM-DD` per ISO 8601. |
| Datetime (lossless) | `YYYY-MM-DDTHH:MM:SS[.fff][Z\|±HH:MM]` exactly as in source, with offset preserved. Fractional seconds emitted only if present in source; trailing zeros stripped. |
| Datetime (strict) | Normalized to UTC: `YYYY-MM-DDTHH:MM:SS[.fff]Z`. Original offset is discarded. |

### 2.7 Type annotations

| Aspect | Rule |
|---|---|
| Form | Long form always: `:int`, `:float`, `:bool`, `:string`, `:date`, `:datetime`, `:bytes`, `:decimal`, `:f16`. Short aliases (`:i :f :b :s :d :dt`) are not emitted in canonical. |
| Array marker | `:string[]`, `:int[]`, etc. The bare `:[]` (inferred array) is canonicalized to its concrete form: emitter resolves the inferred type and emits the explicit annotation. |
| Position | Immediately after MergeRef (if any), before the first Attribute. |

### 2.7a Namespace declarations and prefix usage

**Lossless canonical:** xmlns declarations and prefixed names preserved exactly in source form and source order.

**Strict canonical:** xmlns declaration order and prefix usage are
canonicalized per [`spec/namespaces.md §3.2`](namespaces.md) so that
two semantically-equal namespaced documents produce byte-identical
strict-canonical output. Specifically, at each element with one or
more xmlns declarations:

| Aspect | Rule |
|---|---|
| xmlns declaration ordering | Default-namespace declaration (`xmlns=...`) first when present, then `xmlns:prefix=...` declarations in lexicographic order by prefix. |
| Non-xmlns attribute ordering | Source insertion order; emitted after the sorted xmlns block. (Local override of §2.1 scoped to namespace declarations only.) |
| Prefixed element / attribute names | Rewritten at usage sites to the lex-smallest non-empty in-scope prefix mapping to the resolved URI. The xmlns declaration mapping the URI is preserved verbatim. |
| Reserved `xml:` / `cx:` prefixes | Always in scope; never appear as xmlns declarations on emit. |
| Default-namespace key (empty prefix) | Never wins the canonical-prefix ranking — would corrupt attribute namespacing per XML Namespaces 1.0 §6.2. |

The implementation runs as a post-pass in `cx_text_canonical`
(V core: `vcx/cx/namespaces.v::canonicalize_namespaces`). The pass
is idempotent and adds no new wire-format requirements.

### 2.7b ID declarations and references

**Lossless canonical:** ID spellings preserved exactly. `#id`
declarations and `@id` reference values emit verbatim from source.

**Strict canonical:** IDs are rewritten to a deterministic `id-N`
naming scheme
§D7, so two semantically-equal documents differing only in ID
*spelling* produce byte-identical strict-canonical output (and
therefore the same `cx hash`). Specifically:

| Aspect | Rule |
|---|---|
| Numbering | Declarations are visited depth-first in source order. The Nth distinct `#id` becomes `id-N` (1-indexed). |
| Reference rewriting | Every `is_ref` attribute value pointing at a renamed declaration is rewritten to the new name. Unresolved references (which would have errored at parse time) are left unchanged. |
| Forward references | Refs preceding their target in source order pick up the same `id-N` name when the target is visited. |
| Idempotence | Running on input whose IDs already match `id-1`, `id-2`, ... in document order produces the same output. |
| XML emission | The same `id-N` names round-trip through `xml:id` / matching attribute values per [`spec/identity.md §5`](identity.md). |

The implementation runs as a post-pass in `cx_text_canonical`
(V core: `vcx/cx/identity.v::canonicalize_ids`).

### 2.8 Anchors, aliases, merges

**Lossless canonical:** preserved exactly.

| Aspect | Rule |
|---|---|
| AnchorDef | `&name`. Name canonicalized to source spelling. |
| MergeRef | `*name`. |
| AliasElement | `[*name]`. |

**Strict canonical:** all anchor structure expanded.

- Each AliasElement is replaced by a deep copy of the anchored element's
 resolved content (same as the Resolved AST step in `spec/ast.md`).
- Each MergeRef is replaced by inlining the merged attributes and items into
 the host element, with host-element values overriding merged values per the
 grammar's merge semantics.
- AnchorDef nodes are removed.
- The result is a tree with no `&`, `*`, or `[*]` references.

### 2.9 Comments, directives, processing instructions

**Lossless canonical:** preserved.

- Comments emitted as `[- text -]` with internal whitespace unchanged.
- Line comments (`# text`) emitted as `# text`, terminated at end of line, not
 converted to block form. Comment placement preserved relative to nodes.
- CXDirectives emitted in source position, with attribute order preserved.
- Processing instructions emitted in source position.
- XMLDecl emitted at document head if present in source.

**Strict canonical:** stripped.

- All Comment nodes removed.
- All CXDirective nodes removed (presentation-only).
- PI nodes removed if not declared semantic by name; otherwise preserved.
- XMLDecl removed (presentation-only declaration of the encoding).

### 2.10 BlockContent and RawText

| Aspect | Rule |
|---|---|
| BlockContent (`[\| ... ]`) | Lossless: preserved with whitespace per grammar [28] rules. Strict: contents inlined into parent element body, lossless block markers removed. |
| RawText (`[# ... #]`) | Always preserved in both forms. The contents are opaque; canonicalization does not modify them. |
| TripleQuoted (`'''...'''`) | Used in canonical when content contains literal newlines or characters that would require many escapes in `'...'`. |

### 2.11 Collection literals *(v1.1)*

CXDM v1.1 Sequence, Array, and Map Items (per grammar [56] / 
§D14) canonicalize as follows. The rules apply identically in
lossless and strict canonical forms unless noted.

| Form | Canonical syntax | Empty |
|---|---|---|
| Sequence | `(item, item, item)` — single space after each comma, no space before; no space inside outer parens | `()` |
| Array | `[item, item, item]` — same spacing as Sequence | `[]` |
| Map | `{key: value, key: value}` — single space after `:` and after `,`; no space before `:`; no space inside braces | `{}` |

Items inside collections canonicalize per their own canonical form
(§2.1–§2.10 + recursive §2.11). Nested arrays/maps canonicalize
recursively. Sequences boxed as Items inside an Array or Map value
(Sequence-as-Item per CXDM §2.6) canonicalize as `(…)` and remain
nested (do not flatten).

### 2.11.1 Map key ordering

| Aspect | Rule |
|---|---|
| Runtime ordering | Insertion order (preserved by parsers and evaluators per CXDM v1.1) |
| Canonical-form ordering | **Lexicographic Unicode order** of the canonical-key serialization |
| Key serialization for sort | Per §2.5 (numbers) / §2.6 (bool/date) / §2.4 (strings) — atomic-scalar canonical form |
| Mixed-type keys | Per type-tag tie-break: `bool` < `bytes` < `date` < `datetime` < `float` < `int` < `string` (lexicographic order of type-tag name); within each tag, canonical-value order |
| Duplicate keys | Parse error W014 (per grammar [56g]); not produced by canonicalizer |

Bare-name keys (`{name: 'a'}`) sort as their equivalent string keys
(`{'name': 'a'}` — `name` is a string §D4).

### 2.11.2 Trailing commas

| Aspect | Rule |
|---|---|
| Source-text acceptance | Permitted (per grammar [56d] / [56e]) |
| Lossless canonical emit | Omitted |
| Strict canonical emit | Omitted |
| Empty collections | No comma (`()` / `[]` / `{}`) |

### 2.11.3 Multiline collection layout

A collection literal spans multiple lines when:

- Its source spans multiple lines, OR
- Its single-line canonical form would exceed the canonicalizer's
 line-length budget (default 80 chars, per §2.2 line-width
 convention).

Multiline layout rules:

```
[
 item1,
 item2,
 item3
]
```

- Open bracket / brace / paren on its own line is NOT canonical;
 opener stays on the line introducing the collection.
- Each item gets its own line with **2-space relative indentation**
 from the opener's line.
- Closer aligns with the opener's column.
- Trailing comma still omitted (per §2.11.2).
- Single-line form is preferred when fits within the line-length
 budget; multiline form kicks in deterministically when
 single-line exceeds.

Nested multiline collections nest indentation:

```
[
 [a, b, c],
 [
 deep1,
 deep2
 ]
]
```

### 2.11.4 `:type[]` legacy form

`:type[]` element-prefix annotations from v1.0 are desugared to
Array literals on parse per [`spec/conversions.md §0.2`](conversions.md)
and §D19. Canonical emit produces the Array-literal form,
not the legacy `:type[]` shape. Lossless mode preserves source-form
when in scope of a `cx fmt --preserve-legacy` flag; the default is
to canonicalize to Array-literal form.

---

## 3 — Text CX canonical (strict)

All rules from §2 apply, with the modifications stated above per section.
Summary of strict-only behaviors:

- Comments stripped (§2.9).
- CXDirectives stripped (§2.9).
- XMLDecl stripped (§2.9).
- IDs renamed to `id-N` in document order (§2.7b); references rewritten to match.
- Anchors, aliases, merges expanded (§2.8).
- BlockContent inlined into parent (§2.10).
- Datetime offsets normalized to UTC (§2.6).
- Hex integers converted to decimal (§2.5).
- Type-inferred arrays (`:[]`) converted to concrete annotations (§2.7).
- Inferred-but-omitted defaults made explicit (e.g., element without a TypeAnnotation but whose body unambiguously has one type gets the annotation emitted).

Strict canonical output may not parse to the same parse-AST as the source
(it parses to the same Resolved AST — the shape after anchor resolution and
type inference). This is the intent: data equivalence, not parse equivalence.

---

## 4 — Binary `cx_to_data_bin` canonical

The binary data format is *always* strict canonical. There is no non-canonical
binary form. See `spec/data_bin.md` for the full byte-level format. Canonical
constraints applicable here:

| Aspect | Rule |
|---|---|
| Endianness | Little-endian. Declared in flags byte. |
| Map (element) key order | Insertion order; never sorted. |
| Varint encoding | Minimal width. No leading zero bytes beyond what the value requires. |
| Float NaN, +Inf, -Inf | Rejected (no canonical form). |
| Negative zero | Bit-exact preservation. |
| Strings | UTF-8. No normalization on storage. NFC for duplicate-key comparison only. |
| Empty array vs empty map | Distinct tags, never collapsed. |
| Reserved header bits | Always zero. |
| Reserved tag bytes | Reject on parse. |
| String encoding in dictionaries | Insertion order of distinct values. |
| Bit-packed bool columns | Bit 0 of each byte is row 0 of that block; trailing bits in last byte zero. |

The text CX → binary path: parse text into AST, apply strict-canonical rules
from §3 (anchor expansion, comment stripping, type resolution), then serialize
to binary per `spec/data_bin.md`. The binary form is the strict canonical
serialization in compact bytes.

---

## 5 — JSON emission canonical

Used by `cx --to-json --canonical`. CX → semantic JSON is intrinsically lossy
(see `spec/conversions.md` §2.2); these rules govern only how the lossy
projection is canonicalized.

| Aspect | Rule |
|---|---|
| Whitespace | None between tokens (compact). Pretty-printed JSON is non-canonical. |
| Object key order (Element attrs) | Insertion order from CX source; never sorted. |
| Object key order (Map Items, v1.1) | **Lexicographic Unicode order** of the string-coerced canonical key per §2.11.1 (non-string keys coerce to strings on JSON emit per [`spec/conversions.md §2.2`](conversions.md); the sort order is the lexicographic order of the coerced string form). |
| String encoding | UTF-8. Escape only `"`, `\`, and characters in U+0000–U+001F. Never escape `/`. Use `\b \f \n \r \t` for those C0 chars; `\uXXXX` for other C0; verbatim for everything else (including all printable Unicode). |
| Surrogate pairs | Emitted only for characters above U+FFFF; lone surrogates are an error. |
| Numbers | Same rules as CX (§2.5): shortest decimal, Ryū for floats, `1.0` not `1`. |
| Trailing newline | None. |
| Top-level | Whatever CX projects to (object, array, scalar). |

Note: this differs from RFC 8785 (JSON Canonicalization Scheme) which sorts
keys. CX preserves insertion order because order is meaningful in CX source.
The CX-canonical JSON form is named **CXC-JSON** to distinguish it.

---

## 6 — YAML emission canonical

Used by `cx --to-yaml --canonical`.

| Aspect | Rule |
|---|---|
| Style | Block style only. No flow style. |
| Indent | Two spaces. |
| Map key order | Insertion order. |
| Strings | Always quoted with `'...'` if the value matches any of: a number literal, `true`, `false`, `null`, `yes`, `no`, `on`, `off`, an ISO date, or contains characters that would require quoting under YAML 1.2 plain-scalar rules. The "Norway problem" is prevented by always quoting when ambiguous. |
| Quote choice | Single-quote preferred. Double-quote only when escapes are required (the value contains C0 controls or non-printable Unicode). |
| Trailing newline | Exactly one. |
| `---` document separator | Used only for multi-doc input. |

---

## 7 — TOML emission canonical

Used by `cx --to-toml --canonical`.

| Aspect | Rule |
|---|---|
| `[table]` order | Document order from CX source, never sorted. |
| Key order within tables | Insertion order. |
| Inline tables | Used only when the CX source had a single-line element. |
| Strings | Single-quote literal `'...'` preferred; double-quote `"..."` only when escapes required. |
| Numbers | Same as CX (§2.5). |
| Datetime | Offset-preserving in lossless; UTC-normalized in strict. |
| Trailing newline | Exactly one. |

---

## 8 — XML emission canonical

Used by `cx --to-xml --canonical`. Follows W3C Canonical XML 1.1 with the
modifications below.

| Aspect | Rule |
|---|---|
| Base | C14N 1.1. |
| `cx:` namespace attributes | Sorted within each element per C14N rules (this is the only format where attributes are sorted; required by C14N). |
| CXDirective serialization | Strict: removed. Lossless: emitted as `<?cx ...?>` PI. |
| XMLDecl | Lossless: emitted if present in source. Strict: removed. |
| Default namespace | Not declared unless source declared one. |
| Trailing newline | Exactly one. |

XML is the only format where canonical sorting applies, because the C14N
standard mandates it for cryptographic interop with the wider XML ecosystem.

---

## 9 — CSV / TSV / PSV emission canonical

Used by `cx --to-csv --canonical` (and `--to-tsv`, `--to-psv`).

Applicable only to CX documents whose top-level structure is a single
`:table` block (or whose strict-canonical projection reduces to one).

| Aspect | Rule |
|---|---|
| Header row | One row, column names in `:table` declaration order. |
| Field delimiter | `,` (CSV), `\t` (TSV), `\|` (PSV). |
| Quoting | RFC 4180: a field is quoted with `"..."` if and only if it contains the field delimiter, a `"`, a CR, or an LF. Otherwise unquoted. |
| Escape within quoted fields | `"` doubled to `""`. No backslash escapes. |
| Line ending | LF. Never CRLF, regardless of operating system. |
| BOM | None at start of output. |
| Trailing line ending | One LF after the final row. |
| Empty cell | Empty (zero bytes between delimiters), not the literal string `""` unless the source value is the literal empty string. |
| Boolean | `true` or `false` (lowercase). |
| Null | Empty cell. (Distinct from empty string only via the `:null` annotation in the source schema, which is lost in CSV.) |
| Date / datetime | ISO 8601 form per §2.6. |

---

## 10 — Markdown emission canonical

Used by `cx --to-md --canonical`. The markdown emitter already produces a
deterministic form; this section ratifies it.

| Aspect | Rule |
|---|---|
| Headings | ATX style (`# foo`), never Setext. |
| Code blocks | Fenced with three backticks. Indented code blocks not emitted. |
| Lists | `-` bullets for unordered. `1.` start for ordered. |
| Links | Inline form: `[text](url)`. Reference-style links resolved to inline at canonicalization. |
| Emphasis | `*foo*` for italic, `**foo**` for bold. Underscores not used. |
| Hard line break | Two trailing spaces, then LF. |
| Trailing newline | Exactly one. |

---

## 11 — Implementation requirements

### 11.1 Reference implementation

The V core (`vcx/cx/`) is the reference implementation. Each emitter accepts a
`canonical` flag (`canonical: bool`) and optionally a `strict` flag
(`strict: bool`). Setting `canonical=true, strict=false` produces lossless
canonical; `canonical=true, strict=true` produces strict canonical. Default is
`false` (non-canonical pretty output).

The binary emitter has no flags — it is always strict canonical.

### 11.2 Binding requirements

Every binding must expose at minimum:

```
fmt(s) — lossless canonical text (alias: cxlib.format)
canonicalize(s) — strict canonical text
hash(s) — SHA-256 hex of strict canonical bytes (text or binary form, configurable; default: text)
eq(a, b) — true iff strict canonical of a equals strict canonical of b
```

The CLI exposes the same as `cx fmt`, `cx canonical`, `cx hash`, `cx eq`.

### 11.3 Conformance

The cross-binding parity matrix (`spec/architecture.md` §Conformance) tests
canonical output. Two bindings are conformant if and only if they produce
byte-identical output for every fixture under both `--canonical` and
`--canonical --strict`. Drift in any byte is a conformance failure.

### 11.4 Idempotence and round-trip properties

Implementations must satisfy:

- `fmt(fmt(x)) == fmt(x)` (idempotent).
- `canonicalize(canonicalize(x)) == canonicalize(x)` (idempotent).
- `parse(fmt(x))` produces the same parse AST as `parse(x)`, modulo
 presentation nodes that fmt may have rewritten in idempotent ways.
- `parse(canonicalize(x))` produces the same Resolved AST as `parse(x)`.
- `loads(canonicalize(x)) == loads(x)` (data binding is preserved).
- `hash(x) == hash(y)` if and only if `canonicalize(x) == canonicalize(y)`.

These properties are tested in conformance.

---

## 12 — Versioning

This canonical form is **CXC v1.0**. Future versions may extend or refine the
rules; canonicalized output declares its version implicitly via the parent
CX language version (`[?cx version=...]` in source, or the format version in
binary output).

Strict-canonical bytes are stable within a major CXC version: `cx hash` of the
same input produces the same hash for any conformant implementation at the
same CXC major version. Major-version bumps are reserved for changes that
intentionally invalidate existing hashes (rare; would require a strong reason
such as a discovered ambiguity or a security correction).

---

## 13 — Out of scope

The following are deliberately not specified here:

- Pretty-printed (non-canonical) output. Each tool may choose its own
 formatting for non-canonical mode.
- Streaming canonicalization. Canonical form is defined on whole documents.
- Schema-aware canonicalization. When a schema language ships, schema-driven
 rewrites (e.g., default-value elision) may be specified in a separate
 document; they do not affect the canonical form defined here.

---

## 14 — Relationship to the runtime value model

This document defines canonical *byte* form for CX documents — the
representation tools emit and `cx hash` consumes. The complementary
**runtime value model** that CXPath and CXL operate over (per
)
is specified in [`spec/cxdm.md`](cxdm.md).

The two are related but distinct:

- **Canonical form (this spec)** governs byte output: ordering,
 whitespace, quoting, number formatting. It applies to source
 documents, schemas, CXL programs, and any other CX artifact
 uniformly.
- **CXDM (`spec/cxdm.md`)** governs the in-memory value semantics an
 evaluator manipulates: sequences, items, equality, EBV, type
 coercion. Sequence-flat: every value is a sequence; single values
 are sequences of one; empty results are sequences of zero.

CXPath result types (sequences of Elements per [`spec/cxpath.md`](cxpath.md))
already operate per CXDM; CXDM v1 formalizes this so the v0.6.0+
CXL evaluator can build on a stable value-semantics
commitment. The sequence-flat model is locked at v0.6.0 as part of
the format-stability boundary; retrofitting it later would be a
breaking change.

Canonical scalar formatting (§2.5, §2.6) is the formatting used when
CXDM emits a Scalar Item via `[?=...]` interpolation or as the
serialization of a CXL evaluation result. The two specs agree by
construction on every scalar representation.
