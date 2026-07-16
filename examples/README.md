# CX examples

Every example in this tree runs against the released `cx` binary — no
build flags, no scaffolding. Two kinds of file live here:

- **Data documents** — configs, prose markup, tables, logs. Run
  `cx FILE` to render (a data document renders as itself), or convert
  with `cx --json|--yaml|--toml|--xml|--md|--csv FILE`.
- **Program tours** — `.cx` programs exercising the code surface
  (directives, CXPath, match, modify). Run `cx FILE`, adding
  `--data=FILE.input.cx` where the tour ships an input companion
  (it binds as `$doc`).

## Index

| Example | Demonstrates | Run | Status |
| ------- | ------------ | --- | ------ |
| [`config.cx`](config.cx) | Config idioms: sized types (`::u16`), boolean attrs, numeric underscores, leading-zero strings | `cx --json examples/config.cx` | passing |
| [`env.cx`](env.cx) | Anchors + merges for per-environment config | `cx examples/env.cx` | passing |
| [`books.cx`](books.cx) | `[table[…]]` block — typed columns, positional rows, CSV lane | `cx --csv examples/books.cx`, `cx table info examples/books.cx` | passing |
| [`logs.cx`](logs.cx) | logfmt mode — top-level `key=value` lines, typed cells | `cx --json examples/logs.cx` | passing |
| [`doc.cx`](doc.cx) | Prose markup → Markdown lane | `cx --md examples/doc.cx` | passing |
| [`article.cx`](article.cx) | Rich document: mixed content, raw text, entity/char refs | `cx examples/article.cx` | passing |
| [`post.cx`](post.cx) | Blog post in plain element markup | `cx examples/post.cx` | passing |
| [`chapter.cx`](chapter.cx) | XML-style namespaces (`xmlns:` bearer pattern) | `cx --xml examples/chapter.cx` | passing |
| [`embedding_test.cx`](embedding_test.cx) | Foreign-syntax code blocks via `[# … #]` raw text | `cx examples/embedding_test.cx` | passing |
| [`vcore.cx`](vcore.cx) | Core-grammar showcase, one canonical sample per feature | `cx examples/vcore.cx` | passing |
| [`cx-tour.cx`](cx-tour.cx) | FORMAT tour — every structural feature in one document | `cx examples/cx-tour.cx` | passing |
| [`code-tour.cx`](code-tour.cx) | CODE tour — every core directive | `cx examples/code-tour.cx --data=examples/code-tour.input.cx` | passing |
| [`cxpath-tour.cx`](cxpath-tour.cx) | CXPath tour — every axis and predicate kind | `cx examples/cxpath-tour.cx --data=examples/cxpath-tour.input.cx` | passing |
| [`match-multi.cx`](match-multi.cx) | Multi-arm `[?match]` — case/when/else, patterns, wildcard | `cx examples/match-multi.cx --data=examples/match-multi.input.cx` | passing |
| [`modify-crud.cx`](modify-crud.cx) | Pure-functional CRUD via `[?modify]` | `cx examples/modify-crud.cx --data=examples/modify-crud.input.cx` | passing |
| [`validate/`](validate/) | `.cxs` schema + `cx validate` — pass and fail runs with exact diagnostics | see [`validate/README.md`](validate/README.md) | passing |
| [`comparisons/`](comparisons/) | CX vs JSON/YAML/CSV side-by-side, per-lane trade-offs | see [`comparisons/README.md`](comparisons/README.md) | passing |
| [`cx/`](cx/) | Two tiny data fixtures (`greet.cx`, `users.cx`) | `cx examples/cx/users.cx` | passing |
| [`cxstore/client-server/`](cxstore/client-server/) | Store client+server over CSRP, two real processes | `make -C examples/cxstore/client-server run` | passing |
| [`cxstore/grpc/`](cxstore/grpc/) | Same store surface over gRPC via the `cx store-serve` daemon | `make -C examples/cxstore/grpc run` | passing |
| [`cxstore/dir-sync/`](cxstore/dir-sync/) | Directory tree ⇄ content-addressed store (ingest / materialize / watch) | `make -C examples/cxstore/dir-sync run` | passing |
| [`htmx/`](htmx/) | Server-rendered htmx demos | — | **parked, do not publish** — pre-v0.8.0 syntax; see [`htmx/DO-NOT-PUBLISH.md`](htmx/DO-NOT-PUBLISH.md) |

The four tours ship a `*.input.cx` companion (`code-tour`, `cxpath-tour`,
`match-multi`, `modify-crud`). The documented
`cx TOUR.cx --data=TOUR.input.cx` run line binds the companion as
`$doc` / `$input` (the [#415](https://github.com/cx-home/cx-private/issues/415)
decision: the run surface takes `--data=`, and unknown flags are hard
errors instead of silent no-ops). The tours are document-driven —
running one without `--data` raises the loud unbound-`$doc` error by
design rather than rendering empty sections.

`etl_conventions_cx.md` (ETL conventions write-up) is prose, not a
runnable example; parts of it are stale and tracked in
[#424](https://github.com/cx-home/cx-private/issues/424).

## Format companions — generated, do not hand-edit

The non-`.cx` siblings are **derived** from their `.cx` sources by the
live binary:

| Companion | Source | Lane |
| --------- | ------ | ---- |
| `config.json` / `config.yaml` / `config.toml` / `config.xml` | `config.cx` | `cx --json/--yaml/--toml/--xml` |
| `books.yaml` / `books.toml` | `books.cx` | `cx --yaml/--toml` |
| `books.json` / `books.xml` | `books.cx` | `cx --from=cx --to=json/--to=xml` (see note below) |
| `doc.md` | `doc.cx` | `cx --md` |
| `comparisons/table_block.csv` | `comparisons/table_block.cx` | `cx --csv` |

Regenerate them all with:

```sh
make examples-regen                          # repo build (vcx/target/cx)
make examples-regen CX_BIN=$(command -v cx)  # or any installed binary
```

`books.json` and `books.xml` are generated via the explicit
`--from=cx --to=…` conversion lane: the
[#413](https://github.com/cx-home/cx-private/issues/413) table fix
landed there, while the AST-JSON projection shorthand (`--json FILE`)
still drops table rows
([#443](https://github.com/cx-home/cx-private/issues/443)). The XML
companion round-trips back to `books.cx` exactly (`cx eq` clean).
