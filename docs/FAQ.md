# CX Frequently Asked Questions

A working answer for the questions adopters ask in the first thirty
minutes. For the format itself, see [`docs/TUTORIAL.md`](TUTORIAL.md);
for the formal grammar, [`spec/grammar.ebnf`](../spec/grammar.ebnf);
for migration from older grammars, [`MIGRATION.md`](../MIGRATION.md).

---

## Choosing CX

### Why CX instead of JSON?

JSON has no comments and no type fidelity beyond IEEE 754 doubles.
That's fine for API payloads but punishing for configuration
(rationale belongs next to the values it explains) and for data
exchange that involves big integers, decimals, dates, or anything
else outside the JSON value tower.

CX keeps the round-trip: `cx --json file.cx | cx --from json` brings
your bigints, decimals, dates, and types back unchanged. JSON itself
silently breaks any integer over 2⁵³. If you want comments in your
config, JSON forces you to write JSON5 (which 90% of consumers
don't accept) or sidecar `_comment` keys (which clutter the output).

Use JSON when the consumer is fixed and the data fits the JSON value
tower. Use CX when the same data needs to round-trip into and out of
multiple consumers without losing meaning.

### Why CX instead of YAML?

YAML's implicit typing is the load-bearing problem: `country: NO`
parses as `false`; `version: 1.10` parses as `1.1`; `port: 022`
parses as octal `18`. Specs say which letters become booleans
(YAML 1.1 is permissive, 1.2 is stricter, parsers disagree). CX
inverts the rule: leading-zero tokens are strings (so `02134` stays
`"02134"`), `:type` annotations make the type explicit, and there's
no implicit boolean coercion of strings.

YAML's anchors / aliases (`&base`, `*base`) are useful and CX keeps
them. YAML's significant whitespace is hostile to programmatic
generation — a stray tab corrupts a deeply nested document. CX uses
brackets, which programmatic emitters can't accidentally break.

Use YAML when you're inside the Kubernetes ecosystem and tooling
requires it. Use CX when the file will be hand-edited by humans who
shouldn't have to memorize YAML 1.1 vs 1.2 vs Norway.

### Why CX instead of TOML?

TOML is excellent for flat, table-shaped configuration. It struggles
with deep hierarchy: `[a.b.c.d.e]` headers get repetitive, and
mixing arrays-of-tables with inline tables leaks complexity into
the consumer's mental model. TOML also has no markup story — if
your config wants a documentation paragraph, it's a string with
embedded newlines.

CX nests freely (any depth, no syntactic penalty), unifies markup
and config in the same syntax, and exports to TOML losslessly when
the source happens to fit TOML's shape.

Use TOML when the config is shallow, table-shaped, and your audience
already knows TOML. Use CX when the same source needs to serve as
config, documentation, and data interchange.

### Why CX instead of XML?

XML has the strongest schema and namespace story of any text format
in wide use. It's also verbose: closing tags repeat, attribute
quoting is mandatory, and the XML declaration / DOCTYPE machinery
is cumbersome. Modern tooling (web frameworks, configuration
systems, API specs) has migrated away — XML is mostly used now in
domains with deep institutional investment (Office Open XML,
DocBook, Atom, SOAP).

CX gives you XML's structural power (attributes, mixed content,
namespaces,
ID/IDREF per )
without the verbosity. A CX document that round-trips to XML is
typically half the byte count.

Use XML when you're integrating with an XML-native system. Use CX
when you're building something new and want XML's structural
fidelity without the punctuation cost.

### Why CX instead of Markdown?

Markdown is the right format for *prose with light structure* —
articles, READMEs, blog posts. It has no opinion about types,
schemas, or data, which means you can't put a configuration block
in your Markdown and expect anyone to extract it programmatically.

CX subsumes Markdown for the cases where prose and structured data
live together. The same `[h1 ...]` / `[p ...]` / `[em ...]`
constructs that compose a CX document map to Markdown, and any
plain-Markdown file imports cleanly via `cx --from md`. If you only
need prose, stay in Markdown — there's no reason to switch.

### When is CX the wrong choice?

- **Hot-path JSON for high-throughput APIs.** Use JSON; the parsing
 ecosystem is faster and more universal. CX is comparable in
 microbenchmarks but JSON wins on every-platform support.
- **Kubernetes and the Helm ecosystem.** Stay in YAML; the tooling
 expects it. You can convert CX → YAML at build time if you want
 CX as the source-of-truth.
- **Pure prose documents.** Stay in Markdown.
- **Database export with type-fidelity guarantees.** Use Parquet,
 Arrow, or a typed binary format. CX handles tabular data
 (`:table` block, see 
 for delimited interop) but isn't optimized for analytics workloads.

---

## Adoption

### Is CX production-ready?

Pre-1.0. The format is stable enough that we've locked v0.6.0 as
the API/format-stability boundary through 1.0, but several
adoption-relevant capabilities are still in flight: schema
language, public Table API, streaming write, namespaces
implementation, and the tooling surface (LSP, tree-sitter, lint,
diff). See [`ROADMAP.md`](../ROADMAP.md) for what's planned and when.

There has been no external security audit yet. See
[`SECURITY.md`](../SECURITY.md) for the disclosure policy and
known unhardened areas.

If you adopt today, expect format stability through 1.0 (per the
v0.6.0 boundary commitment) and incremental tooling improvements.
Don't expect drop-in compatibility with every editor or schema
validator until the v0.6.0 → 1.0 path closes.

### Can I adopt incrementally?

Yes — that's the load-bearing design choice. Every CX file converts
losslessly to one or more of the five formats it interoperates with
(XML, JSON, YAML, TOML, Markdown). You can:

- Use CX as your source-of-truth and emit YAML for Kubernetes,
 TOML for static-site configs, and Markdown for docs.
- Author in JSON / YAML / TOML and convert to CX when you need
 comments, types, or hierarchy that the original format doesn't
 carry.
- Run `cx --from xml legacy.xml > new.cx` to start migrating an
 XML pipeline one document at a time.

The conversion contract is in [`spec/conversions.md`](../spec/conversions.md).
Lossy properties (where they exist — delimited, Markdown subsets)
are documented explicitly.

### Which language can I use CX from?

Ten implementations, all backed by the same V core (`vcx/`):

- **V** — the native reference implementation; what `libcx` is built from.
- **Python** (`lang/python/`) — ctypes wrapper around `libcx`.
- **Go** (`lang/go/`) — cgo wrapper.
- **Rust** (`lang/rust/`) — `extern "C"` wrapper.
- **TypeScript** (`lang/typescript/`) — koffi wrapper for Node.
- **Java** (`lang/java/`) — JNA wrapper.
- **Kotlin** (`lang/kotlin/`) — JNA wrapper.
- **Swift** (`lang/swift/`) — clang interop.
- **C#** (`lang/csharp/`) — P/Invoke wrapper.
- **Ruby** (`lang/ruby/`) — FFI wrapper.

The C ABI surface is normative: bindings differ in idiomatic API
shape but the underlying capability set is the same. See
[`spec/abi.md`](../spec/abi.md) for the symbol-by-symbol contract,
and each binding's `README.md` for the language-specific surface.

### What's the binding parity?

Every binding implements the core capability set: parse, emit,
format conversion (CX ↔ XML / JSON / YAML / TOML / MD), canonical
form, hash, equality, data-binary one-shots. Some bindings are
ahead on idiomatic ergonomics (Python's dict-like access, Rust's
typed AST nodes) and some are minimal and FFI-shaped.

The per-binding parity matrix is tracked in
[`spec/governance.md §2`](../spec/governance.md). Use it to confirm
your binding has what you need before adopting.

### How do I migrate from JSON / YAML / TOML / XML / MD?

```sh
cx --from json existing.json > existing.cx # one-shot
cx --from yaml existing.yaml > existing.cx
cx --from toml existing.toml > existing.cx
cx --from xml existing.xml > existing.cx
cx --from md existing.md > existing.cx
```

The reverse direction (CX → format) is the default:

```sh
cx --json file.cx # to stdout
cx --xml --pretty file.cx > file.xml
```

Round-trips are documented per format pair. JSON, YAML, and TOML
are lossless within their value tower (CX features they don't
support — comments, namespaces, ID/IDREF — are stripped on emit;
re-importing them won't recover those features). XML is lossless
in both directions for documents that use the shared subset.
Markdown is lossy on emit (CX features beyond Markdown's vocabulary
are stripped) and lossless on import for plain Markdown.

---

## Format design

### Why brackets instead of braces / indentation / tags?

Brackets are the lightest balanced delimiter that's not in heavy
use already. Braces (`{}`) are JSON; mixing braces with the rest
of CX would create constant visual collision. Indentation (YAML)
breaks under programmatic generation. Tags (`<>`) double the
character count for every construct and force closing-tag
repetition.

Brackets also pun usefully: `[name]` is "the thing called name",
which matches the way humans write structured outlines on
whiteboards. The first edit any CX adopter makes — adding a child
to an existing element — is mechanical and unambiguous.

### Why `:type` annotations?

CX auto-types most values that look unambiguously like one type
(`8080` → int, `3.14` → float, `true` → bool, `2026-01-01` → date).
The `:type` annotation is for cases where the auto-typer would
guess wrong, where you want a stricter range (`:u16` rejects
values over 65535), or where the value should keep a specific
runtime type even when its lexical form would imply something else.

Example: `[port :u16 8080]` says "port is exactly a u16" —
attempting to set it to 65536 fails at parse time, not at
runtime in some downstream consumer.

### Why `+flag` / `-flag` boolean sigils?

Boolean attributes are the most common attribute kind in
configuration. Writing `tls=true tls_v1_3=true http3=true
debug=false` is heavier than `+tls +tls_v1_3 +http3 -debug`. The
sigils are pure syntactic sugar — they parse to the equivalent
`name=true` / `name=false` attribute. See `docs/CHEATSHEET.md` ¶
"Attributes" for the rule.

### Why does CX not support implicit boolean strings (`yes` → true)?

Because YAML's "Norway problem" is a footgun every adopter hits
once and remembers forever. CX is explicit: `true` is the boolean
true, `'yes'` is the string. No locale-dependent parsing, no
historical accident where `no` and `false` mean the same thing.

This is the v3.4 leading-zero rule in another guise: lexical form
predicts the type. `02134` is the string `"02134"`; if you want
the integer 2134, write `2134`. Predictable rules > shorthand.

### What's `:table`?

A row-major-in-text, column-major-in-binary tabular block:

```cx
[stocks :table[ticker:string price:f64 volume:u32]
 AAPL 192.45 38291092
 GOOG 142.30 18234567
 MSFT 415.18 23456789
]
```

In the binary `cx_to_data_bin` form, `:table` rows are stored
column-major and run 5–10× smaller than equivalent
element-per-row encoding for large datasets. In the text form they
read naturally for humans. The same source converts to CSV / TSV
(per ),
JSON arrays-of-objects, YAML lists, etc.

### What's logfmt mode?

A CX file made entirely of bare top-level `key=value` attributes:

```
ts=2026-05-07T10:30:00Z level=info svc=api req_id=abc123 latency_ms=45
ts=2026-05-07T10:30:01Z level=warn svc=api req_id=def456 latency_ms=210 slow=true
```

Each line parses as a synthetic Element. Result: log streams are
valid CX. You can `cx --json logs.cx` and get a JSON array of
typed log records, with `latency_ms` as int and `slow` as bool —
no separate logfmt parser needed. See [`docs/TUTORIAL.md §9`](TUTORIAL.md)
for the full description.

---

## Type system

### What types does CX support?

The atomic types: `int` (arbitrary range, sized variants
`:i8`/`:i16`/`:i32`/`:i64`/`:u8`/`:u16`/`:u32`/`:u64`), `float`
(IEEE 754, sized variants `:f32`/`:f64`), `bool`, `string`,
`null`, `date`, `datetime`, `bytes`, `decimal` (arbitrary
precision), `bigint` (arbitrary precision), and arrays of any
of these.

Compound types are inherent in the structure: any element with
attributes is a record; any element with same-named children is a
collection; the `:table` block is a typed table.

See [`spec/grammar.ebnf §25`](../spec/grammar.ebnf) for the full
auto-typing rules and `docs/CHEATSHEET.md` ¶ "Types" for the
syntax.

### Why does `[zip 02134]` produce a string?

In CX v3.4, leading-zero tokens stay strings unless the prefix is
`0x` (hex), `0o` (octal), or `0b` (binary). The rule is
deliberately predictable: leading-zero numerics are typically
identifiers (postal codes, area codes, BIC codes, account
numbers) where the leading zero is data, not a numeric value.

This is a v3.3 → v3.4 breaking change documented in
[`MIGRATION.md §1`](../MIGRATION.md). Linter `CX-L005` (per
) warns when an
adopter is likely to be hitting it.

### Are numeric underscores significant?

No — they're cosmetic separators. `1_000_000` parses as `1000000`.
You can place underscores anywhere between digits, both for
integer and float literals, including the fractional part:
`3.141_592_653_589_793` is valid. The canonical form drops them
on emit; the lossless form preserves them.

### What's `:decimal` for?

`:decimal` is arbitrary-precision decimal — for money, scientific
quantities, or any value where IEEE 754 binary floats would lose
precision. `0.1 + 0.2` is `0.30000000000000004` in float; in
`:decimal` it's `0.3`. Consumer bindings map `:decimal` to their
language's decimal type (Python `Decimal`, Java `BigDecimal`, .NET
`decimal`, Ruby `BigDecimal`, Swift `Decimal`, Rust `rust_decimal`,
etc.).

### What's `:bigint` for?

Same idea, but for integers larger than `:i64` / `:u64`. JSON's
all-numbers-are-doubles silently breaks IDs above 2⁵³;
`:bigint` carries them exactly. Bindings map to the language's
arbitrary-precision integer type (Python `int`, Java
`BigInteger`, Ruby `Integer`, Rust `num-bigint::BigInt`, .NET
`BigInteger`).

### What about schemas?

A CX-native schema language (`.cxs`) is in design — see

and [`spec/schema.md`](../spec/schema.md). The validator is the
single largest v0.6.0 implementation item (3–4 months); it ships
before 1.0 but isn't usable yet. Until then, validate at the
binding layer (parse, then check the AST yourself) or rely on
CX's auto-typing + sized-type annotations to catch range
violations at parse time.

---

## Tooling and ecosystem

### What does the CLI do?

```sh
cx file.cx # round-trip CX → canonical CX
cx --json file.cx # CX → JSON (also --xml/--yaml/--toml/--md/--ast)
cx --from xml file.xml # XML → CX (also json/yaml/toml/md)
cx fmt file.cx # lossless reformat (preserves comments)
cx canonical file.cx # strict canonical form (data only)
cx hash file.cx # SHA-256 of strict canonical bytes
cx eq a.cx b.cx # exit 0 iff data-equivalent
cx --compact file.cx # one-line output
```

`cx diff` (semantic diff) and `cx lint` (style + correctness
warnings) are designed but not yet implemented — see
 and
.

### Is there an LSP?

Yes, but it's at v0.1.0 and ships only completion (no diagnostics,
no hover, no formatting). The LSP build-out is a v0.6.0 blocker;
the target capability set is diagnostics + hover + document
symbols + formatting via `cx fmt`.

### Is there syntax highlighting for my editor?

A tree-sitter grammar at `tooling/tree-sitter-cx/` supports v3.3
constructs. The v0.6 update (sized types, numeric underscores,
boolean sigils, line comments, logfmt mode, `:table` block,
leading-zero rule) is a v0.6.0 blocker.

The VSCode extension at `tooling/vscode/` and the Neovim
configuration at `tooling/neovim/` use the LSP and tree-sitter
grammar. Both need fixes before they install cleanly out of the
box. Track progress in the readiness rubric.

### How do I run the conformance suite?

```sh
make conform # all 122 cases (core/extended/xml/md)
```

The suite runs against the V core. Per-binding test suites:

```sh
make test # all bindings
make test-python # one binding
make test-rust # etc.
```

See [`CONTRIBUTING.md`](../CONTRIBUTING.md) for the full test matrix.

---

## Performance

### How fast is CX?

Comparable to JSON for parse + emit on text files of the same
size. The strict-canonical and binary `cx_to_data_bin` paths are
faster than JSON because they avoid string-escape overhead. The
data-binary `:table` path is 5–10× smaller than equivalent
element-per-row encoding for large tabular data.

A microbenchmark suite measuring against the SLA budgets in
[`spec/governance.md §6`](../spec/governance.md) is a v0.6.0
blocker — until it ships, the numbers above are the qualitative
shape, not measured commitments.

### Will CX scale to gigabyte files?

Streaming parse is supported today (parse arbitrarily large
inputs without reading them fully into memory; see
[`spec/streaming.md`](../spec/streaming.md)). Streaming write is
designed in 
but not yet implemented; until then, write paths are buffer-based.
For terabyte-scale data you want a binary columnar format
(Parquet, Arrow), not CX.

### Is CX thread-safe?

The C ABI is documented per-symbol with thread-safety classes
(stateless / handle-thread-local / forbidden-from-other-thread)
in [`spec/abi.md §1.5`](../spec/abi.md). All format converters
are stateless and can run concurrently across threads on disjoint
inputs. Per-binding concurrency stories are still being filled in
(a v0.6.0 blocker per the readiness rubric §15).

---

## Project status

### What version is the format?

The grammar is at v3.4. The library is at 0.5.0; the next tag is
v0.6.0, which is the API/format-stability boundary through 1.0.
See [`spec/governance.md §9`](../spec/governance.md) for the
versioning policy.

### When does v0.6.0 ship?

When the planned scope closes. The current set is ~22 substantive
items; estimated 8–12 months of focused work. See
[`ROADMAP.md`](../ROADMAP.md) for the full list.

### Is there a roadmap?

[`ROADMAP.md`](../ROADMAP.md) — split into Now (active branch
work for v0.6.0), Next (post-v0.6.0 production hardening), and
Later (post-1.0). Plus "Deliberate non-features" with rationale
for each.

### What's the license?

Apache 2.0. See [`LICENSE`](../LICENSE).

### How do I contribute?

See [`CONTRIBUTING.md`](../CONTRIBUTING.md) — covers dev setup,
the test matrix, audit-driven coding rules, and the commit / PR
conventions. Bug reports, doc fixes, and PRs all welcome.

For format-design questions or proposed grammar changes, file an
issue first; a recorded design decision is a prerequisite for any
breaking change.

### How do I report a security issue?

Through GitHub's private vulnerability reporting at
<https://github.com/cx-home/cx/security/advisories/new>. Don't
file a public issue for security-sensitive bugs. See
[`SECURITY.md`](../SECURITY.md) for the full policy.

---

## Common syntax confusions

### Why doesn't my comment parse?

`# line comments` work everywhere whitespace is allowed *between*
tokens. They don't work inside attribute values or on the same
line as `[name<head-line-content>` if the `#` immediately follows
the name with no intervening attribute or comment. When in doubt,
put the `#` after at least one attribute: `[server host=localhost
# comment here`.

`[- block comments ]` are most reliable on their own line. Inside
a block comment, `[#` and `[|` sequences confuse the parser
(known issue, fix tracked separately) — keep block comments
prose-like, no embedded CX-shaped syntax.

### Why does `[code [|` `...]` emit garbled output?

`[|...|]` is *parsed-body* — content is parsed as CX, with `[`
opening child elements. If your code contains `[`, `]`, or
quotes, the parser will mangle it. Use `[#...#]` (raw text, never
parsed) instead:

```cx
[code [#
 for (let i = 0; i < arr.length; i++) {
 console.log(arr[i]);
 }
#]]
```

This is the most common syntax confusion adopters hit when
embedding code samples. See [`examples/embedding_test.cx`](../examples/embedding_test.cx)
for canonical usage.

### Why are my attributes after a child element ignored?

Attributes must be on the *head line* of an element — the first
line, before any child element opens. Once a child appears,
subsequent text is body content, not attributes:

```cx
[server host=localhost # attribute on head line: ✅
 [port :u16 8080] # child element
 ssl=true # NOT an attribute — body text
]
```

If you need to add an attribute after-the-fact, put it on the
head line:

```cx
[server host=localhost ssl=true # both attributes here
 [port :u16 8080]
]
```

Boolean sigils have the same rule: `+tls -debug` on the head line
become `tls=true debug=false`; on a continuation line they're
text.

### Why does my anchor merge produce a string?

A common mistake: mixing scalar bodies and anchor merges in the
same element. Anchors / aliases / merges work on attributes, not
on scalar bodies. Use child elements for the data:

```cx
[defaults &base
 [timeout :u16 30] # child elements, not scalar body
 [retries :u8 3]
]

[prod *base
 [host acme.com]
]
```

If you write `[defaults &base timeout=30 retries=3]` (attributes,
no scalar body) the merge works. If you write `[defaults &base 30
3]` (scalar body) the values become a string array, not what you
wanted.

---

## Migration

### What's new in v3.4?

The big-ticket items: sized numeric types (`:u8`/`:u16`/`:u32`/
`:u64`/`:i8`/`:i16`/`:i32`/`:i64`/`:f32`/`:f64`), arbitrary-
precision (`:decimal`, `:bigint`), numeric underscores
(`1_000_000`), boolean sigils (`+flag`/`-flag`), line comments
(`#`), `:table` block, logfmt mode, leading-zero-strings rule.
Full list in `MIGRATION.md`.

### Is v3.3 still supported?

v3.3 documents parse under v3.4 with one exception: leading-zero
numerics are now strings. A v3.3 file that relied on `[port 0080]`
auto-typing to int 80 is broken under v3.4 — write `[port 80]` or
`[port :int 0080]`. Linter `CX-L005` (post-implementation per
) flags this case.

### How do I find v0.5-era patterns in my files?

```sh
cx fmt --check **/*.cx # exit non-zero if any file isn't canonical
cx canonical **/*.cx # emits the strict form to compare
cx lint **/*.cx # post-implementation; CX-L005 flags v3.3 patterns
```

---

## Still have questions?

- **Format / grammar:** [`spec/grammar.ebnf`](../spec/grammar.ebnf),
 [`docs/TUTORIAL.md`](TUTORIAL.md), [`docs/CHEATSHEET.md`](CHEATSHEET.md).
- **Conversion behavior:** [`spec/conversions.md`](../spec/conversions.md).
- **Type rules:** [`spec/grammar.ebnf §25`](../spec/grammar.ebnf),
 [`spec/type_mapping.md`](../spec/type_mapping.md).
- **Security:** [`spec/threat_model.md`](../spec/threat_model.md),
 [`SECURITY.md`](../SECURITY.md).
- **Bug reports:** GitHub Issues.
- **Vulnerabilities:** [`SECURITY.md`](../SECURITY.md) (private
 reporting).
