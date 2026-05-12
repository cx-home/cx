# CX

> **One concise format. Six lossless conversions.** Configs, data, structured
> documents, log streams, and tabular data in a single coherent syntax that
> round-trips through XML, JSON, YAML, TOML, Markdown, and CSV without losing
> meaning.

CX is a bracket-based document and configuration format. Every construct is
a `[...]` pair: no closing tags to repeat, no mandatory quoting, no
indentation rules. It reads like XML, types like TOML, and converts
losslessly to and from the formats that already dominate config and data
exchange — so you can adopt it incrementally without rewriting existing
pipelines.

## Install

```sh
# macOS / Linux — single statically-linked binary, no runtime deps
curl -sSL https://cx-home.io/install | sh

# Or from source (requires V 0.5.1+)
git clone https://github.com/cx-home/cx && cd cx && make build
```

```sh
$ cx demo
```

The in-binary demo runs in < 1 second and shows everything below working.

---

## CX: simple but expressive

Types, comments, structured data, collection literals, tabular rows,
and mixed content — all in one file, with the same brackets throughout:

```cx
[service name=auth version:u8=2

  # nested element with attributes including boolean signal: +tls means tls=true
  [server
    host=0.0.0.0
    port:u16=8443
    +tls
  ]

  [database
    url=postgres://localhost:5432/auth
    pool_size:u16=24
    timeout_ms:u32=5000
  ]

  # block comment for multi-line content or to not parse an element
  [- Daily cap counts successful requests only;
     errors and 429s do not count toward the cap. ]

  # :table block, typed columns
  [limits :table[tier rps:u32 burst:u32 daily_cap:u32]
    free       10    50    100_000
    pro        100   500   10_000_000
    enterprise 1000  5000  999_999_999
  ]

  # array literal
  [allowed_origins [
    https://app.example.com,
    https://admin.example.com,
  ]]

  # map literal
  [features {
    new_billing: true,
    legacy_auth: false,
    canary_rollout: true,
  }]

  # sequence literal where elements flatten in CXL processing
  [labels (production, payments, public-facing,)]

  # array of arrays: weighted upstreams as [name, weight] tuples
  [upstreams [
    [us-east-1, 60,],
    [us-west-2, 30,],
    [eu-west-1, 10,],
  ]]

  # mixed content: markup inside prose
  [doc
    [p This service handles authentication for [strong all production
       traffic]. Rate limits reset at midnight UTC.]
  ]
]
```

What's in those lines:

- **Typed scalars** — `version:u8=2`, `port:u16=8443`, `pool_size:u16=24`,
  `timeout_ms:u32=5000`. Each survives conversion to JSON / YAML / TOML /
  XML / CXDB unchanged.
- **Boolean sigils** — `+tls` means `tls=true`; `-debug` would mean `false`.
- **Numeric underscores** — `100_000`, `10_000_000`.
- **Line comments** — `# …` to end of line, preserved through `cx fmt`.
- **Block comments** — `[- … ]` form for multi-line content, or to comment
  out a whole element without re-parsing it.
- **`:table` block** — typed columns, row-major in CX text, column-major
  on the CXDB wire, CSV-natively round-trippable.
- **Array literal** — `[https://…, https://…,]` for an ordered list.
- **Map literal** — `{new_billing: true, …}` for a string-keyed dictionary.
- **Sequence literal** — `(production, payments, public-facing,)` for a flat
  set that flattens into its containing context under CXL processing.
- **Array of arrays** — `[[us-east-1, 60,], [us-west-2, 30,], …]` for
  nested rows. Pairs, triples, matrices — all the same shape.
- **Mixed content** — `[strong all production traffic]` inline inside a
  paragraph. The same brackets carry markup *and* structured config.

---

## Round-trip in both directions

Import from any of six formats:

```sh
$ cx --from=json --to=cx  config.json   > config.cx
$ cx --from=yaml --to=cx  config.yaml   > config.cx
$ cx --from=toml --to=cx  config.toml   > config.cx
$ cx --from=xml  --to=cx  config.xml    > config.cx
$ cx --from=md   --to=cx  article.md    > article.cx
$ cx --from=csv  --to=cx  data.csv      > data.cx
```

Export to any of seven:

```sh
$ cx --json  service.cx     # → JSON
$ cx --yaml  service.cx     # → YAML
$ cx --toml  service.cx     # → TOML
$ cx --xml   service.cx     # → XML
$ cx --md    service.cx     # → Markdown
$ cx --csv   service.cx     # → CSV (from :table blocks)
$ cx --cxdb  service.cx     # → CXDB binary form
```

Verify with `cx eq` (data-equivalence):

```sh
$ cx --json service.cx | cx --from=json --to=cx > /tmp/rt.cx
$ cx eq service.cx /tmp/rt.cx && echo "data-equivalent"
data-equivalent
```

CX ↔ CXDB is **byte-stable** (CXDB *is* the strict-canonical form).
The other five formats round-trip **data-equivalent** — presentation-layer
differences (comments, attribute order, whitespace) are normalized; the
data survives unchanged. Full per-format details, including the
[lossy-conversion matrix](docs/COMPARISON.md#conversion-loss-matrix),
in [`docs/COMPARISON.md`](docs/COMPARISON.md).

---

## CXPath — querying CX

CXPath is XPath-for-CX: a path-and-predicate query syntax over the
CX data model.

```cx
[users
  [u name=Alice role=admin active=true]
  [u name=Bob   role=user  active=true]
  [u name=Carol role=user  active=false]
]
```

```sh
$ cx select '//u' users.cx
[u name=Alice role=admin active=true]
[u name=Bob role=user active=true]
[u name=Carol role=user active=false]

$ cx select '//u[@role=admin]' users.cx
[u name=Alice role=admin active=true]

$ cx select '//u[@active=true]' users.cx
[u name=Alice role=admin active=true]
[u name=Bob role=user active=true]
```

Predicates support `=` / `!=` / `<` / `>` / `<=` / `>=`, `and` /
`or` / `not(...)`, `contains(...)` / `starts-with(...)`, `[N]`
position, and child-existence (`[tags]`) / attribute-existence
(`[@id]`) tests.

CXPath is **the selection layer underneath CXL templating**, **the
query API exposed by every binding** (`doc.select_all(expr)` etc.),
and **the predicate syntax in `cx lint`, `cx diff`, and schema
rules**. One query language, used everywhere structure is addressed.
See [`spec/cxpath.md`](spec/cxpath.md).

---


## CXL — the CX Language

CXL borrows the **data-code symbiosis** that makes XML + XQuery uniquely
powerful — and improves on it. Where XQuery is a separate language with
its own parser, type system, and runtime, **a CXL template file (.cxl)
is CX format. Code is data and that's very powerful.** The same parser,
the same data model, the same content-hash, the same schema engine
work on configs *and* on the programs that transform them.

CXL is CX's templating, querying, and transformation language. There is
no separate runtime to install, no second grammar to learn, no impedance
mismatch between "the data" and "the code that shapes it."

### 1. Template a value

Given a context document:

```cx
[user name=Alice role=admin active=true]
```

A template can interpolate, conditionally branch, iterate, and render:

```cxl
[?if @active
  :then Welcome [?= @name]! Role: [?= @role].
  :else Account [?= @name] is disabled.
]
```

```sh
$ cx eval notification.cxl --data=user.cx
Welcome Alice! Role: admin.
```

### 2. Iterate over elements

```cx
[team
  [member name=Alice role=admin +active]
  [member name=Bob   role=user  +active]
  [member name=Carol role=user  -active]
]
```

```cxl
[?for m :in //member :return - [?= m/@name] ([?= m/@role])
]
```

```sh
$ cx eval team.cxl --data=team.cx
- Alice (admin)- Bob (user)- Carol (user)
```

(Whitespace control between iterations is part of CXL 1.0's `[?-` /
`-]` syntax; see [`docs/CXL.md`](docs/CXL.md).)

Three more invocation styles — pipe-from-stdin, cross-format pipeline,
and everything-inline `-e`/`-d` flags for shell one-liners — are covered
in [`docs/CXL.md`](docs/CXL.md). The same `cx` binary handles format
conversion, templating, and stdin/stdout composition: no separate
`jq + jinja + pandoc`, no Python wrapper, no shell glue between three
different tools.

### CXL 1.0 → 3.1 → 4.0 — XQuery feature equivalence

**CXL 1.0** (v0.6.0) ships the templating subset — interpolation
(`[?= expr]`), conditional (`[?if]`), iteration (`[?for]`), context
shift (`[?with]`), named blocks (`[?def]` / `[?use]`), parameterized
templates (`[?def name :params [a b] :body …]`), partial inclusion
(`[?include]`), a frozen filter set (`upper`, `lower`, `trim`, `length`,
`concat`, `join`, `replace`, `default`, `first`, `rest`, `empty`,
`reverse`, `escape-html`, `escape-url`, `raw`), and three output targets
(`text` / `cx` / `html` with auto-escape). Enough to replace
Jinja + Liquid + Handlebars for most real workloads.

**CXL 3.1** (v0.9.0+) brings **XQuery 3.1 feature equivalence**: full
FLWOR (`:let` / `:where` / `:order` / `:return`), user-defined functions
(`[?fn name :params … :body …]`), maps and arrays as first-class values,
the arrow operator (`@input => trim => upper`), pattern matching
(`[?match]`), and try/catch.

**CXL 4.0** (v1.x target) tracks XQuery 4.0 once it stabilizes —
pipeline operator, partial function application, enhanced types,
additional collection operations.

The data-code symbiosis XML + XQuery have, in CX flavor: CXL queries
CXL; programs inspect programs; one toolchain for both.

Full reference: [`docs/CXL.md`](docs/CXL.md).

---

## CXDB — the binary form

`.cxdb` is CX's content-addressable binary format. Same data, same
semantics, smaller wire and stricter integrity:

```sh
$ cx --to=cxdb service.cx > service.cxdb
$ wc -c service.cx service.cxdb
    1301 service.cx
     460 service.cxdb              # ~65% smaller; varint-packed, dictionary-encoded
```

CXDB gives you:

- **Type fidelity.** `int64` stays `int64`. `bigint` stays exact.
  `decimal` doesn't drift to float. The JSON round-trip that silently
  truncates IDs above 2⁵³ doesn't happen through CXDB.
- **Content addressability.** The bytes *are* the strict-canonical form —
  no re-canonicalization needed before hashing. The same data produces the
  same SHA-256 across every binding, every platform. Use it as a cache key,
  a deduplication key, or a signed-artifact identity.
- **Streaming.** Pull-based reader for files larger than RAM
  (`cx_table_reader_*` / per-binding `TableReader`); bounded memory.
- **Chunked tables.** Tabular data is column-major in CXDB even though it's
  row-major in CX text — zstd-compressed, dictionary-encoded, and Arrow
  C-Data interop is one optional library (`libcx_arrow`) away.

```python
# Per-binding: parse, work in Python, hash bytes for a cache key.
import cxlib, hashlib
doc = cxlib.parse(open("service.cx").read())
blob = cxlib.to_data_bin("service.cx")    # bytes — the canonical form
key  = hashlib.sha256(blob).hexdigest()
```

See [`spec/data_bin.md`](spec/data_bin.md) for the wire format.

---

## CLI tour

A single statically-linked binary; no Python, Node, or JVM in the way.

```sh
$ cx demo                            # in-binary showcase (< 1 second)
$ cx scaffold config > my.cx         # typed config skeleton
$ cx scaffold table  > rows.cx       # :table skeleton
$ cx scaffold doc    > article.cx    # mixed-content skeleton

# Conversion (any → CX, CX → any)
$ cx --json     file.cx              # → JSON
$ cx --xml      file.cx              # → XML
$ cx --yaml     file.cx              # → YAML
$ cx --toml     file.cx              # → TOML
$ cx --md       file.cx              # → Markdown
$ cx --csv      file.cx              # → CSV (from :table)
$ cx --from=json --to=cx data.json   # JSON → CX

# Canonical / hashing / diff / equality
$ cx fmt        file.cx              # idempotent canonical formatter
$ cx canonical  file.cx              # strict canonical (data only)
$ cx hash       file.cx              # SHA-256 hex
$ cx eq         a.cx b.cx            # exit 0 iff data-equivalent
$ cx diff       a.cx b.cx            # semantic diff

# Linting & validation
$ cx lint       file.cx              # style + correctness checks
$ cx validate   file.cx --schema=svc.cxs

# Tabular operations
$ cx table info   data.cx            # rows, cols, types, byte size
$ cx table dump   data.cx --to=cx    # round-trip via Table API

# Templating
$ cx eval       template.cxl --data=ctx.cx
$ cx render     report.cxl --data=metrics.cx --target=html
```

Every subcommand is also available as a per-binding API call. See
[`docs/CHEATSHEET.md`](docs/CHEATSHEET.md) for the one-page reference.

---

## How CX compares

| | CX | JSON | YAML | TOML | XML |
|---|---|---|---|---|---|
| Syntax weight | brackets, no closing tags | curly braces + brackets | indent-significant | tables + key=val | open + close tags |
| Strong types | ✅ int / float / bool / null / sized / decimal / bigint / date / datetime / bytes | ❌ number only (no int/float distinction) | partial (auto-detect, often wrong) | ✅ int / float / bool / datetime | partial (xs:type) |
| Comments | ✅ block `[- ... ]` and line `# ...` | ❌ | ✅ `# ...` | ✅ `# ...` | ✅ `<!-- ... -->` |
| Mixed content (markup + data) | ✅ first-class | ❌ | ❌ | ❌ | ✅ first-class |
| Multiple top-level docs | ✅ no wrapper required | ❌ requires `[...]` array | ✅ via `---` separator | ❌ single document | partial |
| Attribute / element distinction | ✅ explicit | ❌ flat keys | ❌ flat keys | ❌ flat keys | ✅ explicit |
| Type fidelity through round-trip | ✅ guaranteed via CXDB | ❌ int↔float coerced silently | partial | ✅ preserved | partial |
| Tabular data efficiency | ✅ `:table` block, columnar binary | ❌ verbose array-of-objects | ❌ verbose | partial (array of tables) | ❌ verbose |
| Streaming parser | ✅ pull-based handle API | partial | ❌ usually whole-file | ❌ | ✅ SAX |
| Templating language | ✅ CXL (same parser / data model) | external | external | external | XSLT / XQuery |
| Content-addressable hash | ✅ canonical bytes → SHA-256 | ❌ key-order-dependent | ❌ | ❌ | ❌ |

For the full head-to-head — including the conversion-loss matrix and per-
format adoption guidance — see [`docs/COMPARISON.md`](docs/COMPARISON.md).

---

## Status

CX is pre-1.0 and approaching v0.6.0 — the **API/format-stability boundary
through 1.0**. The grammar is stable, the C ABI is versioned and forward-
compatible, and the full test matrix passes across all 10 language bindings
(V native + V-cffi + 8 FFI bindings).

v0.6.0 highlights:

- **17-member Public Table API** in every binding; stable through v1.0.
- **Collection literals** — first-class `seq[T]`, `arr[T]`, `map[K, V]`
  with cross-emitter parity.
- **CXL 1.0** evaluator (V reference) + 10-binding decoder rollout.
- **`cx table` CLI subcommand** — `info` / `dump` / `load` verbs with
  `--to=cx` round-trip live; Parquet / Arrow IPC export reserved for the
  libcx_arrow follow-up.
- **Schema validator** — 20 of 20 spec rules complete on V / Python / Go.
- **Streaming-write event API** (capability bit 27) for CX + XML.

Formal security review and fuzz-testing infrastructure are still ahead, so
pin a tested version and apply normal pre-1.0 caution before customer-facing
use.

---

## Language bindings

| binding | install |
| ------- | ------- |
| **V** (native — reference implementation) | `v install cx-home.cx-v` — see [`cx-home/cx-v`](https://github.com/cx-home/cx-v) |
| Python | `pip install cxlib` |
| Go | `go get github.com/cx-home/cx/lang/go` |
| Rust | `cargo add cxlib` |
| TypeScript | `npm install @cx-home/cx` |
| Java / Kotlin | `io.cxhome:cxlib:0.6.0` (Maven Central) |
| Swift | SwiftPM via `https://github.com/cx-home/cx` |
| C# | `dotnet add package CX` |
| Ruby | `gem install cxlib` |

**V is the reference implementation.** The V core lives in `vcx/cx/` in
this repo and is published as the `cx-home/cx-v` package for V users.
The other 9 bindings are thin wrappers over the same `libcx` shared
library compiled from the V source — they expose identical behaviour
through each language's idiomatic API.

Every binding ships the v0.6.0 **Public Table API** with a uniform 17-
member surface (`row` / `column` / `cell` / `slice` / `head` / `tail`
/ `select_cols` / iteration / 5 conversion / 4 properties / equality).
Method names follow each language's conventions (snake_case, camelCase,
PascalCase) but the underlying behaviour is byte-identical. Per-binding
READMEs live under [`lang/`](lang/).

---

## Where to go next

| You want to... | Read this |
| --- | --- |
| **Try CX in 60 seconds** | run `cx demo` |
| **Write your first `.cx` file** | [`docs/TUTORIAL.md`](docs/TUTORIAL.md) |
| **One-page syntax reference** | [`docs/CHEATSHEET.md`](docs/CHEATSHEET.md) |
| **Compare CX to JSON / YAML / TOML / XML** | [`docs/COMPARISON.md`](docs/COMPARISON.md) |
| **Learn CXL (templating + querying + transform)** | [`docs/CXL.md`](docs/CXL.md) |
| **Use CX from your favorite language** | [`lang/<your-lang>/cxlib/README.md`](lang/) |
| **Check the formal grammar / C ABI / conversion rules** | [`spec/`](spec/) |
| **Frequently asked questions** | [`docs/FAQ.md`](docs/FAQ.md) |
| **Upgrade existing CX from a previous version** | [`MIGRATION.md`](MIGRATION.md) |
| **See what's in the latest release** | [`RELEASE_NOTES_v0.6.0.md`](RELEASE_NOTES_v0.6.0.md) |
| **Contribute code, docs, or bug reports** | [`CONTRIBUTING.md`](CONTRIBUTING.md) |

---

## CX project at github.com/cx-home

| repo | what's there |
| ---- | ------------ |
| [`cx`](https://github.com/cx-home/cx) (this repo) | spec, V core, all 10 bindings, conformance suite, examples, docs |
| [`cx-v`](https://github.com/cx-home/cx-v) | V native package (`v install cx-home.cx-v`) |

---

## License

Apache-2.0. See [`LICENSE`](LICENSE).
