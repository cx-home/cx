# CX

[![Version](https://img.shields.io/badge/version-v0.18.0-pre.1-blue.svg)](#status)
[![CX](https://img.shields.io/badge/CX-54.3%25_of_source-1a1a17.svg)](#status)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-cxhome.org-brightgreen.svg)](https://cxhome.org/)
[![Status](https://img.shields.io/badge/status-pre--1.0_experimental-orange.svg)](#status)

**TL;DR — reach for CX whenever the data is the point.** One bracketed syntax
is the document, the query, the program and the compiler's own tree, so the
file you read is the file you transform, validate, hash, store and serve.
Python set the standard a working language has to meet — readable on day one,
batteries included — and CX is built to that standard and past it where data
work hurts. Each line below names the conformance fixture that
[cxhome.org](https://cxhome.org/) replays for it when the site is built:

- a query is a pattern over the document, not code over an object model
  (`program-for-003-name-email-pair`);
- a fraction literal is an exact decimal, and mixing one with a binary float
  is refused out loud (`ap-decimal-float-mix-right`);
- a program reads nothing it was not granted, and the denial is a value that
  names the flag (`io-001-read-file-cap-denied`);
- regular expressions are RE2: a construct that would need backtracking is
  refused when the pattern compiles (`re-003-compile-backreference-unsupported`);
- state that outlives the program is two calls to a content-addressed store
  (`store-rt-001-round-trip-get`);
- an agent protocol message is an ordinary value projected to its wire form
  (`mcp-001-call-tool-request-shape`).

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
([`spec/03-approved/core/conversions.md`](https://github.com/cx-home/cx-core-data/blob/main/spec/03-approved/core/conversions.md)),
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
> full-featured, but it's still hardening. Expect rough edges: multi-core
> scaling is still in progress, and a couple of build dependencies are on the
> way out. Pin a version, kick the tires, and file issues — but don't put it
> in front of customers yet.

## Compared to

**Beside Python** — Python is the standard a general-purpose language is
measured by, and the one CX is built to meet and exceed, not a language CX sets
out to replace. The guide's
[CX and Python](https://cxhome.org/comparison.html#cx-vs-python) section shows
each difference — exact decimals, granted effects, RE2, errors as values,
updates that never mutate, one value model, built-in identity — beside the
fixture it replays.

**Data formats** — CX converts to and from JSON, YAML, TOML, XML, and
CSV/TSV/PSV, and adds typed scalars, native tables, and a bracketed directive
form. The conversion contract, exactly as the spec
([`conversions.md`](https://github.com/cx-home/cx-core-data/blob/main/spec/03-approved/core/conversions.md)) states it:

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

**One-line install** — the hosted installer resolves the latest release for
your OS and architecture, verifies the tarball against the release's
`SHA256SUMS.txt`, and installs to `~/.local` (override with `PREFIX=`):

```sh
curl -sSL https://cxhome.org/install | sh
```

The installer installs a **profile** — a named artifact composition with the
same `cx` binary name and a profile-decided surface. The default is
`platform` (everything: evaluator, store/fabric daemons, servers); leaner
compositions install with `CX_PROFILE=`:

```sh
curl -sSL https://cxhome.org/install | CX_PROFILE=data sh
```

| Profile | Surface |
|---|---|
| `platform` (default) | the rings and the platform group: evaluator + local-effect stdlib + store/fabric/XAP daemons |
| `cli` | Rings 0–1: evaluator + local-effect stdlib packs + http client; no servers |
| `embed` | Rings 0–1 core: evaluator only, no local-effect packs; ships the embed-shape `libcx` |
| `data` | Ring 0: parse/convert/canonical/hash/diff/validate — cannot execute programs (no evaluator in the artifact) |

**Prebuilt tarballs** — every
[release](https://github.com/cx-home/cx/releases/latest) carries the four
profiles for macOS on Apple silicon and for Linux on arm64:
`cx-darwin-arm64.tar.gz` and `cx-linux-arm64.tar.gz` (the `platform` profile:
the `cx` CLI plus `libcx` and `cx.h` for embedders) and
`cx-<profile>-<os>-arm64.tar.gz` for the other three, beside a conformance
bundle, the VS Code extension and `SHA256SUMS.txt`. No build is published for
x86_64 or for Windows. To install one by hand, put `cx` on your `PATH`:

```sh
tar -xzf cx-darwin-arm64.tar.gz
sudo install -m 755 cx /usr/local/bin/cx
cx --version
```

**Build from source** — needs `make`, a C compiler, git, and a released `cx`
to fetch the pinned repositories with. The patched V toolchain CX compiles
with is vendored as a submodule, so clone with `--recursive`:

```sh
git clone --recursive https://github.com/cx-home/cx
cd cx
make -C third_party/v   # one-time: build the vendored V toolchain
make deps-sync          # fetch the pinned repositories into deps/
make build-vcx          # libcx + the cx CLI (staged at deps/cx-core-code/vcx/target/cx)
make promote-cli        # verify + install the CLI to /usr/local/bin
cx --version
```

A fresh clone's `git submodule update --init --recursive` must run WITHOUT
`--depth` (`check-v-fork` walks the V fork's full ancestry), and
`make deps-sync` runs on a released `cx`: the one on your `PATH`, the one the
installer put at `~/.local/bin/cx`, or the one `CX_BIN=<path>` names;
`make build-vcx` refuses to start until `deps/` holds every pinned module.

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

The site — the landing page with its replayed examples, the guide (the
language ring by ring, the quickstart, the comparison, a reference page for
every bundled module), the LLM primer and the contributor's front door —
lives at:

**→ [cxhome.org](https://cxhome.org/)**

It is the canonical user-facing surface; this README is the one-screen intro.
Reading offline? The site is generated build output: run `make site` and open
`site/index.html` in a browser (`make guide` alone renders the guide to
`docs/guide/`) — it is a static bundle and works under `file://` with no
server. `cx primer` prints the primer for exactly the binary you run.

## Platform

The language core is one consumption mode; the repo also carries a platform
tier, integrating on the current release line:

- **XAP** — the application/feature-distribution layer: features are sealed,
  signed CX artifacts served to clients over the XAP/XSP protocols. Spec:
  [`spec/03-approved/xap/xap.md`](https://github.com/cx-home/cx-platform-xap/blob/main/spec/03-approved/xap/xap.md); hands-on
  intro: [`docs/dev/xap-quickstart.md`](docs/dev/xap-quickstart.md).
- **cx store** — a content-addressed multimodel store, embeddable in-process
  ([`docs/dev/store-embedded.md`](docs/dev/store-embedded.md)) across mem /
  file / sqlite / s3 substrates. Stdlib surface:
  [`spec/03-approved/platform/store.md`](https://github.com/cx-home/cx-platform-store/blob/main/spec/03-approved/platform/store.md).
- **store-serve** — the store's single-node service tier: a daemon with auth,
  observability, and the XSP store-profile and gRPC remote transports
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
[`include/cx.h`](https://github.com/cx-home/cx-core-code/blob/main/include/cx.h) header, and a pkg-config file (generated from
[`cx.pc.in`](https://github.com/cx-home/cx-core-code/blob/main/cx.pc.in)) so `pkg-config --cflags --libs cx` works from any C
consumer. The versioned C ABI contract — symbols, capability bits,
memory/threading rules — is
[`spec/03-approved/core/abi.md`](https://github.com/cx-home/cx-core-data/blob/main/spec/03-approved/core/abi.md), and every
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
stdlib reference is on the [docs site](https://cxhome.org/).

A formal external security review and the multi-core performance work are
still ahead (in-repo fuzz harnesses exist — see
[`SECURITY.md`](SECURITY.md) — but no third-party audit yet), so pin a tested
version and apply normal pre-1.0 caution, as the disclaimer above says.

**About the CX badge.** GitHub's language bar shows no CX, and that is a gap
in the tooling rather than in this repository: the bar is computed by
[Linguist](https://github.com/github-linguist/linguist), whose registry has no
CX entry yet, so every `.cx`, `.cxd`, and `.cxs` byte is uncounted. Linguist
admits a language only after it is in wide public use, and a project cannot
self-register — so the badge above is the honest self-report meanwhile,
measured by `scripts/lang_stats.cx` over tracked source (vendored and
generated trees excluded) and refreshed with every release.

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
