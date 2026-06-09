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
# bare `v` (e.g. `make test-vcx-v08`) pick whatever is first on PATH — under
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
PYTHON ?= python3

.PHONY: all build build-wasm build-playground build-vcx build-vcx-dev build-lib build-lib-arrow build-rust build-rust-arrow \
 build-go build-go-arrow \
 build-vscode \
 publish publish-push \
 publish-v publish-v-push \
 publish-org \
 release release-v release-all \
 dist install uninstall install-cli uninstall-cli verify-cli promote-cli \
 test test-no-parallel test-python test-python-arrow test-vcx test-rust test-rust-arrow \
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
	$(MAKE) -C vcx build-dev

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

build-go: build-vcx
	cd lang/go/cxlib && go build ./...

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

# Documentation hygiene — every fenced ```cx block parses.
verify-doc-blocks: build-vcx
	@tools/verify-doc-blocks.sh docs/

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
# `make test-vcx-v08`). Nonzero exit on drift propagates through make.
# Module-set parity is owned by `make stdlib-catalogue-gate`.
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

# stdlib catalogue drift gate — verifies the single invariant
#   SPEC_SET == (BUNDLE_SET union DISPATCH_SET)
# i.e. every status=current [module-meta] in spec/03-approved/std-lib/*.md
# is implemented (stdlib/*.cx bundle and/or a *_stdlib_builtin entry in
# vcx/code/stdlib_dispatch.v), and there are no orphan impls/bundles
# without a current spec. The gate is itself written in CX (dog-food) and
# run by `cx eval`; its nonzero exit on drift propagates through make.
# Override the binary with CX_BIN=path (default vcx/target/cx).
.PHONY: stdlib-catalogue-gate
stdlib-catalogue-gate: CX_BIN ?= $(CURDIR)/vcx/target/cx
stdlib-catalogue-gate: build-vcx
	@"$(CX_BIN)" eval scripts/stdlib_catalogue_gate.cx --allow-all

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
verify-doc-links:
	@tools/verify-doc-links.sh docs/
	@tools/verify-doc-links.sh README.md

# Pre-tag version-string consistency (defaults to 0.6.0).
bump-version-check:
	@tools/bump-version.sh --check $(or $(VERSION),0.6.0)

# Full pre-tag check — runs everything in the release process + §0.5.
release-verify:
	@tools/release-verify.sh $(or $(VERSION),0.6.0)

# ── Test ───────────────────────────────────────────────────────────────────────

# Test fan-out — independent per-language targets, plus the C-ABI conformance
# harness. Listed once so `test` and `test-no-parallel` stay in sync.
# Active binding set per backlog d-2026-05-22-03 (v0.8.0) — V + Python + Go + Rust.
# Archived: TypeScript / Java / Kotlin / C# / Ruby / Swift moved to
# lang/_archived/ in v0.8.0; their test targets are no longer wired into
# `test`. Restoration is community opt-in once the Layer-1 16-method
# surface stabilizes (spec/bindings.md §6).
TEST_TARGETS := abi-c-test test-python test-vcx test-v test-rust test-go check-no-legacy-try check-no-infix-range check-no-stale-version check-effect-alignment check-null-absence-conflation check-docs-tier1-guardrail check-no-adr-citations check-no-stub-impl guide-check directive-docs-check

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

# ── NO-STALE-VERSION gate — the retired language name `CXL` must not reappear
# in conformance/ + docs-src/ + examples/ + scripts/ + tooling/ + top-level
# project prose. Token-aware, not a raw grep (live identifiers cxlib / cxl: /
# CXLS / CXLib are not matched; _archive*/_archived/_gate_evidence excluded).
.PHONY: check-no-stale-version
check-no-stale-version:
	@python3 scripts/check_no_stale_version.py

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
	@$(V) test vcx/tests/effect_alignment_test.v

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

# Default parallelism: detected core count, override with `make test TEST_JOBS=N`.
# Measured speedup on a warm build: ~10× wall-clock vs sequential (342s → 33s).
TEST_JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8)

# Default `test` runs targets in parallel. `--output-sync=target` keeps each
# target's logs grouped instead of interleaved across processes.
test:
	@$(MAKE) -j$(TEST_JOBS) --output-sync=target $(TEST_TARGETS)

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

test-python: build-vcx
	$(PYTHON) lang/python/test_fixture_loader.py
	$(PYTHON) lang/python/conformance.py
	$(PYTHON) lang/python/conformance_code.py
	$(PYTHON) lang/python/test_api.py
	$(PYTHON) lang/python/test_stream.py
	$(PYTHON) lang/python/test_data_bin_one_shots.py
	$(PYTHON) lang/python/test_namespaces.py
	$(PYTHON) lang/python/test_identity.py
	$(PYTHON) lang/python/test_delimited.py
	cd lang/python && $(PYTHON) -m unittest test_code_eval -v

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

test-rust: build-rust
	cargo test --manifest-path lang/rust/cxlib/Cargo.toml -- --test-threads=1

# Apache Arrow C-Data interop tests for the Rust binding
# (Phase 7.74c-cont-bindings-multi-rust). Mirrors test-go-arrow:
# builds libcx_arrow then exercises the 9-type round-trip surface
# under `--features arrow`. Pulls in the `arrow` crate (v53.x) the
# first time it runs.
test-rust-arrow: build-vcx build-lib-arrow
	cargo test --features arrow --manifest-path lang/rust/cxlib/Cargo.toml -- --test-threads=1

# Arrow conformance — runs the canonical conformance/data_bin_arrow.txt
# fixtures through the Rust binding. Mirrors test-python-arrow-conformance
# and test-go-arrow-conformance (cross-binding parity per spec/abi.md §2.11).
test-rust-arrow-conformance: build-vcx build-lib-arrow
	cargo test --features arrow --manifest-path lang/rust/cxlib/Cargo.toml \
		--test arrow_conformance -- --nocapture

test-vcx: build-vcx-dev test-vcx-v08
	$(MAKE) -C vcx conform-all

# Convenience wrapper: run the full V suite ONCE, stream live output to a
# log, then print a digest of just the FAIL lines + per-file counts. Uses
# `bash -o pipefail` so the recipe exits with the real `test-vcx` status
# (a plain `... | grep` would mask failures behind grep's exit code).
.PHONY: test-vcx-summary
test-vcx-summary:
	@bash -o pipefail -c '$(MAKE) test-vcx 2>&1 | tee /tmp/cx-test-vcx.log'; st=$$?; \
	echo "──── failures / counts ────"; \
	grep -iE 'FAIL|[0-9]+ passed, [0-9]+ failed|[0-9]+ errored' /tmp/cx-test-vcx.log || true; \
	echo "full log: /tmp/cx-test-vcx.log"; exit $$st

# ── v0.8.0 V-side ADR surface tests ───────────────────────────────────────
# Drives the conformance/code.txt fixture-runner tests + the v0.8.0 ADR
# surface unit tests under vcx/tests/. Files use two prefix conventions:
#   - `code_*_test.v`        — evaluator / parser / lexer / renderer /
#                              fixture-runner against conformance/code.txt
#                              (gate 4 + the per-binding parity input).
#   - `v08_*_test.v`         — v0.8.0 additions: PathNode + CXPath
#                              axes (gate 28.7), `[?match]`
#                              multi-arm, `[?modify]` action
#                              vocabulary (gate 28.8), atoms,
#                              `[?def]` (gate 28.11),
#                              `[?lib]` / `[?const]` / lockfile / module
#                              loader (gate 28.12), `[?expr]`
#                              general predicate (gate 28.13),
#                              `:pure` / `:impure` (gate
#                              28.14), `code_diagram` / `code_tree`
#                              (gates 37.2 / 37.4 / 37.5 / 37.10),
#                              ABI v0.8.0 surface (gate 11 / 28.9
#                              evidence floor).
#
# Each gate's coverage commitment is itemised in
# `spec/v0_8_0_status.md §11.6`; this Make target is the V-side runner.
# Wired into TEST_TARGETS via the `test-vcx` umbrella above.
.PHONY: test-vcx-v08
test-vcx-v08: build-vcx-dev
	@$(V) test vcx/tests/

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
VFLAGS_VCX := -path "$(V_MODULE_PATH)"

test-v: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v $(VFLAGS_VCX) run lang/v/conformance.v
	VFLAGS='$(VFLAGS_VCX)' v test lang/v/tests/v0_8_0_surface_test.v
	VFLAGS='$(VFLAGS_VCX)' v test lang/v/tests/native_atom_test.v

test-vcx-api: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test lang/v/tests/v0_8_0_surface_test.v

test-vcx-stream: build-vcx
	v test vcx/tests/stream_test.v

test-go: build-go
	cd lang/go/cxlib && go test ./...
	cd lang/go/conformance && go run .

test-go-api: build-go
	cd lang/go/cxlib && go test ./...

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

release-all: release release-v publish-org

# ── Editor tooling ────────────────────────────────────────────────────────────
#
# Since v0.7.0 the language server is built into the `cx` binary itself —
# `cx lsp` speaks JSON-RPC 2.0 over stdio (see vcx/cmd/lsp.v and
# tooling/lsp/README.md). Editor integration is `cx` on $PATH plus the
# example configs at tooling/lsp/{vscode,neovim,helix}.example.*.
#
# `make build-vscode` produces a publishable .vsix wrapping the VS Code
# extension at tooling/vscode/. The .vsix bundles the TextMate grammar,
# snippets, language configuration, and LSP-client glue; it does NOT
# bundle a `cx` binary — users install that separately.

build-vscode:
	cd tooling/vscode && npm install --silent && npm run build && npx vsce package --no-dependencies --allow-missing-repository

# ── Benchmark ──────────────────────────────────────────────────────────────────

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
# gate-check (`scripts/v0_8_0_gate_check.sh`) invokes by name. The
# underlying test files all exist and already pass via the `test-vcx-v08`
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
		vcx/tests/v08_code_diagram_test.v

# ── Gate 12 — reference renderer (CLI + web + LSP) ────────────────────────
# Drives the V-side renderer test suite — `code_render_test.v` covers
# the production code renderer (vcx/code/render.v: body-quote selection,
# attribute serialisation, scalar typing, directive shape, structural
# vs. text round-trips); `v08_path_renderer_test.v` covers the
# PathNode → source emitter introduced for the CXPath value kind. LSP CodeLens
# tests are not yet authored; this target tracks the V-side renderer
# coverage. Per spec/v0_8_0_status.md §11.6 gate 12.
.PHONY: test-renderer
test-renderer: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_render_test.v \
		vcx/tests/v08_path_renderer_test.v

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
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/v08_cxpath_forward_test.v \
		vcx/tests/v08_cxpath_reverse_test.v \
		vcx/tests/v08_cxpath_misc_test.v \
		vcx/tests/v08_cxpath_dispatcher_test.v

# ── Gate 28.8 — [?modify] action coverage (all 11 actions) ────────────────
# Drives the V-side modify test files: `v08_modify_eval_test.v` covers
# the structural evaluator with one positive case per
# action (:set / :delete / :using / :rename / :set-attr / :delete-attr /
# :append / :prepend / :insert-before / :insert-after / :replace) plus
# action-chain semantics, focus-miss-skip-not-error, pure-functional
# invariant, multi-match focus, and Z79g path-aware dispatcher hop;
# `v08_modify_node_test.v` + `_codec_test.v` cover the ModifyNode shape
# + binary codec round-trip; `v08_modify_parser_test.v` covers the
# `[?modify]` directive parser. Per spec/v0_8_0_status.md §11.6 gate
# 28.8 (structural-sharing perf budget lives at gate 30.5).
.PHONY: test-modify-action-coverage
test-modify-action-coverage: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/v08_modify_eval_test.v \
		vcx/tests/v08_modify_node_test.v \
		vcx/tests/v08_modify_node_codec_test.v

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
