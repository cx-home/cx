# CX

[![Version](https://img.shields.io/badge/version-v0.14.0-blue.svg)](#status)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-cx--home.github.io%2Fcx-brightgreen.svg)](https://cx-home.github.io/cx/)
[![Status](https://img.shields.io/badge/status-pre--1.0_experimental-orange.svg)](#status)

> **One concise syntax for data *and* code.** Configs, structured documents,
> tabular data, queries, transforms, and the programs that tie them together —
> one tree of `[...]` forms with typed, spec-defined conversions to and from
> XML, JSON, YAML, TOML, and CSV — including fully lossless XML, JSON, and
> YAML lanes.
>
> **Agentic-ready.** Programs are CX values; data is CX values. Humans and AI
> agents read, write, and run the same artifacts through the same parser, the
> same AST, the same tree shape.

CX is a homoiconic data language. Read it like XML, type it like TOML, query
it like XPath, program it like Lisp. As a format, CX converts to and from
JSON, YAML, TOML, XML, and CSV with spec-defined semantics
([`spec/03-approved/core/conversions.md`](spec/03-approved/core/conversions.md)),
so you can adopt it incrementally without rewriting existing pipelines.

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

**Data formats** — CX converts to and from JSON, YAML, TOML, XML, and
CSV/TSV/PSV, and adds typed scalars, native tables, and a bracketed directive
form. The conversion contract, exactly as the spec
([`conversions.md`](spec/03-approved/core/conversions.md)) states it:

- **XML** — lossless round-trip, working on the shipped CLI today
  (`cx --to=xml --lossless … | cx --from=xml` recovers the original document;
  type metadata travels as `cx:` namespace attributes/carriers, `[table]`
  blocks as `cx:cols`/`cx:row`).
- **JSON / YAML** — typed conversions both ways, and a full lossless mode on
  the shipped CLI: `cx --to=json --lossless … | cx --from=json` (same for
  yaml) recovers an element document byte-identically. Structure rides the
  reserved `$tag` envelope; value types ride a `cx:type` sidecar + per-item
  carriers in JSON and native `!!cx:T` tags in YAML.
- **TOML** — typed idiomatic conversion both ways. TOML's grammar has no
  extension point for type tags, so the spec defines no lossless mode for
  it; round through CX or XML when you need full fidelity.
- **CSV / TSV / PSV** — well-defined and typed (auto-typing with per-column
  narrowing), deliberately **not** lossless (conversions.md §8): delimited
  files carry no hierarchy, comments, or type metadata.
- In the other direction, any JSON / YAML / TOML document converts to CX and
  back without loss within that format's expressive range.

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
| Format-interop with non-Lisp world | weak | partial (EDN ↔ JSON) | weak | typed conversions to/from XML/JSON/YAML/TOML/CSV (XML/JSON/YAML lossless) |
| Schema language | external | spec / malli | contracts | built-in |
| Named element / attribute model | — | — | — | ✓ |

CX's bet: lead with the homoiconic property, keep the data-format on-ramp as a
first-class capability. Start by replacing your JSON. Grow into queries, then
transforms, then services. Same syntax all the way.

## Install

**Prebuilt binary** — download the tarball for your platform from the
[latest GitHub release](https://github.com/cx-home/cx/releases/latest)
(currently `cx-darwin-arm64.tar.gz` for macOS on Apple silicon; it contains
the `cx` CLI plus `libcx.dylib` and `cx.h` for embedders), then put `cx` on
your `PATH`:

```sh
tar -xzf cx-darwin-arm64.tar.gz
sudo install -m 755 cx /usr/local/bin/cx
cx --version
```

**Build from source** — needs `make`, a C compiler, and git. The patched V
toolchain CX compiles with is vendored as a submodule, so clone with
`--recursive`:

```sh
git clone --recursive https://github.com/cx-home/cx
cd cx
make -C third_party/v   # one-time: build the vendored V toolchain
make build-vcx          # libcx + the cx CLI (staged at vcx/target/cx)
make promote-cli        # verify + install the CLI to /usr/local/bin
cx --version
```

**One-line install** — once `cxhome.org`'s DNS is live, the hosted installer
downloads the latest release for your platform, verifies its SHA-256, and
installs to `~/.local` (override with `PREFIX=`):

```sh
curl -sSL https://cxhome.org/install | sh
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
Reading offline? The guide is generated build output: run `make guide` first,
then open `docs/guide/index.html` in a browser — it is a static bundle and
works under `file://` with no server.

## Platform

The language core is one consumption mode; the repo also carries a platform
tier, integrating on the current release line:

- **XAP** — the application/feature-distribution layer: features are sealed,
  signed CX artifacts served to clients over the XAP/XSP protocols. Spec:
  [`spec/03-approved/xap/xap.md`](spec/03-approved/xap/xap.md); hands-on
  intro: [`docs/dev/xap-quickstart.md`](docs/dev/xap-quickstart.md).
- **cx store** — a content-addressed multimodel store, embeddable in-process
  ([`docs/dev/store-embedded.md`](docs/dev/store-embedded.md)) across mem /
  file / sqlite / s3 substrates. Stdlib surface:
  [`spec/03-approved/std-lib/store.md`](spec/03-approved/std-lib/store.md).
- **store-serve** — the store's single-node service tier: a daemon with auth,
  observability, and the CSRP/gRPC remote protocols
  ([`docs/dev/store-service.md`](docs/dev/store-service.md)).

## Operations

Running CX in anger is documented in the developer-onboarding set at
[`docs/dev/`](docs/dev/README.md) — deploy artifacts and service operation
([`docs/dev/store-service.md`](docs/dev/store-service.md)), store management
and recovery ([`docs/dev/store-management.md`](docs/dev/store-management.md)),
security posture ([`docs/dev/store-security.md`](docs/dev/store-security.md)),
and registry setup/consumption for distributing features
([`docs/dev/registry-setup.md`](docs/dev/registry-setup.md)).

## Embedding libcx

CX ships as an embeddable C library: `make install` installs `libcx`, the
[`include/cx.h`](include/cx.h) header, and a pkg-config file (generated from
[`cx.pc.in`](cx.pc.in)) so `pkg-config --cflags --libs cx` works from any C
consumer. The versioned C ABI contract — symbols, capability bits,
memory/threading rules — is
[`spec/03-approved/core/abi.md`](spec/03-approved/core/abi.md), and every
language binding under [`lang/`](lang/) is a worked example of embedding it.
(Note: `examples/embedding_test.cx` is about embedding *foreign text in CX
documents*, not about embedding libcx.)

## Status

CX is **pre-1.0** and under active development — the current release is the
version badge above. The grammar is stable and the C ABI is versioned and
forward-compatible.

What's in each release — new surface, fixes, and any migration notes — lives in
[`CHANGELOG.md`](CHANGELOG.md) and the per-release `RELEASE_NOTES_v*.md` files;
the latest of those is the authoritative release surface. Full language and
stdlib reference is on the [docs site](https://cx-home.github.io/cx/).

A formal external security review and the multi-core performance work are
still ahead (in-repo fuzz harnesses exist — see
[`SECURITY.md`](SECURITY.md) — but no third-party audit yet), so pin a tested
version and apply normal pre-1.0 caution, as the disclaimer above says.

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
