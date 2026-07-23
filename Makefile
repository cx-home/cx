# ── v0.8.0 CX Data Language Guide ─────────────────────────────── BEGIN gen_guide
# Makes `make guide` first-class. Renders
# docs-src/canonical/manifest.cxd + sections/*.cxd into docs/guide/.
# When the v0.8.0 cx binary is not yet runnable, the target stages
# chrome + assets and falls back to source-as-body pages — see
# scripts/gen_guide/README.md for the full pipeline.
-include scripts/gen_guide/guide.mk
# ── v0.8.0 CX Data Language Guide ───────────────────────────────── END gen_guide

# Prefer the patched V toolchain (third_party/v/v) for EVERY recipe that
# invokes `v`. It carries the macOS hardened-runtime libgc / -prod fixes and
# the picoev shared-listener patch (`new_with_listen_fd`) the http
# multi-reactor code needs to compile. Without this, recipes that invoke a
# bare `v` (e.g. `make test-vcx-suite`) pick whatever is first on PATH — under
# devbox that is the unpatched /usr/local/bin/v, which fails to compile the
# `code` module on the http branch. Prepending the submodule dir makes bare
# `v` resolve to the patched binary; if the submodule isn't built yet the dir
# simply contains no `v` and PATH falls through to the system V (the
# documented degraded fallback). Mirrors vcx/Makefile's `V := …/third_party/v/v`.
export PATH := $(CURDIR)/third_party/v:$(PATH)

# Explicit handle on the patched V toolchain. The PATH export above is meant to
# make a bare `v` resolve to third_party/v/v, but `v test` recipes have been
# observed re-resolving to the system V (e.g. /usr/local/bin/v) — under which
# the http branch's `code` module fails to compile (it calls the patched
# builtin's cx_region_* / picoev helpers). Recipes that MUST use the patched
# toolchain reference $(V) directly. Mirrors vcx/Makefile's V definition; falls
# back to a bare `v` when the submodule binary isn't built yet.
V := $(if $(wildcard $(CURDIR)/third_party/v/v),$(CURDIR)/third_party/v/v,v)

CONFORMANCE_CORE := conformance/core.cxd
CONFORMANCE_EXT := conformance/extended.cxd
CONFORMANCE_XML := conformance/xml.cxd
CONFORMANCE_MD := conformance/md.cxd

LIB_NAME := libcx
VCX_DYLIB := vcx/target/$(LIB_NAME).dylib
VCX_SO := vcx/target/$(LIB_NAME).so
DIST_DIR := dist
PREFIX ?= /usr/local

UNAME_S := $(shell uname -s)

# ── Python / Go toolchain paths ──────────────────────────────────────────────
# Python: prefer a modern interpreter when the default python3 is too old
# (Xcode ships 3.9; the binding + emscripten need >= 3.10).
PYTHON ?= $(shell if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then echo python3; elif [ -x /opt/homebrew/bin/python3 ]; then echo /opt/homebrew/bin/python3; else echo python3; fi)

.PHONY: all build build-wasm build-playground build-vcx build-vcx-dev build-lib build-lib-arrow build-rust build-rust-arrow \
 build-go build-go-arrow \
 build-vscode \
 publish publish-push \
 publish-v publish-v-push \
 publish-org \
 release release-v release-all \
 dist install uninstall install-cli uninstall-cli verify-cli promote-cli \
 test test-no-parallel test-python test-python-arrow test-vcx test-rust test-rust-arrow \
 test-rust-parquet test-rust-arrow-conformance \
 test-go test-go-arrow \
 test-python-api test-python-stream test-v test-vcx-api test-vcx-stream test-go-api \
 test-xpath-parity test-binding-api-parity \
 abi-c-test \
 conform conform-vcx conform-md bench bench-python bench-streaming bench-cxparse \
 bench-code-pattern-compile bench-code-streaming bench-code-http bench-code-gates \
 examples example-python example-v example-go example-rust \
 demos demo-v demo-go demo-rust \
 clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

# Active binding set (v0.8.0) — V + Python + Go + Rust (per decision d-2026-05-22-03).
# Python has no compile step.
# Archived bindings (TypeScript/Java/Kotlin/C#/Ruby/Swift) live in lang/_archived/
# and are not wired into build or test targets.
build: build-vcx build-rust build-go

build-vcx:
	$(MAKE) -C vcx build

# Unoptimised dev build of libcx + cx (no -prod/-Os). Functionally
# identical for tests but compiles far faster; the test path depends on
# this instead of the -prod `build-vcx`. Shipped artifacts use `build-vcx`.
build-vcx-dev:
	$(MAKE) -C vcx build-dev CX_DFLAGS='$(CX_DFLAGS)'

# v0.7.5 — build libcx.wasm + libcx.js (emscripten
# loader) + cxlib.js (hand-written wrapper). Produces dist/wasm/.
# Opt-in: not invoked by the default `build` target so contributors
# without emcc on PATH aren't blocked. The guide CI lane invokes
# this before scripts/gen_guide/scaffold.sh so the playground page
# bundles the WASM artifacts. Depends on the patched V at
# third_party/v/v (carries the wasm32-emcc vmemcpy fix); falls back
# to system V at the cost of broken Option payloads — see
# the patched-V README at third_party/v/README.md (P1).
build-wasm:
	./scripts/wasm/build_libcx_wasm.sh

# Gate 17 — stage the playground bundle under dist/playground-preview/
# so scripts/test_playground_smoke.sh has a docroot to boot Python's
# http.server against. The layout matches the URL probes the smoke
# script issues: playground.{html,js,css} at the root, wasm artifacts
# under dist/wasm/ (nested), so a `cd dist/playground-preview &&
# python3 -m http.server` exposes /playground.html, /playground.js,
# /playground.css, /dist/wasm/libcx.js, /dist/wasm/cxlib.js — the
# exact set the smoke check curl-probes. Depends on build-wasm so the
# wasm artifacts exist before we copy. When emcc is unavailable,
# build-wasm fails noisily upstream and this target is never reached;
# scripts/test_playground_smoke.sh then reports its documented
# "playground-preview not built" failure.
build-playground:
	@echo "[build-playground] (re)building libcx-async + libcx-pthreads variants"
	@# Two wasm variants — cxlib.js dynamically loads one or the other
	@# at runtime based on crossOriginIsolated + SharedArrayBuffer
	@# availability (cxlib.js §init, ~line 47-70):
	@#   - libcx-async (SINGLE_FILE=1 ASYNCIFY=1 PTHREADS=0) — generic
	@#     HTTP + file:// + GitHub Pages. SINGLE_FILE inlines the wasm
	@#     so file:// double-click works (Chrome blocks sibling fetch
	@#     on null-origin pages).
	@#   - libcx-pthreads (SINGLE_FILE=0 ASYNCIFY=1 PTHREADS=1) — when
	@#     COOP+COEP headers permit SharedArrayBuffer; real parallel
	@#     :par via Web Workers. Needs separate .wasm for pthread
	@#     workers to share the module instance via SAB.
	@# ASYNCIFY=1 lets wall-clock [?sleep DUR] yield through the JS
	@# event loop on the main thread without freezing the UI. ~10%
	@# per-call overhead; the default `make build-wasm` keeps ASYNCIFY=0
	@# so CLI/binding consumers don't pay it.
	@# Build recipe mirrors scripts/gen_guide/guide.mk lines 77-78 so
	@# `build-playground` and `guide` stay consistent.
	@SINGLE_FILE=1 ASYNCIFY=1 PTHREADS=0 OUT_NAME=libcx-async    ./scripts/wasm/build_libcx_wasm.sh
	@SINGLE_FILE=0 ASYNCIFY=1 PTHREADS=1 OUT_NAME=libcx-pthreads ./scripts/wasm/build_libcx_wasm.sh
	@echo "[build-playground] staging dist/playground-preview/"
	@rm -rf dist/playground-preview
	@mkdir -p dist/playground-preview/playground
	@mkdir -p dist/playground-preview/wasm
	@mkdir -p dist/playground-preview/dist/wasm
	@cp scripts/gen_guide/playground/playground.html dist/playground-preview/
	@cp scripts/gen_guide/playground/playground.js dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/playground.css dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/playground.examples.js dist/playground-preview/playground/
	@cp dist/wasm/cxlib.js dist/playground-preview/wasm/cxlib.js
	@cp dist/wasm/libcx-async.js dist/playground-preview/wasm/libcx-async.js
	@if [ -f dist/wasm/libcx-pthreads.js ]; then cp dist/wasm/libcx-pthreads.js dist/playground-preview/wasm/libcx-pthreads.js; fi
	@if [ -f dist/wasm/libcx-pthreads.wasm ]; then cp dist/wasm/libcx-pthreads.wasm dist/playground-preview/wasm/libcx-pthreads.wasm; fi
	@# Smoke-test compatibility: also stage flat copies under dist/wasm/
	@# so scripts/test_playground_smoke.sh (which queries dist/wasm/*
	@# directly) keeps working alongside the absolute-URL layout that
	@# matches docs/guide/ deployment.
	@cp dist/wasm/cxlib.js dist/playground-preview/dist/wasm/cxlib.js
	@cp dist/wasm/libcx-async.js dist/playground-preview/dist/wasm/libcx-async.js
	@if [ -f dist/wasm/libcx-pthreads.js ]; then cp dist/wasm/libcx-pthreads.js dist/playground-preview/dist/wasm/libcx-pthreads.js; fi
	@if [ -f dist/wasm/libcx-pthreads.wasm ]; then cp dist/wasm/libcx-pthreads.wasm dist/playground-preview/dist/wasm/libcx-pthreads.wasm; fi
	@echo "[build-playground] OK — dist/playground-preview/ ready (libcx-async + libcx-pthreads staged)"

# Optional Apache Arrow C-Data interop library (libcx_arrow per ADR
# 0015 D9 / spec/abi.md §2.11). Separate from libcx; bindings dlopen
# this library independently. Built on demand by test-python-arrow
# / the per-binding Arrow tests; not pulled into the default `build`
# target since pyarrow / arrow ecosystems are opt-in per binding.
build-lib-arrow: build-vcx
	$(MAKE) -C vcx lib-arrow

build-rust: build-vcx
	cargo build --manifest-path lang/rust/cxlib/Cargo.toml --release

# Arrow C-Data Rust binding (Phase 7.74c-cont-bindings-multi-rust,
# spec/abi.md §2.11). Gated behind the `arrow` Cargo feature so the
# default `build-rust` does not require the `arrow` crate.
build-rust-arrow: build-vcx build-lib-arrow
	cargo build --features arrow --manifest-path lang/rust/cxlib/Cargo.toml --release

# Go toolchain: prefer a go whose GOARCH matches the host — an Intel-brew
# go in /usr/local shadowing an arm64 host cannot link the arm64 libcx
# (cgo link failure). Falls back to plain `go` everywhere else.
GO ?= $(shell if [ "$$(uname -sm)" = "Darwin arm64" ] && [ -x /opt/homebrew/bin/go ] && [ "$$(go env GOARCH 2>/dev/null)" != "arm64" ]; then echo /opt/homebrew/bin/go; else echo go; fi)

build-go: build-vcx
	cd lang/go/cxlib && $(GO) build ./...

# Arrow C-Data Go binding (Phase 7.74c-cont-bindings-multi-go,
# spec/abi.md §2.11). Gated behind `-tags arrow` so the default
# `build-go` does not require the apache/arrow/go module.
build-go-arrow: build-vcx build-lib-arrow
	cd lang/go/cxlib && go build -tags arrow ./...

build-lib: build-vcx

# Copy vcx dylib + header into dist/ (V implementation is primary)
dist: build-vcx
	mkdir -p $(DIST_DIR)/lib $(DIST_DIR)/include
	cp -f include/cx.h $(DIST_DIR)/include/
	@if [ -f $(VCX_DYLIB) ]; then cp -f $(VCX_DYLIB) $(DIST_DIR)/lib/libcx.dylib; fi
	@if [ -f $(VCX_SO) ]; then cp -f $(VCX_SO) $(DIST_DIR)/lib/libcx.so; fi
	@echo "dist: $(DIST_DIR)/include/cx.h $(DIST_DIR)/lib/"

# Install libcx system-wide (default: /usr/local; override with PREFIX=...)
install: dist
	install -d $(PREFIX)/lib $(PREFIX)/include $(PREFIX)/lib/pkgconfig
	@if [ -f $(DIST_DIR)/lib/libcx.dylib ]; then install -m 755 $(DIST_DIR)/lib/libcx.dylib $(PREFIX)/lib/; fi
	@if [ -f $(DIST_DIR)/lib/libcx.so ]; then install -m 755 $(DIST_DIR)/lib/libcx.so $(PREFIX)/lib/; fi
	install -m 644 $(DIST_DIR)/include/cx.h $(PREFIX)/include/
	sed "s|@PREFIX@|$(PREFIX)|g" cx.pc.in > $(PREFIX)/lib/pkgconfig/cx.pc
	@echo "installed libcx → $(PREFIX)/lib/ header → $(PREFIX)/include/ pkg-config → $(PREFIX)/lib/pkgconfig/cx.pc"

uninstall:
	rm -f $(PREFIX)/lib/libcx.dylib $(PREFIX)/lib/libcx.so
	rm -f $(PREFIX)/include/cx.h
	rm -f $(PREFIX)/lib/pkgconfig/cx.pc
	@echo "uninstalled libcx from $(PREFIX)"

# Install the verified CLI separately from the libcx shared library.
install-cli: build-vcx
	install -d $(PREFIX)/bin
	install -m 755 vcx/target/cx $(PREFIX)/bin/cx
	@echo "installed cx CLI → $(PREFIX)/bin/cx"

uninstall-cli:
	rm -f $(PREFIX)/bin/cx
	@echo "uninstalled cx CLI from $(PREFIX)/bin/cx"

# Smoke-test the staged CLI before promotion.
verify-cli: build-vcx
	./vcx/target/cx --help >/dev/null
	./vcx/target/cx --json examples/config.cx >/dev/null
	@echo "verified staged CLI at vcx/target/cx"

promote-cli: verify-cli install-cli
	@echo "promoted verified cx CLI to $(PREFIX)/bin/cx"

# ── Experience gate (the evaluation-experience checklist) ──────────────────────────

.PHONY: smoke-eval verify-examples verify-readme-blocks verify-binding-quickstarts \
 verify-doc-blocks verify-doc-links bump-version-check release-verify

# F1, F2, F4, F5, F6, F7, F9 — the experience-gate hard-fail checks.
smoke-eval: build-vcx
	@tools/smoke-eval.sh

# F4 — every example must compile and round-trip cleanly.
verify-examples: build-vcx
	@tools/verify-examples.sh

# F6 — README's runnable code blocks must run.
verify-readme-blocks: build-vcx
	@tools/verify-readme-blocks.sh

# F7 — per-binding quickstart blocks must exist and be well-formed.
verify-binding-quickstarts:
	@tools/verify-binding-quickstarts.sh

# Documentation hygiene — every fenced ```cx block parses. No args =
# the script's defaults (spec/ docs-src/ docs/ README.md).
verify-doc-blocks: build-vcx
	@tools/verify-doc-blocks.sh

# V2 — upstream V patch tracking. Reports status of the vlang/v
# issues that block cx v0.7.0. Exit non-zero only
# on a closed-unfixed (upstream-rejected) outcome.
check-v-upstream:
	@python3 scripts/check_v_upstream_patches.py

# V6 — pre-commit lint rules over .cx files. Catches the retired
# v0.7.x syntax forms the v0.8.0 parser rejects, plus the
# cxl-version=/cx-eval-version= rename window deprecation.
check-lint-rules:
	@python3 scripts/check_lint_rules.py

# V6 — install the .githooks/ scripts as repo-local git hooks
# (idempotent). Sets core.hooksPath rather than symlinking each
# hook individually so a new hook script lands without re-running
# the install target.
install-hooks:
	@git config core.hooksPath .githooks
	@echo "[install-hooks] git core.hooksPath set to .githooks"
	@ls -1 .githooks/ | sed 's/^/  - /'

# std-lib documentation freshness gate — CX-native (dog-food), run by
# `cx eval`. Verifies the co-located [module-doc]/[fn-doc] in stdlib/*.cx:
# presence parity (every public [?def] has a [fn-doc] and vice-versa),
# purity agreement, and that every [fn-doc] example is backed verbatim by
# the module's conformance corpus (conformance/stdlib/<m>.cxd, run green by
# `make test-vcx-suite`). Nonzero exit on drift propagates through make.
# Module-set parity is owned by `make stdlib-catalog-gate`.
# Override the binary with CX_BIN=path (default vcx/target/cx).
.PHONY: guide-check
guide-check: CX_BIN ?= $(CURDIR)/vcx/target/cx
guide-check: build-vcx
	@"$(CX_BIN)" eval scripts/gen_guide/stdlib_docs_check.cx --allow-all

# Directive + syntax reference drift gate — every code.md §4.1 registry
# directive has a [directive-doc], no orphans, and each example is backed
# verbatim by the conformance corpus (mirrors guide-check for the stdlib).
.PHONY: directive-docs-check
directive-docs-check: CX_BIN ?= $(CURDIR)/vcx/target/cx
directive-docs-check: build-vcx
	@"$(CX_BIN)" eval scripts/gen_guide/directive_docs_check.cx --allow-all

# Playground example drift gate (#92) — every entry in
# scripts/gen_guide/playground/playground.examples.js must still run clean on
# the current binary, and the committed file must match a fresh render. The
# generator audits the *composed* form (input + the `[; … ]` note comment) with
# NO capability flags, mirroring the file:// wasm sandbox: a top-level parse/
# eval error fails the gate, an unbalanced bracket in a note (→ unterminated
# comment) fails the gate, and examples needing a wasm-unavailable capability
# carry runnable:false (exempt). --check verifies without rewriting the file.
.PHONY: verify-playground-examples
verify-playground-examples: build-vcx
	@python3 scripts/gen_guide/playground/gen_examples.py --check

# stdlib catalog drift gate — verifies the single invariant
#   SPEC_SET == (BUNDLE_SET union DISPATCH_SET)
# i.e. every status=current [module-meta] in spec/03-approved/std-lib/*.md
# is implemented (stdlib/*.cx bundle and/or a *_stdlib_builtin entry in
# vcx/code/stdlib_dispatch.v), and there are no orphan impls/bundles
# without a current spec. The gate is itself written in CX (dog-food) and
# run by `cx eval`; its nonzero exit on drift propagates through make.
# Override the binary with CX_BIN=path (default vcx/target/cx).
.PHONY: stdlib-catalog-gate
stdlib-catalog-gate: CX_BIN ?= $(CURDIR)/vcx/target/cx
stdlib-catalog-gate: build-vcx
	@"$(CX_BIN)" eval scripts/stdlib_catalog_gate.cx --allow-all

# Format-companion regeneration (#424) — the derived companions under
# examples/ (books.*, config.*, doc.md, comparisons/table_block.csv) are
# GENERATED from their .cx sources; regenerate them here so they cannot
# drift from what the live binary actually emits (gen-docs discipline:
# never hand-edit a companion). Run after any change to the sources or
# to a conversion lane, then commit the results.
# Override the binary with CX_BIN=path (default vcx/target/cx).
#
# ── LANE NOTES ─────────────────────────────────────────────────────────
#   * books.json/books.xml use the explicit --from=cx conversion lane.
#     Since #443 the `--json FILE` shorthand no longer drops table rows,
#     but it renders the AST-JSON projection (the eval-render shape,
#     "table": {cols, rows}), NOT the semantic JSON image the companion
#     pins — so books.json stays on the conversion lane by design.
.PHONY: examples-regen
examples-regen: CX_BIN ?= $(CURDIR)/vcx/target/cx
examples-regen:
	@test -x "$(CX_BIN)" || { echo "examples-regen: no cx binary at $(CX_BIN); run 'make build-vcx' or pass CX_BIN=/path/to/cx"; exit 1; }
	@echo "==> regenerating examples/ format companions with $(CX_BIN)"
	"$(CX_BIN)" --json examples/config.cx > examples/config.json
	"$(CX_BIN)" --yaml examples/config.cx > examples/config.yaml
	"$(CX_BIN)" --toml examples/config.cx > examples/config.toml
	"$(CX_BIN)" --xml  examples/config.cx > examples/config.xml
	"$(CX_BIN)" --yaml examples/books.cx  > examples/books.yaml
	"$(CX_BIN)" --toml examples/books.cx  > examples/books.toml
	"$(CX_BIN)" --from=cx --to=json examples/books.cx > examples/books.json
	"$(CX_BIN)" --from=cx --to=xml  examples/books.cx > examples/books.xml
	"$(CX_BIN)" --md   examples/doc.cx    > examples/doc.md
	"$(CX_BIN)" --csv  examples/comparisons/table_block.cx > examples/comparisons/table_block.csv
	@echo "==> done; review with 'git diff examples/' and commit"

# V7 — bench harness JSON runner. Drives bench-streaming and emits
# a stable JSON shape consumable by scripts/compare_bench.py.
bench-json:
	@python3 scripts/run_bench_json.py

# V7 — bench regression comparison. Pass BASELINE= and CURRENT= as
# paths to JSON files produced by bench-json. Default threshold is
# 30%; pass STRICT=1 for the 10% threshold.
bench-compare:
	@python3 scripts/compare_bench.py \
	  $(or $(BASELINE),bench/baseline.json) \
	  $(or $(CURRENT),bench/current.json) \
	  $(if $(STRICT),--strict,)

# Documentation hygiene — every relative markdown link resolves.
# Source markdown lives in docs-src/ (docs/ is the GENERATED HTML guide /
# Pages site, which has no .md files — pointing the check there made the
# target exit 2 on an empty target list). Coverage includes EVERY published
# root doc (the #426 audit found ROADMAP/SECURITY/CONTRIBUTING rotting
# precisely because only docs-src/ + README were gated) and the approved
# spec tree (#499/#503 found spec/03-approved/ links rotting invisibly
# because the gate never looked there).
verify-doc-links:
	@tools/verify-doc-links.sh docs-src/
	@tools/verify-doc-links.sh spec/03-approved/
	@tools/verify-doc-links.sh README.md CONTRIBUTING.md ROADMAP.md \
	  SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md RELEASE_NOTES_v*.md

# Pre-tag version-string consistency. VERSION (the repo-root file) is the
# single source of truth; scripts/check_version_consistency.py verifies every
# stamped manifest + derived code surface against it. An explicit
# VERSION=X.Y.Z arg additionally asserts the file holds the version you
# intend to release (catches "forgot to run scripts/bump_version.sh").
bump-version-check:
	@if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$(cat VERSION)" ]; then \
	  echo "bump-version-check: VERSION file holds $$(cat VERSION), expected $(VERSION) — run scripts/bump_version.sh $(VERSION)"; \
	  exit 1; \
	fi
	@python3 scripts/check_version_consistency.py

# Full pre-tag check — runs everything in the release process + §0.5.
# Defaults to the VERSION file (single source of truth).
release-verify:
	@tools/release-verify.sh $(or $(VERSION),$(shell cat VERSION))

# ── Test ───────────────────────────────────────────────────────────────────────

# Test fan-out — independent per-language targets, plus the C-ABI conformance
# harness. Listed once so `test` and `test-no-parallel` stay in sync.
# Active binding set per backlog d-2026-05-22-03 (v0.8.0) — V + Python + Go + Rust.
# Archived: TypeScript / Java / Kotlin / C# / Ruby / Swift moved to
# lang/_archived/ in v0.8.0; their test targets are no longer wired into
# `test`. Restoration is community opt-in once the Layer-1 16-method
# surface stabilizes (spec/bindings.md §6).
TEST_TARGETS := abi-c-test test-python test-vcx test-v test-rust test-go check-prod-build check-no-legacy-try check-no-infix-range check-no-cxl-token check-version-consistency check-effect-alignment check-null-absence-conflation check-docs-tier1-guardrail check-no-adr-citations check-no-stub-impl check-xap-dist-absences check-completions-drift check-tmlanguage-sync guide-check directive-docs-check verify-doc-blocks verify-playground-examples

# ── -prod strictness gate (#338) — shipped artifacts build with -prod
# (`build-vcx`), which enforces strict map-index checks (`or {}` required on
# sum-type / pointer-carrying map values) that the dev builds tolerate. This
# runs the V checker (no codegen, ~2s) over vcx/code/ with the `lib` -prod
# flags, wired into TEST_TARGETS so a -prod-only break surfaces on every
# `make test` (the release gate) instead of sitting dark until a cut.
.PHONY: check-prod-build
check-prod-build:
	@$(MAKE) -s -C vcx check-prod

# ── NO-LEGACY-TRY gate (SAP C3c) — the retired [?try]/[catch]/[on-error]
# surfaces must not reappear in conformance/ + docs-src/ + examples/ + lang/.
# Token-aware, not a raw grep ([?try-send]/[?try-receive] + the CSV dialect
# [on-error "…"] option + the retirement-pinning negatives are allowlisted).
.PHONY: check-no-legacy-try
check-no-legacy-try:
	@python3 scripts/check_no_legacy_try.py

# ── NO-INFIX-RANGE gate (generator-family reshape, C-gen-1) — the retired
# infix range operators `to`/`by` must not reappear in conformance/ + docs-src/
# + examples/ + lang/. Ranges are the prefix builtin [$range lo hi step?].
# Token-aware, not a raw grep (English to/by prose, to=/by= named args, and the
# colon slice-stride [a:b:s] are not matched; the negatives are allowlisted).
.PHONY: check-no-infix-range
check-no-infix-range:
	@python3 scripts/check_no_infix_range.py

# ── NO-CXL-TOKEN gate — the retired language name `CXL` must not reappear
# in conformance/ + docs-src/ + examples/ + scripts/ + tooling/ + top-level
# project prose. Token-aware, not a raw grep (live identifiers cxlib / cxl: /
# CXLS / CXLib are not matched; _archive*/_archived/_gate_evidence excluded).
# (Formerly mis-named `check-no-stale-version` — it never checked versions;
# version-number drift is now caught by check-version-consistency below.)
.PHONY: check-no-cxl-token
check-no-cxl-token:
	@python3 scripts/check_no_cxl_token.py

# ── VERSION-CONSISTENCY gate — the repo-root VERSION file is the single source
# of truth for the release version. Every static manifest must equal it and the
# code surfaces (cabi.v/main.v) must DERIVE it from the build define. Catches the
# drift that previously went unnoticed (cx.pc.in at 0.6.1, C-ABI at 0.8.0 while
# the CLI said 0.10.0). Re-stamp with scripts/bump_version.sh.
.PHONY: check-version-consistency
check-version-consistency:
	@python3 scripts/check_version_consistency.py

# ── check-null-absence-conflation gate (SAP C1 / spec/core/code.md §9.1.2.1
# rule (b)) — the no-conflation guard: no builtin returns `null` to mean
# "absent." An optional read signals "nothing here" via the absence channel
# (the empty sequence `()`), never `null`. Token-aware: it flags the
# `[returns [or T null]]` declared-optional-return shape in the stdlib def
# surface (spec/std-lib/*.md + the vcx/code bundle sources); unit-null
# `[returns null]` and param-position `[or T null]` are deliberately not
# flagged. Permanent gate, not migration-only.
.PHONY: check-null-absence-conflation
check-null-absence-conflation:
	@python3 scripts/check_null_absence_conflation.py

# ── ALIGNMENT gate (SAP C2 / spec/core/code.md §6.5.1) — the one-way
# capability-alignment invariant: (1) every capability-gated effect point is
# reached only through an `impure` builtin (gated ⇒ impure, by construction in
# builtin_purity_table); (2) every impure-without-capability builtin is in the
# closed, enumerated exception table. NOT symmetric. The V test owns both
# directions + drift canaries (process- prefix, env- minus pure prims, io
# read/write/open). Runs as part of `test-vcx` too; this dedicated target is
# the named gate.
.PHONY: check-effect-alignment
check-effect-alignment: build-vcx
	@$(V) -cc cc $(CX_GC) test vcx/tests/effect_alignment_test.v

# ── check-docs-tier1-guardrail gate (SAP C6 / SAP §0.1) — the learnability
# guardrail: the canonical guide's beginner sections (quickstart §0 + intro §1)
# show Tier 1 ONLY, and fp.md / the words "monad"/"functor"/"typeclass" never
# appear in beginner material. Makes §0.1's reviewer rule a permanent gate so
# the entry surface cannot silently drift into advanced theory. Token-aware
# (whole-word advanced terms); a deferring mention ("no monads required") is
# allowlistable. Tier 2/3 sections (concepts §9, libraries §16) are out of
# scope by design — they carry the opt-in/advanced markers.
.PHONY: check-docs-tier1-guardrail
check-docs-tier1-guardrail:
	@python3 scripts/check_docs_tier1_guardrail.py

# ── NO-ADR-CITATION gate — the spec (spec/core/*.md) is the only source of
# truth. Decision records are archived (under the guarded decisions dir) and
# MUST NOT be cited from the live tree; such a citation pins live code/docs to
# a non-authoritative record and corrupts the single-source model. The gate is
# token-aware; the gate script + the SAP audit report are allowlisted.
.PHONY: check-no-adr-citations
check-no-adr-citations:
	@python3 scripts/check_no_adr_citations.py --self-test
	@python3 scripts/check_no_adr_citations.py

# ── NO-STUB-IMPL gate (global no-stub rule) — the stdlib impl bundle
# (vcx/code/*.v) must contain no fake-success stub: an effectful prim returning
# a deterministic synthetic success value instead of performing the real effect
# (the failure mode that shipped the http client / net layer as placeholders and
# sailed through the gate because fixtures asserted the fake shape). Flags the
# fake-success confession phrases only; honest fail-closed errors
# (mk_err(... not yet implemented / unsupported ...)) are NOT flagged — refusing
# an effect is correct, faking it is the bug. A new effect must be real + carry a
# behavioral (real socket/process/file) test, or fail closed.
.PHONY: check-no-stub-impl
check-no-stub-impl:
	@python3 scripts/check_no_stub_impl.py

# Distribution-spec §9 checkable absences (fixture §11.8): the xap-dist engine
# (vcx/code/stdlib_xap_dist.v) composes the store/did/vc/compose surfaces and
# ships NO parallel primitive — no own hashing, no archive format, no
# transport, no second compose gate.
.PHONY: check-xap-dist-absences
check-xap-dist-absences:
	@python3 scripts/check_xap_dist_absences.py

# ── Shell-completion drift gate (#423) — the bash/zsh/fish completions in
# tooling/completions/ must mention every subcommand in the vcx/cmd/main.v
# dispatch table (and none it doesn't have), and the `cx diagram` flag surface
# must match vcx/cmd/diagram.v (--format=mermaid|svg|png + -o; the fabricated
# --format=graphviz / --output= / --depth= surface must never reappear).
.PHONY: check-completions-drift
check-completions-drift:
	@python3 scripts/check_completions_drift.py

# ── TextMate grammar single-sourcing gate (#423) — the canonical grammar is
# tooling/vscode/syntaxes/cx.tmLanguage.json (scope-tested via
# `npm run test:grammar`); tooling/syntax/cx.tmLanguage.json is a derived
# byte-identical copy for path-stable consumers (GitHub web view / Shiki /
# docs-site configs). Regenerate with `make sync-tmlanguage`.
.PHONY: check-tmlanguage-sync
check-tmlanguage-sync:
	@cmp -s tooling/vscode/syntaxes/cx.tmLanguage.json tooling/syntax/cx.tmLanguage.json \
		|| { echo "check-tmlanguage-sync: tooling/syntax/cx.tmLanguage.json has drifted from the canonical tooling/vscode/syntaxes/cx.tmLanguage.json — run 'make sync-tmlanguage'"; exit 1; }
	@echo "check-tmlanguage-sync: OK — tooling/syntax copy is byte-identical to the canonical vscode grammar"

.PHONY: sync-tmlanguage
sync-tmlanguage:
	@cp tooling/vscode/syntaxes/cx.tmLanguage.json tooling/syntax/cx.tmLanguage.json
	@echo "sync-tmlanguage: tooling/syntax/cx.tmLanguage.json refreshed from tooling/vscode/syntaxes/"

# Stage-1 registry publish (distribution spec §4.1 — publish-by-PR): seal +
# sign + alias a package directory into registry/store, then re-verify.
#   CX_PKG_DIR=packages/nmea0183 CX_PKG_NAME=nmea0183 CX_PKG_VERSION=0.1.0 \
#     make registry-publish
.PHONY: registry-publish
registry-publish: build-vcx-dev
	@vcx/target/cx --allow-all registry/publish.cx

# Stage-2 served registry (distribution spec §4.2): the SAME store, re-hosted
# behind the CSRP daemon on loopback. Consumers open
# cx-store+http://127.0.0.1:8460/registry/ — hashes/signatures unchanged.
.PHONY: registry-serve
registry-serve: build-vcx-dev
	@vcx/target/cx store-serve --config registry/cxstore.service.cx --allow-net=127.0.0.1:8460

# Default parallelism: detected core count, override with `make test TEST_JOBS=N`.
# Measured speedup on a warm build: ~10× wall-clock vs sequential (342s → 33s).
TEST_JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8)

# Default `test` runs targets in parallel. `--output-sync=target` keeps each
# target's logs grouped instead of interleaved across processes.
# --output-sync needs GNU make >= 4.0 (Apple ships 3.81); pass it only
# when the running make advertises the feature.
OUTPUT_SYNC := $(if $(filter output-sync,$(.FEATURES)),--output-sync=target,)
test:
	@$(MAKE) -j$(TEST_JOBS) $(OUTPUT_SYNC) $(TEST_TARGETS)

# Sequential fallback — useful for debugging output-order issues, sanitizer
# runs that want low concurrency, or environments where `-j` parallelism
# causes resource contention.
test-no-parallel: $(TEST_TARGETS)

# ── gate 37.10 — code_diagram / code_tree conformance ────────────
# Runs conformance/code_diagram.txt through cx_code_diagram and
# cx_code_tree with structural-equivalence comparison.
# Skips cleanly when the binary lacks the subcommands (Phase 7.1 / 7.6
# / 7.7 implements them) so this target stays green during scaffold.
.PHONY: test-code-diagram
test-code-diagram:
	@python3 scripts/check_code_diagram_fixtures.py

# ── v0.8.0 gate 28.5 — XPath 3.1 parity (Saxon-HE reference) ─────────────
# Runs conformance/xpath_31_parity.txt fixtures through both `cx eval` and
# Saxon-HE (via Docker) and asserts byte-identical results for the parity
# tag and documented divergence for the divergence tag. Requires Docker on
# PATH; skip-cleanly behaviour lives inside the script (exit 2 on missing
# prerequisites). Active gate per spec/v0_8_0_status.md §11.6.
.PHONY: test-xpath-parity
test-xpath-parity: build-vcx
	@CX_BIN=$(CURDIR)/vcx/target/cx bash scripts/test_xpath_parity.sh

# ── v0.8.0 gates 28.6 + 28.9 — Layer-1 binding-API parity ────────────────
# Runs conformance/binding_api.txt (49 Layer-1 parity fixtures, spec/
# bindings.md §4.1) through every active binding (V / Python / Go / Rust)
# and asserts byte-identical results across all four. Tier-2 archived
# bindings (TS / Java / C# / Ruby / Kotlin / Swift) are out of scope per
# d-2026-05-22-03.
#
# Driver architecture: `scripts/compile_binding_api_fixtures.py` parses
# the fixture file and emits a JSONL op-tree per fixture; per-binding
# drivers under `lang/<lang>/binding_api_driver/` execute each op-tree
# through their Layer-1 surface. The shell harness diffs the four
# outputs and surfaces divergence cleanly.
.PHONY: test-binding-api-parity
test-binding-api-parity:
	@CX_BIN=$(CURDIR)/vcx/target/cx bash scripts/test_binding_api_parity.sh

# Pin the Python binding to the freshly-built libcx (vcx/target) so the gate
# tests THIS build, not whatever libcx is installed system-wide. The cxlib
# loader (lang/python/cxlib/cx.py) checks /usr/local/lib and /opt/homebrew/lib
# BEFORE the repo build, so a stale installed libcx.dylib silently shadows the
# fresh one — which is exactly how a pre-`[; …]`-migration install made the
# gate report spurious comment-parse failures. LIBCX_LIB_DIR (loader priority 2)
# wins over the system paths. Go/Rust already pin vcx/target via rpath.
test-python: export LIBCX_LIB_DIR := $(CURDIR)/vcx/target
test-python: check-python-test-lane check-python-interpreter build-vcx
	$(PYTHON) lang/python/test_fixture_loader.py
	$(PYTHON) lang/python/conformance.py
	$(PYTHON) lang/python/conformance_code.py
	$(PYTHON) lang/python/test_api.py
	$(PYTHON) lang/python/test_stream.py
	$(PYTHON) lang/python/test_data_bin_one_shots.py
	$(PYTHON) lang/python/test_namespaces.py
	$(PYTHON) lang/python/test_identity.py
	$(PYTHON) lang/python/test_delimited.py
	$(PYTHON) lang/python/test_streaming_table.py
	$(PYTHON) lang/python/test_iterator.py
	cd lang/python && $(PYTHON) -m unittest test_code_eval -v
	cd lang/python && $(PYTHON) -m unittest test_store_client -v
	cd lang/python && $(PYTHON) -m unittest test_event_writer -v
	cd lang/python && $(PYTHON) -m unittest test_surface -v
	cd lang/python && $(PYTHON) -m unittest test_surfaces -v
	cd lang/python && $(PYTHON) -m unittest test_table -v

# Interpreter preflight (#512). cxlib needs Python >= 3.10 (cx.py carries
# runtime `X | None` unions); stock macOS `python3` is the Xcode 3.9-era
# build, which fails the import in ways that masquerade as cxlib bugs.
# Fail loudly with the remedy instead.
.PHONY: check-python-interpreter
check-python-interpreter:
	@$(PYTHON) -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null || { \
	  echo "ERROR: test-python needs Python >= 3.10; '$(PYTHON)' reports: $$($(PYTHON) --version 2>&1)."; \
	  echo "       Re-run as: make test-python PYTHON=/opt/homebrew/bin/python3 (or any modern python3)."; \
	  exit 1; }

# Lane completeness (#512) — no test file in lang/python/ may sit outside
# every Makefile lane (that is how test_table.py silently missed #509).
# Every lang/python/test_*.py must be referenced somewhere in this
# Makefile — this lane or an opt-in lane (test-python-arrow, …).
.PHONY: check-python-test-lane
check-python-test-lane:
	@missing=""; \
	for f in lang/python/test_*.py; do \
	  b=$$(basename $$f .py); \
	  grep -qw "$$b" Makefile || missing="$$missing $$b"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "ERROR: python test files wired into NO Makefile lane (#512):$$missing"; \
	  echo "       Add each to test-python (or an opt-in lane) in the top-level Makefile."; \
	  exit 1; \
	fi

# Apache Arrow C-Data interop tests (Phase 7.74c-cont-bindings).
# Skip-cleanly if pyarrow is not installed; otherwise builds libcx_arrow
# and exercises the full 9-type round-trip surface. Install the optional
# dep with `pip install pyarrow` (or `pip install lang/python[arrow]`).
test-python-arrow: build-vcx build-lib-arrow
	$(PYTHON) lang/python/test_arrow.py

# Arrow conformance — runs the canonical conformance/data_bin_arrow.txt
# fixtures through the Python binding. Cross-binding parity means each
# active binding has an equivalent runner over the same fixture file
# (see spec/abi.md §2.11 + spec/bindings.md §4.1).
test-python-arrow-conformance: build-vcx build-lib-arrow
	$(PYTHON) -m unittest lang.python.test_arrow_conformance -v

# Phase 5 Tier-1 binding parity (Python) — exercises the v0.8.0
# cx_code_eval* surface (spec/audits/code_abi_v1.md) and its
# Pythonic eval_code / eval_code_streaming wrappers.
test-python-code-eval: build-vcx
	cd lang/python && $(PYTHON) -m unittest test_code_eval -v
	$(PYTHON) lang/python/conformance_code.py

test-python-api: build-vcx
	$(PYTHON) lang/python/test_api.py

test-python-stream: build-vcx
	$(PYTHON) lang/python/test_stream.py

# C-level ABI conformance test (Phase 7.74c-abi-c-test). Compiles a
# small C harness against libcx + libcx_arrow under UBSan, then runs
# it. Catches the boundary-surface bugs binding rollouts have surfaced
# (size-header garbage, double-free on Export error, NULL-input
# rejection) at the source instead of via N binding rollouts. See
# spec/abi.md §1.5 / §2.10 / §2.11 for the surface;
# tests/abi/c_abi_test.c for what is exercised.
#
# Sanitizer choice: UBSan only by default. Apple clang's AddressSanitizer
# runtime on macOS 26 (Tahoe) deadlocks during AsanInitInternal —
# malloc re-enters the asan interceptor before init completes, the
# spin lock yields forever in StaticSpinMutex::LockSlow. The bug is
# in __sanitizer_mz_malloc → AsanInitFromRtl, present whether or not
# MallocNanoZone is disabled. Until Apple ships a fix or we adopt
# Homebrew LLVM as a build dep, ASan stays disabled here. UBSan
# alone reliably catches the integer-overflow / null-deref / out-of-
# bounds-load classes the boundary surface is most likely to expose.
# To opt back into ASan when running on Linux or with Homebrew clang,
# set ABI_C_TEST_SAN=address,undefined when invoking make.
ABI_C_TEST_BIN := vcx/target/c_abi_test
ABI_C_TEST_SAN ?= undefined
ifeq ($(UNAME_S),Darwin)
 ABI_LIB_PATH_VAR := DYLD_LIBRARY_PATH
 ABI_ARROW_LIB := vcx/target/libcx_arrow.dylib
else
 ABI_LIB_PATH_VAR := LD_LIBRARY_PATH
 ABI_ARROW_LIB := vcx/target/libcx_arrow.so
endif
abi-c-test: build-vcx build-lib-arrow
	$(CC) -std=c11 -Wall -Wextra -Werror -g -O1 \
	 -fsanitize=$(ABI_C_TEST_SAN) \
	 -I include -I vcx/arrow \
	 tests/abi/c_abi_test.c \
	 -L vcx/target -lcx -ldl \
	 -o $(ABI_C_TEST_BIN)
	$(ABI_LIB_PATH_VAR)=vcx/target $(ABI_C_TEST_BIN) $(ABI_ARROW_LIB)

# Pin the Rust binding to the freshly-built libcx (vcx/target), same
# rationale as test-python above: build.rs probes /usr/local/lib and
# /opt/homebrew/lib BEFORE the repo-relative fallback, so a stale
# installed libcx.dylib silently shadows THIS build — and the arrow
# lanes fail to link outright, because system paths carry libcx but
# never libcx_arrow (#511). LIBCX_LIB_DIR is build.rs's priority-1
# override and also sets the rpath to vcx/target.
test-rust: export LIBCX_LIB_DIR := $(CURDIR)/vcx/target
test-rust: build-rust
	cargo test --manifest-path lang/rust/cxlib/Cargo.toml -- --test-threads=1

# Apache Arrow C-Data interop tests for the Rust binding
# (Phase 7.74c-cont-bindings-multi-rust). Mirrors test-go-arrow:
# builds libcx_arrow then exercises the 9-type round-trip surface
# under `--features arrow`. Pulls in the `arrow` crate (v53.x) the
# first time it runs.
test-rust-arrow: export LIBCX_LIB_DIR := $(CURDIR)/vcx/target
test-rust-arrow: build-vcx build-lib-arrow
	cargo test --features arrow --manifest-path lang/rust/cxlib/Cargo.toml -- --test-threads=1

# Parquet bridge tests + smoke example (`parquet` implies `arrow`).
# Before #511 this surface was wired into NO lane, which is how the
# missing `ipc` feature sat unbuildable on release/0.13.0.
test-rust-parquet: export LIBCX_LIB_DIR := $(CURDIR)/vcx/target
test-rust-parquet: build-vcx build-lib-arrow
	cargo test --features parquet --manifest-path lang/rust/cxlib/Cargo.toml -- --test-threads=1
	cargo run --features parquet --example parquet_smoke --manifest-path lang/rust/cxlib/Cargo.toml

# Arrow conformance — runs the canonical conformance/data_bin_arrow.txt
# fixtures through the Rust binding. Mirrors test-python-arrow-conformance
# and test-go-arrow-conformance (cross-binding parity per spec/abi.md §2.11).
test-rust-arrow-conformance: export LIBCX_LIB_DIR := $(CURDIR)/vcx/target
test-rust-arrow-conformance: build-vcx build-lib-arrow
	cargo test --features arrow --manifest-path lang/rust/cxlib/Cargo.toml \
		--test arrow_conformance -- --nocapture

test-vcx: build-vcx-dev test-vcx-suite test-vcx-code test-vcx-cmd test-vcx-cxstore
	$(MAKE) -C vcx conform-all

# Convenience wrapper: run the full V suite ONCE, stream live output to a
# log, then print a digest of just the FAIL lines + per-file counts + the
# skipped-with-reason lanes (#318 — absent prerequisites, counted separately,
# never failures). Uses `bash -o pipefail` so the recipe exits with the real
# `test-vcx` status (a plain `... | grep` would mask failures behind grep's
# exit code).
.PHONY: test-vcx-summary
test-vcx-summary:
	@bash -o pipefail -c '$(MAKE) test-vcx 2>&1 | tee /tmp/cx-test-vcx.log'; st=$$?; \
	echo "──── failures / skips / counts ────"; \
	grep -iE '^FAIL|[0-9]+ passed, [0-9]+ failed|[0-9]+ errored|^SKIP |lane\(s\) SKIPPED' /tmp/cx-test-vcx.log || true; \
	echo "full log: /tmp/cx-test-vcx.log"; exit $$st

# ── V-side unit + fixture-runner suite ────────────────────────────────────
# Runs the entire vcx/tests/ corpus: the conformance fixture-runners
# (code_*_test.v against conformance/code.txt et al.) plus the per-feature
# unit tests (CXPath axes, [?match], [?modify], atoms, [?def], [?lib]/
# [?const]/lockfile, [?expr], purity, code_diagram/code_tree, the C ABI
# surface, stdlib modules, net/http real-socket behavior, …). Test files are
# named for what they cover — NO version prefix (the single VERSION file is
# the only place a version lives). Wired into TEST_TARGETS via the `test-vcx`
# umbrella above.
# v0.9.0 — the V-impl gate compiles the vcx test corpus under cx's default
# memory model, architecture E (`-gc e`): Perceus RC front line + precise STW vgc
# backstop. CX_GC is overridable (e.g. `make CX_GC='-gc boehm' test-vcx-suite`) to
# A/B against the prior collector. Only the FORK `$(V)` implements `-gc e`; the
# bare-`v` lang/v reference paths below stay on the upstream default.
CX_GC ?= -gc e
# Default DB engines (#520) — mirrors vcx/Makefile CX_ENGINES: the shipped
# artifact carries sqlite + redis, so the test gate compiles the suite with the
# same gates. This makes the $if-gated engine tests (vcx/code/sql_test.v,
# redis lanes) and the engine-dependent conformance fixtures
# (conformance/stdlib/db.cxd success/denial lanes) actually run — the gate
# tests the BEHAVIOR the artifact ships. Override CX_ENGINES='' to gate an
# engine-free build (then db.cxd's engine lanes are expected red; see the
# fixture doc-comment).
CX_ENGINES ?= -d cx_db_sqlite -d cx_db_redis
# `v test dir/` compiles EACH `*_test.v` as its own standalone executable, and
# with no cache every one recompiles the whole graph (builtin + os + all vcx
# modules) from scratch — the dominant cost is the per-file clang subprocess.
# `-usecache` C-compiles each unchanged module ONCE and reuses the object across
# every test binary (and across re-runs): the first file pays a cold tax, the
# rest reuse the shared `vcx`/`builtin`/`os` objects. Cache-safe with `-gc e` —
# the cache salt folds in the gc defines + `cc` + cflags + lookup path
# (third_party/v/vlib/v/pref/default.v), so different flags get distinct buckets.
# Overridable to A/B: `make CX_CACHE= test-vcx-suite` disables it.
CX_CACHE ?= -usecache
# #318 — a lane whose environment prerequisite is absent (e.g. vcx/target/cx
# not built in a bare out-of-tree checkout) SELF-SKIPS with a named reason via
# vcx/testenv (exit 0, never failing-as-regression) and records the reason in
# this ledger. Plain `v test` suppresses passing-lane output, so the recipe
# truncates the ledger before the run and prints the skipped-with-reason
# digest LOUDLY after it — skips are counted separately, never silently.
CX_SKIP_LOG := vcx/target/test-skips.log
.PHONY: test-vcx-suite
# On a suite failure the recipe retries EXACTLY the lanes that failed, each
# under the retry class it belongs to — never a fixed proxy list (#572: the
# old shape retried only the socket lanes on ANY failure, so an unrelated
# failure that coincided with green socket retries was mislabeled "load
# flake" and the gate exited 0 on a lane nobody re-ran):
#   • a lane in SUITE_SERIAL_RETRY (real-socket contention: ephemeral-port /
#     deadline races, each repeatedly proven green in isolation) → one
#     serial retry, same flags;
#   • any lane whose -j run died in a C compilation error → one serial
#     retry WITHOUT -usecache (#572: a stale cache layer can inject a
#     duplicate V-runtime symbol, e.g. ___v_thread_wait; cache-free green
#     proves the artifact — the cache-key root fix is the V-fork follow-up);
#   • anything else → a real failure, no retry, gate stays red.
SUITE_SERIAL_RETRY := vcx/tests/net_udp_read_deadline_test.v \
                      vcx/tests/net_dtls_test.v \
                      vcx/tests/net_real_socket_test.v \
                      vcx/tests/a2a_real_test.v

test-vcx-suite: build-vcx-dev
	@rm -f $(CX_SKIP_LOG)
	@log=vcx/target/test-suite-run.log; stf=vcx/target/test-suite-status; \
	{ $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test vcx/tests/ 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  failed=$$(grep -E '^FAIL ' $$log | grep -oE '[^ ]+_test\.v$$' | sort -u); \
	  if [ -n "$$failed" ]; then \
	    st=0; \
	    for t in $$failed; do \
	      rel=$${t#$(CURDIR)/}; \
	      case " $(SUITE_SERIAL_RETRY) " in \
	        *" $$rel "*) \
	          echo "──── serial retry (known real-socket contention lane): $$rel ────"; \
	          $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test "$$rel" || st=1 ;; \
	        *) \
	          if grep -q 'C compilation error' $$log; then \
	            echo "──── cache-free retry (#572: -usecache layer artifact check): $$rel ────"; \
	            $(V) -cc cc $(CX_GC) $(CX_ENGINES) test "$$rel" || st=1; \
	          else \
	            echo "──── real failure (no retry class applies): $$rel ────"; st=1; \
	          fi ;; \
	      esac; \
	    done; \
	    if [ $$st -eq 0 ]; then \
	      echo "──── every failed lane green on its classified retry (socket lanes: serial; C-compile failures: cache-free, #572) ────"; \
	    fi; \
	  fi; \
	fi; \
	if [ -s $(CX_SKIP_LOG) ]; then \
	  echo "──── $$(wc -l < $(CX_SKIP_LOG) | tr -d ' ') lane(s) SKIPPED with a named reason (absent prerequisite, counted separately — NOT failures) ────"; \
	  cat $(CX_SKIP_LOG); \
	fi; exit $$st

# White-box unit tests that live INSIDE the `code` module (vcx/code/*_test.v) —
# they exercise unexported internals (e.g. store_cxpack_flush / store_put_canonical
# / the object-graph persistence) that the black-box vcx/tests/ corpus cannot
# reach. `v test` only runs the directory it is given, so vcx/tests/ does not pull
# these in; this dedicated target wires the in-module suite into the gate (under
# the same default -gc e memory model as test-vcx-suite).
.PHONY: test-vcx-code
test-vcx-code: build-vcx-dev
	@$(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test vcx/code/

# White-box unit tests for the `cxstore` module (vcx/cxstore/*_test.v) — the
# content-addressed object store internals (pack/seqtree/bloom/index/gc/reflog/
# repo/planner/retention/mmap/compression + the cx adapter + round-trip). Like
# test-vcx-code, `v test` only runs the directory it is given, so neither
# vcx/tests/ nor vcx/code/ pulls these in; this dedicated target wires the
# cxstore in-module suite into the gate (same default -gc e memory model).
# Scoped to the top-level `*_test.v` glob (NOT the directory) so it excludes
# the `cxsqlite/` subdir — that DB-engine backend test needs sqlite3.h +
# `-d cx_db_sqlite` (the separate db-access milestone) and is not part of the
# default build surface. The glob still picks up every cxstore module test
# (V compiles the whole `cxstore` module behind the listed test files).
.PHONY: test-vcx-cxstore
test-vcx-cxstore: build-vcx-dev
	@$(V) -cc cc $(CX_GC) test vcx/cxstore/*_test.v

# White-box unit tests that live INSIDE the CLI module (vcx/cmd/*_test.v) —
# they assert on the cmd module's own constants (e.g. the `cx scaffold`
# templates, #306/#448) that neither vcx/tests/ nor vcx/code/ can import.
# `v test` only runs the directory it is given, so without this target the
# cmd suite had NO gate consumer (#448 wired it in).
.PHONY: test-vcx-cmd
test-vcx-cmd: build-vcx-dev
	@$(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test vcx/cmd/

# ── Columnar (Parquet / Arrow-IPC) [$store] backend gate — #129 D5 (#76) ──
# The columnar document backend (document+file://…?encoding=parquet) lives behind
# `-d cxstore_columnar`; its Arrow file I/O lives behind `-d cx_arrow_files`
# (libcx_arrow + libparquet via the C++ shim). It is therefore NOT in the default
# `make test` gate — that gate stays green Arrow-free, and an ungranted/absent-Arrow
# caller gets an honest E_STORE_UNRESOLVED_BACKEND (the gated-substrate posture).
# This DEDICATED target builds the shim and runs the spec §9 acceptance gate
# (store_columnar_test.v) with BOTH flags + Apache Arrow discovered via pkg-config,
# so the backend is genuinely exercised (no unconsumed seam). CI runs this target on
# a runner where Apache Arrow is installed (brew install apache-arrow / apt
# libarrow-dev libparquet-dev). Mirrors test-python-arrow's build-the-lib-first shape.
ifeq ($(UNAME_S),Darwin)
  COLUMNAR_ARROW_PKGCONFIG := /opt/homebrew/opt/apache-arrow/lib/pkgconfig
else
  COLUMNAR_ARROW_PKGCONFIG :=
endif
.PHONY: test-vcx-columnar
test-vcx-columnar: build-vcx-dev
	$(MAKE) -C vcx arrow-shim
	PKG_CONFIG_PATH="$(COLUMNAR_ARROW_PKGCONFIG):$$PKG_CONFIG_PATH" $(V) -cc cc -enable-globals $(CX_GC) -d cxstore_columnar -d cx_arrow_files test vcx/code/store_columnar_test.v

# ── sqlite [$store] backend gate — #77 / #220 (concurrent-writer durability) ──
# The sqlite:// store backend lives behind `-d cxstore_sqlite` (links libsqlite3);
# it is NOT in the default `make test` gate so that gate stays green without
# sqlite headers. This DEDICATED target runs the gated in-module suite — the
# round-trip/dedup/integrity tests plus the #220 concurrent-writer stress
# (32-wide burst through the daemon dispatch path → no crash, cold reopen
# intact) — with the flag. On macOS the system libsqlite3 ships no headers, so
# they come from Homebrew sqlite.
ifeq ($(UNAME_S),Darwin)
  SQLITE_CFLAGS := -I/opt/homebrew/opt/sqlite/include
  SQLITE_LDFLAGS := -L/opt/homebrew/opt/sqlite/lib
else
  SQLITE_CFLAGS :=
  SQLITE_LDFLAGS :=
endif
.PHONY: test-vcx-sqlite
test-vcx-sqlite: build-vcx-dev
	$(V) -cc cc $(CX_GC) -d cxstore_sqlite -cflags "$(SQLITE_CFLAGS)" -ldflags "$(SQLITE_LDFLAGS)" test vcx/code/store_sqlite_test.v vcx/code/store_sqlite_encryption_test.v vcx/code/store_concurrent_writer_test.v

# V module search path. `lang/v/native/` + `lang/v/conformance.v` import
# `cx` and `code` modules whose source lives under `vcx/`. The historical
# fix was to symlink `lang/v/cx → ../../vcx/cx` and `lang/v/code →
# ../../vcx/code`; that broke on Windows (where symlinks need developer
# mode + a git config flag) and required a Makefile bootstrap step.
#
# Cross-platform replacement: V's `-path` flag prepends a directory to
# the module-resolver search order. Setting it via `VFLAGS` propagates
# through `v test`'s per-file fork; setting it via `-path` directly on
# `v run` also works. `@vlib` and `@vmodules` are the V-runtime
# placeholders (stdlib + `$VMODULES`).
V_MODULE_PATH := @vlib|@vmodules|vcx
# `-cc cc` (clang): cx's patched builtin uses C11 atomics + `@[thread_local]` TLS
# that tcc cannot compile on macOS (the V default cc for non-prod). Carried through
# every `v test` / `v run` that uses VFLAGS_VCX so the conformance corpus builds.
VFLAGS_VCX := -cc cc -path "$(V_MODULE_PATH)"

test-v: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v $(VFLAGS_VCX) run lang/v/conformance.v
	VFLAGS='$(VFLAGS_VCX)' v test lang/v/tests/surface_test.v
	VFLAGS='$(VFLAGS_VCX)' v test lang/v/tests/native_atom_test.v

test-vcx-api: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test lang/v/tests/surface_test.v

test-vcx-stream: build-vcx
	v test vcx/tests/stream_test.v

test-go: build-go
	cd lang/go/cxlib && $(GO) test ./...
	cd lang/go/conformance && $(GO) run .

test-go-api: build-go
	cd lang/go/cxlib && $(GO) test ./...

# Apache Arrow C-Data interop tests for the Go binding
# (Phase 7.74c-cont-bindings-multi-go). Mirrors test-python-arrow:
# builds libcx_arrow then exercises the 9-type round-trip surface
# under `-tags arrow`. Pulls in github.com/apache/arrow/go/v18 the
# first time it runs.
test-go-arrow: build-vcx build-lib-arrow
	cd lang/go/cxlib && go test -tags arrow ./...

# Arrow conformance — runs the canonical conformance/data_bin_arrow.txt
# fixtures through the Go binding. Mirrors test-python-arrow-conformance;
# both consume the same fixture file (cross-binding parity per
# spec/abi.md §2.11).
test-go-arrow-conformance: build-vcx build-lib-arrow
	cd lang/go/cxlib && go test -tags arrow -v -run TestArrowConformance

conform-md: build-vcx
	$(MAKE) -C vcx conform-md

# ── Conformance ────────────────────────────────────────────────────────────────

conform: conform-vcx

conform-vcx: build-vcx
	$(MAKE) -C vcx conform

# ── Examples (transform showcase) ────────────────────────────────────────────

examples: example-python example-v example-go example-rust

example-python: build-vcx
	$(PYTHON) lang/python/examples/transform.py

example-v: build-vcx
	v run lang/v/examples/transform.v

example-go: build-go
	cd lang/go/cxlib && go run ./examples/transform/

example-rust: build-rust
	cargo run --example transform --manifest-path lang/rust/cxlib/Cargo.toml

# ── Demos (Document Model + Streaming + CXPath + Transform) ──────────────────

demos: demo-v demo-go demo-rust

demo-v: build-vcx
	v run lang/v/examples/demo.v

demo-go: build-go
	cd lang/go/cxlib && go run ./examples/demo/

demo-rust: build-rust
	cargo run --example demo --manifest-path lang/rust/cxlib/Cargo.toml

# ── Publish to public repo ────────────────────────────────────────────────────

publish:
	@bash scripts/publish.sh

publish-dry-run:
	@bash scripts/publish.sh --dry-run

publish-push:
	@bash scripts/publish_push.sh

publish-v:
	@bash scripts/publish_v.sh

publish-v-push:
	@bash scripts/publish_v_push.sh

publish-org:
	@bash scripts/publish_org.sh

release: publish publish-push

release-v: publish-v publish-v-push

# Tag the public mirrors (cx, cx-v) at the VERSION release version. Run AFTER
# release + release-v so the tag lands on the pushed release content. Use
# `make tag-public FORCE=--force` to move an existing published tag.
tag-public:
	@bash scripts/tag_public.sh $(FORCE)

# tag-public (the real release step) runs BEFORE publish-org (best-effort org
# branding), so a failed/empty org-README sync can never block tagging a release.
release-all: release release-v tag-public publish-org

# ── The ONE end-to-end local release command ─────────────────────────────────
# gate (make test + verify-doc-links) → bump → build → tag → push → GitHub
# release → publish mirrors (release-all). The `release`/`release-all` targets
# above are the building blocks it composes. Preview first:
#   make cut-release ARGS='--dry-run vX.Y.Z'
#   make cut-release ARGS='vX.Y.Z'
# See scripts/release.sh --help. (Local because org CI runners are unavailable;
# .github/workflows/release.yml is the CI equivalent once they're restored.)
cut-release:
	@bash scripts/release.sh $(ARGS)

# ── Editor tooling ────────────────────────────────────────────────────────────
#
# Since v0.7.0 the language server is built into the `cx` binary itself —
# `cx lsp` speaks JSON-RPC 2.0 over stdio (see vcx/cmd/lsp.v and
# tooling/lsp/README.md). Editor integration is `cx` on $PATH plus the
# example configs at tooling/lsp/{vscode,neovim,helix}.example.*.
#
# `make build-vscode` produces a publishable .vsix wrapping the VS Code
# extension at tooling/vscode/. The .vsix bundles the TextMate grammar,
# snippets, language configuration, and the esbuild-bundled extension
# (LSP-client glue compiled into out/extension.js); it does NOT bundle
# a `cx` binary — users install that separately. `npm run package`
# (vsce, a devDependency) runs the typecheck + bundle via
# vscode:prepublish. Needs node >= 18.13.

build-vscode:
	cd tooling/vscode && npm ci --silent && npm run package

# ── Benchmark ──────────────────────────────────────────────────────────────────

# #608 — xap/fabric throughput harness (CX-native scenarios + shell
# orchestration). Emits a canonical [bench-report …] to
# vcx/target/bench-report.cx; gates nothing. BENCH_K scales the run.
.PHONY: bench-xap
bench-xap: BENCH_K ?= 500
bench-xap: build-vcx-dev
	@bench/xap/run.sh $(BENCH_K)

bench: build-vcx
	$(PYTHON) bench_report.py

bench-python: build-vcx
	$(PYTHON) lang/python/bench.py

# Y6 — Streaming evaluator throughput. Standalone V runner; surfaces
# buffered vs streaming MB/s for a representative ?for-over-large-
# sequence workload. Uses the patched V at third_party/v/ (carries
# the macOS hardened-runtime libgc source-compile bypass + vlang/v
# #27178/#27179 fixes) so -prod can be safely enabled on macOS.
# Falls back to system V if the submodule isn't present.
PATCHED_V := $(if $(wildcard $(CURDIR)/third_party/v/v),$(CURDIR)/third_party/v/v,v)
bench-streaming: build-vcx
	$(PATCHED_V) -prod run vcx/tests/runners/streaming_bench.v

# cxparse unification — parser perf baseline / per-phase N3 gate
# (spec/02-inprogress/cxparse_unification_PLAN.md §6). MUST use the patched V:
# the PATH/devbox V bundles a boehm GC source-compile that corrupts the heap
# during collection and segfaults in -prod on macOS (the patched V carries the
# hardened-runtime libgc bypass — same reason bench-streaming uses $(PATCHED_V)).
bench-cxparse: build-vcx
	VFLAGS='-path "@vlib|@vmodules|vcx"' $(PATCHED_V) -prod run vcx/tests/runners/cxparse_baseline_bench.v

# T1 — Evaluator-feature microbench. Covers the v0.7.0 evaluator
# surface additions (FLWOR clauses, ?fn calls, partial application,
# pipeline/arrow operators, ?match, regex via RE2, range, tumbling
# windows). Output is parsed by scripts/run_bench_json.py into the
# T1.* benchmark keys for the V7 perf regression gate.
bench-eval: build-vcx
	v run vcx/tests/runners/eval_features_bench.v

# ── v0.8.0 §11.6 release-gate harnesses ────────────────────────────────────────
#
# Each target runs one of the three perf gates blocking the v0.8.0 tag
# (spec/v0_8_0_status.md §11.6, spec/code.md §11.4.4). Exit code
# is 0 on PASS, non-zero on FAIL; CI consumes the gate verdict line.
# The benches print their threshold + measured numbers so PASS/FAIL is
# self-evident in logs. Env knobs documented in each .v file header.

# Gate 14 — pattern compilation (depth-8, 32-binding pattern):
# p99 parse-time MUST be ≤ 1 ms.
bench-code-pattern-compile: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_pattern_compile_bench.v

# Gate 15 — streaming throughput on JSON-shape workloads:
# mean MUST be ≥ 200 MB/s + no trial below 80 % of mean.
bench-code-streaming: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_streaming_throughput_bench.v

# Gate 16 — HTTP service throughput (in-process substrate per §1.2):
# mean MUST be ≥ 10K req/s AND p99 ≤ 10 ms.
bench-code-http: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_http_throughput_bench.v

# HTTP backend-direction isolation bench — settles whether the ~10k
# req/s ceiling is transport-bound (net.http socket stack) or
# interpreter-bound (code.eval + env.clone) before any backend rewrite.
# Two-point: in-process code.eval leg vs real net.http listener on :0
# with a trivial no-op handler. Prints a ratio + verdict, no PASS/FAIL.
bench-code-http-isolation: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_http_isolation_bench.v

# Gate 7 — concurrency soak. Loops a buffered send/receive workload
# detecting deadlocks (per-iter wall-clock cap) and registry leaks
# across an extended run. Default is a 30 s smoke; release candidate
# runs the full 24 hours via `GATE7_DURATION_SEC=86400`.
bench-code-soak: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_concurrency_soak.v

# Gate 8 — async cancellation battery. 10 000-iteration battery
# against the canonical [?cancel] → [?await] pattern; zero non-
# deterministic failures required.
bench-code-cancel: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_async_cancel_battery.v

# Aggregate runner — drives all three v0.8.0 perf gates back-to-back.
# Exit code is the FIRST failing gate's exit code (make stops on
# first non-zero); use individual targets to triage in isolation.
bench-code-gates: bench-code-pattern-compile bench-code-streaming bench-code-http

# ── v0.8.0 §11.6 gate-evidence targets (5 / 6 / 9 / 12 / 28.7 / 28.8 / 30.5) ──
#
# Each target below corresponds to a §11.6 release gate that the master
# gate-check (`scripts/gate_check.sh`) invokes by name. The
# underlying test files all exist and already pass via the `test-vcx-suite`
# umbrella; these targets are narrowly-scoped gate-evidence pointers so
# the gate-check can verify each gate's coverage in isolation rather
# than relying on the umbrella having run a moment earlier. Per
# spec/v0_8_0_status.md §11.6.

# ── Gate 5 — resilience composition matrix ────────────────────────────────
# Drives the 67 resilience fixtures in conformance/code.txt (31 single-
# directive + 36 composition matrix) via vcx/tests/code_eval_fixtures_test.v
# whose `supported_fixtures` whitelist covers all 67. The fixture runner
# parses each block, evaluates in_code with $doc bound, and compares the
# rendered result against out_text. Asserts at runtime that at least one
# fixture executed. Per spec/v0_8_0_status.md §11.6 gate 5.
.PHONY: test-vcx-resilience-matrix
test-vcx-resilience-matrix: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_eval_fixtures_test.v

# #63/#58 concurrency-soundness gate. Stresses the cooperative-safepoint collector
# (now the default) under multi-reactor HTTP + concurrent [?worker] threads and
# asserts ZERO sweep-while-live via the passive detector oracle (0xbf1) + crash
# count. The gate builds its own detector binary and has proven detection power
# (RED on the legacy -d vgc_legacy_stw collector, GREEN on the default). Skips the
# HTTP stressor gracefully if `wrk` is absent. See scripts/concurrency_soundness_gate.sh.
.PHONY: test-vcx-concurrency-soundness
test-vcx-concurrency-soundness:
	zsh scripts/concurrency_soundness_gate.sh

# ── Gate 6 — service + client round-trip ──────────────────────────────────
# Drives the 21 services + clients fixtures in conformance/code.txt via
# the same vcx/tests/code_eval_fixtures_test.v whose `supported_fixtures`
# whitelist covers all 21 program-svc-NNN fixtures (HTTP verbs + status
# codes + TLS + streaming body + graceful-stop + handle lookup). Per
# spec/v0_8_0_status.md §11.6 gate 6.
.PHONY: test-vcx-services
test-vcx-services: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_eval_fixtures_test.v

# ── Gate 9 — diagram round-trip (SVG / PNG / Mermaid) ─────────────────────
# Diagram round-trip coverage already lives under `test-code-diagram`
# (drives conformance/code_diagram.txt through cx_code_diagram +
# cx_code_tree with structural-equivalence — 29/29
# fixtures). This target is the §11.6-named alias plus the V-side
# diagram unit tests that exercise the emitter + round-trip directly.
# Per spec/v0_8_0_status.md §11.6 gate 9.
.PHONY: test-vcx-diagram-roundtrip
test-vcx-diagram-roundtrip: build-vcx
	$(MAKE) test-code-diagram
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_diagram_roundtrip_test.v \
		vcx/tests/code_diagram_test.v

# ── Gate 12 — reference renderer (CLI + web + LSP) ────────────────────────
# Drives the V-side renderer test suite — `code_render_test.v` covers
# the production code renderer (vcx/code/render.v: body-quote selection,
# attribute serialisation, scalar typing, directive shape, structural
# vs. text round-trips); `path_renderer_test.v` covers the
# PathNode → source emitter introduced for the CXPath value kind. LSP CodeLens
# tests are not yet authored; this target tracks the V-side renderer
# coverage. Per spec/v0_8_0_status.md §11.6 gate 12.
.PHONY: test-renderer
test-renderer: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_render_test.v \
		vcx/tests/path_renderer_test.v

# ── Gate 28.7 — CXPath axis coverage (all 12 axes) ────────────────────────
# Drives the V-side per-axis test files: forward axes (21 tests:
# child / descendant / descendant-or-self / following-sibling / following
# / attribute / self / parent), reverse axes (17 tests: ancestor /
# ancestor-or-self / preceding-sibling / preceding), misc/expression
# scaffolding (21 tests: predicates, unions, integer-literal predicate,
# attribute-axis short-form), and dispatcher integration (3 tests:
# `[?find …/axis::…]` end-to-end). 62 tests total exercising the
# 12-axis vocabulary. Per spec/v0_8_0_status.md §11.6 gate 28.7.
.PHONY: test-cxpath-axis-coverage
test-cxpath-axis-coverage: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/cxpath_forward_test.v \
		vcx/tests/cxpath_reverse_test.v \
		vcx/tests/cxpath_misc_test.v \
		vcx/tests/cxpath_dispatcher_test.v

# ── Gate 28.8 — [?modify] action coverage (all 11 actions) ────────────────
# Drives the V-side modify test files: `modify_eval_test.v` covers
# the structural evaluator with one positive case per
# action (:set / :delete / :using / :rename / :set-attr / :delete-attr /
# :append / :prepend / :insert-before / :insert-after / :replace) plus
# action-chain semantics, focus-miss-skip-not-error, pure-functional
# invariant, multi-match focus, and Z79g path-aware dispatcher hop;
# `modify_node_test.v` + `_codec_test.v` cover the ModifyNode shape
# + binary codec round-trip; `modify_parser_test.v` covers the
# `[?modify]` directive parser. Per spec/v0_8_0_status.md §11.6 gate
# 28.8 (structural-sharing perf budget lives at gate 30.5).
.PHONY: test-modify-action-coverage
test-modify-action-coverage: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/modify_eval_test.v \
		vcx/tests/modify_node_test.v \
		vcx/tests/modify_node_codec_test.v

# ── Gate 30.5 — [?modify] structural-sharing perf budget ──────────────────
# Drives vcx/tests/runners/code_modify_sharing_bench.v — single-match
# `:set` heap delta + 1000-match `:set-attr` heap delta + identity-hash
# invariant. Budget: < 1 KB new heap per matched node on
# 10 MB doc. v0.8.0 ships with sharing-ratio + identity invariants
# enforced; the absolute-byte budgets are ADVISORY per the bench
# header's Element + Attribute diet analysis (post-diet residual cost
# is spine-frame overhead that closes to v0.9.0+ with HAMT-backed
# items containers). Per spec/v0_8_0_status.md §11.6 gate 30.5.
bench-code-modify-sharing: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/code_modify_sharing_bench.v

# ── Rosetta corpus cadence audit ──────────────────────────────
#
# `make corpus-audit` re-audits every program under corpus/rosetta/ against
# the current HEAD: runs each `NN-*.cx` via vcx/target/cx, classifies the
# live status (green / workaround / blocked / missing), and diffs against
# the table in corpus/rosetta/AUDIT.md. Exits 0 on full agreement, 1 on
# drift — drift is the cadence signal that a Wave-N fix has re-classified
# a program (or that AUDIT.md is stale). Closure of the
# task tracker's W1-H #32 item.
#
# Override knobs: CX_BIN=path (default vcx/target/cx),
# CORPUS_DIR=path (default corpus/rosetta).
.PHONY: corpus-audit
corpus-audit: build-vcx
	@bash scripts/corpus_audit.sh

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	$(MAKE) -C vcx clean
	rm -rf $(DIST_DIR)
	cargo clean --manifest-path lang/rust/cxlib/Cargo.toml
	find lang/python -name '*.pyc' -delete
	find lang/python -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
