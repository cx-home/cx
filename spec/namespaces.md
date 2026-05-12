# CX Namespaces

**Version:** 1.0 — 2026-05-08
**Status:** v0.6.0 (V core + 9-binding accessors + CXPath ns-aware predicates + canonical-form prefix-resolution shipping)

CX adopts XML-style scoped namespaces. This spec records the syntax,
the resolution model, the conversion behavior across formats, and the
implementation contract for parsers, emitters, and bindings.

---

## 1. Syntax

### 1.1 Prefix declaration

```cx
[doc xmlns:dc=http://purl.org/dc/elements/1.1/
 [dc:title CX Spec]
]
```

`xmlns:prefix=URI` declares a namespace binding scoped to the
declaring element and all of its descendants until a redeclaration
ends the scope.

### 1.2 Default namespace

```cx
[doc xmlns=urn:doc
 [section ...]
]
```

`xmlns=URI` declares a default namespace. Applies to the declaring
element and to all unprefixed descendants until redeclared. Per
XML Namespaces 1.0 §6.2 it does **not** apply to attribute names.

### 1.3 Prefixed names

```cx
[ns:elem ns:attr=value body]
```

A name of the form `prefix:local` is an element or attribute whose
prefix is to be resolved against the in-scope binding. The first
colon delimits prefix from local part. Names without a colon have an
empty prefix; for elements the default namespace applies.

### 1.4 Reserved prefixes

| Prefix | URI | Notes |
| ------- | -------------------------------------------- | ---------------------------------- |
| `xml` | `http://www.w3.org/XML/1998/namespace` | XML built-in; always resolves |
| `cx` | `https://cx-home.org/ns/cx` | CX metadata; cannot be redeclared |
| `xmlns` | declaration syntax only | Never resolves as a name prefix |

`xml:lang` is accepted as an alias for `cx:lang` on XML import per
[`spec/i18n.md`](i18n.md). `xml:space` is a deliberate non-feature
per `ROADMAP.md`.

### 1.5 Empty-URI undeclaration

`xmlns=""` undeclares the default namespace for the declaring element
and its unprefixed descendants until the next redeclaration. The
declaring element's expanded name has no namespace.

---

## 2. Resolution model

CX resolves namespaces at parse time. After parsing every Document,
the parser invokes `resolve_namespaces(doc)` which walks the tree
and populates two fields on every `Element` and `Attribute`:

- `local` — the part after the first `:` in the source name, or the
 whole name if no colon appears.
- `ns_uri` — the resolved URI (an `?string`); `none` when no binding
 is in scope and the prefix is not reserved.

The source-form `name` is preserved verbatim. Round-trip emit uses
`name`; resolved equality uses `(ns_uri, local)`.

### 2.1 Scope stack

Resolution walks the document depth-first. At each element entry:

1. Scan `attrs` for `xmlns` and `xmlns:prefix` declarations and
 build a frame `{prefix → URI}`. The empty key represents the
 default namespace.
2. Push the frame on the scope stack if non-empty.
3. Resolve the element's prefix against the stack (innermost first).
4. Resolve each attribute's prefix.
5. Recurse into element children.
6. Pop the frame.

### 2.2 Element resolution

| Source name | Default ns in scope | Result |
| ------------------ | ------------------- | ----------------------------------- |
| `prefix:local` | (irrelevant) | `(URI of prefix, local)` or unbound |
| `local` | `urn:foo` | `(urn:foo, local)` |
| `local` | none | `(none, local)` |
| `xml:local` | (irrelevant) | `(http://w3.org/XML/1998/ns, local)`|
| `cx:local` | (irrelevant) | `(https://cx-home.org/ns/cx, local)`|

If `prefix:local` is used with no in-scope binding for `prefix` and
`prefix` is not reserved, `ns_uri` stays `none`. CX does not error;
the colon-bearing name passes through. Adopters that want strict
validation can layer that on top (cx lint L004 candidate, future).

### 2.3 Attribute resolution

Per XML Namespaces 1.0 §6.2, the default namespace does **not**
apply to attribute names. Unprefixed attributes always have
`ns_uri = none`. Prefixed attributes resolve identically to elements.

`xmlns` and `xmlns:*` declaration attributes are passed through with
`ns_uri = none` — they are declarations, not data.

### 2.4 Idempotence

`resolve_namespaces` is idempotent: calling it twice produces the
same tree. Implementations may call it after any AST mutation that
adds, removes, or reorders xmlns declarations.

---

## 3. Equality and canonical form

### 3.1 Equality (`cx eq`)

Two elements are equal when their `(ns_uri, local)` pairs match and
all corresponding attributes match (with the same expanded-name
rule). Source prefix choice is **not** part of equality. A document
that declares `xmlns:foo=urn:x` and uses `foo:bar` is equal to one
that declares `xmlns:bar=urn:x` and uses `bar:bar` — both expand to
`(urn:x, bar)`.

### 3.2 Canonical form

`cx canonical` (strict canonical) emits:

- Namespace declarations sorted at each declaration site:
 default-namespace declaration (`xmlns=...`) first when present,
 then `xmlns:prefix=...` declarations in lexicographic order by
 prefix.
- Non-xmlns attributes preserved in source order, after the sorted
 xmlns block within the same element. (This is the only deviation
 from `spec/canonical.md §2.1`'s "attribute order = source order"
 rule, scoped to xmlns declarations only — required for
 cross-document hash equality.)
- A canonical prefix per URI: when multiple in-scope prefixes alias
 the same URI, the lex-smallest non-empty prefix wins.
 Element-name and prefixed-attribute usage sites are rewritten to
 the canonical prefix; the xmlns declarations themselves are
 preserved (they carry the URI mapping the consumer round-trips).
- Reserved `xml:` and `cx:` prefixes resolve unconditionally; they
 never appear as xmlns declarations on emit, but they participate
 in the canonical-prefix ranking when a document happens to alias
 the XML or CX URIs.
- Default-namespace declarations preserved (canonical form retains
 scope structure to keep canonicalization local). The empty key
 (default-namespace) never wins the canonical-prefix ranking — the
 default ns doesn't apply to attributes, so canonicalizing
 prefixed usage sites onto the default-ns key would corrupt
 attribute namespacing.

The implementation of these rules lives in
`vcx/cx/namespaces.v::canonicalize_namespaces`, run from
`cx_text_canonical` after the presentation-strip pass per
`spec/canonical.md §2.8`. Canonical form is idempotent.

This matches XML-C14N's expanded-name equality rule.

---

## 4. Conversion across formats

### 4.1 CX → XML

Round-trip lossless. `xmlns` and `xmlns:prefix` attributes are
emitted verbatim. Prefixed element and attribute names emit with
their source prefix. The post-parse-resolved expanded name is not
needed for emission since CX preserves source `name`.

### 4.2 XML → CX

`xmlns="URI"` and `xmlns:prefix="URI"` map to literal CX attributes
of the same name. Prefixed element/attribute names retain their
prefix. The post-parse `resolve_namespaces` pass populates `ns_uri`
on the AST.

### 4.3 CX → JSON / YAML / TOML

Per, prefixed names flatten to the literal `prefix:local`
string. The URI is **not** preserved in these formats since they
have no namespace concept. Adopters who need URI-fidelity in JSON
must use the future output-shape control mechanism (ROADMAP §6).

`xmlns` and `xmlns:*` declarations flatten as ordinary string-valued
attributes. They are not interpreted on JSON/YAML/TOML import.

### 4.4 CX → Markdown

Same as JSON. Prefixed names flatten; declarations strip during
emit since Markdown has no facility for them.

### 4.5 JSON / YAML / TOML / MD → CX

Imported documents have no namespace declarations and no resolved
`ns_uri`. A name with an embedded colon imports as a literal name
with that colon. The `resolve_namespaces` pass runs but finds no
declarations, so all names have `ns_uri = none`.

If the resulting CX is then emitted to XML with no
xmlns declarations, the output XML is *not* namespace-aware. To
re-namespace an imported document the caller must add `xmlns:prefix`
attributes explicitly.

### 4.6 CX ↔ ast_bin and data_bin

`ast_bin` carries source `name` verbatim. After load, decoders run
`resolve_namespaces` to repopulate `ns_uri` from the in-scope
xmlns declarations preserved as attributes. `data_bin` is a
semantic-data projection and uses `name` as the key per
[`spec/data_bin.md`](data_bin.md) §3.

---

## 5. Implementation contract

V core (this implementation) ships:

- `cx.Element.{name, local, ns_uri}` and
 `cx.Attribute.{name, local, ns_uri}` populated post-parse.
- `cx.resolve_namespaces(mut doc)` callable as a public function.
- `cx.xml_namespace_uri` and `cx.cx_namespace_uri` exported
 constants.
- Reserved-prefix handling: `xml:` and `cx:` always resolve to
 their fixed URIs regardless of declarations.

Bindings (shipped 2026-05-08, Phase 7.58): each of the 9 bindings
(Python, Go, Rust, TypeScript, Java, Kotlin, Swift, C#, Ruby)
implements `resolve_namespaces` in-language (~50 LOC scope-stack
walk mirroring `vcx/cx/namespaces.v`) and wires it into all 6
binding-side parse entry points (`parse`, `parse_xml`, `parse_json`,
`parse_yaml`, `parse_toml`, `parse_md`). Each public `Element`/
`Attribute` API exposes the source-form `name` (back-compatible) and
adds accessors `localName()` / `namespaceUri()` returning the
resolved fields. Naming follows language idiom: `local_name` /
`namespace_uri` (snake_case) for Python, Rust, Ruby; `LocalName` /
`NamespaceURI` (PascalCase) for Go; `localName()` / `namespaceUri()`
(camelCase) for TypeScript, Java, Kotlin, Swift, C#. The wire format
(ast_bin) does not change for this release; bindings re-resolve
on load.

Tooling shipping in v0.6.0:

- `cx canonical` emits the canonical-form rules in §3.2 — V core
 `canonicalize_namespaces` runs after the presentation strip pass.
 Conformance: `conformance/namespaces.txt` ns-013 through ns-016.
- CXPath gains namespace-aware predicates per
 [`spec/cxpath.md`](cxpath.md) §Namespace-aware queries: prefixed
 name tests resolve via the document's xmlns map (first-occurrence
 wins; reserved `xml:` and `cx:` always available), plus
 `local-name()` and `namespace-uri()` predicate functions for
 cross-prefix queries. Conformance: `vcx/tests/ns_cxpath/cxpath_test.v`.
- `cx eq` and `cx hash` use the canonical form above and therefore
 hash to the same value for two semantically equal documents
 regardless of prefix choice.

Future tooling that builds on this:

- `cx lint` will gain a check for unbound prefixes (proposed L004 —
 current L004 is dangling-alias; namespace check is a candidate
 for the next batch of lint rules).
- `cx validate` (schema validator, separate work item)
 can constrain attribute namespaces.

---

## 6. Examples

### 6.1 Default namespace + scoped redeclaration

```cx
[html xmlns=http://www.w3.org/1999/xhtml
 [body
 [svg xmlns=http://www.w3.org/2000/svg
 [circle r=10]
 ]
 ]
]
```

After resolution:

- `html.ns_uri = http://www.w3.org/1999/xhtml`
- `body.ns_uri = http://www.w3.org/1999/xhtml` (inherited)
- `svg.ns_uri = http://www.w3.org/2000/svg`
- `circle.ns_uri = http://www.w3.org/2000/svg` (inherited)

### 6.2 Multiple prefixes

```cx
[chapter xmlns=urn:doc
 xmlns:dc=http://purl.org/dc/elements/1.1/
 xmlns:xl=http://www.w3.org/1999/xlink
 [dc:title Intro]
 [xl:link href=https://example.com See here]
]
```

After resolution:

- `chapter.ns_uri = urn:doc`
- `dc:title.ns_uri = http://purl.org/dc/elements/1.1/`, `local=title`
- `xl:link.ns_uri = http://www.w3.org/1999/xlink`, `local=link`
- `href` (unprefixed attr, no ns per §2.3): `ns_uri=none`

### 6.3 Reserved xml: prefix

```cx
[doc xml:base=https://example.com content]
```

Even without an `xmlns:xml=...` declaration:

- `xml:base.ns_uri = http://www.w3.org/XML/1998/namespace`

---

## 7. References

- — Namespaces (the
 decision record this spec implements)
- [`spec/grammar.ebnf`](grammar.ebnf) — productions for prefixed
 names and xmlns declarations
- [`spec/ast.md`](ast.md) — AST shape with the `ns_uri`/`local`
 fields
- [`spec/conversions.md`](conversions.md) — per-format conversion
 tables (referencing this document for the namespace dimension)
- W3C — *Namespaces in XML 1.0 (Third Edition)* — the standard CX
 is mirroring
- `conformance/namespaces.txt` — 12-case behavior suite
