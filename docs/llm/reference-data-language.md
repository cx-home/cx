# Reference: the CX data language — v0.17.0

> **GENERATED.** Source: `docs-src/llm/reference-data-language.md.tmpl` + the
> conformance corpus. Every output was re-recorded from the `cx` v0.17.0
> binary. Read `primer.md` first.

This is Ring 0: the reading, the canonical form, and the conversions. No
evaluator exists in this ring, so nothing here can execute.

## Elements

A document is a sequence of elements. An element is `[name …]` with optional
attributes and children; children may be elements, text, or collections.

`input.cx`
```cx
[a href=https://example.com/path Click here]
```

```console
$ cx --from=cx --to=cx input.cx
[a href=https://example.com/path Click here]
```

Attribute order is not significant to equality; the canonical form fixes one
order so that hashing and diffing are stable.

## Scalars and auto-typing

Bare tokens are typed on read. `true`/`false` are booleans, integers are
ints, fractions are **decimals**, `null` is the explicit null, and anything
else is an atom. Quoting suppresses all of it and gives you a string.

`input.cx`
```cx
[active true]
```

```console
$ cx --from=cx --to=cx input.cx
[active true]
```

### Decimal and float are two kinds, and the literal decides

A bare fraction is a **decimal**: exact, base-10, arbitrary precision. A
float arises only from an `e`-exponent literal (`1.5e0`), a `::float`
annotation, `[cast … :float]`, division (`[/ …]`), `[$avg …]`, and the
float-returning `math` functions.

```
1.5        decimal        1.5e0      float
19.99      decimal        [/ 7 2]    float
[* 2 1.5]  decimal        [$avg …]   float
```

They do not mix in arithmetic — `[cast]` is the only bridge — and they are
distinct to identity: the two spell different canonical bytes, hash
differently, and `[$eq]` says `false`. `primer.md` §2 carries the worked
refusal.

**The float image is exponent form.** A float's canonical image is Ryū
exponent notation (`3.5e0`, `1.024e3`) in every position, attribute and body
alike; a decimal's image is the fraction as written (`1.5` stays `1.5`,
`25.00` stays `25.00`); and a `date` / `datetime` **attribute** value renders
bare. That asymmetry is deliberate and load-bearing — it is what makes the
canonical form *bijective*, so a fraction written without an exponent reads
back as a decimal and never as a float.

> Images in this pack are re-recorded from the binary that generated the
> page, and the canonical-image repair (`RULED: CO-12`) is landing across the
> emitters. If a float example here still shows a bare image, that binary
> predates the repair — `cx canonical` on the binary you are running is
> always the authority, and this page is regenerated against it.

A value that must survive as text — a version number, an id with dots, a URL
— has to be quoted, and the canonical form keeps the quotes:

`input.cx`
```cx
[m {k: 'a b', j: 'a.b', u: 'https://a.com', ok: 'x', p: 'a/b'} [note a b]]
```

```console
$ cx --from=cx --to=cx input.cx
[m
  {k: 'a b', j: 'a.b', u: 'https://a.com', ok: x, p: a/b}
  [note a b]
]
```

## Text, mixed content, and raw text

Text children and element children can interleave.

`input.cx`
```cx
[p text [b bold] more]
```

```console
$ cx --from=cx --to=cx input.cx
[p 'text ' [b bold] ' more']
```

Raw text is written `[# … #]` and is **opaque**: no entity expansion, no
escaping, no reinterpretation. It is how CX carries a payload in another
language — SQL, a shell script, a regex, prose with brackets in it — without
the reader touching a byte. `[$text]` cannot see inside a raw block; the
serialization is its defined byte-exact projection, which is why tooling that
needs the payload (including the generator that produced this page) reads it
by serializing and stripping the delimiters. The corresponding fixture is
`012-rawtext` in `conformance/core.cxd`; it cannot be *shown* here, because a
raw block containing raw-block delimiters is exactly the case that defeats
that extraction — and this layer refuses to print a fixture it cannot
reproduce byte-exactly.

## Namespaces

A `ns:name` head or attribute is namespaced. Namespaces are part of identity:
two documents differing only in prefix binding are not equal.

`input.cx`
```cx
[doc xmlns=urn:doc xmlns:xl=http://www.w3.org/1999/xlink
  [xl:a href=https://example.com Link]
]
```

```console
$ cx --from=cx --to=cx input.cx
[doc xmlns=urn:doc xmlns:xl=http://www.w3.org/1999/xlink
  [xl:a href=https://example.com Link]
]
```

## Operator-headed elements

A **delimited** operator glyph in head position names an element. The head set
is the evaluator's, and it is closed at eighteen names, twelve of them glyphs:

```
one-char   +  *  -  /  %  =  <  >  ~
two-char   != <= >=
```

"Delimited" means the glyph is followed by whitespace or `]`. So `[% 7 3]` is
an element named `%`, and the data reading keeps it that way:

`input.cx`
```cx
[% 7 3]
```

```console
$ cx --from=cx --to=cx input.cx
[% 7 3]
```

`input.cx`
```cx
[!= 5 3]
```

```console
$ cx --from=cx --to=cx input.cx
[!= 5 3]
```

Two guard rails matter, because both used to be soundness holes rather than
formatting warts:

* **Out-of-set glyphs are not heads.** `**` and `==` are absent from the ruled
  set, so `[== 5 3]` stays in the array lane and canonicalizes as the string
  `'== 5 3'` — deliberately, and pinned.
* **Glued continuations are not heads.** `[-1, 2]` is an array with a negative
  number, `[*n]` is an alias reference, `[<=x]` is an array item. Only the
  delimited glyph dispatches to the element lane.

Getting this wrong is not cosmetic: before the alphabet was closed, `[<= 5 3]`
canonicalized into the very bytes of `['<= 5 3']` and shared its content
address — two documents the evaluator reads differently at one address.

## Anchors and references (identity)

`@name` declares an anchor; a reference resolves to the anchored node.
Forward references resolve — the document is not read strictly top-to-bottom
for identity purposes.

`input.cx`
```cx
[users
  [reviewer assigned-to=@u-1]
  [user #u-1 name=alice]
]
```

```console
$ cx --from=cx --to=cx input.cx
[users
  [reviewer assigned-to=@u-1]
  [user #u-1 name=alice]
]
```

## Tables

`[table[…]]` is the columnar block: typed columns, rows as records. It is a
first-class data form, not a convention over elements, which is what lets
`cx table` project it to Parquet/Arrow without guessing.

`input.cx`
```cx
[users [table[name::string age::int active::bool]]
  alice 30 true
  bob 25 false
]
```

```console
$ cx --from=cx --to=cx input.cx
[users [table[name::string age::int active::bool]]
  alice 30 true
  bob 25 false
]
```

## Conversions

The data reading round-trips to and from XML, JSON, YAML, TOML, CSV/TSV/PSV
and Markdown. `--lossless` adds the markers that make the round trip
byte-identical rather than merely equivalent.

```console
cx --from=json --to=cx in.json
cx --from=cx --to=xml doc.cx
cx --from=cx --to=json --lossless doc.cx    # re-imports byte-identically
cx --xml doc.cx                             # projection shorthand
```

The XML lane is the one to check your mental model against, because the two
models are close but not identical:

`input.xml`
```xml
<a href="https://example.com" class="link">Click</a>
```

```console
$ cx --from=xml --to=cx input.xml
[a href=https://example.com class=link Click]
```

## Canonical form, equality, hashing, diffing

Ring 0's whole value proposition is that these four agree:

```console
cx canonical doc.cx      # strict canonical text (presentation stripped)
cx fmt doc.cx            # lossless format (comments and anchors preserved)
cx hash doc.cx           # SHA-256 of the strict-canonical bytes
cx eq a.cx b.cx          # exit 0 iff canonical(a) == canonical(b)
cx diff a.cx b.cx        # semantic diff over the canonical forms
```

`cx fmt` and `cx canonical` are different tools on purpose: `fmt` is what you
run on source, `canonical` is what identity is defined over.

### CX has two equality notions, and they are not the same notion

This trips up anyone who assumes a language has one `==`. Both of these are
deliberate, and neither may drift into the other:

| Notion | Reached by | What it does |
|---|---|---|
| **Value equality** | `[$eq a b]`, `[= a b]`, `[?match]`, `[$distinct]` | Compares under the atomization policy: an element with single scalar content compares as that value, and a scalar compares against the string of its image |
| **Identity** | `cx canonical`, `cx hash`, `cx eq`, store handles | Type-faithful over the strict-canonical bytes: it distinguishes exactly the pairs value equality merges |

So a decimal attribute and the string of its image compare *equal* as values,
by design:

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[probe
  dec-str=[$eq [u a=1.5] [u a='1.5']]
  atom-str=[$eq [u a=:ops] [u a='ops']]]
```

```console
$ cx --data=input.cx prog.cx
[probe dec-str=true atom-str=true]
```

…while `cx hash` mints them distinct addresses. Pick the notion you meant. If
you are asking "is this the same document" — for caching, deduplication, or a
content address — you want identity, not `[$eq]`.

Canonical serialization is **bijective**: every scalar kind has a
type-faithful image in every position, so `parse(canonical(v))` returns the
same typed value. That is what lets a content address stand for a value rather
than merely for its text.

## Schemas

`.cxs` files describe documents; `cx validate` checks one against a schema,
`cx schema infer` derives a schema from a corpus, and `cx schema export`
projects it to JSON Schema.

```console
cx validate doc.cx --schema=shape.cxs
cx schema infer corpus/*.cx
```
