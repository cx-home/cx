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

```cx
[config
  [server host=localhost port=8080 +tls]      # comments are line- or block-
  [- timeouts in seconds]
  [timeouts :int connect=5 read=30 write=30]  # typed attributes
  [allowed-origins :string[]                  # typed array
    https://app.example.com
    https://admin.example.com
  ]
]
```

Same data as JSON, YAML, or TOML — emitted by the `cx` CLI, byte-stable
across runs:

```sh
$ cx --json config.cx
{"config": {"server": {"host": "localhost", "port": 8080, "tls": true},
            "timeouts": {"connect": 5, "read": 30, "write": 30},
            "allowed-origins": ["https://app.example.com", "https://admin.example.com"]}}
```

> **Status: pre-1.0, not production-hardened.** The grammar is stable and
> tested (~1,200 tests across 9 language bindings, 0 failures), the C ABI is
> versioned and forward-compatible, and the [2026-05 binding
> audit](spec/binding_audit_2026.md) closed five systemic shortcuts at the
> core. **But:** there has been no security review, no fuzz-testing
> infrastructure, no production deployments at scale, and the V toolchain
> CX builds on is itself pre-1.0. Use it for prototypes, internal tools,
> and exploratory work. Don't bet a customer-facing system on it yet.

---

## Why CX exists

Three things in one format that no other format gives you together:

1. **Markup and data in one syntax.** XML can carry data but is verbose;
   JSON/YAML/TOML can carry config but can't represent mixed-content
   documents. CX is at home in both: `[p Hello [strong world]]` is a
   document fragment and `[server host=localhost port=8080]` is config —
   same grammar.
2. **Type fidelity end-to-end.** `[port :int 8080]` is an integer, not a
   string-that-looks-like-a-number, and stays integer through every
   conversion (JSON's `8080`, YAML's `8080`, TOML's `8080 = ...`). Sized
   types (`u16`, `i64`, `decimal`, `bigint`) and typed arrays preserve
   precision and intent.
3. **Lossless conversions.** `cx --xml` then `cx --from xml` round-trips
   to byte-identical CX. Same for JSON, YAML, TOML, and Markdown
   (with one well-defined caveat per format, documented in
   [`spec/conversions.md`](spec/conversions.md)).

If you're choosing between formats: see [`docs/COMPARISON.md`](docs/COMPARISON.md)
for an honest accounting of when CX is the right pick and when it isn't.

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
| **See CX in many shapes at a glance** (config / data / docs / logs) | [`docs/CHEATSHEET.md`](docs/CHEATSHEET.md) |
| **Decide whether to adopt CX over JSON/YAML/TOML/XML** | [`docs/COMPARISON.md`](docs/COMPARISON.md) |
| **Learn the format end-to-end with the design rationale** | [`docs/TUTORIAL.md`](docs/TUTORIAL.md) |
| **Use CX from your favorite language** | [`lang/<your-lang>/cxlib/README.md`](lang/) |
| **Check the formal grammar / C ABI / conversion rules** | [`spec/`](spec/) |
| **Upgrade existing CX from a previous version** | [`MIGRATION.md`](MIGRATION.md) |
| **Read frequently asked questions** | [`docs/FAQ.md`](docs/FAQ.md) |
| **Contribute code, docs, or bug reports** | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| **See what's in the latest release** | [`RELEASE_NOTES_v0.6.0.md`](RELEASE_NOTES_v0.6.0.md) |

---

## A 30-second tour

CX in three different roles. All three are valid CX, all three convert
losslessly to JSON / YAML / TOML / XML / MD via the `cx` CLI.

### As config

```cx
[server :u16 port=8080
  [tls cert=/etc/ssl/cert.pem key=/etc/ssl/key.pem]
  [logging level=info format=json]
]
```

### As data

```cx
[users
  [user id=1 name=alice +admin]
  [user id=2 name=bob]
  [user id=3 name=carol +admin]
]
```

### As a document

```cx
[article lang=en
  [head [title Introducing CX]]
  [body
    [p CX unifies markup and data in one syntax.]
    [p It [em reads] like XML, [em types] like YAML.]
    [pre :code [# server { port = 8080 } #]]
  ]
]
```

The same grammar handles all three. No wrapper element required. No format
switch.

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

All 9 bindings wrap the same `libcx` shared library and expose the same
core API: parse, query, mutate, stream, convert, hash, equality. Per-binding
READMEs live under [`lang/`](lang/).

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

[License TBD — placeholder until v0.6.0 release.]

---

*CX is engineered to be approachable but takes its formal contracts
seriously. The
[`spec/`](spec/) directory is normative; the
[2026-05 binding audit](spec/binding_audit_2026.md) is the closing
artifact for the project's "no shortcuts" rule
([`spec/governance.md`](spec/governance.md) §1). If you find a
bug or a spec violation, that's a real bug — please report it.*
