# CX Tutorial — Why It's Shaped This Way

This is a guided introduction to CX that explains the *why* behind every
syntactic choice. It's longer than the
[cheatsheet](CHEATSHEET.md) on purpose: the cheatsheet shows you what
CX *is*, this tutorial shows you why it *takes that shape* and how to
use it well.

You should already be familiar with at least one of JSON, YAML, TOML,
or XML — CX assumes you know what an object, array, scalar, and
attribute are.

---

## 1 — The problem CX solves

Modern projects almost always have *two* kinds of files:

- **Config files** — typed scalars in nested structures. JSON / YAML /
 TOML are the usual choices.
- **Documents** — prose with embedded structure. Markdown / HTML / XML
 are the usual choices.

The traditional dividing line is real: the formats optimized for one
camp are awkward for the other. JSON cannot represent
`<p>Hello <strong>world</strong></p>` cleanly. XML cannot represent
`{"port": 8080}` without verbosity tax. So projects end up with
multiple file formats and multiple parsers, which means duplicate
schemas, duplicate validation, and duplicate emitters.

CX is one syntax for both kinds of file. Same parser, same grammar,
same trees in memory. The format is bracket-shaped (`[...]`) so it
inherits XML's strengths (mixed content, attribute/element
distinction) without inheriting XML's costs (closing tags, mandatory
quoting, namespace machinery).

The design constraints CX picked:

1. **One construct.** Every CX element is a `[...]` pair. No
 exceptions, no auxiliary syntax for sections, frontmatter, or
 block markers.
2. **No indentation semantics.** Whitespace doesn't change meaning.
 You can copy-paste anywhere without breaking the file.
3. **Optional, never required, quoting.** You quote a value when it
 contains whitespace or special characters; otherwise quotes are
 noise.
4. **Types are first-class.** `[port :int 8080]` says "this is an
 integer" at parse time, not "this is a number, the schema will
 tell you which kind."
5. **Lossless conversion to existing formats.** CX must convert
 to and from JSON / YAML / TOML / XML / Markdown without losing
 meaning; otherwise it's just adding to the format zoo.

Everything else in CX's syntax follows from those five constraints.
Let's walk through the syntax in that frame.

---

## 2 — Elements

The fundamental construct:

```cx
[name body content]
```

A pair of brackets, a name token, and an optional body. That's it.

Why brackets and not, say, indented blocks or `<tags>`?

- **Brackets work in any context.** Pasted into Slack, Markdown,
 source code comments — the `[...]` structure survives. Indented
 YAML loses its meaning the moment whitespace is mangled.
- **No closing tags to repeat.** XML's `<server>...</server>`
 duplicates `server` on every element. CX writes the name once. For
 a 1000-element document, that's 1000 fewer tokens.
- **The bracket pair is delimited.** Editors balance brackets
 natively. Code folding works without parser hooks.

Empty element:

```cx
[hr]
```

Element with text:

```cx
[p Hello]
[p Hello World] # multi-word body — whitespace inside body is preserved
```

Nested elements:

```cx
[outer
 [inner one]
 [inner two]
]
```

Multiple top-level elements — no wrapper required:

```cx
[title Page]
[body
 [p Content]
]
```

This last point matters: JSON requires `[...]` (an array) or `{...}`
(an object) to wrap multiple top-level items. CX simply lets the file
have multiple roots, which is closer to how Markdown or XML fragments
work in practice.

---

## 3 — Attributes

Inside a bracket, anything of the form `name=value` is an attribute.
Anything else (after the element name and before any nested elements)
is the body text.

```cx
[server host=localhost port=8080]
[a href=https://example.com Click here]
```

Why no quotes? Because the bracket itself is the delimiter. Inside
`[a href=https://example.com Click here]`, the parser finds:

- `a` — element name
- `href=https://example.com` — attribute (value runs until whitespace
 or `]`)
- `Click here` — body text

URLs with `?` and `&` work unquoted as long as no whitespace is
embedded. The most common attribute hazard in XML — having to escape
`&amp;` everywhere — disappears.

When you need quotes (for values containing whitespace or special
characters), use single quotes:

```cx
[user name='Alice Quinn' email='alice@example.com']
```

Triple-quoted strings for multi-line content with no
escaping:

```cx
[doc :string '''
This string can contain
"double quotes" and 'single quotes'
and even brackets [like this] verbatim.
''']
```

### Boolean attribute sigils

A frequent attribute pattern is "this flag is on / off." CX has
shorthand for that:

```cx
[user +admin -disabled]
```

Equivalent to:

```cx
[user admin=true disabled=false]
```

Read `+x` as "x is true" and `-x` as "x is false". Mixes freely with
plain attributes:

```cx
[user name=alice +admin -trial age=30]
```

---

## 4 — Comments

Two forms, because there are two situations:

```cx
[- this is a block comment, can span multiple tokens and lines ]
```

The block form (`[- ... ]`) is itself a bracketed construct, so it
nests comfortably inside elements. Use it for documentation that
should survive being passed through tools that parse and re-emit CX.

```cx
[server host=localhost # this is a line comment to end-of-line
 port=8080
]
```

The line form (`# ...`) exists because end-of-line comments are how
config files traditionally annotate config values.
The block form is preserved by `cx fmt`; the line form is also
preserved by `cx fmt` but stripped by `cx canonical` (because
comments are presentation, not data).

---

## 5 — Types and auto-typing

CX has a real type system at the syntactic level. This is the most
important difference from JSON / YAML.

### Auto-typing (the convenience)

When you write a bare value in a body or attribute slot, CX
auto-types it:

```cx
[port 8080] # body 8080 → int
[ratio 1.5] # body 1.5 → float
[active true] # body true → bool
[empty null] # body null → null
[name alice] # body alice → string (no other type matches)
[hex 0xFF] # body 0xFF → int 255
```

Auto-typing is conservative: anything that doesn't unambiguously
match int / float / bool / null is a string. There are no surprises
like YAML's "Norway problem" (where `NO` becomes `false`).

> **One subtle rule:** integers cannot have leading
> zeros. `[zip 02134]` is the string `"02134"`, not int 2134. This
> protects ZIP codes, zero-padded IDs, area codes — values that
> *look* numeric but are semantically strings.

### Explicit type annotations (the contract)

When you want to be explicit — for documentation, for type checking,
or to override auto-typing — annotate the type with `:`:

```cx
[port :int 8080] # explicit int
[ratio :float 1.5] # explicit float
[zip :string 02134] # force string (auto-typing would also produce string here)
[port :u16 8080] # sized: 16-bit unsigned
[fingerprint :bigint 340282366920938463463374607431768211456] # arbitrary precision
[balance :decimal 1234567.89] # exact decimal (no float rounding)
[birthday :date 1990-01-15]
[created :datetime 2026-05-07T10:30:00Z]
[blob :bytes 0xDEADBEEF]
```

The explicit annotation is preserved through round-trips. After
converting to JSON and back to CX, the `:u16` annotation survives if
your binding uses the binary AST path (which all 9 in-tree bindings
do).

### Why bother with `:u16`?

YAML and TOML have `int` and `float`, period. CX has sized variants
because:

- **Documentation.** `:u16 port` immediately tells a reader that the
 value is a 0..65535 port number.
- **Validation at load time.** If your binding's loader sees `:u16`
 and the value is `100000`, it errors at parse, not at runtime.
- **Round-trip fidelity.** Without `:u16`, a value like `40000`
 becomes a generic `int` after JSON round-trip; the original intent
 is lost.

You don't *have* to use sized types. Plain `:int` and `:float` work
fine for most cases. Use sized types when the size is part of your
data's contract.

---

## 6 — Arrays

CX has three array forms because there are three different array
situations.

### Typed homogeneous array

```cx
[ports :u16[] 80 443 8080]
[tags :string[] devops infra production]
```

`:T[]` declares the element type. The body is a whitespace-separated
sequence of values. Compact and obvious.

### Inferred-type array

When the elements are mixed types and you don't want to force one:

```cx
[mixed :[] 1 2.0 three true]
# values: int 1, float 2.0, string "three", bool true
```

`:[]` says "array, types per element." Each value is auto-typed
independently.

### Auto-array (sibling collection)

The most idiomatic form for *structured* lists:

```cx
[users
 [user id=1 name=alice]
 [user id=2 name=bob]
 [user id=3 name=carol]
]
```

This is a single `users` element containing three `user` children.
When emitted as JSON, the consecutive same-name children collapse
into an array:

```json
{
 "users": {
 "user": [
 {"id": 1, "name": "alice"},
 {"id": 2, "name": "bob"},
 {"id": 3, "name": "carol"}
 ]
 }
}
```

Why three forms instead of one? Because the *intent* differs:

- `:T[]` is for arrays of bare scalars: ports, tags, IDs.
- `:[]` is for arrays of mixed scalars when type-per-element is the
 point.
- Auto-arrays of named children are for collections of structured
 records.

Trying to force all three through one syntax (the way JSON does, with
`[ ... ]` for everything) makes the structured-record case verbose
and the bare-scalar case awkward.

### Tabular blocks

For wide-table data, CX has `:table`:

```cx
[stocks :table
 [columns ticker:string price:f64 volume:u32]
 [rows
 AAPL 192.45 38291092
 GOOG 142.30 18234567
 MSFT 415.18 23456789
 ]
]
```

The CX text form is row-major (one record per line). The binary form
(via `cx_to_data_bin`) is *column-major*: bit-packed booleans,
delta-encoded ints, per-column string dictionaries. For datasets
larger than ~10K rows, the binary table is 5–10× smaller than the
equivalent element-per-row form. See
[`spec/table_api.md`](../spec/table_api.md) for the detailed
encoding.

---

## 7 — Mixed content (the markup half)

This is where CX leaves JSON / YAML / TOML behind. An element body
can contain text *and* nested elements freely interleaved:

```cx
[p Plain text with [strong inline emphasis] and [em italics] mixed in.]
```

The body of `[p ...]` is a sequence: text fragment, `strong`
element, text fragment, `em` element, text fragment. JSON cannot
express this without an awkward `["Plain text...", {"strong": "..."}]`
wrapper that loses the meaning of "this is a paragraph with inline
emphasis."

This mixed-content capability is the reason CX can serve as both a
config and a document format: the same parser handles both.

```cx
[article lang=en
 [head
 [title Why CX?]
 [tags :string[] tutorial intro]
 ]
 [body
 [h1 Why CX?]
 [p CX unifies markup and data in [strong one] format.]
 [code [# [server :int port=8080] #]]
 ]
]
```

You can mix structured config-like elements (`[tags ...]`) with
document-like ones (`[p ...]`) in the same tree.

### Raw text blocks

Sometimes you need *literal* text that should not be parsed as CX —
code samples, embedded other languages, content with `[` and `]`
characters that aren't CX brackets. The raw-text block:

```cx
[code [# def hello():
 print("brackets [like this] won't be parsed")
#]]
```

`[#` opens the raw block; `#]` closes it. Everything in between is
copied verbatim into the element's body as a single text node.

### Triple-quoted strings

A lighter-weight alternative for multi-line strings:

```cx
[doc :string '''
This is a multi-line string.
"Quotes" don't need escaping.
Even [brackets] are fine inside.
''']
```

Three single quotes open, three close. No escaping needed inside.
Use raw-text blocks when you need brackets in body text without a
type annotation; use triple-quoted when you want a typed multi-line
string.

---

## 8 — Anchors, merges, and aliases

For configuration, you often want to define a base set of values
once and reuse them. CX has YAML-style anchors:

```cx
[server &default port=8080 host=localhost retries=3]
[server &prod *default host=prod.example.com]
[server *default] # alias: re-use as-is
```

- `&name` defines an anchor (a named reference point).
- `*name` aliases — re-use the named element.
- `&name *other` merges — start from `*other`'s attributes, then
 add/override with this element's attributes.

In the example, `&prod` has `port=8080 retries=3` (from `*default`)
and `host=prod.example.com` (overridden).

The merge model is well-defined for attributes; child elements are
not currently merged (a future minor version may add deep-merge as
an option).

### What anchors are *not*

Anchors / aliases / merges are **intra-document only** — they're a
shorthand for "the same attribute set, with overrides." They are
not:

- **Cross-document references.** An anchor declared in `base.cx`
 is not visible from `prod.cx`. If you need cross-document
 identity (e.g., "this `<order>` references that `<customer>`"),
 use ID / IDREF — see.
- **A type system.** A merge gives you the source's *attributes*,
 not its *type-shape*. There's no "instance of `Server`"
 relationship inferred. Type-shape constraints are a schema
 concern — see.
- **Late-bound.** Resolution happens at parse time. An alias to an
 anchor declared *after* it in document order is a forward
 reference and works, but only because the parser does a two-pass
 scan; the model is "all anchors visible everywhere within the
 document," not "first declaration wins" or "lexically scoped."

When you find yourself wanting cross-file reuse, the right tool is
either `[?cx include=...]` (file inclusion — splice content from
another file) or ID / IDREF (post-implementation, for actual
reference semantics).

If you only need attribute reuse within one file, anchors are the
right tool and there is nothing wrong with using them.

### File inclusion: `[?cx include=...]`

For splitting config across files — base configuration plus
per-environment overrides, secrets in a separate file, deployment
manifests composed from service-owned fragments — use the
`[?cx include=path]` directive:

```cx
[deployment env=production
 [?cx include=base.cx] # splice in the shared baseline
 [?cx include=secrets/prod.cx] # splice in environment secrets
 [server host=acme.com :u16 port=443 +tls] # local overrides
]
```

The parser resolves relative paths against the including file's
location. Includes can nest. Cycles are detected and reported as
parse errors. Each include is a one-time splice at parse time —
the result is one `Document` indistinguishable from a single
hand-written file.

Combine includes with anchors for the common config-management
shape: `base.cx` declares anchors; per-environment files include
`base.cx` and merge.

---

## 9 — Multi-document files and logfmt mode

A CX file can contain multiple top-level elements; that's how a
config file with multiple peer roots works. But there's a special
case for *streams* of small documents:

```
ts=2026-05-07T10:30:00Z level=info svc=api req_id=abc123 latency_ms=45
ts=2026-05-07T10:30:01Z level=warn svc=api req_id=def456 latency_ms=210 slow=true
ts=2026-05-07T10:30:02Z level=info svc=api req_id=ghi789 latency_ms=12
```

This is logfmt: each line is a sequence of `key=value` attributes
with no enclosing element. CX recognizes this pattern (top-level
attributes, no element wrapper) and parses each line as a synthetic
Element with the attributes attached.

Result: log streams are valid CX. You can `cx --json` a logfmt file
and get a JSON array of log records, type-fidelity-preserved.

Why is this in the format? Because logs are config-shaped data
emitted in a stream; if CX is a config format that can carry types,
it should be able to ingest typed log lines without a separate parser.

---

## 10 — Bringing it together: a realistic example

Here's a deployment manifest using most of CX's features:

```cx
[deployment :string env=production version=v1.2.3
 [- deployment configuration for the api service ]

 # ── server config ─────────────────────────────────────────────
 [server &base host=0.0.0.0 :u16 port=8080 +tls]
 [server &api *base path=/api/]
 [server &admin *base :u16 port=8081 path=/admin/]

 # ── feature flags ──────────────────────────────────────────────
 [features
 +signup -beta-ui +metrics -experimental-cache
 ]

 # ── timeouts (typed) ──────────────────────────────────────────
 [timeouts :int connect=5 read=30 write=30 idle=120]

 # ── deployment notes (mixed content) ──────────────────────────
 [doc
 [h2 Deployment Notes]
 [p This release introduces [strong rolling] updates with
 [em zero-downtime] semantics.]
 [p Rollback target: [code v1.2.2].]
 ]

 # ── monitoring (tabular data) ──────────────────────────────────
 [monitors :table
 [columns name:string url:string interval_s:u32]
 [rows
 health https://api.example.com/health 30
 metrics https://api.example.com/metrics 60
 ready https://api.example.com/ready 10
 ]
 ]
]
```

This single file has typed scalars, sized types, boolean sigils,
anchors and merges, line and block comments, mixed-content
documentation, and a tabular monitors block. It converts losslessly
to JSON, YAML, TOML (with some structural reshaping), and Markdown.
Hash with `cx hash deployment.cx` for a stable signature you can
sign or store.

---

## 11 — What's next

You've now seen most of CX. The pieces left to learn are mostly
edge cases and tooling:

- **Canonical forms and hashing.** `cx fmt`, `cx canonical`,
 `cx hash`, `cx eq` — see [the cheatsheet](CHEATSHEET.md) and
 [`spec/canonical.md`](../spec/canonical.md).
- **CXPath queries.** `//service[@active=true]`-style selection.
 See [`spec/cxpath.md`](../spec/cxpath.md).
- **Streaming.** Pull-based event API for large documents. See
 [`spec/streaming.md`](../spec/streaming.md).
- **Per-language usage.** Each binding has its own README under
 [`lang/`](../lang/) with idiomatic examples in that language.
- **The C ABI.** If you're embedding `libcx` in a custom binding,
 see [`spec/abi.md`](../spec/abi.md).

For frequently asked questions and adoption decisions, see
[`docs/FAQ.md`](FAQ.md) and
[`docs/COMPARISON.md`](COMPARISON.md).

---

*Tutorial by example, with the design rationale exposed throughout.
The format takes the shape it does because each constraint listed in
§1 forced a specific syntactic decision — bracket pairs over
indentation, type annotations as first-class, mixed content as
native. Once you see the constraints, the syntax stops feeling
arbitrary.*
