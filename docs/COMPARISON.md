# CX vs JSON, YAML, TOML, XML

This document is for people deciding whether to adopt CX. It compares CX
to the four formats it converts to and from, with honest assessments of
when CX is the right pick and when one of the others is a better fit.
There is no need to choose CX for everything; CX is designed to live
alongside these formats and convert losslessly between them.

If you've already picked CX and just want syntax, see
[`docs/CHEATSHEET.md`](CHEATSHEET.md).

---

## At a glance

| | CX | JSON | YAML | TOML | XML |
|---|---|---|---|---|---|
| Syntax weight | brackets, no closing tags | curly braces + brackets | indent-significant | tables + key=val | open + close tags |
| Strong types | ✅ int / float / bool / null / sized / decimal / bigint / date / datetime / bytes | ❌ number only (no int/float distinction) | partial (auto-detect, often wrong) | ✅ int / float / bool / datetime | partial (xs:type) |
| Comments | ✅ block `[- ... ]` and line `# ...` | ❌ | ✅ `# ...` | ✅ `# ...` | ✅ `<!-- ... -->` |
| Mixed content (markup + data) | ✅ first-class | ❌ | ❌ | ❌ | ✅ first-class |
| Multiple top-level docs | ✅ no wrapper required | ❌ requires `[...]` array | ✅ via `---` separator | ❌ single document | partial (with declaration tricks) |
| Attribute / element distinction | ✅ explicit | ❌ flat keys | ❌ flat keys | ❌ flat keys | ✅ explicit |
| Type fidelity through round-trip | ✅ guaranteed via CXDB v1 binary | ❌ int↔float coerced silently | partial | ✅ preserved | partial |
| Tabular data efficiency | ✅ `:table` block, columnar binary | ❌ verbose array-of-objects | ❌ verbose | partial (array of tables) | ❌ verbose |
| Streaming parser | ✅ pull-based handle API | partial (per-implementation) | ❌ usually whole-file | ❌ | ✅ SAX |

CX's specific advantages buy you something concrete: type fidelity for
typed config, mixed content + structured data in one file, lossless
six-way conversion, and a stable canonical form for hashing and
signing. The rest of this document walks through where CX wins against
each format individually.

---

## Conversion-loss matrix

CX advertises "lossless conversion" with each of the five formats it
interoperates with. *Lossless* here means **the data round-trips
without semantic loss**, but presentation details (comments,
whitespace, attribute order) can be normalized. This table is the
honest accounting of what survives, what gets normalized, and what's
genuinely lossy.

| CX → format → CX | Lossless? | What's preserved | What's normalized or lost |
| ---------------- | --------- | ---------------- | ------------------------- |
| CX → **JSON** → CX | data ✅ / presentation 📋 | Element shape, attributes, types (via CXDB), values, nesting | Comments dropped (JSON has none); element vs attribute distinction collapses to keys; ordered attribute groups become object keys |
| CX → **YAML** → CX | data ✅ / presentation 📋 | Element shape, types via explicit `!!tags`, multiline strings | Comments dropped by most parsers; flow-vs-block style normalized; anchor names rewritten |
| CX → **TOML** → CX | data ✅ / presentation 📋 | Element shape (via table headers), strong types | Comments dropped through most parsers; section ordering normalized; deeply nested data flattened to dotted keys |
| CX → **XML** → CX | data ✅ / presentation 📋 | Element shape, attributes, mixed content, namespaces, processing instructions | Whitespace between tags normalized per `xml:space`; entity references resolved; PI ordering preserved |
| CX → **Markdown** → CX | data 📋 / presentation 📋 | Headings, paragraphs, lists, emphasis, code blocks, links | Data-shaped elements (attribute-only, typed scalars) flatten to inline text — Markdown round-trips work *only* for document-shaped CX |
| CX → **CXDB** → CX | bytes ✅ | Everything, byte-for-byte | Nothing — CXDB *is* the strict-canonical form |
| CX → **CSV** → CX | data partial | `:table` block columns + rows | Non-table data can't be CSV-encoded; cell types lose subtyping (i8/i16/i32/i64 collapse to "int"); collection cells flatten to text |

### Cross-format round-trip via CXDB

The strict guarantee is **CX ↔ CXDB ↔ CX is byte-stable** (the bytes
*are* the canonical form). For the other five formats, the guarantee
is **data-equivalent**, verified by `cx eq`:

```sh
$ cx eq myfile.cx <(cx --json myfile.cx | cx --from=json)
$ echo $?     # 0 → data-equivalent (passes for JSON, YAML, TOML, XML)
```

`cx eq` is a *strict-canonical* comparison: comments, whitespace,
attribute order, and anchor names are not considered.

### What "presentation" means

Presentation-layer differences that conversions normalize away:

- **Comments.** Only XML and CX preserve comments across emit. JSON
  has none; YAML and TOML lose comments through most parsers.
- **Whitespace.** Indentation, blank lines, line endings are
  normalized to the target format's conventions.
- **Order of attribute groups.** `[user id=1 name=alice]` and
  `[user name=alice id=1]` are data-equivalent; emission may pick
  a canonical order.
- **Anchor names.** `&alpha` and `&beta` are anonymous handles;
  canonical form renumbers them.

These all show up as identical hashes via `cx hash` because the
hash operates on strict-canonical bytes, where presentation is
stripped.

### When CX → X is genuinely lossy

| Pair | What's lost | When it matters |
| ---- | ----------- | --------------- |
| CX → JSON | Element/attribute distinction, comments | Reverse-engineering CX-from-JSON loses the original structure |
| CX → YAML | Sized integer types (`:u16` becomes plain integer) | If the consumer needs to enforce `u16`-bound checks, you'd validate against the schema before YAML emit |
| CX → TOML | Mixed content (markup-inside-text) | TOML can't represent inline `[em ...]` in a string |
| CX → Markdown | Anything that isn't doc-shaped (typed scalars, attributes) | Markdown is for the doc-shaped CX subset only |
| CX → CSV | Anything that isn't `:table`-shaped | CSV is tabular-only |

For these lossy cases, CXDB or CX text is the source of truth; the
lossy format is a downstream consumer.

---

## CX vs JSON

JSON is the lingua franca of API data exchange. CX is not trying to
replace it for that role.

### Similarities

Both are tree-shaped, support nested objects + arrays + scalars, and
have the same notion of basic types (string / bool / null + number).

### Where CX wins

- **Integer vs float distinction.** JSON says `"port": 8080` and you
 get back `8080.0` from many parsers (Python's `json` is one of the
 good ones; many aren't). CX's `[port :int 8080]` round-trips as
 `int`, every time, in every binding.
- **Comments.** JSON famously has none. CX has both block and line.
- **Larger types.** CX's `:decimal`, `:bigint`, `:u64`, etc. don't
 exist in JSON.
- **Mixed content.** `[p Hello [strong world]]` is natural in CX and
 awkward in JSON (`{"p": ["Hello", {"strong": "world"}]}` —
 ambiguous order).

### Where JSON wins

- **Universal tooling.** Every language has a parser. Every editor
 highlights it. Every API speaks it.
- **Smaller for purely-data payloads.** `{"a":1}` is shorter than
 `[a 1]` only by one character, but at scale the absence of typing
 metadata makes JSON output more compact.
- **Browsers parse it natively.** `JSON.parse(s)` is built in.

### Use JSON when

- You're talking to an external API.
- You need wire-format compactness above all.
- The consumer is a browser without a CX library.

### Use CX when

- Type fidelity through round-trips matters (financial, scientific,
 precision-critical data).
- You want to comment your config or your data.
- You need both markup and structured data in one file.

---

## CX vs YAML

YAML is the most common "human-friendly" config format. CX is in
direct competition for this niche.

### Similarities

Both target human readability. Both support comments. Both have
typed scalars.

### Where CX wins

- **No indent semantics.** YAML's significant whitespace is famous
 for breaking under copy-paste, mixed tabs/spaces, and editor
 reflow. CX uses brackets — copy-paste anywhere, no whitespace
 anxiety.
- **No "Norway problem."** YAML's `country: NO` parses as boolean
 `false` in YAML 1.1 because `NO` is reserved. CX never does
 type-by-value-string magic in attribute positions: `country=NO`
 is the string `"NO"` unless you write `country :bool NO` and CX
 errors that out.
- **Strict types and sized integers.** YAML's `port: 8080` is "some
 number"; the schema decides. CX's `[port :u16 8080]` is checked
 at parse time.
- **Mixed content.** YAML can't represent `[p Hello [em world]]`
 cleanly.
- **Streaming.** YAML parsers typically read the whole file. CX has
 a handle-based pull API.
- **Canonical form.** CX has `cx canonical` + `cx hash` for stable
 content-addressable hashing. YAML has nothing like this without
 third-party tools.

### Where YAML wins

- **Massive ecosystem.** Kubernetes, Ansible, GitHub Actions, GitLab
 CI, almost every modern devops tool. If you're integrating with
 those, YAML is the lingua franca.
- **No brackets.** Some readers find indented YAML easier to scan
 than bracketed structures.
- **Multi-document files** (separated by `---`) are well-established.

### Use YAML when

- You're writing a Kubernetes manifest, GitHub Action, or similar
 pipeline file.
- Your team strongly prefers indent-based syntax.

### Use CX when

- You want config that doesn't break under copy-paste.
- You've been bitten by YAML's auto-detection corner cases.
- You need both config and embedded structured data (e.g., feature
 flags + their typed parameter sets) in one file.

---

## CX vs TOML

TOML is "Tom's Obvious Minimal Language" — designed specifically for
config files.

### Similarities

Both prioritize human readability for config. Both support comments.
Both have strong types including dates.

### Where CX wins

- **Multi-format conversion.** TOML doesn't convert to XML or
 Markdown. CX → TOML and TOML → CX both work; if you also need XML
 or HTML output, only CX provides that path.
- **Document markup.** TOML cannot represent mixed content. CX can.
- **Larger numeric types.** TOML has `int` and `float`. CX has sized
 variants (`u8`..`u64`, `i8`..`i64`, `f16`/`f32`/`f64`),
 `:decimal`, and `:bigint`.
- **Tabular data.** TOML's "array of tables" is a common pattern but
 requires repeating the table header. CX's `:table` block is more
 compact and has a column-major binary form.

### Where TOML wins

- **Even simpler for flat config.** `port = 8080` in TOML is shorter
 than `[port :int 8080]` in CX.
- **Mature tooling.** Used by Cargo, pyproject, many others.
- **Less syntax to learn.** TOML's grammar fits on a postcard.

### Use TOML when

- Your config is mostly flat key=value pairs.
- You're integrating with an ecosystem that already uses TOML
 (Cargo, Python's pyproject).

### Use CX when

- Your config has deeply nested structure (CX's brackets scale
 better than TOML's `[section.subsection.deeply.nested]` headers).
- You want config + documentation in one file.
- You need typed arrays of mixed types (`:[]`).

---

## CX vs XML

XML is the most direct comparison: bracket-shaped, supports mixed
content, has attributes vs elements as first-class concepts.

### Similarities

Both are tree-structured with element-and-attribute model. Both
support mixed content (text + child elements). Both support comments
and processing instructions. Both can carry document markup.

### Where CX wins

- **No closing tags.** `<server><host>localhost</host></server>` vs
 `[server [host localhost]]`. The verbosity savings are not just
 cosmetic — they reduce parse cost, file size, and reading
 fatigue.
- **Typed attributes natively.** XML's `<port>8080</port>` is a string
 unless XSD says otherwise. CX's `[port :int 8080]` is typed at the
 format level.
- **No mandatory quoting.** XML attributes must be quoted. CX
 attributes don't unless they contain whitespace or special
 characters.
- **No namespace gymnastics.** XML namespaces are notoriously hard
 to teach. CX has no namespaces (and doesn't need them for its
 use cases).
- **JSON / YAML / TOML round-trips.** XML has XSLT and various
 awkward path-based mappings to JSON. CX converts losslessly to all
 five via the `cx` CLI.

### Where XML wins

- **XSLT, XPath, XML Schema.** Decades of tooling for transformation,
 query, and validation. CX's CXPath is a small subset; CX's spec
 doesn't include schema yet.
- **Industry contracts.** SOAP, SAML, MathML, SVG, XHTML, Office Open
 XML — these are XML, period. Don't try to replace them.
- **Mature parser security.** XML's well-known attack surface (entity
 expansion, billion-laughs, XXE) is documented and defended in
 established parsers.

### Use XML when

- You're integrating with anything in the SOAP / SAML / SVG / Office
 ecosystem.
- Your data has a published XSD that defines its contract.
- You need XSLT-style transformations.

### Use CX when

- You like XML's element-and-attribute model but find the verbosity
 painful.
- You need to convert losslessly to JSON / YAML / TOML.
- Your "document" has both structured data and prose markup.

---

## Decision flowchart

```
 ┌──────────────────────────────────────┐
 │ What kind of file is this? │
 └──────────────┬───────────────────────┘
 │
 ┌─────────────┼─────────────┬──────────────┐
 │ │ │ │
 config data exchange markup mixed
 │ │ │ │
 ▼ ▼ ▼ ▼
TOML or CX JSON XML or CX CX
(or YAML if (or CX if (CX if you (CX is the
 ecosystem type fidelity want JSON only one
 pulls you) matters) round-trip) that handles
 this cleanly)
```

Decision rules:

- **Talking to external systems?** Use whatever they speak. JSON for
 most APIs, XML for SOAP/SAML/etc., YAML for Kubernetes-shaped
 things, TOML for Cargo-shaped things.
- **Internal config in a project you control?** TOML for flat,
 YAML for indent-people, CX for nested + typed + commented +
 documented.
- **Need to round-trip between formats with type fidelity and a
 stable hash?** CX is the only one that gives you all three.
- **Need both markup and data in the same file?** CX is the only
 one that does this without contortions.

---

## A concrete example

Same data, four ways:

```cx
# CX
[config :u16 port=8080
 [server host=localhost +tls]
 [- TLS is required in production]
 [allowed-origins :string[]
 https://app.example.com
 https://admin.example.com
 ]
]
```

```json
{
 "config": {
 "port": 8080,
 "server": { "host": "localhost", "tls": true },
 "allowed-origins": ["https://app.example.com", "https://admin.example.com"]
 }
}
```

```yaml
config:
 port: 8080
 server:
 host: localhost
 tls: true
 # TLS is required in production
 allowed-origins:
 - https://app.example.com
 - https://admin.example.com
```

```toml
[config]
port = 8080
allowed-origins = ["https://app.example.com", "https://admin.example.com"]

[config.server]
host = "localhost"
tls = true
# TLS is required in production
```

The CX form has explicit type annotation on `port`, an inline comment
about TLS, and a typed array. After a round-trip through any of the
other formats, the CX is *still* `[port :u16 8080]` (the type
annotation is preserved through the binary AST round-trip).

---

*See [`docs/CHEATSHEET.md`](CHEATSHEET.md) for syntax. See
[`spec/conversions.md`](../spec/conversions.md) for the formal
conversion contract per format pair. See
[`docs/FAQ.md`](FAQ.md) for the most common adoption questions.*
