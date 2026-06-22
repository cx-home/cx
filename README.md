# CX

[![Version](https://img.shields.io/badge/version-v0.12.0-blue.svg)](#status)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-cx--home.github.io%2Fcx-brightgreen.svg)](https://cx-home.github.io/cx/)
[![Status](https://img.shields.io/badge/status-pre--1.0_experimental-orange.svg)](#status)

> **One concise syntax for data *and* code.** Configs, structured documents,
> tabular data, queries, transforms, and the programs that tie them together —
> one tree of `[...]` forms that round-trips losslessly through XML, JSON,
> YAML, TOML, and CSV.
>
> **Agentic-ready.** Programs are CX values; data is CX values. Humans and AI
> agents read, write, and run the same artifacts through the same parser, the
> same AST, the same tree shape.

CX is a homoiconic data language. Read it like XML, type it like TOML, query
it like XPath, program it like Lisp. As a format, CX round-trips losslessly
through JSON, YAML, TOML, XML, and CSV, so you can adopt it incrementally
without rewriting existing pipelines.

```cx
[service name=auth port=8443 tls=true
  [route path=/login  method=:post]
  [route path=/health method=:get]
  [active [?for [in $r //route] [yield $r@path]]]]
```

Same brackets, same parser. The `?` sigil is the only visible cue that a
subtree is executable — it's still CX data, queryable and transformable like
every other node. That's the homoiconic property, and it's why CX is one
product, not "a format plus a separate language."

> ⚠️ **Not production-ready — experimental, pre-1.0.** CX is already
> full-featured, but it's still hardening. Expect rough edges: single-core
> performance is strong (~135k HTTP requests/second) while multi-core scaling
> is still in progress, and a couple of build dependencies are on the way out.
> Pin a version, kick the tires, and file issues — but don't put it in front
> of customers yet.

## Compared to

**Data formats** — CX subsumes JSON, YAML, TOML, and XML round-trip, and adds
typed scalars, native tables, and a bracketed directive form. The lossless
conversion contract is real: every CX document can be emitted in any of the
five target formats and parsed back without information loss.

| | JSON | YAML | TOML | XML | CX |
|---|:---:|:---:|:---:|:---:|:---:|
| Nested structures | ✓ | ✓ | ✓ | ✓ | ✓ |
| Typed scalars | partial | partial | ✓ | strings only | ✓ |
| Native tables | — | — | partial | — | ✓ |
| Comments | — | ✓ | ✓ | ✓ | ✓ |
| Schema language | external | external | external | XSD | built-in |
| Homoiconic with own language | — | — | — | — | ✓ |

**Homoiconic languages** — CX is closer in spirit to Common Lisp, Clojure,
Scheme, and Racket than to "yet another config format." Programs are data;
data is programs; one syntax substrate, one universal container.

| | Common Lisp | Clojure | Scheme / Racket | CX |
|---|:---:|:---:|:---:|:---:|
| Homoiconic substrate | S-expressions | EDN | S-expressions | CX trees |
| Data is code | ✓ | ✓ | ✓ | ✓ |
| Format-interop with non-Lisp world | weak | partial (EDN ↔ JSON) | weak | lossless to JSON/YAML/TOML/XML/CSV |
| Schema language | external | spec / malli | contracts | built-in |
| Named element / attribute model | — | — | — | ✓ |

CX's bet: lead with the homoiconic property, keep the data-format on-ramp as a
first-class capability. Start by replacing your JSON. Grow into queries, then
transforms, then services. Same syntax all the way.

## Install

```sh
# macOS / Linux — single statically-linked binary, no runtime deps
curl -sSL https://cx-home.io/install | sh

# Or build from source
git clone https://github.com/cx-home/cx && cd cx && make build && make test
```

V users — the native V binding lives in its own
[`cx-home/cx-v`](https://github.com/cx-home/cx-v) repo so V's package manager
can install it directly:

```sh
v install --git https://github.com/cx-home/cx-v
```

Try the in-binary demo (runs in under a second, no file I/O, no network):

```sh
cx demo
```

## Documentation

The full documentation — overview, install, quickstart, tutorial, the data and
code tours, the standard-library reference, cookbook, every binding, and the
interactive playground — lives at:

**→ [cx-home.github.io/cx](https://cx-home.github.io/cx/)**

It is the canonical user-facing surface; this README is the one-screen intro.
Reading offline? Open [`docs/guide/index.html`](docs/guide/index.html) in a
browser — the guide is a static bundle and works under `file://` with no
server.

## Status

CX is **pre-1.0** and under active development — the current release is the
version badge above. The grammar is stable and the C ABI is versioned and
forward-compatible.

What's in each release — new surface, fixes, and any migration notes — lives in
[`CHANGELOG.md`](CHANGELOG.md) and the per-release `RELEASE_NOTES_v*.md` files;
the latest of those is the authoritative release surface. Full language and
stdlib reference is on the [docs site](https://cx-home.github.io/cx/).

Formal security review, fuzz-testing, and the multi-core performance work are
still ahead — so pin a tested version and apply normal pre-1.0 caution, as the
disclaimer above says.

## Contributing

CX is built in the open, and feedback shapes it. The most useful things you can
do right now:

- **Try it and report what breaks** — open an issue with a minimal `.cx` repro.
  Conversion edge cases, surprising parses, and crashes are all valuable.
- **Review** — corrections to the guide, unclear docs, rough ergonomics, or a
  plain "this surprised me" are exactly the signal that's wanted.
- **Suggest** — language and standard-library ideas, missing conversions,
  workflow gaps.

Pull requests are welcome too, but at this stage issue reports, reviews, and
suggestions are the highest-leverage help. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) and
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## License

Apache-2.0. See [`LICENSE`](LICENSE).
