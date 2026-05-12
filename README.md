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

## A complete example

```cx
[service name=auth version:u8=2
  # primary listen socket — TLS terminates here, backend speaks plaintext
  [server host=0.0.0.0 port:u16=8443 +tls -debug]

  [database
    url=postgres://localhost:5432/auth
    pool_size:u16=24
    connect_timeout_ms:u32=5000
    slow_query_threshold:decimal=0.250
  ]

  [allowed_origins
    https://app.example.com
    https://admin.example.com
  ]

  [- rate limits per client tier; rps and burst are counters per second ]
  [limits :table[tier rps:u32 burst:u32 daily_cap:u32]
    free       10    50    100_000
    pro        100   500   10_000_000
    enterprise 1000  5000  999_999_999
  ]
]
```

One file. Typed scalars (`:u8`, `:u16`, `:u32`, `:decimal`). Boolean sigils
(`+tls`, `-debug`). Numeric underscores (`100_000`). Comments where they
matter (`#` line and `[- block ]`). A `:table` block for tabular rows.
Convert it to anything:

```sh
$ cx --json    service.cx    # → JSON, types preserved through CXDB
$ cx --yaml    service.cx    # → YAML
$ cx --toml    service.cx    # → TOML
$ cx --xml     service.cx    # → XML, with namespaces if declared
$ cx --md      service.cx    # → Markdown, prose-aware
$ cx --csv     service.cx    # → CSV (from :table block)
```

All six round-trip. `cx eq service.cx <(cx --json service.cx | cx --from=json)`
returns 0.

---

## Mixed content — config and prose, one file

The same brackets that hold typed scalars hold markup:

```cx
[release v=2.1.0 :date date=2026-05-12
  [- production rollout notes ]
  [doc
    [p This release adds the [strong Public Table API] across all 10
       language bindings and ships [em CXL 1.0] as the templating layer.]
    [p Upgrade path: see [link href=docs/migrations/v0.5-to-v0.6.md
       v0.5 → v0.6 migration guide].]
  ]

  [server host=0.0.0.0 :u16 port=8443]
  [feature_flags
    new_billing=true
    legacy_auth=false
  ]
]
```

Inline `[em ...]` and `[strong ...]` inside paragraph text — the thing JSON,
YAML, and TOML can't represent without escape gymnastics, and the thing XML
traditionally does at the cost of verbosity. CX uses the same brackets either
way.

---

## CXL — the CX Language

CXL is CX's templating, querying, and transformation language. Same parser,
same data model, no separate runtime. A `.cxl` file is itself a `.cx`
document — so every CX tool (parser, schema validator, formatter, hash,
diff) works on CXL programs unchanged.

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

A more involved example — iterate over elements:

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

(Output joining and whitespace control are part of CXL 1.0's `[?-` /
`-]` syntax; see [`docs/CXL.md`](docs/CXL.md).)

CXL 1.0 ships in v0.6.0 with `[?if]` / `[?for]` / `[?with]` / `[?def]` /
`[?use]` / `[?include]` directives, `[?= expr]` interpolation, a frozen
filter set (`upper`, `lower`, `trim`, `length`, `concat`, `join`, `replace`,
`default`, `first`, `rest`, `empty`, `reverse`, `escape-html`, `escape-url`,
`raw`), and output targets (`text` / `cx` / `html` with auto-escape).

CXL 3.1 (XQuery 3.1 equivalence — FLWOR, maps, arrays, user-defined
functions, arrow operator) is planned for v0.9.0+. CXL 4.0 (XQuery 4.0
equivalence) is the long-term target.

Full reference: [`docs/CXL.md`](docs/CXL.md).

---

## CXDB — the binary form

`.cxdb` is CX's content-addressable binary format. Same data, same
semantics, smaller wire and stricter integrity:

```sh
$ cx --to=cxdb service.cx > service.cxdb
$ wc -c service.cx service.cxdb
     597 service.cx
     404 service.cxdb              # ~32% smaller; varint-packed, dictionary-encoded
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
| Python | `pip install cxlib` |
| Go | `go get github.com/cx-home/cx/lang/go` |
| Rust | `cargo add cxlib` |
| TypeScript | `npm install @cx-home/cx` |
| Java / Kotlin | `io.cxhome:cxlib:0.6.0` (Maven Central) |
| Swift | SwiftPM via `https://github.com/cx-home/cx` |
| C# | `dotnet add package CX` |
| Ruby | `gem install cxlib` |

All 9 FFI bindings wrap the same `libcx` shared library and expose the same
core API. The 10th binding is **V native** — V is the reference
implementation, so `lang/v/native/` imports the V core directly rather than
going through FFI. Per-binding READMEs live under [`lang/`](lang/).

Every binding ships the v0.6.0 **Public Table API** with a uniform 17-member
surface (`row` / `column` / `cell` / `slice` / `head` / `tail` / `select_cols`
/ iteration / 5 conversion / 4 properties / equality). Method names follow
each language's conventions (snake_case, camelCase, PascalCase) but the
underlying behaviour is byte-identical.

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
