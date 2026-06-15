# CX v0.8.0 — Full Delivery Session Prompt

**Purpose.** Paste this into a fresh Claude Code session to deliver
CX v0.8.0 end-to-end without further owner input. Versioned in-repo
so revisions accumulate alongside the design artifacts they describe.

**Last revised:** 2026-05-22.
**Companion documents:**
- [`backlog.cx`](backlog.cx) — living decision log
- [`manifest.cxd`](manifest.cxd) — guide TOC
- [`spec/code.md`](../../spec/code.md) — CXPath value kind, `[?match]`, `[?modify]`
- [`spec/bindings.md`](../../spec/bindings.md)
- [`spec/cxpath_alignment.md`](../../spec/cxpath_alignment.md)

---

## Copy-paste starter prompt

```
═════════════════════════════════════════════════════════════════
CX v0.8.0 — FULL DELIVERY SESSION
═════════════════════════════════════════════════════════════════

Branch: v0.8.0-dev (cx-private).  Latest commit: see `git log -1`.
Model: claude-opus-4-7. Thinking: high.

MISSION
═════════════════════════════════════════════════════════════════
Deliver CX v0.8.0 end-to-end with no further input from the owner.
Spec, implementation, conformance, bindings, tooling, doc-gen,
playground, examples, migration, release artifacts. Everything.

Work autonomously. Do not pause to ask. Represent the owner. When
the work runs into a real block (spec ambiguity, persistent test
failure, new ADR needed), file it in backlog.cx, note in the
commit, move on. Do not stall the whole session on one item.

Done means: every gate below is ✅ green, branch ready to tag.

STANDING RULES (from memory — apply throughout)
═════════════════════════════════════════════════════════════════
- Spec-first: fixture → implement → test. No ad-hoc smoke checks.
- All shell via `devbox run -- <cmd>`.
- Parallelize independent reads/tasks; one message, many tool calls.
- Number questions + label options if asking is warranted. Avoid asking.
- Commit in logical chunks, conventional-commit style, no Co-Authored-By
  trailers — owner is sole author.
- After every commit emit a one-line update: hash · scope · gates moved.
- Report v0.8.0 gate completion N/M after each commit.

READ FIRST — in this order
═════════════════════════════════════════════════════════════════
1.  memory/MEMORY.md (auto-loaded)
2.  docs-src/canonical/backlog.cxd
3.  docs-src/canonical/v0_8_0_session_prompt.md (this file)
4.  spec/code.md (full — normative; CXPath value kind, `[?match]`, `[?modify]`)
8.  spec/bindings.md (two-layer binding contract)
9.  spec/grammar.ebnf [127e] + [130]–[148e]
10. spec/cxpath_alignment.md
11. spec/cxdm.md §2 (Path as sixth Item kind)
12. conformance/code.txt (fixture format; renamed to code.txt in 1.2)
14. spec/abi.md (C ABI surface)
15. Makefile (every target)
16. docs-src/canonical/manifest.cxd (guide TOC, 9 sections)
17. scripts/gen_docs/build.cx (doc-gen pipeline — broken on v0.8.0-dev)
18. docs/playground/playground.js (cxl-* starter examples to migrate)
19. tooling/tree-sitter-cx/grammar.js + queries/highlights.scm
20. tooling/lsp/ (LSP server structure)

ALREADY DONE — do not redo
═════════════════════════════════════════════════════════════════
- CXPath value kind, `[?match]`, `[?modify]` designs drafted
- spec/code.md: §5.2 rule 8, §5.5 CXPath, §6.2 extended binding
  paths, §7.5 pattern-generator, §8.1 [?find] retirement, §8.2 multi-arm
  [?match], §8.10 [?modify], §8.11 integration directives
- spec/grammar.ebnf: [130]–[148e] added, [127e] updated
- spec/cxdm.md: Path as sixth Item kind
- spec/cxpath_alignment.md: created
- spec/bindings.md: two-layer contract created
- conformance/code.txt: in_cxl→in_code, [?find]→[?for], +29 fixtures
  (10 cxpath + 10 match-multi + 9 modify)
- vcx/code/tokens.v: 'find' removed, 'modify' added
- docs-src/canonical/{manifest.cxd, backlog.cx, v0_8_0_session_prompt.md}
  scaffolded
- backlog.cx: decisions d-2026-05-22-01 through d-2026-05-22-15 ratified

═════════════════════════════════════════════════════════════════
PHASE 1 — SPEC COMPLETION
═════════════════════════════════════════════════════════════════
1.1  spec/v0_8_0_status.md — create, modeled on prior status-doc convention.
     List every gate (Phase 1–11) with ✅/🚧/📋. Update each commit.
1.2  "programs → code" rename — draft design + execute:
     · spec/code.md → spec/code.md (update every internal link)
     · spec/audits/programs_*.md → spec/audits/code_*.md
     · vcx/code/ → vcx/code/ (module rename, v.mod, all imports)
     · cx_code_eval → cx_code_eval (spec/abi.md, C ABI header, every binding)
     · _cx_code_diagram → _cx_code_diagram (wasm export)
     · conformance/code.txt → conformance/code.txt
     · Makefile target references
     · All cross-refs in spec/*.md, README, docs-src/, ROADMAP.md
1.3  Idiomatic fixture shapes — audit conformance/code.txt program-for-*
     core fixtures. Scalars belong in attributes. Reshape inputs +
     update selectors to idiomatic CXPath (//user/@email etc.).
     Keep [?for] only where nested structure genuinely needs destructure.
1.4  (migration spec retired during v0.8.0 cleanup — renames committed
     across codebase; ADR-level migration rules live in the ADRs)
1.5  spec/misc/parity-matrix.md — update for v0.8.0 binding scope (V/Python/Go/Rust).
     Add Layer-1 method rows from spec/bindings.md §2.1.
     Footnote archived bindings; remove obsolete rows.
1.6  spec/ast.md — add PathNode AST entry; PathNode kind enum value.
1.7  spec/core/ast-bin.md — wire format for PathNode; cap bit increment
     (cap bits 29+30 used by playground gate 17; use 31 next).
1.8  spec/abi.md — Layer-1 method surface per spec/bindings.md:
     cx_code_eval, doc.select_all, doc.select, doc.modify(focus, action).
     Function signatures + error matrix.
1.9  spec/canonical.md — Path round-trip rules (terse // form is canonical).
1.10 spec/eval.md §12 — directive table update (remove 'find', add 'modify').
1.11 spec/audits/code_design_v1.md → audits/code_design_v1.md; v0.8.0
     appendix for ADRs 0028-0030.
1.12 spec/governance.md §10 — confirm or update for v0.8.0 ADR cadence.
1.13 ROADMAP.md — v0.8.0 scope LOCKED section; mark v0.7.6 as skipped.
1.14 CHANGELOG.md — v0.8.0 entry (Added/Changed/Removed/Migration).
1.15 README.md — v0.8.0 highlights (CXPath restored, multi-arm [?match],
     [?modify], V/Python/Go/Rust scope, two-layer bindings).
1.16 backlog.cx — flip the CXPath / `[?match]` / `[?modify]` / rename
     designs status draft→accepted as each implementation completes.
     Move resolved open issues to [completed].

═════════════════════════════════════════════════════════════════
PHASE 2 — IMPLEMENTATION (vcx/code/ after 1.2 rename)
═════════════════════════════════════════════════════════════════
2.1  AST — add PathNode struct (steps, axes, predicates). Update ast.v,
     ast_json.v, ast_bin codec. Equality + hashing.
2.2  Lexer — already updated for 'find' removal + 'modify' addition.
     Verify no stale references in lexer.v.
2.3  Parser — PathExpr (grammar [130]–[135]):
     · '//' StepList | '/' StepList | StepList
     · 12 axes; NodeTest; Predicate+
     · AttrTest in predicates: @Name CompOp Value
     · Binding paths: $x/* , $x//name , $x/axis::name
     · Round-trip: terse // form is canonical emit
2.4  Parser — multi-arm [?match] (grammar [136]–[140]):
     · Optional value (predicate-only mode)
     · :case PAT (:where GUARD)? :yield E
     · :when PRED :yield E
     · :else :yield E  (at most one, last)
     · Pattern kinds: element, scalar literal, PathExpr, _, $bind
2.5  Parser — [?modify] (grammar [141]–[148e]):
     · doc PathExpr Action+
     · 11 actions: :set :delete :using :rename :set-attr :delete-attr
       :append :prepend :insert-before :insert-after :replace
2.6  Evaluator — CXPath:
     · Path eval against doc → Sequence of nodes
     · All 12 axes; positional + boolean predicates
     · //user/@email returns scalar attribute values
     · Path in [?if] cond: truthy iff non-empty
     · Path in [?for] :in: iterates result
     · Path in [?match] :case: type-test
2.7  Evaluator — multi-arm [?match]:
     · First-match-wins, top-down
     · No EBV in :case (strict); EBV in :when (per cxdm §4.6)
     · Scalar literal: type-strict, no coercion
     · No-match: ()-empty without :else; CXER0100 single-arm form
2.8  Evaluator — [?modify]:
     · Structural sharing (spine copy only, O(depth) heap)
     · Multi-match: action applies to every node
     · Zero match → original returned unchanged
     · :using takes [?fn] lambda; CXER0104 on type mismatch
     · :set-attr / :delete-attr on attribute-step path → static CXER0100
2.9  Renderer — render.v: PathNode canonical emit (terse //).
2.10 Diagram emitter — diagram.v:
     · Path values as query boxes
     · Multi-arm [?match] as N-branch diamond
     · [?modify] as update-box (focus → action → new-doc)
     · Pipeline of modifies as sequential update-boxes
2.11 cabi.v — Layer-1 surface per spec/bindings.md:
     cx_code_eval, cx_code_diagram, doc.select_all, doc.modify.
     Increment ABI cap bits as needed.

═════════════════════════════════════════════════════════════════
PHASE 3 — BINDINGS  (V/Python/Go/Rust only)
═════════════════════════════════════════════════════════════════
Normative contract: spec/bindings.md.
- Layer 1 = 16 canonical methods, identical across bindings.
- Layer 2 = per-language idiom packs that desugar to Layer 1.
- Conformance via conformance/binding_api.txt (gate 28.6 — byte-identical
  Layer-1 results across all four bindings).

3.1  Archive retired bindings: mv lang/typescript, lang/java, lang/csharp,
     lang/ruby, lang/kotlin, lang/swift → lang/_archived/. Update Makefile
     so make test doesn't attempt them. README footnote on restoration.
3.2  V binding (lang/v/native/) — native reference:
     · Layer 1 IS the V surface (no L2 wrapper).
     · 16-method canonical set per spec/bindings.md §2.1.
     · Version → 0.8.0.
3.3  Python binding (lang/python/cxlib/):
     · Layer 1: 16 methods, snake_case.
     · Layer 2 (cxlib.idioms): __getitem__ on CXPath strings, list/dict
       comprehensions over Nodes, __setitem__ → modify().
     · cxlib.idioms.explain() returns Layer-1 desugaring (LSP hover use).
     · pyproject.toml → 0.8.0.
3.4  Go binding (lang/go/cxlib/):
     · Layer 1: 16 methods, PascalCase.
     · Layer 2 (cxlib/idioms): builder-pattern filter chains compiling
       to CXPath; .Users().Where(...).Get(...) style.
     · go.mod version → 0.8.0.
3.5  Rust binding (lang/rust/cxlib/):
     · Layer 1: 16 methods, snake_case.
     · Layer 2 (cxlib::idioms): typed Iterator wrappers compiling to
       CXPath; doc.iter::<T>().filter(...) style. #[derive(CxData)].
     · Cargo.toml → 0.8.0. Remove dead code: cx_code_eval (wrong
       arity), node_from_value, attr_from_value, element_from_value,
       doc_from_value.
3.6  vcx binary version constant → 0.8.0; tooling/vscode/package.json → 0.8.0.

═════════════════════════════════════════════════════════════════
PHASE 4 — CONFORMANCE
═════════════════════════════════════════════════════════════════
4.1  conformance/code.txt (post-rename): all fixtures green against
     implementation. CXPath + match-multi + modify all pass.
4.2  conformance/binding_api.txt — new Layer-1 parity suite per
     spec/bindings.md §4.1. Format: --- in_cx, --- call, --- out_text/err.
     Every binding (V/Python/Go/Rust) runs identical fixtures.
4.3  conformance runner — update scripts/check_code_fixtures.py +
     scripts/check_code_spec_consistency.py for rename + new categories.
4.4  XPath 3.1 parity gate (28.5) — scripts/test_xpath_parity.sh shelling
     to Saxon-HE Docker image. Tag fixtures xpath31-parity / xpath31-divergence.
4.5  All other conformance suites verified green (core.txt, extended.txt,
     xml.txt, md.txt, schema_validate.txt, streaming_write.txt, identity.txt,
     delimited.txt, include.txt, diff.txt, lint.txt, namespaces.txt,
     table.txt, data_bin_*.txt, cx_lang.txt, cx_module.txt, log_module.txt).
4.6  make check-conformance-coverage green; check-lint-rules green.

═════════════════════════════════════════════════════════════════
PHASE 5 — TOOLING
═════════════════════════════════════════════════════════════════
5.1  tooling/tree-sitter-cx/grammar.js — productions for:
     · PathExpr (//, /, steps, axes, predicates, AttrTest)
     · Multi-arm [?match]: :case / :when / :else / _
     · [?modify] action slots
     · Updated directive_name keywords (no 'find', + 'modify')
5.2  tooling/tree-sitter-cx/queries/highlights.scm — highlight new tokens.
5.3  tooling/tree-sitter-cx/queries/injections.scm — if Path needs special.
5.4  tooling/syntax/cx.tmLanguage.json — TextMate grammar update for same.
5.5  tooling/lsp/ — diagnostics:
     · Unreachable [?match] arm warning
     · Missing :else hint
     · :where consolidation suggestion
     · CXPath focus hover: match-count + axis docs
     · [?modify] focus type check (attribute-step + :set-attr → error)
     · Path completion: axis names, node-kind tests
5.6  tooling/vscode/ — bump version, regenerate cx-language-0.8.0.vsix,
     update snippets for new directives.
5.7  tooling/neovim/, tooling/completions/ — refresh for new keywords.
5.8  tooling/web/cx-diagram.js — if any changes for new renderings.
5.9  Editor examples — tooling/{helix,neovim,vscode}.example.* updated.

═════════════════════════════════════════════════════════════════
PHASE 6 — DOC-GEN
═════════════════════════════════════════════════════════════════
6.1  scripts/gen_docs/build.cx — full port to v0.8.0 syntax. Currently
     uses v0.7.0: [- -] comments, [?=] substitution, :return bodies,
     bare paths. Port to: line/block comments, CXPath selectors,
     :yield bodies, // path expressions.
6.2  Sectional rendering fixed (i-doc-gen-sectional-regression closed).
     Use //page/section sectional [?for] iteration. v0.7.5 byte-identical
     baseline restored for unchanged pages.
6.3  docs-src/content/reference/code.cx → reference/code.cx (rename).
     Update content for v0.8.0 surface.
6.4  New page: docs-src/content/reference/cxpath.cx — XPath 3.1 alignment
     reference; links to spec/cxpath_alignment.md.
6.5  All docs-src/content/*.cx pages — audit for stale [?find], cxl,
     cx_code_eval references. Update.
6.6  docs-src/content/playground.cx — update for v0.8.0 starters.
6.7  docs-src/content/release-notes.cx — v0.8.0 entry.
6.8  docs-src/content/install.cx — version bumps.
6.9  docs-src/content/comparison.cx — refreshed table with v0.8.0 features.
6.10 docs-src/content/bindings/ — drop retired binding pages (typescript,
     java, csharp, ruby, kotlin, swift) or move to archive. Update remaining
     V/Python/Go/Rust pages for Layer-1 + Layer-2 surfaces per spec/bindings.md.
6.11 docs-src/canonical/sections/ — author all 9 sections of the guide
     per manifest.cxd:
     01-intro.cx, 02-data-language.cx, 03-surfaces.cx, 04-identity.cx,
     05-code.cx, 06-bindings.cx, 07-tooling.cx, 08-concepts.cx, 09-migration.cx.
6.12 docs-src/canonical/template.cx — render template walks manifest,
     emits docs/cx-data-and-code-guide.md (single file for v0.8.0).
6.13 make docs green; make verify-doc-links green (no broken links).
6.14 make docs-publish — gated, NOT run on v0.8.0-dev until tag time
     (per d-2026-05-22-06).
6.15 docs/internal/ — update DECISIONS.md cross-refs if present.

═════════════════════════════════════════════════════════════════
PHASE 7 — PLAYGROUND
═════════════════════════════════════════════════════════════════
7.1  WASM rebuild — scripts/wasm/build_libcx_wasm.sh:
     · Re-export _cx_code_eval (renamed from _cx_code_eval)
     · Re-export _cx_code_diagram (renamed)
     · New exports if needed for [?modify] / CXPath visualization
     · Cap bit 31 if new capability exposed
7.2  scripts/wasm/cxlib.js — update method names to Layer-1 vocabulary
     (16 methods per spec/bindings.md). Add modify(), select_all().
7.3  docs/playground/playground.js — port all 9 starter examples to v0.8.0:
     · cxl-substitute → code-substitute
     · cxl-for → code-for
     · cxl-if → code-if
     · cxl-let → code-let
     · cxl-filters → code-filters
     · cxl-templates → code-templates
     · cxl-paths → code-paths (showcase CXPath value kind)
     · cxl-merge → code-merge
     · cxl-includes → code-includes
     Plus 3 new starters:
     · code-match (multi-arm dispatch)
     · code-modify (pure-functional update)
     · code-cxpath (path-value showcase)
7.4  docs/playground/playground.css — style updates for new diagram
     elements (CXPath query box, multi-arm diamond, modify update-box).
7.5  Fix i-playground-graph-mixed-input — when corpus mixes data + code,
     detect and either skip diagram or emit a hint. CXER0100 must not surface.
7.6  Source-pane Mermaid diagram works on every starter.
7.7  Output-pane interactive tree (bidirectional selection bridge) works.
7.8  Fullscreen toggle on diagram (already shipped 4d279181) — verify works
     against rebuilt wasm.
7.9  Local file load + run end-to-end test: every starter green in browser.

═════════════════════════════════════════════════════════════════
PHASE 8 — EXAMPLES
═════════════════════════════════════════════════════════════════
8.1  Restore examples/programs-tour.cx as examples/code-tour.cx — port to
     v0.8.0. Cover: CXPath, [?for], [?match] multi-arm, [?modify],
     [?let], [?fn], [?if], [?match]-on-err recovery, [?pipe].
8.2  Audit every examples/*.cx — replace [?find] → [?for] or //path.
     Update for code-language rename.
8.3  Add new examples specific to v0.8.0:
     · examples/cxpath-tour.cx — every axis + every predicate kind
     · examples/match-multi.cx — heterogeneous dispatch
     · examples/modify-crud.cx — pure-functional CRUD pipeline
8.4  examples/cx/ subdir (greet.cx, users.cx) — verify still parse + run.
8.5  examples/comparisons/ — if any v0.7.x comparison files, refresh.
8.6  make verify-examples green.

═════════════════════════════════════════════════════════════════
PHASE 9 — MIGRATION (agent-only, no external users)
═════════════════════════════════════════════════════════════════
9.3  (retired during v0.8.0 cleanup — internal example/fixture renames
     [[?find]→[?for], in_cxl→in_code, cx_program_*→cx_code_*] were
     applied directly across the codebase; pre-release with no external
     users, so no standing migration tooling is needed)
9.4  cx-data-and-code-guide §9 (Migration section) — agent-facing
     reference for mechanical rename patterns.

═════════════════════════════════════════════════════════════════
PHASE 10 — TESTS / BUILD / CI
═════════════════════════════════════════════════════════════════
10.1  make test — green (parallelized).
10.2  make test-no-parallel — green.
10.3  make test-v / test-vcx / test-vcx-api / test-vcx-stream — green.
10.4  make test-python / test-python-api / test-python-stream / test-python-arrow — green.
10.5  make test-go / test-go-api / test-go-arrow — green.
10.6  make test-rust / test-rust-arrow — green.
10.7  make abi-c-test — green.
10.8  make bench-json — 300+ MB/s sustained (Y6 streaming target).
10.9  make verify-cli / verify-examples / verify-readme-blocks /
      verify-binding-quickstarts / verify-doc-blocks — green.
10.10 make check-conformance-coverage / check-lint-rules /
      check-v-upstream — green.
10.11 make verify-doc-links — zero broken links.
10.12 make bump-version-check — green after 1.16 backlog flips.
10.13 New: make test-xpath-parity (Saxon-HE Docker, gate 28.5) — green.
10.14 New: make test-binding-api-parity (gate 28.6, Layer-1 parity) — green.

═════════════════════════════════════════════════════════════════
PHASE 11 — RELEASE ARTIFACTS
═════════════════════════════════════════════════════════════════
11.1 RELEASE_NOTES_v0.8.0.md (top-level, modeled on v0.7.0).
11.2 docs/releases/v0_8_0.md.
11.3 docs/migrations/v0_8_0.md (created in 9.2).
11.4 spec/v0_8_0_status.md — every gate ✅; final commit.
11.5 Gate evidence bundle — v0.8.0-gate-evidence.tar.gz with all gate
     artifacts. Released as GitHub release attachment at tag time.
11.6 backlog.cx final pass:
     · ADRs 0028 / 0029 / 0030 / 0032 status → accepted
     · Every open issue resolved → moved to [completed] with note
     · Meta block last-updated stamped
11.7 README.md cover image / badges updated for v0.8.0.
11.8 ROADMAP.md — mark v0.8.0 shipped; advance v0.9.0 / 1.0 horizons.
11.9 scripts/tag_release.sh dry-run — confirms branch ready.

═════════════════════════════════════════════════════════════════
PHASE 12 — FINAL POLISH
═════════════════════════════════════════════════════════════════
12.1 Grep audit — no stray "[?find" outside intentional retirement prose.
12.2 Grep audit — no "in_cxl" anywhere (except changelog/migration history).
12.3 Grep audit — no "cx_code_eval" / "vcx/code" / "spec/code.md"
     anywhere live (only in migration docs explaining the old names).
12.4 Grep audit — no "cxl" outside archive/migration prose.
12.5 No TODO/FIXME blocking release (file as backlog issue if any remain).
12.6 dist/ rebuilt; tree-sitter artifact regenerated; .vsix repacked.

═════════════════════════════════════════════════════════════════
DONE CRITERIA
═════════════════════════════════════════════════════════════════
- spec/v0_8_0_status.md every row ✅
- All make test-* + make verify-* + make check-* green on devbox
- conformance/code.txt + conformance/binding_api.txt fully passing
- Playground builds + every starter runs + diagrams render
- make docs produces complete output; verify-doc-links green
- backlog.cx: zero open issues from this release scope
- Branch ready: scripts/tag_release.sh dry-run clean

When everything is done, post a final report:
- Commit graph summary (commits this session, ordered)
- Test results matrix (every target)
- Gate status table
- Files changed by phase
- Anything filed to backlog for v0.8.x follow-up
- Recommend: tag now / hold for owner review

Then stop. Don't speculate beyond v0.8.0.
```

---

## Revision history

| Date | Change |
|---|---|
| 2026-05-22 | Initial assembly: 12 phases, read order updated for `spec/bindings.md` and this file's own existence. Phase 3 expanded with two-layer binding contract. Gates 28.5 (XPath parity) + 28.6 (Layer-1 parity) added. |
