# CX contributor front door — implementation

> **GENERATED FILE.** Source: `docs-src/llm/contributor-implementation.md.tmpl`,
> assembled by `scripts/gen_docs/primer_build.cx`. This file is rules only;
> each cites its decision and the step that refuses the tree that breaks it.
> The facts it relies on are projected in `contributor-architecture.md`.
> Edit the template, never this file.

## TL;DR

- Write CX first. The implementation language of the evaluator and the
  products is V; everything else — scripts, gates, generators, probes — is a
  CX program run with `cx FILE` (RULED: CXF-1).
- **A V module is one directory**, and V compiles it as one unit: a file move
  across directories is an interface change, never a rename (RULED: RS-24).
- **Imports point down only**: Ring 0 imports nothing above it; Ring 1 imports
  Ring 0; a product imports the rings and exactly the products its row pins
  (RULED: RS-1, RS-24).
- **`pub` is per caller**: a symbol is exported when a caller in another
  module needs it, and the product's `pub` surface IS its interface
  (RULED: RS-24).
- The core names no product: a product plugs in through the registration
  hooks from its own `init()` (RULED: D71a, D73a).

## 1. Where V code goes

| The code is | Directory (in its repository) | `module` | It may import |
|---|---|---|---|
| Ring 0 — the reader, writer, canonical form, codecs | `vcx/cx/` (`cx-core-data`) | `cx` | vlib only |
| Ring 1 — the evaluator, the stdlib natives, a platform module's declared pure half | `vcx/code/` (`cx-core-code`) | `code` | `cx`, vlib |
| a V product (store, net, mail, identity, db, fabric, xsp, xap) | `vcx/<vmodule>/` (its product repository) | `<vmodule>` | `cx`, `code`, vlib, and the V modules of the repositories its row pins |
| the front door's own verbs and grader | `vcx/cmd/`, `vcx/corpus/` (`cx`) | per directory | whatever the assembled build provides |

The `vmodule=` and `pins=` of each product are in the repository map
(`contributor-architecture.md` §2). `product-import-gate` refuses an import a
product's pins do not name; `ring-import-gate` refuses a ring importing
upward (RULED: RS-24, VC-22).

## 2. The rules for a V change

| # | Rule | Decision | Held by |
|---|---|---|---|
| 1 | A behaviour change lands its failing corpus case FIRST, in its own commit; the code that passes it follows. | AGENTS.md rule 2 (RULED: CFG-1) | the fixture graders |
| 2 | No stub, no placeholder success, no seam with no live consumer. An effectful primitive that cannot be finished refuses; it never returns a synthetic shape. | AGENTS.md rule 3 (RULED: CFG-1) | `check-no-stub-impl` |
| 3 | Errors travel as `[err code=cx-err:CXERnnnn …]` values with a registered code; an effect is refused with the capability that would allow it. | the corpus cases in `contributor.md` §2 | `cxer-registry-gate`, the corpus |
| 4 | Move a file across modules only with its imports and its `pub` surface; a bare same-module call that crosses a repository line cannot compile alone. | RULED: RS-24 | `product-import-gate`, each product's own build |
| 5 | A product registers its builtins with `register_stdlib_builtin(family, f)` and its CLI verbs with `register_cli_verb(v)` from its own `init()`. A family registered twice panics naming both. | RULED: D71a, D73a | the profile builds (a binary without the product refuses its names `CXER0136`) |
| 6 | A pure Ring-1 V half stays in `vcx/code` even when one product is its only caller; its row names it in `half=` or re-allocates it to the core. | RULED: D76c, D84a | `placement-gate`, `repos-allocation-gate` |
| 7 | A long-lived evaluator (a grader, a server loop) closes a finished env before the next program: per-case cost stays flat under `-gc e`. | RULED: RS-17 | review; the step timings `check-verification-budget` judges |
| 8 | The V compiler is a pinned fork; a fork change lives in the fork's own repository and gets a register row. Never edit `third_party/`. | RULED: VC-1 | `check-v-fork` |
| 9 | No version literal in code, a comment or a spec sentence: derive it from `VERSION`. | AGENTS.md rule 5 (RULED: CFG-1) | `check-version-consistency` |
| 10 | A mover fixes every reader it missed — path scans, doc links, selection examples, baselines — in the same branch. | RULED: RS-8 | the post-merge union |

Two operational rules from `CONTRIBUTING.md` (practice, not decisions): a new
standalone `*_test.v` links the whole module graph on every run, so add test
functions to the umbrella that owns the area (`contributor-test.md` §3); and
the dev build accepts shapes the `-prod` checker refuses, so `check-prod-build`
runs on every change set.

## 3. The front door's build, from the pins

The front door compiles nothing of its own but its verbs and grader; the
binaries are assembled from the pinned checkouts:

```console
$ git submodule update --init --recursive        # the V fork and re2, at their gitlinks
$ make -C third_party/v                          # the fork builds itself
$ make deps-sync CX_BIN=<any cx>                 # every deps.cxd pin into deps/<repo>/, refusing a stale or drifted one
$ make build-vcx                                 # deps/cx-core-code/vcx's build over the front door's deps.cxd and deps/
$ deps/cx-core-code/vcx/target/cx --version      # names the commit and the V fork it was built from
```

- The build passes the pinned checkouts to V through `-path`; a direct
  `v test` of anything importing `cx` needs the same flags, printed by
  `make -s -C deps/cx-core-code/vcx print-VFLAGS`.
- Four builds share one source: `data`, `embed`, `cli`, `platform`
  (`make build-vcx` is the platform build). A `ring=1` corpus case is graded
  in every profile, so a Ring-1 case may not lean on a platform pack
  (RULED: RS-10).
- A `deps/<repo>/` checkout is a build INPUT, never a place to edit: a change a
  product needs is made in that product's repository and reaches the front
  door as a pin bump (RULED: RS-7).

## 4. Tooling in CX

- A new script is a CX program (`scripts/<name>.cx`) run with `cx FILE`,
  imported by path (`[?lib './scripts/<name>.cx' as=x]`) when another program
  needs it. Keep the logic PURE — text in, verdict out — and put the reads,
  writes and exit in the program that calls it (`scripts/deps_pins.cx` is the
  shape) (RULED: CXF-1).
- Another language for a task needs a filed `cx-gap` issue — the task, the CX
  attempt, the gap by kind — BEFORE it runs, for a probe as much as for a
  checked-in tool (RULED: CXF-1).
- A CX surprise — a silent wrong answer, a lint that passes what the run
  refuses, a diagnostic that points elsewhere — is filed the same hour with
  its reproduction (RULED: CXF-8).
- A script that reads or writes the corpus is graded by `reader-parity`
  against the other readers of the same files (RULED: CXF-5).
- A check that derives its population from the tree refuses to vouch when the
  derivation comes up empty or short — a check that runs over the empty set
  passes forever (`check-selection-manifest` and this layer's generators hold
  a row floor for that reason).
