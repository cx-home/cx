# CX

> **The CX Data Language** — one syntax for configs, queries, transforms,
> and full programs. Every config, document, query, transform, and
> program is the same tree of `[...]` forms, so the JSON you write today
> can grow into the queries, transforms, and services you write tomorrow
> without changing syntax or learning a second tool.
>
> **Agentic Ready.** Programs are CX values; data is CX values. Humans
> and AI agents read, write, and run the same artifacts through the
> same parser, same AST, same tree shape.

CX is a homoiconic data language. Read it like XML, type it like TOML,
query it like XPath, program it like Lisp. As a format, CX round-trips
losslessly through JSON, YAML, TOML, XML, Markdown, and CSV, so you can
adopt it incrementally without rewriting existing pipelines.

```cx
[service name=auth version:u8=2
  [server host=0.0.0.0 port:u16=8443 +tls]
  [limits :table[tier rps:u32 burst:u32]
    free       10    50
    pro        100   500
    enterprise 1000  5000
  ]
  [?on-request                              ; the program lives in the same tree
    [?rate-limit :tier @user.tier
      [?retry :max=3 :backoff=exponential
        [?forward-to /server]]]]
]
```

Same brackets, same parser. The `?` sigil is the only visible cue that
some subtrees are executable; they're still CX data, queryable and
transformable like every other node. That's the homoiconic property —
and it's why CX is positioned as one product, not "a format plus a
separate language."

## Compared to

**Data formats** — CX subsumes JSON, YAML, TOML, and XML round-trip,
and adds typed scalars, native tables, and a labeled-slot directive
form. The lossless conversion contract is real: every CX document can
be emitted in any of the six target formats and parsed back without
information loss.

| | JSON | YAML | TOML | XML | CX |
|---|:---:|:---:|:---:|:---:|:---:|
| Nested structures | ✓ | ✓ | ✓ | ✓ | ✓ |
| Typed scalars | partial | partial | ✓ | strings only | ✓ |
| Native tables | — | — | partial | — | ✓ |
| Comments | — | ✓ | ✓ | ✓ | ✓ |
| Schema language | external | external | external | XSD | built-in |
| Homoiconic with own language | — | — | — | — | ✓ |

**Homoiconic languages** — CX is closer in spirit to Common Lisp,
Clojure, Scheme, and Racket than to "yet another config format."
Programs are data; data is programs; one syntax substrate, one
universal container.

| | Common Lisp | Clojure | Scheme / Racket | CX |
|---|:---:|:---:|:---:|:---:|
| Homoiconic substrate | S-expressions | EDN | S-expressions | CX trees |
| Data is code | ✓ | ✓ | ✓ | ✓ |
| Format-interop with non-Lisp world | weak | partial (EDN ↔ JSON) | weak | lossless to JSON/YAML/TOML/XML/MD/CSV |
| Schema language | external | spec / malli | contracts | built-in |
| Named element / attribute model | — | — | — | ✓ |

CX's bet: lead with the homoiconic property, keep the data-format
on-ramp as a first-class capability. Start by replacing your JSON.
Grow into queries, then transforms, then services. Same syntax all
the way.

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

The full documentation — overview, install, quickstart, tutorial,
50-way data and programs tours, cookbook, every reference page, every
binding, the interactive playground — lives at:

**→ [cx-home.github.io/cx](https://cx-home.github.io/cx/)**

It is the canonical user-facing surface. README is the one-screen
intro; everything else is over there.

Reading offline? Clone the repo and open [`docs/index.html`](docs/index.html)
in a browser — the site is a static bundle and works under `file://`
with no server.

## Status

CX is pre-1.0. **v0.7.6** is the current development line, building on
the v0.6.0 API/format-stability lock — the grammar is stable and the
C ABI is versioned and forward-compatible.

**v0.7.6 — the CX Data Language consolidation release**, ratified by
[ADR 0027](spec/decisions/0027-unified-pattern-query-transform.md).
v0.7.6 unifies the executable subset of CX into one coherent surface:
patterns as literal CX with `$bindings`, Scala-style for-yield
comprehensions, a small named directive set (`[?find]`, `[?match]`,
`[?for]`, `[?if]`, `[?let]`, `[?try]`, …), full integration
capabilities (visualization, resilience, services, concurrency,
async), and errors-as-values. The "CXL" name from v0.7.0–v0.7.5 is
retired per [§Positioning](spec/decisions/0027-unified-pattern-query-transform.md#positioning-added-2026-05-21);
the language and its data substrate now share one brand.

v0.7.6 ships with a Tier-1 binding parity matrix (V, Python, Go),
with C#, Java, Kotlin, Ruby, Rust, Swift, and TypeScript catching up
on a per-binding cadence. The current per-binding state is tracked
in the bindings catalog on the docs site.

v0.8.0 will tag stable after a burn-in window of bug-fix-only
releases. Formal security review and fuzz-testing infrastructure are
still ahead, so pin a tested version and apply normal pre-1.0 caution
before customer-facing use.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
