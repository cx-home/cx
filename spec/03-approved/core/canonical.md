# CX Canonical Form Specification

**Status:** Current.

This document defines canonical forms for CX across every output format. Two
implementations are conformant if and only if they produce byte-identical
canonical output for any valid input. Canonical form is the basis for the
cross-binding parity matrix (see `../misc/parity-matrix.md`), content-addressable
hashing, signed configuration bundles, and stable diffs.

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

**Secret values are the one exception** (`cxdm.md` §12): a secret's *value* is
redacted to `'‹redacted›'` unless the emitter holds the `secret-reveal`
capability, so a document containing un-declassified secrets is not losslessly
recoverable — by design. The secret-ness metadata, the value's type, and node
structure are preserved; only the value is withheld. Such output is then a
**lossy, safe projection**, not the lossless form.

Use cases:
- `cx fmt` — opinionated formatter for source files.
- Diff stability across edits that don't change data.
- Code review: reviewers see only meaningful changes.

Property: `fmt(fmt(x)) == fmt(x)` for any valid `x` (idempotent).

### 1.1a Idiomatic layer

Lossless-canonical presentation decomposes into two layers:

- **Idiomatic** — syntax-usage normalization that preserves the node tree
 AND the author's layout: the quote hierarchy (§2.3), glued type annotations
 (`name::T`), head-dispatch call form (`[$fn …]`), atom rendering, number
 formatting. A tool MAY apply only this layer (`cx fmt --profile=idiomatic`)
 to normalize syntax without reflowing whitespace.
- **Layout** — whitespace, indent, line-wrapping, blank-line policy (§2.1–2.2).

So `lossless canonical = idiomatic + a fixed, version-stable layout`, and
`strict canonical (§1.2) = lossless − presentation/comments + data
normalization`. Formatting is **presentation-only** — it never changes data or
the node tree (changing those is a *transform*, e.g. `[?modify]`). Named and
custom formatting profiles compose these layers declaratively; see
`formatting.md`.

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
error. See `../misc/parity-matrix.md` §Error policies.

### 1.4 Identity tiers

Content-addressed identity is two-tier; both tiers are first-class.

- **Tier 1 — data identity.** The strict canonical bytes (§1.2). This is the
  universal content-address: `cx hash`, signing, dedup, and equality all key on it.
  Strict canonicalization is type-driven — unordered constructs normalize
  (map keys, §2.11.1), ordered constructs are preserved (sequences/arrays §2.11.1,
  element attributes and children §2.1), and presentation is discarded (§2.8–2.9,
  §2.6–2.7). Tier-1 is always computed and is the storage/round-trip identity.

- **Tier 2 — code identity.** A *further* normalized identity for content-addressed
  CX code: binder-alpha-normalized, comment-insensitive, and
  dependency-resolved-by-hash, so semantically equal definitions collide regardless
  of bound-variable names or formatting. Tier-2 is an **additional** key, computed
  only in an opt-in code namespace, never conflated with Tier-1. Its normalization
  is defined normatively by [`code-identity.md`](code-identity.md); this section
  reserves the tier and its non-conflation guarantee.

Attribute order is **never** a normalization axis in either tier (§2.1).

---

## 2 — Text CX canonical (lossless)

The `cx fmt` command produces lossless canonical text CX. All rules below
apply.

### 2.1 Element ordering

| Aspect | Rule |
|---|---|
| Top-level node order | Source order; never reordered. |
| Children of an element | Source order; never reordered. |
| ElementMeta order within an element | `AnchorDef? MergeRef? IdDecl? TypeAnnotation? Attribute*` (per grammar [51]). |
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

Quoting follows the **idiomatic hierarchy** `bare > single > double` (§1.1a):
prefer no quotes; quote with single quotes when needed; use double quotes only
when they avoid escaping a `'`. Triple-quoting is reserved for multiline values.

| Aspect | Rule |
|---|---|
| Bare strings | Used when value is BareChar-eligible (no whitespace, `[`, `]`, `=`, `'`, `"`) AND does not match an auto-typing literal — the lexicon's full auto-typing set: number (including underscore-grouped and over-i64 bigint forms), bool, null, date, datetime, duration, period, atom, hex. A string whose bare image would re-parse as any typed scalar quotes, in every position (element body, attribute value, collection item, map value). |
| Single-quoted | `'...'` — the default form when quoting is required (value contains whitespace/special chars, or matches an auto-typing literal). |
| Double-quoted | `"..."` — used when the value contains a `'` but no `"`, so the apostrophe need not be escaped (e.g. `"can't"`). A value that is only a `'` is `"'"`. |
| Both `'` and `"` | Single-quoted with `\'` escape (the `"` needs no escape inside `'...'`) — the disambiguating tiebreak. |
| Triple-quoted | `'''...'''` — ONLY for values containing literal newlines OR consecutive whitespace. The parser also accepts `"""..."""` (lookahead-on-close §2.10.1); canonicalization rewrites it to `'''...'''`. NOT used merely to avoid an apostrophe escape — that case is double-quoted. |
| Empty string | `''`. |

### 2.4 Escape sequences

Within single-/double-quoted text, the following escapes are emitted (triple-
quoted content is verbatim — §2.10.1 — and uses no escapes):

| Char | Escape |
|---|---|
| `\` | `\\` **only when re-escape is required for round-trip** (see below); otherwise verbatim |
| Active delimiter (`'` in `'...'`, `"` in `"..."`) | `\'` / `\"` |
| LF (U+000A) | `\n` |
| CR (U+000D) | `\r` |
| Tab (U+0009) | `\t` |
| Other C0 controls (U+0000–U+001F except above) | `\u00XX` |
| DEL (U+007F) | `` |
| Other characters (including all printable Unicode) | Verbatim, as UTF-8. |

**Minimal backslash re-escape (bijection rule).** The parser's escape decode is
*lenient* (`lexicon.ebnf` §5 [L32], `code.md` §3.7): a backslash followed by a
byte that is NOT a recognized escape initial (`\ ' " n r t u U`) is kept
verbatim — both bytes survive — so regex patterns such as `'\d+'`, `'\w'`,
`'\.'` round-trip without doubling. Canonical emit mirrors this: a literal
backslash is doubled (`\\`) **only** when the following byte would otherwise be
consumed as the start of a recognized escape, or when the backslash is the final
byte of the content (where it would pair with the closing delimiter). A
backslash the parser would pass through verbatim is emitted unchanged. This is
the minimal re-escape that guarantees `parse(emit(x)) ≡ x` (conversions.md §1)
for every string scalar — including a value obtained by reading a *verbatim*
triple-quoted literal whose bytes contain `\` — while keeping the verbatim regex
surface intact. A blanket `\` → `\\` would be value-preserving too, but would
needlessly rewrite every regex literal (`'\d+'` → `'\\d+'`) and is therefore NOT
canonical.

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
| Boolean attribute | `name=true` / `name=false`. The `+name` / `-name` boolean-flag sigil is removed and never emitted in canonical. |
| Null | `null` (lowercase). |
| Date | `YYYY-MM-DD` per ISO 8601. |
| Datetime (lossless) | `YYYY-MM-DDTHH:MM:SS[.fff][Z\|±HH:MM]` exactly as in source, with offset preserved. Fractional seconds emitted only if present in source; trailing zeros stripped. |
| Datetime (strict) | Normalized to UTC: `YYYY-MM-DDTHH:MM:SS[.fff]Z`. Original offset is discarded. |

### 2.7 Type annotations

| Aspect | Rule |
|---|---|
| Form | Glued double-colon, long names only: `name::T` where `T` is any TypeName per [`grammar.ebnf` [26a]](../formal/grammar.ebnf) (the 9 semantic kinds plus storage-precision refinements `decimal`, `bigint`, `i8..i64`, `u8..u64`, `f16/f32/f64`, `duration`, `instant`). |
| Array marker | `::string[]`, `::int[]`, etc. The bare `::[]` (inferred array) is canonicalized to its concrete form: emitter resolves the inferred type and emits the explicit annotation. |
| Position | Glued to the element-head / attribute / param name (`name::T`). |

### 2.7a Namespace declarations and prefix usage

**Lossless canonical:** xmlns declarations and prefixed names preserved exactly in source form and source order.

**Strict canonical:** xmlns declaration order and prefix usage are
canonicalized per `cxdm.md §3` so that
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
| Idempotence | Running on input whose IDs already match `id-1`, `id-2`... in document order produces the same output. |
| XML emission | The same `id-N` names round-trip through `xml:id` / matching attribute values per `identity.md`. |

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
 resolved content (same as the Resolved AST step in `ast.md`).
- Each MergeRef is replaced by inlining the merged attributes and items into
 the host element, with host-element values overriding merged values per the
 grammar's merge semantics.
- AnchorDef nodes are removed.
- The result is a tree with no `&`, `*`, or `[*]` references.

### 2.9 Comments, directives, processing instructions

**Lossless canonical:** preserved.

- Comments emitted as `[; text ]` with internal whitespace unchanged.
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
| TripleQuoted (`'''...'''` or `"""..."""`) | Used in canonical when content contains literal newlines or characters that would require many escapes in `'...'`. Both delimiter styles obey the §2.10.1 lookahead-on-close rule for closing the literal. |

### 2.10.1 Triple-quoted close rule (lookahead-on-close)

A triple-quoted string (`'''...'''` or `"""..."""`) closes at the LAST
occurrence of the triple-delimiter within any maximal run of the delimiter
character.

Equivalently — operational definition: when the lexer encounters the
triple-delimiter, it peeks one byte further; if that byte is the same
delimiter character, the matched triple is treated as **content** (advance
one byte and continue scanning) rather than as **close**. The scan does not
close until the byte following the triple is something other than the
delimiter (or EOF).

This makes content containing trailing delimiters expressible without
escapes (which triple-quoted forms otherwise lack), and lets the data
parser round-trip strings emitted by the code-render emitter that contain
both `'` and `"` and end with the chosen outer delimiter — e.g.
`"""hello""""` parses as content `hello"`, `'''hello''''` as `hello'`.

The rule is symmetric across the two delimiter styles. It is the data
parser's responsibility; emitters need not pre-escape trailing delimiters
in the triple-quoted form.

### 2.11 Collection literals *(v1.1)*

CXDM v1.1 Sequence, Array, and Map Items (per grammar [56] /
§D14) canonicalize as follows. The rules apply identically in
lossless and strict canonical forms unless noted.

| Form | Canonical syntax | Empty |
|---|---|---|
| Sequence | `(item, item, item)` — single space after each comma, no space before; no space inside outer parens | `` |
| Array | `[item, item, item]` — same spacing as Sequence | `[]` |
| Map | `{key: value, key: value}` — single space after `:` and after `,`; no space before `:`; no space inside braces | `{}` |

Items inside collections canonicalize per their own canonical form
(§2.1–§2.10 + recursive §2.11). Nested arrays/maps canonicalize
recursively. Sequences boxed as Items inside an Array or Map value
(Sequence-as-Item per CXDM §2.7) canonicalize as `(…)` and remain
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

This canonical map-key ordering is **normative for content-addressed
identity**: a content-addressed store hashes a map's entries in this order, so
two maps with the same entries written in any source order address to the same
object (order-normalized dedup). Sequences and Arrays remain order-significant
(§2.1) — their item order is part of their identity.

### 2.11.2 Trailing commas

| Aspect | Rule |
|---|---|
| Source-text acceptance | Permitted (per grammar [56d] / [56e]) |
| Lossless canonical emit | Omitted |
| Strict canonical emit | Omitted |
| Empty collections | No comma (`` / `[]` / `{}`) |

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

### 2.12 PathNode canonical form

The rules below specify the canonical text-CX surface a renderer MUST
emit when round-tripping a PathNode value. The rules apply identically
in lossless and strict canonical forms; PathNode has no
presentation-vs-data split because all of its fields are data-bearing
and do not participate in equality or canonical emit.

#### 2.12.1 Statement of intent

A PathNode MUST round-trip to the **terse form** whenever an
equivalent terse form is producible from the AST. The general form
is canonical **only** when no terse equivalent exists. This is the
strongest reading of
and: the
canonical renderer is expected to recognise atomic templates on
the PredicateExpr AST and prefer their terse spelling on output.

#### 2.12.2 Form discriminator — leading-token emit rules

The PathNode `form` field (per [`ast.md` PathNode](ast.md))
maps to the leading-token emission as follows:

| `form` field | Canonical lead | Source surface |
|---|---|---|
| `descendant` | `//` | `//user` |
| `absolute` | `/` | `/root/item` |
| `relative` | (none — bare first step) | `user/email` |
| `binding` | `$name/` where `name` is the `binding` field | `$u/name` |

The four discriminator values are exhaustive (grammar [130] + [135]).
For `form = "binding"` the `binding` field carries the bound
identifier without `$`; the renderer prefixes `$` and the inter-step
`/` separator before emitting the first step.

#### 2.12.3 Axis emit rules

The default axis (`child`) is **omitted** on output; every other
axis emits as the explicit `axis::` prefix. The `attribute` axis has
a dedicated `@` sigil (grammar [133]) — that sigil is the canonical
terse form.

| Step `axis` field | Canonical emit | Notes |
|---|---|---|
| `child` | (axis omitted) | `child::user` → `user` |
| `attribute` | `@` sigil | `attribute::name` → `@name` |
| `descendant`, `descendant-or-self`, `parent`, `ancestor`, `ancestor-or-self`, `following-sibling`, `preceding-sibling`, `following`, `preceding`, `self` | `axis::` verbatim | `ancestor::section` |

The ten non-default, non-attribute axes (all of XPath 3.1's axis set
per grammar [131a]) emit their full `axis::` spelling. There is no
shorter terse form for these axes.

#### 2.12.4 Node-test emit rules

| Step `node_test` field | Canonical emit |
|---|---|
| `Name` (bare identifier) | the name verbatim |
| `Prefix:LocalName` (QName) | the QName verbatim |
| `*` | `*` |
| `*:LocalName` | `*:LocalName` verbatim |
| `Prefix:*` | `Prefix:*` verbatim |
| `node`, `text`, `element`, `attribute` | the kind-test verbatim, including the trailing `` |

Kind tests retain their parentheses on output; the test name carries
no canonical alternative spelling.

#### 2.12.5 Predicate emit rules

Each predicate in a step's `predicates` array emits as written
(code.md §5.5.2): the notation atoms (attribute existence / absence /
integer positional / step existence) keep their atom spellings, a
general body emits as its canonical prefix form with FUSED brackets
(the predicate's brackets are the form's brackets — never `[[…]]`),
and there is NO template-preferring rewrite in either direction —
the former terse-form re-emit rule was retired with the grammar
[132]–[134] predicate sublanguage. A canonical renderer MUST
round-trip every predicate bit-for-bit.

Top-level (whole-path) predicates from the PathNode's
`predicates` array (rare; see [`ast.md` PathNode](ast.md))
emit using the same `[BODY]` rule, appended after the final step.

#### 2.12.6 Step separator and whitespace

| Aspect | Rule |
|---|---|
| Inter-step separator | `/` between every pair of `steps` entries. |
| Whitespace inside the path expression | None. Zero ASCII spaces between any two tokens of a PathNode emit. |
| Whitespace before / after the path expression | Governed by the surrounding context (e.g. inside a `[?for]` directive body); the PathNode itself emits a token stream with no internal whitespace. |

This is the strictest whitespace policy in this document; PathNode's
identity-equality rule (D9 below) requires byte-identical canonical
strings for AST-equal values, and any optional whitespace would
break that property.

#### 2.12.7 Identity round-trip guarantee

For any two PathNode values **A** and **B**, if `A.eq(B) == true`
under the
equality rule (form, binding, steps pairwise on axis / node-test /
predicates, top-level predicates — `source` and `loc` excluded),
then the canonical emit of A and the canonical emit of B MUST be
**byte-identical** strings.

This is the strongest reading of the round-trip rule and the
anchor PathNode contributes to the content-hash contract of §11.4:
`hash(x) == hash(y)` whenever the strict-canonical bytes match,
and PathNode subtrees never introduce a divergence the equality
rule does not also recognise.

The reverse direction also holds by construction: two PathNode
values whose canonical emit is byte-identical parse back to AST-
equal values, because every field that participates in equality
also participates in canonical emit (and vice versa — `source`
and `loc` are emit-excluded **and** equality-excluded).

#### 2.12.8 Worked examples

| Input AST shape | Canonical emit | Why |
|---|---|---|
| `form=descendant`, step `(child, user, [])` | `//user` | `child` axis omitted (§2.12.3); bare-name node-test (§2.12.4); descendant `//` lead (§2.12.2). |
| `form=descendant`, step `(child, user, [PredicateExpr matching atomic AttrTest @active])` | `//user[@active]` | Attribute-existence atomic template. |
| `form=descendant`, steps `[(descendant-or-self, node, []), (child, user, [])]` | `//user` | Axis + kind-test pair `descendant-or-self::node/child::user` is the canonical desugaring of `//user`. The reverse-collapsed AST shape SHOULD be normalised by the parser to the single-step descendant form, but the renderer MUST emit `//user` either way. |
| `form=binding`, `binding="u"`, step `(child, email, [])` | `$u/email` | Binding form (§2.12.2); `child` axis omitted; bare-name node-test. |
| `form=absolute`, steps `[(child, root, []), (child, item, [PredicateExpr matching atomic INT 3])]` | `/root/item[3]` | Absolute lead (§2.12.2); positional atomic template. |
| `form=descendant`, step `(attribute, name, [])` | `//@name` | Attribute axis terse form (§2.12.3) is `@name`; the leading `//` then prefixes it. |
| `form=descendant`, step `(child, user, [PredicateExpr non-atomic: `[and $_@active $_@verified]`])` | `//user[and $_@active $_@verified]` | General predicate form (no atomic template match. Whitespace inside the predicate body follows the body's own canonical rules (this section governs only the PathNode-level whitespace policy). |
| `form=binding`, `binding="t"`, steps `[(child, member, [PredicateExpr `[= $_@role "lead"]`])]` with `[bind ...]` clause-child on the outer step | `$t/member[= $_@role "lead"]` | Binding lead; `[bind ...]` clause-children attached to a step emit; an AttrTest-template AST emits the prefix comparison form (`= $_@role "lead"` fused into the predicate brackets, [`code.md` §5.5.2](code.md) — the infix terse form is retired, grammar [132]–[134]) — implementations MUST check the AST shape, not the surface. |

The seventh and eighth examples show the general-form fall-through. The third example shows
the canonical-desugaring collapse the renderer is required to
perform.

#### 2.12.9 Cross-references

- [`ast.md` PathNode](ast.md) — struct field definitions the
 renderer consumes (`form`, `binding`, `steps[].axis`,
 `steps[].node_test`, `steps[].predicates`, `predicates`).
- [`grammar.ebnf` productions [130]–[135]](../formal/grammar.ebnf) —
 the surface forms canonical emit must produce.
- Atomic-predicate desugaring + canonical-render template table.
- §11.4 — content-hash contract PathNode inherits.

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
binary form. See `data-bin.md` for the full byte-level format. Canonical
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
to binary per `data-bin.md`. The binary form is the strict canonical
serialization in compact bytes.

---

## 5 — JSON emission canonical

Used by `cx --to-json --canonical`. CX → semantic JSON is intrinsically lossy
(see `conversions.md` §2.2); these rules govern only how the lossy
projection is canonicalized.

| Aspect | Rule |
|---|---|
| Whitespace | None between tokens (compact). Pretty-printed JSON is non-canonical. |
| Object key order (Element attrs) | Insertion order from CX source; never sorted. |
| Object key order (Map Items, v1.1) | **Lexicographic Unicode order** of the string-coerced canonical key per §2.11.1 (non-string keys coerce to strings on JSON emit per `conversions.md`; the sort order is the lexicographic order of the coerced string form). |
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
`[table[ ... ]` block (or whose strict-canonical projection reduces
to one).

| Aspect | Rule |
|---|---|
| Header row | One row, column names in `[table[ ... ]` declaration order. |
| Field delimiter | `,` (CSV), `\t` (TSV), `\|` (PSV). |
| Quoting | RFC 4180: a field is quoted with `"..."` if and only if it contains the field delimiter, a `"`, a CR, or an LF. Otherwise unquoted. |
| Escape within quoted fields | `"` doubled to `""`. No backslash escapes. |
| Line ending | LF. Never CRLF, regardless of operating system. |
| BOM | None at start of output. |
| Trailing line ending | One LF after the final row. |
| Empty cell | Empty (zero bytes between delimiters), not the literal string `""` unless the source value is the literal empty string. |
| Boolean | `true` or `false` (lowercase). |
| Null | Empty cell. (Distinct from empty string only via the `::null` type annotation in the source schema, which is lost in CSV.) |
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

The cross-binding parity matrix (`../misc/parity-matrix.md` §Conformance) tests
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
**runtime value model** that CXPath and CX code operate over
is specified in [`cxdm.md`](cxdm.md).

The two are related but distinct:

- **Canonical form (this spec)** governs byte output: ordering,
 whitespace, quoting, number formatting. It applies to source
 documents, schemas, CX code, and any other CX artifact
 uniformly.
- **CXDM (`cxdm.md`)** governs the in-memory value semantics an
 evaluator manipulates: sequences, items, equality, EBV, type
 coercion. Sequence-flat: every value is a sequence; single values
 are sequences of one; empty results are sequences of zero.

CXPath result types (sequences of Elements per [`code.md` §5.5](code.md))
already operate per CXDM; CXDM v1 formalizes this so the program evaluator can build on a stable value-semantics
commitment. The sequence-flat model is locked at as part of
the format-stability boundary; retrofitting it later would be a
breaking change.

Canonical scalar formatting (§2.5, §2.6) is the formatting used when
CXDM emits a Scalar Item via `[?=...]` interpolation or as the
serialization of a CX code evaluation result. The two specs agree by
construction on every scalar representation.
