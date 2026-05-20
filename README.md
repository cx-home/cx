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

```cx
[service name=auth version:u8=2
  [server host=0.0.0.0 port:u16=8443 +tls]
  [limits :table[tier rps:u32 burst:u32]
    free       10    50
    pro        100   500
    enterprise 1000  5000
  ]
]
```

## Install

```sh
# macOS / Linux — single statically-linked binary, no runtime deps
curl -sSL https://cx-home.io/install | sh

# Or from source (requires V 0.5.1+)
git clone https://github.com/cx-home/cx && cd cx && make build
```

V users — the native V binding lives in its own
[`cx-home/cx-v`](https://github.com/cx-home/cx-v) repo so V's package
manager can install it directly:

```sh
v install --git https://github.com/cx-home/cx-v
```

```sh
$ cx demo
```

The in-binary demo runs in < 1 second and shows the full feature set.

## Documentation

The full documentation — overview, install, quickstart, tutorial, 50-way
data and CXL tours, cookbook, every reference page, every binding, the
interactive playground — lives at:

**→ [cx-home.github.io/cx](https://cx-home.github.io/cx/)**

It is the canonical user-facing surface. README is the one-screen intro;
everything else is over there.

Reading offline? Clone the repo and open [`docs/index.html`](docs/index.html)
in a browser — the site is a static bundle and works under `file://` with
no server.

## Status

CX is pre-1.0. **v0.7.0** is the current release line, building on
the v0.6.0 API/format-stability lock — the grammar is stable and the
C ABI is versioned and forward-compatible.

v0.7.0 shipped with a five-binding parity matrix (V, Python, Go,
Rust, TypeScript) by ADR 0022 §D4 to control release scope, with C#,
Java, Kotlin, Ruby, and Swift held in a "frozen" sentinel substate.
Per [Amendment #5](spec/decisions/0022-cx-is-one-language-v0_7_0-scope.md)
the five frozen bindings are being re-promoted to the active matrix
on a binding-by-binding cadence; the C ABI rename is in across all
ten, and each binding's v0.7.0 eval corpus + streaming-events catch-
up lands as that binding's sentinel is removed. The current per-
binding state is tracked in the bindings catalog on the docs site.

v0.7.0 brings **XQuery 4.0 / XPath 4.0 parity** to CXL (FLWOR with
`:let` / `:where` / `:count` / `:while` / `:order-by` / `:group-by`,
windows, `?fn` / `?match` / `?try`, partial application), an ~80-entry
standard function library, a pull-based streaming evaluator, CXPath 4.0
axes (parent / ancestor / sibling / following / preceding), a
parse-time + eval-time include resolver, `cx:lang` inherited-scope
resolution, the doc-gen pipeline this site is built with, and Parquet
bridges in Python, Go, and Rust. Full notes:
[`RELEASE_NOTES_v0.7.0.md`](RELEASE_NOTES_v0.7.0.md).

Formal security review and fuzz-testing infrastructure are still ahead,
so pin a tested version and apply normal pre-1.0 caution before
customer-facing use.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
