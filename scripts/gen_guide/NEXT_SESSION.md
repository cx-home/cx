# Handoff — finish the CX-native guide (a → b → c), autonomously to completion

Branch: `release/0.8.0` of cx-private. Execute (a) then (b) then (c) below to
completion, committing + gating each chunk. Do not ask for approval mid-plan.

## What is already DONE (commits `b2b3b4ff` … `dab5e2dd`, all gates green)

The guide is now a single idiomatic CX pipeline in
[`scripts/gen_guide/guide_build.cx`](guide_build.cx)
(`read → [$cx:parse] → extract → reshape → [$xml:emit] → write`):

- **Grouped nav + landing/submenu** for three areas: **Guide** (hand-authored
  `docs-src/canonical/sections/*.cxd`, 0–15), **Standard library** (landing
  `libraries.html` + 38 `lib-<m>.html` pages), **XAP** (landing `xap.html` +
  D1–D4 demo pages). Nav built per-group; **never concatenate for-result
  sequences** (they nest — see gotchas).
- **Recursive renderer** (`render-block`/`render-section`/`heading`, h2…h6 by
  depth) + an `[output]` block type. Verified byte-identical on the 16 existing
  sections.
- **Standard library** pages projected from **co-located `[module-doc]` /
  `[fn-doc]` in `stdlib/<m>.cx`** (single source of truth). 927 functions render
  with signature + a VERIFIED example (code + expected output). Built directly
  as HTML and `[$xml:emit]`'d (NOT via a constructed `[section]` navigated by
  CXPath — that collapses the per-example `[?for]`).
- **XAP** pages read demos live from `spec/03-approved/xap/demos/` (source +
  `expected-output.txt`), so they can't drift.
- **Loader fix** (`vcx/code/module_loader.v`): `find_close_bracket` now skips
  `"""…"""` spans so bracketed code in co-located examples doesn't miscount.
- **Seeder** [`scripts/gen_stdlib_docs/seed.cx`](../gen_stdlib_docs/seed.cx):
  one-time CX bootstrap that read the (nested) `conformance/stdlib/coverage.cx`
  and appended `[module-doc]`+`[fn-doc]` to each module. Idempotent (skips
  modules with a `[module-doc]`).

Schema spec (DRAFT, do NOT graduate — user owns G3):
`spec/02-inprogress/stdlib_colocated_docs.md`.

Gate commands (run after each chunk; all must be green):
- `make build-vcx-dev` (binary at `vcx/target/cx`)
- `make test-vcx-suite` (NOT raw `v test`; currently 123/123)
- `make -C vcx conform-all` (currently 146/146)
- render: `vcx/target/cx scripts/gen_guide/guide_build.cx --allow-read --allow-write`
  (or `make guide`, which also rebuilds wasm — slow).

## (a) Polish the stdlib content — make it genuinely world-class to read

Current gaps: module **scope prose is rough** (seeded from each module's
impl-focused `[- … -]` header comment, includes internal/“edit both” notes; and
`header-scope` in seed.cx has a **UTF-8 offset bug** — `[$strings:find]` returns
a BYTE offset but the em-dash `—` is 3 bytes, so `+4` clips the first word, e.g.
“string”→“ring”). Per-function **summaries are empty**.

Tasks:
1. Replace each module's `[module-doc]/[scope]` with the user-facing **§1 Scope**
   prose from `spec/03-approved/std-lib/<m>.md` (NOT the impl header comment).
   Decide extraction: a CX projection reading the md is fuzzy — simplest robust
   path is to author a clean one-paragraph scope per module (38 of them) by
   reading each spec §1. Keep it co-located in `stdlib/<m>.cx`.
2. Fill per-function `[summary """…"""]` from the spec per-function descriptions
   (or hand-author terse, accurate one-liners). This is the bulk; consider a
   module-at-a-time pass. Examples are already verified — don't touch them.
3. Edit IN PLACE in `stdlib/<m>.cx` (co-located source is the point). After
   edits, rebuild + gate (docs are inert, but verify modules still load).
4. Consider keeping/expanding examples to 1–2 per function where the extra one
   adds signal (error cases are in coverage.cx fixtures).

## (b) Finish the toolchain cutover (no Python, no drift)

1. **Retire Python**: delete `scripts/stdlib_coverage.py` and
   `scripts/gen_guide_libraries.py`; remove the `stdlib-coverage` /
   `guide-libraries` make targets (in `scripts/gen_guide/guide.mk` + any
   top-level Makefile refs). The seeder did its one-time job.
2. **Drop stale artifacts**: delete `docs-src/canonical/sections/16-libraries.cxd`
   (guide_build already skips it) and the `[section n=16 id=libraries …]` block
   in `docs-src/canonical/manifest.cxd`. **Before deleting
   `conformance/stdlib/coverage.cx`, verify nothing else consumes it** (grep
   tests/Makefile/conformance harness) — the guide no longer needs it, but the
   coverage gate might; if so, leave it or replace its generator with CX.
3. **Reconcile examples↔fixtures (design decision)**: fn-doc examples were
   SEEDED FROM `conformance/stdlib/*.cxd`. End state should have ONE source.
   Original plan Phase 2 = "examples ARE the fixtures". Either (i) make the
   conformance harness extract `[example]/[expect]` from each module's fn-doc and
   run them (then the `.cxd` per-module fixtures become generated/retired), or
   (ii) keep `.cxd` as the test source and gate that each fn-doc example matches
   its fixture. Pick (i) for the cleaner end state if feasible; document the call
   in `spec/02-inprogress/stdlib_colocated_docs.md`.
4. **Freshness gates (CX, in CI)**: (1) presence parity — every public `[?def
   NAME]` has a `[fn-doc name=NAME]` and vice-versa; (2) signature/purity
   agreement; (3) regenerate §16 + assert unchanged (so 38≠N can't recur); (4)
   examples run green via conformance. A deliberately-stale artifact must fail.
   Wire into `make -C vcx conform-all` or a new `make guide-check`.

## (c) Release items

1. **WASM/playground**: `make build-playground-wasm-for-guide` (builds
   `libcx-async` + `libcx-pthreads` into `dist/wasm/`), then `make guide`
   copies them. Smoke-test the playground against the CURRENT binary (lots of
   net/http/process/xap landed since the Jun-8 artifacts). Verify
   `docs/guide/playground.html` runs an example.
2. **Tooling currency** (`tooling/`): tree-sitter (`tooling/tree-sitter-cx`),
   LSP (`tooling/lsp`), completions, neovim, vscode. Audit module lists /
   keywords for the **new surface**: `xap` (the 38th + `cx-xap`), and any new
   functions/modules since the tooling was last synced. The skills
   `cx-tooling-author` / `cx-docs-author` may help regenerate install/editor
   layers. Update + verify.

## CX gotchas (DON'T re-learn these)

- **for-result nesting**: combining bound `[?for]` results in a `(…)` sequence
  NESTS them (sequence-flat does NOT apply to bound for-results / arrays); a
  re-iteration then yields inner sequences → `no attribute` errors. Build each
  list once and consume once, or derive inline. `[$fp:map]` returns a clean
  array but `( $arrA, $arrB )` still nests — there is no array concat in `fp`
  (map/flat-map/fold/sequence/traverse only); restructure to avoid concatenation.
- **CXPath `$node/*` does NOT spread a `[?for]` child** (yields one sequence
  node); `[$xml:emit]` DOES spread it. So build pages as HTML and emit; don't
  construct a data `[section]` then navigate it with `/*`.
- **`[?def]`/`[?lib]`/`[?const]` directives stringify under `[$cx:parse]`** (data
  codec keeps directives opaque). Co-located docs are PLAIN elements
  (`[module-doc]`, `[fn-doc]`), which parse navigably. Element-text auto-unwrap
  is context-dependent/unreliable — extract text via `[?for [in $c $node/*]
  [yield [?match $c [case [tag $t] $t] …]]]`.
- **Triple-quote `"""…"""`** is raw; content that **begins or ends with `"`** (or
  contains `"""`) can't be triple-quoted — the `""""` boundary is ambiguous to
  the lexer. The seeder guards these (`tq-unsafe`); keep that guard if
  regenerating.
- **`[$cx:emit]` of a CX-like string emits it UNQUOTED** (breaks round-trip), so
  the seeder builds fn-doc TEXT with explicit triple-quotes rather than emitting
  values.
- **Embed/rebuild dance**: `stdlib/<m>.cx` is `$embed_file`'d into the binary at
  COMPILE time. After editing a module you MUST `make build-vcx-dev` before the
  binary's bundled copy reflects it (the guide projection reads disk, but
  `[?lib]` loads the embedded copy). If you revert on-disk files, rebuild too.
- **Comments can't appear inside `(…)` sequences or `[?let]` binding lists**;
  `#]`/`[#` inside a `[# … #]` comment closes it early.
- **`[?if [= $x v]]`** is equality in condition position; reading a missing attr
  hard-errors; env access needs `--allow-env` (returns an error VALUE otherwise,
  which `[?if]` treats truthy).

## Conventions (hard)
- NO `Co-Authored-By` / Claude attribution on commits.
- Spec is the only source of truth; edit specs only in `spec/02-inprogress/` and
  STOP — only the USER graduates to `03-approved`. Never write/cite decision records.
- Dogfood: use CX where CX can do the job. End-state guide toolchain is
  Python-free.
- Commit per logical chunk with a clear message; gate each.
- Inline labeled options for any user question (no popup menus); but here:
  execute to completion without prompting.
