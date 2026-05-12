# CX

> **One concise format. Six lossless conversions.** Configs, data, structured
> documents, and log streams in a single coherent syntax that round-trips
> through XML, JSON, YAML, TOML, and Markdown without losing meaning.

CX is a bracket-based document and configuration format. Every construct is
a `[...]` pair: no closing tags to repeat, no mandatory quoting, no
indentation rules. It reads like XML, types like YAML, and converts
losslessly to and from the five formats that already dominate config and
data exchange — so you can adopt it incrementally without rewriting
existing pipelines.

---

## CX at a glance

Five small things CX makes ordinary that other formats made hard.

### 1. Config that documents itself

```cx
[server
  # bind to 0.0.0.0 so the load balancer can reach us
  host=0.0.0.0 :u16 port=8080 +tls
  [- TLS terminates here; backend speaks plaintext on 127.0.0.1:8081 ]
]
```

`# line comments` and `[- block comments ]` are first-class. The rationale
lives next to the values it explains — no separate runbook drifting out
of sync. JSON has no comments at all; YAML and TOML drop them through
most parser round-trips.

### 2. Types that survive a round trip

```cx
[server :u16 port=8080]
[ratio :float 1.5]
[user_id :bigint 1234567890123456789]
[balance :decimal 1234.56]
```

`cx --json | cx --from json` brings these back unchanged. `8080` stays
an integer; the bigint stays exact; the decimal doesn't drift to a
float. JSON's all-numbers-are-IEEE-doubles silently breaks IDs over
2⁵³; YAML's implicit typing means `1.10` parses as `1.1` and `no`
parses as `false`.

### 3. Config and prose, one file

```cx
[deployment
  [- production rollout notes — keep these in sync with the values below ]
  [doc
    [p This service uses [em rolling] updates with a 30-second drain window.]
    [p Rollback target is the previous git tag.]
  ]
  [server host=0.0.0.0 :u16 port=8080]
]
```

Structured config and the prose that explains it live in the same
document because the grammar is the same for both. The pattern of "the
runbook is on the wiki, the values are in git, neither is canonical"
stops being unavoidable.

### 4. Log streams in the same grammar

```
ts=2026-05-07T10:30:00Z level=info  svc=api req_id=abc123 latency_ms=45
ts=2026-05-07T10:30:01Z level=warn  svc=api req_id=def456 latency_ms=210 slow=true
ts=2026-05-07T10:30:01Z level=error svc=api req_id=ghi789 err='connection refused'
```

CX's *logfmt mode* treats bare `key=value` lines as one synthetic
element each — the format you already see in production logs is valid
CX. Same parser, same query language (CXPath), same bindings as for
your config.

### 5. Mixed-content documents

```cx
[article lang=en
  [head [title Introducing CX]]
  [body
    [p CX is at home in [em prose] and [strong structured data] alike.]
    [pre :code [# server { port = 8080 } #]]
  ]
]
```

Inline `[em ...]` inside paragraph text — the thing JSON, YAML, and
TOML can't represent without escape gymnastics, and the thing XML
traditionally does at the cost of verbosity. CX uses the same brackets
either way.

---

## How CX compares

|  | CX | JSON | YAML | TOML | XML |
|---|---|---|---|---|---|
| Syntax weight        | brackets, no closing tags | curly braces + brackets | indent-significant | tables + key=val | open + close tags |
| Strong types         | ✅ int / float / bool / null / sized / decimal / bigint / date / datetime / bytes | ❌ number only (no int/float distinction) | partial (auto-detect, often wrong) | ✅ int / float / bool / datetime | partial (xs:type) |
| Comments             | ✅ block `[- ... ]` and line `# ...` | ❌ | ✅ `# ...` | ✅ `# ...` | ✅ `<!-- ... -->` |
| Mixed content (markup + data) | ✅ first-class | ❌ | ❌ | ❌ | ✅ first-class |
| Multiple top-level docs | ✅ no wrapper required | ❌ requires `[...]` array | ✅ via `---` separator | ❌ single document | partial (with declaration tricks) |
| Attribute / element distinction | ✅ explicit | ❌ flat keys | ❌ flat keys | ❌ flat keys | ✅ explicit |
| Type fidelity through round-trip | ✅ guaranteed via CXDB v1 binary | ❌ int↔float coerced silently | partial | ✅ preserved | partial |
| Tabular data efficiency | ✅ `:table` block, columnar binary | ❌ verbose array-of-objects | ❌ verbose | partial (array of tables) | ❌ verbose |
| Streaming parser | ✅ pull-based handle API | partial (per-implementation) | ❌ usually whole-file | ❌ | ✅ SAX |

For the full head-to-head against each format — including where CX
wins, where it doesn't, and the format-by-format adoption guidance —
see [`docs/COMPARISON.md`](docs/COMPARISON.md).

---

## Status

CX is pre-1.0 and approaching v0.6.0 — the
**API/format-stability boundary through 1.0**. The grammar is stable,
the C ABI is versioned and forward-compatible, and the full test matrix
passes across all 10 language bindings (V native + V-cffi + 8 FFI
bindings). v0.6.0 highlights:

- **17-member Public Table API** ([ADR 0018](spec/decisions/0018-public-table-api.md))
  shipping in every binding; stable through v1.0.
- **Collection literals** ([ADR 0017](spec/decisions/0017-collection-literals-and-cxl-refactor.md))
  — first-class `seq[T]`, `arr[T]`, `map[K, V]` with cross-emitter parity.
- **`cx table` CLI subcommand** ([ADR 0019 §D1](spec/decisions/0019-analytics-bridge-public-surface.md))
  — `info` / `dump` / `load` verbs with `--to=cx` round-trip live;
  Parquet / Arrow IPC export reserved for Phase C (libcx_arrow).
- **Streaming-write event API** (Tier 1/2) + **20/20 schema validator
  rules** (Tier 1) round out the format-side completeness.

The [2026-05 binding audit](spec/binding_audit_2026.md) closed five
systemic shortcuts (CB-1..CB-5) at the core and across all bindings —
duplication is gone, type fidelity is preserved through CXDB, and one
fix-site replaces drift across nine. Formal security review and
fuzz-testing infrastructure are still ahead, so pin a tested version
and apply normal pre-1.0 caution before customer-facing use.

**CXL — the CX Language** — a CX-native expression language (`.cxl`)
for rendering, querying, and transformation, designed for eventual
feature equivalence with XQuery 4.0. CXL programs share one parser
and one data model with the format itself, in the spirit of XML+XQuery
but with CX's typed scalars, indentation-significant syntax, and
hashable canonical form. **CXL 1.0 (template-oriented subset, with
labeled directive form per ADR 0017 §D23 and parameterized templates
per ADR 0020) ships at CX release v0.6.0**; CXL 3.1 (full FLWOR + maps
+ arrays + XQuery 3.1 equivalence) at v0.9.0+; CXL 4.0 is the long-
term target. The architectural commitment is in
[ADR 0016](spec/decisions/0016-templates-queries-cx-expression-family.md);
the v0.6.0 surface-syntax rewrite is in
[ADR 0017](spec/decisions/0017-collection-literals-and-cxl-refactor.md).

---

## Why CX

If you've used JSON, YAML, TOML, XML, and Markdown long enough, you've
hit a recurring set of papercuts:

- A YAML file behaves differently after copy-paste because indentation
  got rewritten.
- A JSON config has no comments, so the *why* lives in a separate doc
  that goes stale.
- An integer ID over 2⁵³ silently becomes an approximate float through
  a JSON round trip.
- A document needs both prose and config-shaped data — neither
  Markdown nor YAML cover both, so you maintain two files and hope
  they stay aligned.
- A schema change loses the distinction between `8080` (integer) and
  `"8080"` (string) because the wire format never preserved it.
- A log line and a config file use different parsers, different query
  languages, and different libraries, so you write the same selector
  logic three times.

Each of these has a workaround — you've shipped them. CX is what
happens when one grammar is designed with all six in mind from the
start:

- **One bracket form, every shape.** No indentation rules, no
  closing-tag repetition, no special-case section headers. `[...]`
  carries config, data, prose, log lines, and tabular rows uniformly.
- **Optional explicit types.** `:int`, `:f64`, `:decimal`, `:bigint`,
  `:u16[]` — declare the type once and the value survives conversion
  to JSON, YAML, TOML, XML, and back.
- **Comments as a first-class construct.** `# line` and `[- block ]`
  forms, preserved through `cx fmt`. Strict-canonical mode (used for
  hashing) is the only place they're dropped, and that's a deliberate
  trade.
- **Mixed content out of the box.** Inline markup inside text works
  the same way nested config does — same brackets, same parser.
- **Lossless six-way conversion.** XML, JSON, YAML, TOML, and
  Markdown round-trip with documented per-format caveats
  ([`spec/conversions.md`](spec/conversions.md)). Adopt CX
  incrementally without rewriting downstream consumers.

For an honest head-to-head against each format, including where CX is
*not* the right pick, see [`docs/COMPARISON.md`](docs/COMPARISON.md).

---

## Quick install

```sh
git clone https://github.com/cx-home/cx
cd cx
make build              # CLI + libcx shared library
make promote-cli        # install `cx` to /usr/local/bin
```

Prerequisites: [V](https://vlang.io) 0.5.1+. No other dependencies.

```sh
$ cx --version
cx 0.5.0

$ echo '[server host=localhost port=8080]' | cx --json
{"server": {"host": "localhost", "port": 8080}}
```

For language bindings (Python, Go, Rust, TypeScript, Java, Kotlin, Swift,
C#, Ruby), see the per-binding READMEs under [`lang/`](lang/).

---

## Where to go next

| You want to... | Read this |
| --- | --- |
| **See more CX in many shapes** (config / data / docs / logs / table) | [`docs/CHEATSHEET.md`](docs/CHEATSHEET.md) |
| **Decide whether to adopt CX over JSON/YAML/TOML/XML** | [`docs/COMPARISON.md`](docs/COMPARISON.md) |
| **Learn the format end-to-end with the design rationale** | [`docs/TUTORIAL.md`](docs/TUTORIAL.md) |
| **Use CX from your favorite language** | [`lang/<your-lang>/cxlib/README.md`](lang/) |
| **Check the formal grammar / C ABI / conversion rules** | [`spec/`](spec/) |
| **Upgrade existing CX from a previous version** | [`MIGRATION.md`](MIGRATION.md) |
| **Read frequently asked questions** | [`docs/FAQ.md`](docs/FAQ.md) |
| **Contribute code, docs, or bug reports** | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| **See what's in the latest release** | [`RELEASE_NOTES_v0.6.0.md`](RELEASE_NOTES_v0.6.0.md) |

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

All 9 FFI bindings wrap the same `libcx` shared library and expose the
same core API: parse, query, mutate, stream, convert, hash, equality.
The 10th binding is **V native** — V is the reference implementation,
so `lang/v/native/` imports the V core directly rather than going
through FFI. Per-binding READMEs live under [`lang/`](lang/).

Every binding ships the v0.6.0 **Public Table API** ([ADR 0018](spec/decisions/0018-public-table-api.md))
with a uniform 17-member surface — properties (`cols`/`types`/`row_count`/
`col_count`), access (`row`/`column`/`col_at`/`cell`/`cell_by_name`/
`slice`/`head`/`tail`/`select_cols`), iteration, and `to_cx`/`to_csv`/
`to_json`/`to_data_bin`/`to_dict_list` conversion. Method names follow
each language's conventions (snake_case, camelCase, PascalCase) but the
underlying behaviour is byte-identical.

---

## CX project at github.com/cx-home

| repo | what's there |
| ---- | ------------ |
| [`cx`](https://github.com/cx-home/cx) (this repo) | spec, V core, all 9 bindings, conformance, examples, docs |
| [`cx-v`](https://github.com/cx-home/cx-v) | V binding (separate because V can also import vcx natively) |

Issues and pull requests welcome on `cx`. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for dev setup, testing
expectations, and the audit-driven coding rules.

---

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).

---

*CX is engineered to be approachable but takes its formal contracts
seriously. The
[`spec/`](spec/) directory is normative; the
[2026-05 binding audit](spec/binding_audit_2026.md) is the closing
artifact for the project's "no shortcuts" rule
([`spec/governance.md`](spec/governance.md) §1). If you find a
bug or a spec violation, that's a real bug — please report it.*
