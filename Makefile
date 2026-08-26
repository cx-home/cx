# ── v0.8.0 CX Data Language Guide ─────────────────────────────── BEGIN gen_guide
# Makes `make guide` first-class. Renders
# docs-src/canonical/manifest.cxd + sections/*.cxd into docs/guide/.
# When the v0.8.0 cx binary is not yet runnable, the target stages
# chrome + assets and falls back to source-as-body pages — see
# scripts/gen_guide/README.md for the full pipeline.
-include scripts/gen_guide/guide.mk
# ── v0.8.0 CX Data Language Guide ───────────────────────────────── END gen_guide

# ── LLM onboarding layer (#938) ──────────────────────────────────── BEGIN gen_docs
# Makes `make docs` / `make docs-check` first-class. Renders docs-src/llm/
# templates into docs/llm/ (primer.md, reference-*.md, llms.txt,
# llms-full.txt), pulling every example from a conformance fixture and
# re-recording its output from the live binary. `make docs-check` is the drift
# gate (in TEST_TARGETS + tools/release-verify.sh).
-include scripts/gen_docs/docs.mk
# ── LLM onboarding layer (#938) ────────────────────────────────────── END gen_docs

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
 test-xpath-parity test-xpath-parity-cx test-binding-api-parity \
 abi-c-test \
 conform conform-vcx conform-md bench bench-python bench-streaming bench-cxparse \
 bench-code-pattern-compile bench-code-streaming bench-code-http bench-code-gates \
 bench-lazy-ceiling \
 bench-streamed-alloc \
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
	@# event loop on the main thread without freezing the UI. The
	@# default `make build-wasm` keeps ASYNCIFY=0 so CLI/binding
	@# consumers don't pay it.
	@# ASYNCIFY_MODE=2 selects JSPI (-sASYNCIFY=2) instead of the
	@# classic binaryen Asyncify rewriter (#930): the classic rewriter
	@# under emcc 5.0.7 costs ~7x host stack per CX eval level, which
	@# shrank the recursion window to ~10-11 levels and broke the
	@# diagram walkers on stock example [64]. JSPI removes the
	@# instrumentation entirely — sync exports get full depth (the
	@# #319 guard trips catchably at ~40 levels) and the single-file
	@# bundle drops 36MB → 13MB. Requires a JSPI-capable browser
	@# (Chromium 137+); cxlib.js routes the async lanes through
	@# WebAssembly.promising wrappers when Module.cxAsyncifyMode == 2.
	@# Build recipe mirrors scripts/gen_guide/guide.mk (build-playground-
	@# wasm-for-guide) so `build-playground` and `guide` stay consistent.
	@# libcx-sync: plain (ASYNCIFY=0) compatibility bundle for hosts
	@# WITHOUT the JSPI API (Safari; Firefox where still flag-gated).
	@# The JSPI bundles abort at instantiation there, so cxlib.js
	@# selects this one when WebAssembly.Suspending is absent — full
	@# recursion window, wall-clock [?sleep] raises catchable CXER0270
	@# (mock sleeps work). No pthreads.
	@SINGLE_FILE=1 ASYNCIFY=1 ASYNCIFY_MODE=2 PTHREADS=0 OUT_NAME=libcx-async    ./scripts/wasm/build_libcx_wasm.sh
	@SINGLE_FILE=0 ASYNCIFY=1 ASYNCIFY_MODE=2 PTHREADS=1 OUT_NAME=libcx-pthreads ./scripts/wasm/build_libcx_wasm.sh
	@SINGLE_FILE=1 ASYNCIFY=0                 PTHREADS=0 OUT_NAME=libcx-sync     ./scripts/wasm/build_libcx_wasm.sh
	@echo "[build-playground] staging dist/playground-preview/"
	@rm -rf dist/playground-preview
	@mkdir -p dist/playground-preview/playground
	@mkdir -p dist/playground-preview/playground/vendor
	@mkdir -p dist/playground-preview/wasm
	@mkdir -p dist/playground-preview/dist/wasm
	@cp scripts/gen_guide/playground/playground.html dist/playground-preview/
	@cp scripts/gen_guide/playground/playground.js dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/playground.css dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/playground.examples.js dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/jspi_probe.html dist/playground-preview/playground/
	@# highlight/ + assets/ make the preview docroot FAITHFUL to the shipped
	@# page (#1007's offline run surfaced two ERR_FILE_NOT_FOUND here that
	@# docs/guide does not have — the smoke gate must test the real layout).
	@mkdir -p dist/playground-preview/highlight dist/playground-preview/assets
	@cp scripts/gen_guide/highlight/*.js dist/playground-preview/highlight/ 2>/dev/null || true
	@cp -R scripts/gen_guide/assets/. dist/playground-preview/assets/ 2>/dev/null || true
	@# The vendored diagram renderer (#1007) — mermaid at a pinned version,
	@# no longer a jsDelivr <script>. It is staged like any other playground
	@# asset because it IS one now; the license travels with it, the way
	@# third_party/re2's does into every release tarball. Copied, not
	@# symlinked, so the preview docroot is self-contained.
	@cp scripts/gen_guide/playground/vendor/mermaid.min.js dist/playground-preview/playground/vendor/
	@cp scripts/gen_guide/playground/vendor/LICENSE-mermaid.txt dist/playground-preview/playground/vendor/
	@cp dist/wasm/cxlib.js dist/playground-preview/wasm/cxlib.js
	@cp dist/wasm/libcx-async.js dist/playground-preview/wasm/libcx-async.js
	@cp dist/wasm/libcx-sync.js dist/playground-preview/wasm/libcx-sync.js
	@if [ -f dist/wasm/libcx-pthreads.js ]; then cp dist/wasm/libcx-pthreads.js dist/playground-preview/wasm/libcx-pthreads.js; fi
	@if [ -f dist/wasm/libcx-pthreads.wasm ]; then cp dist/wasm/libcx-pthreads.wasm dist/playground-preview/wasm/libcx-pthreads.wasm; fi
	@# Smoke-test compatibility: also stage flat copies under dist/wasm/
	@# so scripts/test_playground_smoke.sh (which queries dist/wasm/*
	@# directly) keeps working alongside the absolute-URL layout that
	@# matches docs/guide/ deployment.
	@cp dist/wasm/cxlib.js dist/playground-preview/dist/wasm/cxlib.js
	@cp dist/wasm/libcx-async.js dist/playground-preview/dist/wasm/libcx-async.js
	@cp dist/wasm/libcx-sync.js dist/playground-preview/dist/wasm/libcx-sync.js
	@if [ -f dist/wasm/libcx-pthreads.js ]; then cp dist/wasm/libcx-pthreads.js dist/playground-preview/dist/wasm/libcx-pthreads.js; fi
	@if [ -f dist/wasm/libcx-pthreads.wasm ]; then cp dist/wasm/libcx-pthreads.wasm dist/playground-preview/dist/wasm/libcx-pthreads.wasm; fi
	@# Staleness gate (#992). The three builds above are unconditional, so
	@# reaching here with a stale artifact means one of them silently did
	@# not produce what it claimed — which is exactly the failure that
	@# shipped a 0.13.0 engine into a v0.17 playground for five releases.
	@# The gate refuses rather than staging it.
	@$(MAKE) --no-print-directory wasm-fresh-gate
	@echo "[build-playground] OK — dist/playground-preview/ ready (libcx-async + libcx-pthreads + libcx-sync staged)"

# ── playground engine staleness gate (#992) ───────────────────────────────────
# Two signals, either of which means the playground would run an engine that is
# not this tree's: an artifact older than vcx/ + stdlib/ + VERSION + the build
# script, or an artifact whose own cx_version() export disagrees with VERSION.
# Run it directly to ask "is my playground current?"; `build-playground` runs it
# as a post-condition, and `guide` runs it in --warn mode (guide reuses the
# existing bundle by design, but must never do so silently).
.PHONY: wasm-fresh-gate
wasm-fresh-gate:
	@./scripts/wasm/check_wasm_fresh.sh

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

# V2 — V FORK divergence inventory (RULED: VC-1). CX builds against a
# permanent fork of the V compiler, so there is no pending-upstream state
# to track: this gate asserts that every commit third_party/v carries
# beyond its upstream base has a documented row in the register, and that
# no register row names a commit the fork has dropped. Red on undocumented
# divergence, in either direction.
#
# It replaced check-v-upstream, which queried the GitHub API for two
# tracked issues — a network dependency that made it advisory-only (CI ran
# it under continue-on-error, so it could never fail anything). This one is
# OFFLINE and deterministic, which is what earns it a place in TEST_TARGETS.
.PHONY: check-v-fork
check-v-fork: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-v-fork: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_v_fork_patches.cx

# V module-cache soundness gate (#700 wave 2, VC-23) — adversarial proof of
# the -usecache key: for every input that can change a cached object's bytes,
# mutate it -> MISS; byte-identical rerun -> HIT; planted/poisoned objects ->
# detected, never linked. Behavioral assertions (built binaries are RUN and
# compared against current sources), so it stays red-capable against future
# mechanism regressions; `--prove-red` (run manually) forges a provenance
# manifest and requires the gate to catch it. ~2 min wall. CADENCE: run on
# every third_party/v change (alongside check-v-fork), before a release cut,
# and before widening -usecache to more lanes — it proves the COMPILER, not
# the tree, so it is not in the default TEST_TARGETS ring. Audit + evidence:
# ledger/audit_2026_08_24_vcache_key_soundness.md.
.PHONY: check-vcache-soundness
check-vcache-soundness:
	@log=vcx/target/vcache-soundness.log; \
	bash scripts/vcache_soundness_gate.sh > $$log 2>&1; rc=$$?; \
	grep -E '^PROBE|^vcache-soundness' $$log; \
	echo "full log: $$log; GATE-RC=$$rc"; exit $$rc

# V6 — pre-commit lint rules over .cx files. Catches the retired
# v0.7.x syntax forms the v0.8.0 parser rejects, plus the
# cxl-version=/cx-eval-version= rename window deprecation.
check-lint-rules: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-lint-rules:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_lint_rules.cx

# V6 — install the .githooks/ scripts as repo-local git hooks
# (idempotent). Sets core.hooksPath rather than symlinking each
# hook individually so a new hook script lands without re-running
# the install target.
install-hooks:
	@git config core.hooksPath .githooks
	@echo "[install-hooks] git core.hooksPath set to .githooks"
	@ls -1 .githooks/ | sed 's/^/  - /'

# std-lib documentation freshness gate — CX-native (dog-food), run as
# `cx <file>`. Verifies the co-located [module-doc]/[fn-doc] in stdlib/*.cx:
# presence parity (every public [?def] has a [fn-doc] and vice-versa),
# purity agreement, and that every [fn-doc] example is backed verbatim by
# the module's conformance corpus (conformance/stdlib/<m>.cxd, run green by
# `make test-vcx-suite`). Nonzero exit on drift propagates through make.
# Module-set parity is owned by `make stdlib-catalog-gate`.
# Override the binary with CX_BIN=path (default vcx/target/cx).
.PHONY: guide-check
guide-check: CX_BIN ?= $(CURDIR)/vcx/target/cx
guide-check: build-vcx
	@"$(CX_BIN)" --allow-all scripts/gen_guide/stdlib_docs_check.cx

# Directive + syntax reference drift gate — every code.md §4.1 registry
# directive has a [directive-doc], no orphans, and each example is backed
# verbatim by the conformance corpus (mirrors guide-check for the stdlib).
.PHONY: directive-docs-check
directive-docs-check: CX_BIN ?= $(CURDIR)/vcx/target/cx
directive-docs-check: build-vcx
	@"$(CX_BIN)" --allow-all scripts/gen_guide/directive_docs_check.cx

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
	@vcx/target/cx --allow-read --allow-write --allow-subprocess --allow-env \
	  scripts/gen_guide/playground/gen_examples.cx --check

# ── playground diagram validity gate (#992) ───────────────────────────────────
# Every diagram the playground can put on screen must PARSE:
#   example × {auto, instance} × {source, output} × {min, compact, full}
# checked against the very mermaid bundle the page loads — since #1007 that is
# the vendored scripts/gen_guide/playground/vendor/mermaid.min.js, not a CDN
# range and not the gate's own npm copy, so gate and page cannot pin different
# renderers. The emitters are reached where they really live — the `auto` graphs
# from the built wasm engine, the `instance` graphs from playground.js's own
# builder — so the gate cannot go green over a shipped file that has rotted.
#
# Opt-in, like `build-wasm`: it needs `make build-playground` to have produced
# dist/wasm/, plus one npm install for jsdom. Both preconditions FAIL
# LOUD (exit 2) rather than skipping, so this lane can never report a vacuous
# pass. It is deliberately NOT in TEST_TARGETS — that lane must not require
# emcc or a network fetch — and belongs with scripts/test_playground_smoke.sh as
# the playground release lane.
.PHONY: test-playground-mermaid
test-playground-mermaid:
	@node scripts/test_playground_mermaid.mjs

# stdlib catalog drift gate — verifies the single invariant
#   SPEC_SET == (BUNDLE_SET union DISPATCH_SET)
# i.e. every status=current [module-meta] in spec/03-approved/std-lib/*.md
# is implemented (stdlib/*.cx bundle and/or a *_stdlib_builtin entry in
# vcx/code/stdlib_dispatch.v), and there are no orphan impls/bundles
# without a current spec. The gate is itself written in CX (dog-food) and
# run as `cx <file>`; its nonzero exit on drift propagates through make.
# Override the binary with CX_BIN=path (default vcx/target/cx).
.PHONY: stdlib-catalog-gate
stdlib-catalog-gate: CX_BIN ?= $(CURDIR)/vcx/target/cx
stdlib-catalog-gate: build-vcx
	@"$(CX_BIN)" --allow-all scripts/stdlib_catalog_gate.cx

# ── tools-export golden gate (stream 18, #690) ────────────────────────────────
# `cx tools export` over the checked-in M5 module must reproduce the checked-in
# golden byte-for-byte — the offline registration lane pinned end-to-end
# (cx-x/tools descriptors → cx-x/mcp-server adapter → JSON emission). A
# projection change that moves these bytes is deliberate and regenerates the
# golden via the verb itself in the same commit.
.PHONY: tools-export-gate
tools-export-gate: CX_BIN ?= $(CURDIR)/vcx/target/cx
tools-export-gate: build-vcx
	@out=$$("$(CX_BIN)" tools export conformance/tools-export/refund_order.cx) || { echo "tools-export-gate: the verb FAILED"; exit 1; }; \
	want=$$(cat conformance/tools-export/refund_order.tools.json); \
	if [ "$$out" != "$$want" ]; then \
	  echo "tools-export-gate: OUTPUT DIVERGES from conformance/tools-export/refund_order.tools.json"; \
	  echo "--- got:"; echo "$$out"; echo "--- want:"; echo "$$want"; \
	  exit 1; \
	fi; \
	echo "tools-export-gate OK — refund_order.tools.json reproduced byte-for-byte"

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
# a stable JSON shape consumable by scripts/compare_bench.cx.
bench-json: CX_BIN ?= $(CURDIR)/vcx/target/cx
bench-json:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-clock scripts/run_bench_json.cx

# V7 — bench regression comparison. Pass BASELINE= and CURRENT= as
# paths to JSON files produced by bench-json. Default threshold is
# 30%; pass STRICT=1 for the 10% threshold.
bench-compare: CX_BIN ?= $(CURDIR)/vcx/target/cx
bench-compare:
	@"$(CX_BIN)" --allow-read --allow-write scripts/compare_bench.cx \
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
	  SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md RELEASE_NOTES_v*.md \
	  AGENTS.md CLAUDE.md
	@# docs/llm/ (#938) is the GENERATED LLM layer. It is expected to carry
	@# ZERO relative links: it is served from the published SITE ROOT, where a
	@# repo-relative path resolves to nothing. So this row's job is to stay at
	@# "0 failed" as the layer grows — the moment a template starts emitting
	@# `](…)` paths, they have to resolve in the checkout too.
	@tools/verify-doc-links.sh docs/llm/

# Pre-tag version-string consistency. VERSION (the repo-root file) is the
# single source of truth; scripts/check_version_consistency.cx verifies every
# stamped manifest + derived code surface against it. An explicit
# VERSION=X.Y.Z arg additionally asserts the file holds the version you
# intend to release (catches "forgot to run scripts/bump_version.sh").
bump-version-check: CX_BIN ?= $(CURDIR)/vcx/target/cx
bump-version-check: build-vcx
	@if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$(cat VERSION)" ]; then \
	  echo "bump-version-check: VERSION file holds $$(cat VERSION), expected $(VERSION) — run scripts/bump_version.sh $(VERSION)"; \
	  exit 1; \
	fi
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_version_consistency.cx

# RULED: PGL-1 (#741) — the R2.2 BLOCKING per-profile install gate, runnable
# WITHOUT a cut. It used to live only inside release.sh phase 2, in the arm
# that --dry-run skips, so its first execution was always the real cut.
.PHONY: release-profile-gate
release-profile-gate:
	@scripts/release_profile_gate.sh

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
TEST_TARGETS := abi-c-test check-v-fork check-serial-retry-rosters test-python test-vcx-suite test-vcx-code test-vcx-cmd test-vcx-cxstore test-vcx-cx test-vcx-conform test-vcx-columnar test-vcx-sqlite test-v test-rust test-go check-prod-build check-no-legacy-try check-pipefail-pipes check-no-infix-range check-no-cxl-token check-no-consumer-terms check-version-consistency check-effect-alignment check-null-absence-conflation check-docs-tier1-guardrail check-no-adr-citations check-no-stub-impl check-xap-dist-absences check-completions-drift check-tmlanguage-sync guide-check directive-docs-check verify-doc-blocks verify-playground-examples docs-check ring-import-gate gates-manifest-gate ring-tag-gate cxer-registry-gate spec-freeze-gate test-extraction-gate abi-gc-gate libcx-abi-gate test-profile-gate check-code-spec-consistency check-code-fixtures stdlib-catalog-gate address-baseline-gate tools-export-gate test-code-diagram test-oriel-lane test-xpath-parity-cx corpus-audit

# ── test-changed (#700, ruled 1a 2026-08-09) — the lane-input skip manifest ──
# THE DEVELOPMENT-LOOP ENTRY POINT. Runs only the TEST_TARGETS lanes whose
# declared input globs intersect BASE..HEAD (+worktree). Deny-by-default: a
# lane without a manifest row in scripts/test_changed.sh ALWAYS runs. The full
# `make test` union stays MANDATORY at wave/phase exits — this target never
# substitutes for an exit gate.
#
# BASE defaults to HEAD, i.e. "what I have not committed yet" — the loop a
# developer is actually in, and a ref that always resolves. Widen the window
# explicitly when the work is already committed:
#   make test-changed BASE=origin/release/0.17     # the whole branch's change set
#   make test-changed BASE=HEAD~3
# `make test-changed-dry` prints the SKIP/RUN decision and executes nothing.
# (#700 wave 1, 2026-08-24: BASE had no default, so the entry point AGENTS.md
# documents exited 2 with a usage message unless the caller already knew to
# pass BASE=.)
BASE ?= HEAD
.PHONY: test-changed
test-changed:
	@bash scripts/test_changed.sh $(BASE)

.PHONY: test-changed-dry
test-changed-dry:
	@bash scripts/test_changed.sh $(BASE) --dry-run

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
# ── SIGPIPE-PIPE gate (RULED: SPG-1, #916) — `external cmd | grep -q P`
# inside a pipefail script fires FALSE failures: grep -q exits on the first
# match, the producer takes SIGPIPE (141), pipefail promotes it. Two
# instances existed before this gate, one of them inside the BLOCKING R2.2
# release gate, where it aborted a cut on a good artifact (PGL-1a). Landed
# green with ZERO annotated exceptions; that is the standard to hold.
.PHONY: check-pipefail-pipes
check-pipefail-pipes:
	@scripts/pipefail_pipe_gate.sh

check-no-legacy-try: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-no-legacy-try:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_legacy_try.cx

# ── NO-INFIX-RANGE gate (generator-family reshape, C-gen-1) — the retired
# infix range operators `to`/`by` must not reappear in conformance/ + docs-src/
# + examples/ + lang/. Ranges are the prefix builtin [$range lo hi step?].
# Token-aware, not a raw grep (English to/by prose, to=/by= named args, and the
# colon slice-stride [a:b:s] are not matched; the negatives are allowlisted).
.PHONY: check-no-infix-range
check-no-infix-range: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-no-infix-range:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_infix_range.cx

# ── NO-CXL-TOKEN gate — the retired language name `CXL` must not reappear
# in conformance/ + docs-src/ + examples/ + scripts/ + tooling/ + top-level
# project prose. Token-aware, not a raw grep (live identifiers cxlib / cxl: /
# CXLS / CXLib are not matched; _archive*/_archived/_gate_evidence excluded).
# (Formerly mis-named `check-no-stale-version` — it never checked versions;
# version-number drift is now caught by check-version-consistency below.)
.PHONY: check-no-cxl-token
check-no-cxl-token: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-no-cxl-token:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_cxl_token.cx

# ── NO-CONSUMER-TERMS gate — downstream-consumer identity (names, products,
# business-domain vocabulary) must never appear in tracked content: the public
# release repos are CUT from this one, so anything here flows into them. The
# denylist lives in the script; extend it the day a new consumer engagement
# begins. Standing owner ruling 2026-07-24: all artifacts speak CX-generic
# workload language (users / tracked entities / events / deployments).
.PHONY: check-no-consumer-terms
check-no-consumer-terms:
	@bash scripts/check_no_consumer_terms.sh

# ── VERSION-CONSISTENCY gate — the repo-root VERSION file is the single source
# of truth for the release version. Every static manifest must equal it and the
# code surfaces (cabi.v/main.v) must DERIVE it from the build define. Catches the
# drift that previously went unnoticed (cx.pc.in at 0.6.1, C-ABI at 0.8.0 while
# the CLI said 0.10.0). Re-stamp with scripts/bump_version.sh.
.PHONY: check-version-consistency
check-version-consistency: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-version-consistency: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_version_consistency.cx

# ── check-null-absence-conflation gate (SAP C1 / spec/core/code.md §9.1.2.1
# rule (b)) — the no-conflation guard: no builtin returns `null` to mean
# "absent." An optional read signals "nothing here" via the absence channel
# (the empty sequence `()`), never `null`. Token-aware: it flags the
# `[returns [or T null]]` declared-optional-return shape in the stdlib def
# surface (spec/std-lib/*.md + the vcx/code bundle sources); unit-null
# `[returns null]` and param-position `[or T null]` are deliberately not
# flagged. Permanent gate, not migration-only.
.PHONY: check-null-absence-conflation
check-null-absence-conflation: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-null-absence-conflation:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_null_absence_conflation.cx

# ── ALIGNMENT gate (SAP C2 / spec/core/code.md §6.5.1) — the one-way
# capability-alignment invariant: (1) every capability-gated effect point is
# reached only through an `impure` builtin (gated ⇒ impure, by construction in
# builtin_purity_table); (2) every impure-without-capability builtin is in the
# closed, enumerated exception table. NOT symmetric. The V test owns both
# directions + drift canaries (process- prefix, env- minus pure prims, io
# read/write/open). Runs as part of `test-vcx` too; this dedicated target is
# the named gate.
# (#700: effect_alignment_test.v consolidated into the eval_semantics
# umbrella — the named target retargets to the umbrella like its siblings.)
.PHONY: check-effect-alignment
check-effect-alignment: build-vcx
	@$(V) -cc cc $(CX_GC) test vcx/tests/eval_semantics_umbrella_test.v

# ── check-code-spec-consistency (#707 item 4 / code.md §11.4.1 gates 1-3 +
# the clean-room no-impl-anchor / no-dangling-decision checks). The tool
# existed since v0.7.6 but was wired into NEITHER the Makefile NOR CI — its
# gate 3 (registry↔grammar [127e] parity) had been silently dead since the
# formal-files move and nobody noticed. Repaired + wired at I2. Gate 1 runs
# on the code.md bounded-freedom register (BF-* ids), not a blanket token ban.
.PHONY: check-code-spec-consistency
check-code-spec-consistency: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-code-spec-consistency: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_code_spec_consistency.cx > /dev/null && echo "check-code-spec-consistency OK — gates 1-3 + no-impl-anchor + no-dangling-decision green (run the script directly for the JSON report)"

# ── check-code-fixtures (gate 4; repaired + wired by the #805 gate-truth
# batch — it was RED and in no lane, so no stream gate ever ran it). The
# corpus/spec agreement gate over conformance/code.cxd: id-category
# registry, directive registry (§4.1) with retired/PI/intentional-unknown
# discipline, and ENFORCED spec-error-code coverage (every CXER code
# cited, verified covered cross-suite, or pinned to its filed issue —
# #808 rows are the visible debt).
# CX gate (#922, RULED: PYE-5): reads the corpus through THIS TREE's cx
# binary ([$cx:parse]) — the gate exercises the reader it guards. The
# former LIBCX_LIB_DIR pin is obsolete (nothing dlopens cxlib any more);
# the build-vcx dep remains the #902 rule — the shipped artifact is the
# only honest subject for a gate.
.PHONY: check-code-fixtures
check-code-fixtures: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-code-fixtures: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_code_fixtures.cx > /dev/null && echo "check-code-fixtures OK — 1000+ fixtures: ids/directives/error-code coverage green (run the script directly for the JSON report)"

# ── check-docs-tier1-guardrail gate (SAP C6 / SAP §0.1) — the learnability
# guardrail: the canonical guide's beginner sections (quickstart §0 + intro §1)
# show Tier 1 ONLY, and fp.md / the words "monad"/"functor"/"typeclass" never
# appear in beginner material. Makes §0.1's reviewer rule a permanent gate so
# the entry surface cannot silently drift into advanced theory. Token-aware
# (whole-word advanced terms); a deferring mention ("no monads required") is
# allowlistable. Tier 2/3 sections (concepts §9, libraries §16) are out of
# scope by design — they carry the opt-in/advanced markers.
.PHONY: check-docs-tier1-guardrail
check-docs-tier1-guardrail: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-docs-tier1-guardrail:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_docs_tier1_guardrail.cx

# ── NO-ADR-CITATION gate — the spec (spec/core/*.md) is the only source of
# truth. Decision records are archived (under the guarded decisions dir) and
# MUST NOT be cited from the live tree; such a citation pins live code/docs to
# a non-authoritative record and corrupts the single-source model. The gate is
# token-aware; the gate script + the SAP audit report are allowlisted.
.PHONY: check-no-adr-citations
check-no-adr-citations: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-no-adr-citations:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_adr_citations.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_adr_citations.cx

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
check-no-stub-impl: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-no-stub-impl:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_stub_impl.cx

# ── RING IMPORT GATE (partition spec §3, phase I0) — the ring import contract,
# enforced grep-level, zero-tolerance. Lands BEFORE any code moves so the seam
# can never regress silently. As of I0 it gates the structurally-clean Ring-0
# sink invariant (vcx/cx imports nothing internal — the §7 byte-for-byte
# extraction precondition); the Ring-1/2 split inside vcx/code is gated at I3.
.PHONY: ring-import-gate
ring-import-gate:
	@bash scripts/ring_import_gate.sh
	@bash scripts/ring_import_gate_selftest.sh

# ── GATES MANIFEST GATE (corpus audit G17) — validate conformance/gates.cxd:
# it parses, every gate= value is in-enum, and every [module name=X] row
# resolves (suite-aware) to a real fixture. Nothing else validated this policy
# file, and it governs whether every OTHER fixture blocks its gate.
.PHONY: gates-manifest-gate
gates-manifest-gate:
	@bash scripts/gates_manifest_gate.sh

# ── CXER REGISTRY GATE (corpus-audit G18; remediation register R3.7) —
# every emitted CXER code must have a governance §9.6 registry row and no
# registry-internal band overlap. --strict = the mechanical certainties.
.PHONY: cxer-registry-gate
cxer-registry-gate:
	@bash scripts/cxer_registry_report.sh --strict

# ── SPEC-FREEZE GATE (remediation register R4.1) — no commit after the
# audit epoch may touch normative spec AND implementation together without
# a RULED: token referencing a recorded ruling (rulings-before-edits, R4.2).
.PHONY: spec-freeze-gate
spec-freeze-gate:
	@bash scripts/spec_freeze_gate.sh
	@bash scripts/spec_freeze_gate_selftest.sh

# ── EXTRACTION GATE (partition spec §7, phase I2) — the Ring-0 byte-for-byte
# rule, executable: the extracted artifacts must match the monolith over the
# full Ring-0-tagged corpus — outputs, canonical bytes, hashes, error codes.
# Two lanes:
#   ABI lane — vcx/tests/runners/extraction_gate/probe/ dlopens ONE artifact,
#     feeds every Ring-0 case input through a fixed C-ABI battery (conversions
#     matrix, canonical/hash/fmt/lint, ast-bin/data-bin/events + decoder
#     round-trips, diff/eq pairs, schema validate, the streaming-write event
#     interpreter) and emits a deterministic transcript; the transcript from
#     libcx.dylib and the one from libcx-core.dylib must be BYTE-IDENTICAL
#     (`cmp`). Errors are records too, so error-text identity is asserted.
#     One artifact per process — the GC-carrying dylibs never co-load.
#     Vacuous-pass defense (audit F-15 / remediation R3.8): the probe
#     enforces the case-count floor below AND refuses any zero-record
#     Ring-0 case that is not an intentional exclusion. The only
#     intentional exclusions are the md-input cases (no md surface in the
#     C ABI) — the CLI lane covers those via --from=md.
#   CLI lane — vcx/tests/runners/extraction_gate/cli/ runs monolith cx and
#     data-profile cx over the shared surface (verbs + EXPLICIT --from=
#     convert; the bare-FILE run-vs-data reading is a ruled profile
#     difference, spec §4) requiring stdout+stderr+rc identical, plus the
#     17 monolith-verb profile refusals on the data binary (#426 discipline).
#     Same case-count floor.
# Dev-shape builds (same codegen semantics as -prod minus optimization);
# the release cut re-runs this against the prod-shape artifacts.
#
# RULED: VC-24 — the harness builds under $(CX_GC), cx's memory model, like
# everything else. These three runner binaries (probe, cli_gate, and
# abi-gc-gate below) carried a hard-coded `-gc boehm` from daf3f921b
# (2026-08-06) with no rationale in the commit or the comment, overriding the
# `-gc e` default that had been cx's since a27d61b6b. CX has one collector;
# the gate harness is not exempt. If a `-gc e` host ever fails HERE it is a
# vgc dlopen-host defect (two statically-linked vgc runtimes in one process
# share a pthread_once signal-handler install and keep per-image __thread
# state) — that gets FILED and fixed on its own landing, never absorbed by a
# silent Boehm override.
# Floor = the Ring-0 census recorded at I2 (partition_I2_extraction.md);
# raise it when Ring-0 cases are added, never lower it silently.
EXTRACTION_GATE_FLOOR := 1564
# CLI-lane shard count (RULED: VC-32). This lane was the gate's serial floor:
# 10,579 invocation pairs = 21,158 process spawns issued two at a time, 717 s at
# ~1 core, 91% of the extraction gate and 12 of `make test`'s ~21 minutes.
#
# It runs as PROCESSES, not threads: a bounded thread pool deadlocked vgc's
# stop-the-world, because a thread parked in a blocking read never reaches a
# safepoint (#973). Shards have separate heaps, and the parent is single-threaded
# with inherited stdio so it never blocks reading a child's pipe.
#
# MEASURED 2026-08-25, same binary, cleared scratch: serial 721 s, --jobs=8
# 103 s (7.0x), and both produce the IDENTICAL verdict digest
# 07de4e13ae9706744c68b8207c712a33d8c21da662e10cce554ba64fe5f91a0e over the same
# 1,838 cases / 10,579 pairs. That digest prints in the OK line on every run: if
# it moves, the lane compared a different set and the change is wrong — do not
# re-bless it (a moved digest is how a hollow gate looks green; measured once
# already, 271 comparisons reading a stale fixture).
EXTRACTION_GATE_JOBS ?= 8
LIBCX_ART      := vcx/target/$(LIB_NAME).$(if $(filter Darwin,$(shell uname -s)),dylib,so)
LIBCX_CORE_ART := vcx/target/libcx-core.$(if $(filter Darwin,$(shell uname -s)),dylib,so)
.PHONY: test-extraction-gate
# #902 — depends on the SHIPPED library (build-vcx), not build-vcx-dev.
# These gates dlopen $(LIBCX_ART); pinning them to the -prod artifact makes
# "which build is under test" a decision instead of a race, and it is the
# only honest subject for a gate — the dev library is not what ships.
test-extraction-gate: build-vcx
	@$(MAKE) -C vcx build-data-dev
	@mkdir -p vcx/target/extraction_gate
	@$(V) -n -w -cc cc $(CX_GC) -o vcx/target/extraction_gate/probe vcx/tests/runners/extraction_gate/probe/
	@$(V) -n -w -cc cc $(CX_GC) -o vcx/target/extraction_gate/cli_gate vcx/tests/runners/extraction_gate/cli/
	@vcx/target/extraction_gate/probe $(LIBCX_ART) conformance --min-cases=$(EXTRACTION_GATE_FLOOR) > vcx/target/extraction_gate/transcript_monolith.txt
	@vcx/target/extraction_gate/probe $(LIBCX_CORE_ART) conformance --min-cases=$(EXTRACTION_GATE_FLOOR) > vcx/target/extraction_gate/transcript_core.txt
	@cmp vcx/target/extraction_gate/transcript_monolith.txt vcx/target/extraction_gate/transcript_core.txt \
	  && echo "extraction-gate ABI lane OK — libcx-core transcript byte-identical to libcx ($$(wc -c < vcx/target/extraction_gate/transcript_monolith.txt | tr -d ' ') bytes)" \
	  || { echo "extraction-gate ABI lane FAILED — transcripts diverge (see vcx/target/extraction_gate/)"; exit 1; }
	@vcx/target/extraction_gate/cli_gate vcx/target/cx vcx/target/profiles/data/cx conformance --min-cases=$(EXTRACTION_GATE_FLOOR) --jobs=$(EXTRACTION_GATE_JOBS)

# ── ABI GC-LIVENESS GATE (remediation R3.8 discovery) — a dlopen'd libcx
# built with -gc e must actually COLLECT: V only emitted vgc_init() in
# generated main() paths, so shared artifacts ran with gc_enabled=0 —
# unbounded embedder heap growth + a degenerate empty-pool span scan
# (~75x slower large parses through the ABI than in the cx binary).
# The gate churns each artifact past the pacer goal under VGC_GCTRACE=1
# and requires at least one gc cycle. Runs on both Ring artifacts.
# ── address-baseline-gate (#651/#516 stream-2 C9; RULED: L100) — the Tier-2
# byte-identity guard for the ONE-walk retirement. Recomputes every corpus
# def's Tier-2 address and diffs against the recorded baseline
# (vcx/tests/runners/address_baseline/tier2_addresses.txt). A moved or
# vanished address FAILS — no re-bless is available to this stream. Refresh
# the baseline deliberately with `make address-baseline-capture` only when
# NEW corpus defs are added (never to absorb a move).
.PHONY: address-baseline-gate
address-baseline-gate:
	@$(V) $(VFLAGS_VCX) run vcx/tests/runners/address_baseline/address_baseline.v

.PHONY: address-baseline-capture
address-baseline-capture:
	@$(V) $(VFLAGS_VCX) run vcx/tests/runners/address_baseline/address_baseline.v --capture

.PHONY: abi-gc-gate
# #902 — depends on the SHIPPED library (build-vcx), not build-vcx-dev.
# These gates dlopen $(LIBCX_ART); pinning them to the -prod artifact makes
# "which build is under test" a decision instead of a race, and it is the
# only honest subject for a gate — the dev library is not what ships.
abi-gc-gate: build-vcx
	@$(MAKE) -C vcx build-data-dev
	@mkdir -p vcx/target/extraction_gate
	@$(V) -n -w -cc cc $(CX_GC) -o vcx/target/extraction_gate/abi_gc_gate vcx/tests/runners/abi_gc_gate/
	@vcx/target/extraction_gate/abi_gc_gate $(LIBCX_ART)
	@vcx/target/extraction_gate/abi_gc_gate $(LIBCX_CORE_ART)

# ── LIBCX ABI GATE (I3, partition spec §8 freeze direction) — the split
# changes module boundaries, never the export surface. Baseline captured at
# the I3 branch cut (7a38b6a6, `nm -gU` over the dev-shape libcx): 713
# exported symbols = 166 cx_* (the intentional ABI, incl. the two
# cx_iowatch_* C→V callbacks) + vendored C statics (zstd/re2 shim). V does
# NOT export module-mangled internals, so the full-list diff is stable
# across module splits — any diff means the shipped surface moved.
# Darwin-only for now: the baseline is per-platform (Mach-O vs ELF export
# semantics differ); a Linux baseline joins if/when the linux lane runs
# TEST_TARGETS (it builds only today).
.PHONY: libcx-abi-gate
# #888: the gate checks the CX EXPORT SURFACE (cx_*/vgc_*, pinned) and
# HEADER/BINARY AGREEMENT (every include/cx.h entry point is exported).
# Vendored statics (re2/abseil/zstd — 543 symbols, toolchain-vintage
# dependent) are counted as an advisory, never asserted: the old full-nm
# diff went red on any dependency rebuild with no CX change. Symbol names
# are underscore-normalized, so one baseline serves Darwin AND Linux —
# the platform SKIP is retired.
# #902 — depends on the SHIPPED library (build-vcx), not build-vcx-dev.
# These gates dlopen $(LIBCX_ART); pinning them to the -prod artifact makes
# "which build is under test" a decision instead of a race, and it is the
# only honest subject for a gate — the dev library is not what ships.
libcx-abi-gate: build-vcx
	@tools/libcx-abi-gate.sh $(LIBCX_ART)

# ── I4 PROFILE CORPUS GATE (#651/#516, spec §4/§7) — each §4 profile builds
# and passes its ring-tagged corpus: the vcx recipe builds the full profile
# matrix (data/embed/cli; platform = the default build) and runs the
# profile_gate runner at the cli and embed engine compositions with binary
# probes. The data profile's corpus clause is test-extraction-gate (I2).
.PHONY: test-profile-gate
test-profile-gate:
	@$(MAKE) -C vcx test-profile-gate

# ── PER-RING GATE LANES (#700 structural relief, activated at I4) — run the
# lanes that cover the ring you touched instead of the full battery. Each
# lane is a SUPERSET of the ones below it (a Ring-1 change can still break
# Ring 0). These are inner-loop dev lanes; `make test` stays the merge gate.
#   test-ring0 — Ring-0 surfaces: vcx/cx in-module tests, the byte-identity
#                extraction gate, the libcx ABI freeze, the import/tag gates.
#   test-ring1 — + the evaluator: code+platform in-module tests, the §4
#                profile corpus gate (cli/embed compositions over the ring≤1
#                eval corpus), fmt conformance, effect alignment.
#   test-ring2 — + the platform battery: the full V suite (daemons, store,
#                fabric, xap) + conform-all. Near `make test` scope minus
#                the binding/doc/tooling gates.
.PHONY: test-ring0 test-ring1 test-ring2
test-ring0: test-vcx-cx test-extraction-gate libcx-abi-gate ring-import-gate ring-tag-gate gates-manifest-gate
test-ring1: test-ring0 test-vcx-code test-profile-gate check-effect-alignment
	@$(MAKE) -C vcx conform-fmt
test-ring2: test-ring1 test-vcx-suite test-vcx-cxstore test-vcx-cmd
	@$(MAKE) -C vcx conform-all

# ── RING QUERY (corpus audit §2 tagging mechanics; C8 repair, I0) — the
# ring-lane corpus query, dog-food CX. Parameters via env: RING=0|1|2,
# LANE=doc|eval|both, FORMAT=summary|ids|count. `ring-tag-gate` is the
# no-parameter run wired into TEST_TARGETS: it hard-fails (exit 2) when any
# suite header lacks ring= — an untagged suite silently falls out of every
# ring lane, which is exactly how C8's blanket-tag defect went unseen.
.PHONY: ring-query ring-tag-gate
ring-query: CX_BIN ?= $(CURDIR)/vcx/target/cx
ring-query:
	@"$(CX_BIN)" --allow-read --allow-env --allow-write scripts/ring_query.cx
ring-tag-gate: CX_BIN ?= $(CURDIR)/vcx/target/cx
ring-tag-gate: build-vcx
	@FORMAT=count "$(CX_BIN)" --allow-read --allow-env --allow-write scripts/ring_query.cx >/dev/null && echo "ring-tag-gate OK — every suite header carries ring=; lanes queryable via 'make ring-query'"

# Distribution-spec §9 checkable absences (fixture §11.8): the xap-dist engine
# (vcx/code/stdlib_xap_dist.v) composes the store/did/vc/compose surfaces and
# ships NO parallel primitive — no own hashing, no archive format, no
# transport, no second compose gate.
.PHONY: check-xap-dist-absences
check-xap-dist-absences: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-xap-dist-absences:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_xap_dist_absences.cx

# ── Shell-completion drift gate (#423) — the bash/zsh/fish completions in
# tooling/completions/ must mention every subcommand in the vcx/cmd/main.v
# dispatch table (and none it doesn't have), and the `cx diagram` flag surface
# must match vcx/cmd/diagram.v (--format=mermaid|svg|png + -o; the fabricated
# --format=graphviz / --output= / --depth= surface must never reappear).
.PHONY: check-completions-drift
check-completions-drift: CX_BIN ?= $(CURDIR)/vcx/target/cx
check-completions-drift:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_completions_drift.cx

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
#   CX_PKG_DIR=packages/gtin CX_PKG_NAME=gtin CX_PKG_VERSION=0.1.0 \
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
	# Serial pre-build BEFORE the parallel fan-out: every lane's recursive
	# `$(MAKE) build-vcx` then hits the vcx Makefile's up-to-date guard and
	# skips the relink — without this, concurrent sub-makes RELINKED
	# target/cx while sibling lanes were exec'ing it (the v0.16.0 cut's
	# 'Exec format error' / empty-output-rc-0 class; see the guard's note).
	@$(MAKE) build-vcx
	@$(MAKE) -j$(TEST_JOBS) $(OUTPUT_SYNC) $(TEST_TARGETS)

# Sequential fallback — useful for debugging output-order issues, sanitizer
# runs that want low concurrency, or environments where `-j` parallelism
# causes resource contention.
test-no-parallel: $(TEST_TARGETS)

# ── gate 37.10 — code_diagram / code_tree conformance ────────────
# Runs conformance/code_diagram.cxd through `cx code-diagram` and
# `cx code-tree` with structural-equivalence comparison. An all-SKIP
# run FAILS (RULED: PYE-6) and a missing binary is exit 2 — this tree's
# build or CX_BIN, never PATH (#929).
# #774: this checker is the ONLY gate that sees the ERD attribute-type
# rows and the diagram structure (the roundtrip suites in the eval-fixtures
# lane compare trees, not emitted types), and for a long time it was wired
# into NO union target — so a real regression sat green for a whole stream.
# It is in TEST_TARGETS now. CX gate (#922, RULED: PYE-5): the former
# LIBCX_LIB_DIR pin is obsolete — nothing dlopens cxlib any more; the
# gate drives the tree's own cx binary end to end.
.PHONY: test-code-diagram
test-code-diagram: CX_RUNNER ?= $(CURDIR)/vcx/target/cx
test-code-diagram: build-vcx-dev
	@"$(CX_RUNNER)" --allow-read --allow-write --allow-env --allow-subprocess scripts/check_code_diagram_fixtures.cx

# ── gate 28.5a — CXPath / XPath 3.1 alignment, CX side (RULED: VC-7, #945) ─
# The half of the old gate 28.5 that needs no Docker and is real new signal:
# every case in conformance/xpath_31_parity.cxd evaluated by THIS tree's cx and
# graded against an expectation DERIVED from that same binary. Before VC-7 those
# 23 cases had no conformance/gates.cxd row and no lane read them, so they ran
# NOWHERE while the register showed a gate. Normative reference:
# spec/02-working/cxpath_alignment.md. In TEST_TARGETS.
.PHONY: test-xpath-parity-cx
test-xpath-parity-cx: CX_RUNNER ?= $(CURDIR)/vcx/target/cx
test-xpath-parity-cx: build-vcx-dev
	@"$(CX_RUNNER)" --allow-read --allow-write --allow-env --allow-subprocess scripts/check_xpath_parity_fixtures.cx

# ── gate 28.5b — the Saxon-HE cross-check (MANUAL, RULED: VC-7, #945) ─────
# Deliberately NOT in TEST_TARGETS and deliberately NOT automated: it needs
# Docker + network + the third-party saxonica/saxonhe:12 image, so wiring it
# would make `make test` fail or hang on any host without them. It is the only
# implementation-vs-external compliance check in the tree, which is why VC-7
# kept it rather than retiring it. Running it prints the operator recipe and the
# preconditions and exits 2 — it does not "skip cleanly", because a clean skip
# is what let the old breakage sit unexamined for months. The CX side of the
# same corpus is gate 28.5a above and DOES run in every `make test`.
# Full contract: conformance/GATE_REGISTER.md rows 28.5a/28.5b and the header of
# scripts/test_xpath_parity.sh.
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
# Driver architecture: `scripts/compile_binding_api_fixtures.cx` parses
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
#
# #984 — the harness also pins the LIBRARY's version stamp against the built
# artifact. The two derived inputs come from the ONE implementation of the rule
# (vcx/Makefile's CX_VERSION / CX_RELEASE, read back through print-%, the #979
# precedent) rather than being re-derived here; the harness independently
# restates what libcx must then report. --no-print-directory: `make -C`
# otherwise brackets the value with Entering/Leaving lines.
MAKE_PRINT_VCX = $(shell $(MAKE) -s --no-print-directory -C vcx print-$(1) 2>/dev/null | tail -1 | tr -d '[:space:]')
abi-c-test: build-vcx build-lib-arrow
	$(CC) -std=c11 -Wall -Wextra -Werror -g -O1 \
	 -fsanitize=$(ABI_C_TEST_SAN) \
	 -I include -I vcx/arrow \
	 tests/abi/c_abi_test.c \
	 -L vcx/target -lcx -ldl \
	 -o $(ABI_C_TEST_BIN)
	CX_EXPECT_VERSION='$(call MAKE_PRINT_VCX,CX_VERSION)' \
	 CX_EXPECT_RELEASE='$(call MAKE_PRINT_VCX,CX_RELEASE)' \
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

# conform-all now covers EVERY suite in one process (the runner's
# default list was extended at the #795 batch, 2026-08-15 — the
# transparency/chunked/compression/schema/atoms/delimited/yaml/
# conversions suites were previously OUTSIDE every union target, the
# #743-battery unwired-gate class; and the per-suite `conform`
# aggregate fan-out OOM-killed the parallel union with 27 concurrent
# `v run` compiles). The Arrow lane rides its own runner/target.
test-vcx: build-vcx-dev test-vcx-suite test-vcx-code test-vcx-cmd test-vcx-cxstore test-vcx-cx
	$(MAKE) -C vcx conform-all
	$(MAKE) -C vcx conform-fmt
	$(MAKE) -C vcx conform-data-bin-arrow
	# RULED: R5.8 (#860) — the corpus/spec agreement gates run IN THIS LANE now.
	# Both were in TEST_TARGETS but not a test-vcx dependency, so a green full
	# `make test-vcx` never executed them: check-code-spec-consistency sat red
	# from 2026-08-17 (a directive-extractor bug plus an unallowlisted impl
	# anchor) straight through a run recorded as green. A gate in the roster but
	# not in a lane that runs is indistinguishable from no gate.
	$(MAKE) check-code-spec-consistency
	$(MAKE) check-code-fixtures
	# RULED: R6.3 (#832) — spec-freeze-gate runs IN THIS LANE now, wired only
	# after R6.1/R6.2 made it green (R5.8's order). It sat in TEST_TARGETS
	# while 13 violations accumulated across six work streams over three days
	# of green test-vcx runs — the discipline did not decay, the feedback loop
	# was disconnected.
	$(MAKE) spec-freeze-gate

# ── test-vcx-conform (RULED: VC-22) — the conformance aggregates, as their
# OWN lane. `test-vcx` used to be the single TEST_TARGETS row for the whole V
# side: five ring test lanes PLUS these three aggregates. That umbrella made
# ring-precise selection impossible — a change anywhere under vcx/ selected
# all five ring lanes, because the gate could only see one node.
#
# TEST_TARGETS now names the five ring lanes individually, so
# scripts/test_changed.sh can skip the ones a change cannot reach. These three
# aggregates were the ONLY work the old umbrella contributed that no other
# TEST_TARGETS row already carries (check-code-spec-consistency,
# check-code-fixtures and spec-freeze-gate are their own rows), so they get a
# lane rather than being dropped — splitting the umbrella must not narrow the
# release gate by one target.
#
# `test-vcx` itself is UNCHANGED and stays the human entry point: `make
# test-vcx` still runs everything the V side owns in one command.
.PHONY: test-vcx-conform
test-vcx-conform: build-vcx-dev
	$(MAKE) -C vcx conform-all
	$(MAKE) -C vcx conform-fmt
	$(MAKE) -C vcx conform-data-bin-arrow

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
#     proves the artifact — the cache-key root fixes LANDED as #700 wave 2
#     (canonical keys, provenance manifests, inline-vs-linked discipline) and
#     #971 removed the muldefs mask; the retry stays as defense-in-depth
#     until a measured run justifies removing it);
#   • anything else → a real failure, no retry, gate stays red.
#   • code_eval_fixtures_test.v joined 2026-08-23 for the #951 supervise
#     load-race family (sup-011/sup-012: a note/terminal lost or starved
#     only under full-parallel compile storms — measured green 25/25 and
#     80/80 in isolation, red 3× across gates only under -j12 load, root
#     tracked on #951). The serial retry keeps the same honesty contract:
#     a deterministic eval regression re-fails it and the gate stays red.
SUITE_SERIAL_RETRY := vcx/tests/net_udp_read_deadline_test.v \
                      vcx/tests/net_dtls_test.v \
                      vcx/tests/net_real_socket_test.v \
                      vcx/tests/a2a_real_test.v \
                      vcx/tests/code_eval_fixtures_test.v

# The retry ROSTERS above say WHICH lanes get a serial retry. This says WHY,
# PER LANE. The emitted line used to read "serial retry (known real-socket
# contention lane)" for every lane in either roster, which became a false
# statement the moment code_eval_fixtures_test.v joined on 2026-08-23: its cause
# is the #951 supervise note/terminal load-race, and it holds no socket. A log
# line that asserts a single cause for a heterogeneous roster sends whoever
# reads it after a red gate looking in the wrong place.
#
# The default branch is deliberately LOUD rather than a guessed cause: a lane in
# a roster with no declared reason still GETS ITS RETRY — the retry mechanism is
# load-bearing and is not weakened here — but the log says the reason is
# undeclared instead of inventing one.
RETRY_REASON_CASE = case "$$rel" in \
	  vcx/tests/code_eval_fixtures_test.v) \
	    reason="\#951 supervise note/terminal load-race under -j compile storms; green 25/25 and 80/80 in isolation" ;; \
	  vcx/tests/net_udp_read_deadline_test.v|vcx/tests/net_dtls_test.v|vcx/tests/net_real_socket_test.v|vcx/tests/a2a_real_test.v) \
	    reason="real-socket contention: ephemeral-port / deadline race under -j" ;; \
	  vcx/platform/store_admin_plane_test.v|vcx/platform/store_grpc_live_test.v|vcx/platform/store_lazy_load_test.v) \
	    reason="real-socket contention: live store/grpc endpoint under -j (\#648)" ;; \
	  *) \
	    reason="NO REASON DECLARED for this lane -- retried anyway; declare it in RETRY_REASON_CASE in the Makefile" ;; \
	esac

# The cache-free class is NO LONGER A RETRY — it is a DIAGNOSTIC that never
# changes the verdict (#700 wave 2 part ii). It was written when the -usecache
# key was unsound by reputation, so "cache-free green proves the artifact" was
# the best available answer. Part (i) made the key PROVABLY sound
# (make check-vcache-soundness, 16 behavioural probes, red-proven), which
# inverts the conclusion: if a cached build fails where a cache-free build
# passes, the cache produced a failure the soundness gate did not catch. That
# is a gate ESCAPE — the single most valuable signal this tree can emit about
# the cache — and turning it green is how it stays hidden.
#
# This is not hypothetical. 2026-08-25, rolling -usecache onto the first
# NON-TEST binary build surfaced `ld: symbol(s) not found` for
# builtin__closure__closure_init: three mechanisms each assumed the closure
# runtime was inside builtin.o while it was in no object at all (fork fix
# 46f1be51d5, gate probe H11). A verdict-flipping retry on that lane would
# have reported green and the defect would still be in the tree.
#
# So the cache-free run still HAPPENS — it is the classifier, and its outcome
# is the diagnosis — but `st` is never cleared by it:
#   cache-free PASSES  → GATE ESCAPE, loud, red, with the capture recipe;
#   cache-free FAILS   → an ordinary real failure, red.
# The serial-retry (socket / #951) class is untouched and still flips its
# verdict: those lanes hold real sockets and their flakiness is environmental,
# not a statement about compiler correctness.
# NOTE for editors: this is a make VARIABLE, so a bare `#` starts a make
# comment and silently truncates the line it is on (measured while writing
# this: the banner became `GATE ESCAPE (`). Issue numbers here must be
# written `\#700`, the same idiom RETRY_REASON_CASE above uses for `\#951`.
CACHE_ESCAPE_PROBE = \
	echo "──── cache-free DIAGNOSTIC (verdict stays red; classifying): $$rel ────"; \
	if $(V) -cc cc $(CX_GC) $(CX_ENGINES) test "$$rel"; then \
	  echo "════ GATE ESCAPE (\#700): $$rel FAILED under $(CX_CACHE) and PASSES cache-free ════"; \
	  echo "     The module cache produced a failure make check-vcache-soundness does not catch."; \
	  echo "     DO NOT re-run to get green. Capture and file against \#700:"; \
	  echo "       - $$log (the cached failure)"; \
	  echo "       - make check-vcache-soundness   (expect green — that is the point: a hole)"; \
	  echo "       - the failing cc/ld symbols, and the cache namespace for this lane"; \
	  echo "     Then add a probe to scripts/vcache_soundness_gate.sh that goes RED on it."; \
	else \
	  echo "──── real failure, not a cache artifact (fails cache-free too): $$rel ────"; \
	fi; \
	st=1

# A retry roster is matched against the lane paths the suite REPORTS, so a
# row naming a file that no longer exists matches nothing and silently
# disables its retry class — the class stops applying and the gate looks
# unchanged. That is the vacuous-gate failure mode, and here it would
# disable the mitigation currently absorbing the #951 supervise load-race.
# Consolidation (#700) deletes lane files by design, so this is now a live
# hazard rather than a theoretical one: assert every roster row exists,
# before the suite runs.
.PHONY: check-serial-retry-rosters
check-serial-retry-rosters:
	@missing=""; \
	for t in $(SUITE_SERIAL_RETRY) $(CODE_SERIAL_RETRY); do \
	  [ -f "$$t" ] || missing="$$missing $$t"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "check-serial-retry-rosters: retry roster names file(s) that do not exist —"; \
	  echo "  a row matching no lane silently disables its retry class:"; \
	  for t in $$missing; do echo "    $$t"; done; \
	  echo "  fix the roster in Makefile (SUITE_SERIAL_RETRY / CODE_SERIAL_RETRY)."; \
	  exit 1; \
	fi; \
	echo "check-serial-retry-rosters OK — every retry-roster row names an existing lane"

test-vcx-suite: build-vcx-dev check-serial-retry-rosters
	@rm -f $(CX_SKIP_LOG)
	@log=vcx/target/test-suite-run.log; stf=vcx/target/test-suite-status; \
	{ $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test vcx/tests/ 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  failed=$$(grep -aE '^FAIL ' $$log | grep -aoE '[^ ]+_test\.v$$' | sort -u); \
	  want=$$(grep -aE '^Summary for all V _test\.v files: [0-9]+ failed,' $$log | tail -1 | sed -E 's/[^0-9]*([0-9]+) failed.*/\1/'); \
	  have=$$(printf '%s\n' $$failed | grep -c '_test\.v$$' || true); \
	  if [ -n "$$want" ] && [ "$$have" -ne "$$want" ]; then \
	    echo "retry classifier: extracted $$have failed lane(s) but the suite summary says $$want — refusing the partial retry roster (binary-log suppression class)"; \
	    exit 1; \
	  fi; \
	  if [ -n "$$failed" ]; then \
	    st=0; \
	    for t in $$failed; do \
	      rel=$${t#$(CURDIR)/}; \
	      case " $(SUITE_SERIAL_RETRY) " in \
	        *" $$rel "*) \
	          $(RETRY_REASON_CASE); \
	          echo "──── serial retry ($$reason): $$rel ────"; \
	          $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test "$$rel" || st=1 ;; \
	        *) \
	          if grep -aq 'C compilation error' $$log; then \
	            $(CACHE_ESCAPE_PROBE); \
	          else \
	            echo "──── real failure (no retry class applies): $$rel ────"; st=1; \
	          fi ;; \
	      esac; \
	    done; \
	    if [ $$st -eq 0 ]; then \
	      echo "──── every failed lane green on its classified SERIAL retry (socket / #951 load-race lanes) ────"; \
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
#
# Same classified-retry contract as test-vcx-suite (#648: this target had NO
# retry class, so a live-socket lane flaking under -j parallel load failed the
# umbrella with no re-run — store_admin_plane_test.v, repeatedly green in
# isolation, is the proven case).
#
# store_grpc_parity_test.v was dropped from this roster 2026-08-24: the file
# has not existed since abaea9b9b retired the CSRP data plane, so the row
# matched no lane and was doing nothing. check-serial-retry-rosters (below)
# is what found it, and is what stops the next one.
CODE_SERIAL_RETRY := vcx/platform/store_admin_plane_test.v \
                     vcx/platform/store_grpc_live_test.v \
                     vcx/platform/store_lazy_load_test.v

# I3 module split (#651/#516): the in-module tests now live in TWO
# modules — vcx/code (Ring 1) and vcx/platform (Ring 2, where the
# store/journal/grpc/service subjects moved). One lane runs both.
.PHONY: test-vcx-code
test-vcx-code: build-vcx-dev check-serial-retry-rosters
	@log=vcx/target/test-code-run.log; stf=vcx/target/test-code-status; \
	{ $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test vcx/code/ vcx/platform/ 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  failed=$$(grep -aE '^FAIL ' $$log | grep -aoE '[^ ]+_test\.v$$' | sort -u); \
	  want=$$(grep -aE '^Summary for all V _test\.v files: [0-9]+ failed,' $$log | tail -1 | sed -E 's/[^0-9]*([0-9]+) failed.*/\1/'); \
	  have=$$(printf '%s\n' $$failed | grep -c '_test\.v$$' || true); \
	  if [ -n "$$want" ] && [ "$$have" -ne "$$want" ]; then \
	    echo "retry classifier: extracted $$have failed lane(s) but the suite summary says $$want — refusing the partial retry roster (binary-log suppression class)"; \
	    exit 1; \
	  fi; \
	  if [ -n "$$failed" ]; then \
	    st=0; \
	    for t in $$failed; do \
	      rel=$${t#$(CURDIR)/}; \
	      case " $(CODE_SERIAL_RETRY) " in \
	        *" $$rel "*) \
	          $(RETRY_REASON_CASE); \
	          echo "──── serial retry ($$reason): $$rel ────"; \
	          $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test "$$rel" || st=1 ;; \
	        *) \
	          if grep -aq 'C compilation error' $$log; then \
	            $(CACHE_ESCAPE_PROBE); \
	          else \
	            echo "──── real failure (no retry class applies): $$rel ────"; st=1; \
	          fi ;; \
	      esac; \
	    done; \
	    if [ $$st -eq 0 ]; then \
	      echo "──── every failed lane green on its classified SERIAL retry (socket / #951 load-race lanes) ────"; \
	    fi; \
	  fi; \
	fi; exit $$st

# White-box unit tests for the `cxstore` module (vcx/cxstore/*_test.v) — the
# content-addressed object store internals (pack/seqtree/bloom/index/gc/reflog/
# repo/planner/retention/mmap/compression + the cx adapter + round-trip). Like
# test-vcx-code, `v test` only runs the directory it is given, so neither
# vcx/tests/ nor vcx/code/ pulls these in; this dedicated target wires the
# cxstore in-module suite into the gate (same default -gc e memory model).
# (The dead `cxsqlite/` subdir this glob used to dodge was deleted at I2 —
# the live sqlite store backend is vcx/code/store_sqlite_d_cxstore_sqlite.v.)
.PHONY: test-vcx-cxstore
test-vcx-cxstore: build-vcx-dev
	@$(V) -cc cc $(CX_GC) test vcx/cxstore/*_test.v

# White-box unit tests INSIDE the Ring-0 `cx` module (vcx/cx/*_test.v) plus
# the `fixtures` test-support module (vcx/fixtures/ — the corpus loader,
# moved out of shipped libcx at I2). These lanes ran NOWHERE before I2:
# `v test` only runs the directory it is given, and no target named vcx/cx —
# five in-module tests sat outside every gate (found wiring this lane).
# Files are listed explicitly, not the directory glob:
# vcx/cx/parser_multidoc_test.v is EXCLUDED — it segfaults under the shipped
# `-gc e` model (module-internal-test-only RC double-free of the multi-doc
# Document tree; production paths and external-linkage tests are green).
# That exclusion is #737; delete the list and glob the directory when it
# closes.
.PHONY: test-vcx-cx
test-vcx-cx: build-vcx-dev
	@$(V) -cc cc $(CX_GC) test vcx/cx/anchor_resolve_test.v vcx/cx/atom_test.v vcx/cx/token_golden_test.v vcx/cx/version_stamp_test.v
	@$(V) -cc cc $(CX_GC) test vcx/fixtures/

# White-box unit tests that live INSIDE the CLI module (vcx/cmd/*_test.v) —
# they assert on the cmd module's own constants (e.g. the `cx scaffold`
# templates, #306/#448) that neither vcx/tests/ nor vcx/code/ can import.
# `v test` only runs the directory it is given, so without this target the
# cmd suite had NO gate consumer (#448 wired it in).
.PHONY: test-vcx-cmd
# -d cx_platform: the cmd lane tests the DEFAULT (platform-profile) shape —
# the shipped binary's composition (I4; a bare cmd/ compile is the cli
# profile, where CX_ENGINES would be inert).
# Same cache-free DIAGNOSTIC as test-vcx-suite/test-vcx-code (see
# CACHE_ESCAPE_PROBE above): this is the ONLY vcx test lane besides those that
# runs -usecache ($(CX_CACHE)). A cached-only C-compile/link failure is now a
# GATE ESCAPE against the proven key, reported red with the capture recipe —
# not retried to green. The historical case this lane recorded (a fresh symbol
# added to code/ while the cmd lane reused a pre-change cached object, the S6.3
# pushdown symbols) is precisely a provenance failure that part (i)'s manifests
# now make impossible, and if it recurs the gate needs a probe, not a retry.
test-vcx-cmd: build-vcx-dev
	@log=vcx/target/test-cmd-run.log; stf=vcx/target/test-cmd-status; \
	{ $(V) -cc cc $(CX_GC) -d cx_platform $(CX_ENGINES) $(CX_CACHE) test vcx/cmd/ 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  if grep -aqE 'C compilation error|linker command failed|symbol\(s\) not found|duplicate symbol' $$log; then \
	    echo "──── cache-free DIAGNOSTIC (verdict stays red; classifying): vcx/cmd ────"; \
	    if $(V) -cc cc $(CX_GC) -d cx_platform $(CX_ENGINES) test vcx/cmd/; then \
	      echo "════ GATE ESCAPE (#700): vcx/cmd FAILED under $(CX_CACHE) and PASSES cache-free ════"; \
	      echo "     The module cache produced a failure make check-vcache-soundness does not catch."; \
	      echo "     DO NOT re-run to get green. Capture $$log + the gate output + the failing"; \
	      echo "     symbols, file against #700, and add a RED-going probe to"; \
	      echo "     scripts/vcache_soundness_gate.sh."; \
	    else \
	      echo "──── real failure, not a cache artifact (fails cache-free too): vcx/cmd ────"; \
	    fi; \
	  fi; \
	fi; \
	exit $$st

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
	@if ! PKG_CONFIG_PATH="$(COLUMNAR_ARROW_PKGCONFIG):$$PKG_CONFIG_PATH" pkg-config --exists arrow parquet 2>/dev/null; then \
	  line="SKIP test-vcx-columnar: Apache Arrow/Parquet not discoverable via pkg-config (absent prerequisite, #318 — brew install apache-arrow / apt libarrow-dev libparquet-dev)"; \
	  echo "$$line"; mkdir -p vcx/target; echo "$$line" >> $(CX_SKIP_LOG); \
	else \
	  $(MAKE) -C vcx arrow-shim && \
	  PKG_CONFIG_PATH="$(COLUMNAR_ARROW_PKGCONFIG):$$PKG_CONFIG_PATH" $(V) -cc cc -enable-globals $(CX_GC) -d cxstore_columnar -d cx_arrow_files test vcx/platform/store_columnar_test.v vcx/platform/store_columnar_lineage_test.v; \
	fi

# ── sqlite [$store] backend gate — #77 / #220 (concurrent-writer durability) ──
# The sqlite:// store backend lives behind `-d cxstore_sqlite` (links libsqlite3).
# It runs the gated in-module suite — the round-trip/dedup/integrity tests plus
# the #220 concurrent-writer stress (32-wide burst through the daemon dispatch
# path → no crash, cold reopen intact). On macOS the system libsqlite3 ships no
# headers, so they come from Homebrew sqlite.
#
# IN TEST_TARGETS since #989. It was held out on the reasoning that `make test`
# must stay green on a box without sqlite headers — but 41f44e97c then landed
# #891's shared-open protection behind a lane no gate ran, so the protection
# could rot without anything noticing, which is the cost the exclusion was
# actually buying. The header worry is answered the way #318 answers it for
# test-vcx-columnar, three targets up: PROBE the prerequisite and SELF-SKIP with
# a named reason into $(CX_SKIP_LOG) when it is absent (skips are counted
# separately and printed loudly — never silently, never as failures). A box with
# sqlite runs the lane; a box without says so out loud.
#
# GATE-DURATION EVIDENCE (#700 dead-ends register — a lane may not join the ring
# on assertion; ledger/dead_ends_700_test_duration.md). MEASURED on the
# reference machine, this recipe's own `v test` (the build-vcx-dev prerequisite
# is shared with every other vcx lane, so it is not marginal cost), 3/3 green on
# every run:
#
#   cold caches, contended    231.1 s elapsed | comptime 674.9 CPU-s | runtime 1.6 s
#   warm, uncontended          38.1 s elapsed | comptime 108.7 CPU-s | runtime 4.4 s
#   THIS recipe at HEAD,
#   after a full build-dev      73.7 s elapsed | comptime 218.1 CPU-s | runtime 1.2 s
#
# The third row is the one to budget against — the shape a gate run actually
# sees, and it reproduced within 3% across a rebase (75.8 s / 224.0 CPU-s on the
# earlier base). Sized the way the register's POST-CLOSE ADDENDUM requires: by
# CPU, not by serial length. The gate is THROUGHPUT-bound (1,154 s wall x 12
# cores against 182 CPU-min is ~9.5x parallelism, already near the 15.2-min CPU
# floor), so a lane's own duration is NOT its cost — its CPU-min is. This lane
# adds 3.6 CPU-min (+2.0% of 182), projecting to ~+23 s of gate wall; the warm
# and cold extremes bracket that at +1.0% and +6.2%.
#
# The estimate in #989 ("seconds") was low by 6-60x, and the reason is worth
# recording: the RUNTIME is milliseconds (1.2-4.4 s for all three suites), but V
# recompiles the whole platform module once per test FILE, so the lane is ~99%
# compile. A lane's runtime is not its gate cost.
#
# What it buys: the ONLY gate coverage of the sqlite backend, including #891's
# shared-open protection and the #220 concurrent-writer durability contract.
# Before this the alternative was not a cheaper lane, it was no coverage.
ifeq ($(UNAME_S),Darwin)
  SQLITE_CFLAGS := -I/opt/homebrew/opt/sqlite/include
  SQLITE_LDFLAGS := -L/opt/homebrew/opt/sqlite/lib
  SQLITE_PKGCONFIG := /opt/homebrew/opt/sqlite/lib/pkgconfig
else
  SQLITE_CFLAGS :=
  SQLITE_LDFLAGS :=
  SQLITE_PKGCONFIG :=
endif
.PHONY: test-vcx-sqlite
test-vcx-sqlite: build-vcx-dev
	@if ! PKG_CONFIG_PATH="$(SQLITE_PKGCONFIG):$$PKG_CONFIG_PATH" pkg-config --exists sqlite3 2>/dev/null; then \
	  line="SKIP test-vcx-sqlite: libsqlite3 development headers not discoverable via pkg-config (absent prerequisite, #318 — brew install sqlite / apt libsqlite3-dev)"; \
	  echo "$$line"; mkdir -p vcx/target; echo "$$line" >> $(CX_SKIP_LOG); \
	else \
	  $(V) -cc cc $(CX_GC) -d cxstore_sqlite -cflags "$(SQLITE_CFLAGS)" -ldflags "$(SQLITE_LDFLAGS)" test vcx/platform/store_sqlite_test.v vcx/platform/store_sqlite_encryption_test.v vcx/platform/store_concurrent_writer_test.v; \
	fi

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

# #743 INTERIM (documented, never silent): a dylib collection inside a
# Go host can hang the STW ack-wait forever. 2026-08-14 finding: this is
# NOT specific to SIGURG (the original report's theory) — a SIGXCPU
# default was battery-green on pure-V soundness yet the Go-host hang
# REPRODUCED under it (run 3 of 5, ~70min ack-wait spin; the Go runtime
# intercepts/forwards signals generally). Only a signal-free suspend
# path (the mach direction on #743) can clear the class. Until then the
# Go lanes pin the pacer headroom high (VGC_NEXT_GC_MB) so no collection
# triggers in these SHORT-LIVED test processes.
test-go: build-go
	cd lang/go/cxlib && VGC_NEXT_GC_MB=65536 $(GO) test ./...
	cd lang/go/conformance && VGC_NEXT_GC_MB=65536 $(GO) run .

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

bench: CX_BIN ?= $(CURDIR)/vcx/target/cx
bench: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-clock \
	   --allow-env bench_report.cx

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
# pipeline/arrow operators, ?match, regex via RE2, range).
# Output is parsed by scripts/run_bench_json.cx into the
# T1.* benchmark keys for the V7 perf regression gate.
bench-eval: build-vcx
	v run vcx/tests/runners/eval_features_bench.v

# ── v0.8.0 §11.6 release-gate harnesses ────────────────────────────────────────
#
# Each target runs one of the three perf gates blocking the v0.8.0 tag
# (conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded), spec/code.md §11.4.4). Exit code
# is 0 on PASS, non-zero on FAIL; CI consumes the gate verdict line.
# The benches print their threshold + measured numbers so PASS/FAIL is
# self-evident in logs. Env knobs documented in each .v file header.

# Gate 14 — pattern compilation (depth-8, 32-binding pattern):
# p99 parse-time MUST be ≤ 1 ms.
#
# `-prod` is load-bearing here for the same reason it is on gate 15 (#804,
# #835): the recipe depends on `build-vcx`, which builds the SHIPPED artifacts
# optimised — but the bench links the evaluator as V SOURCE and compiles it
# fresh, so without `-prod` the gate measured an unoptimised build of the very
# code under test. Measured on gate 15's corpus, the same shape of workload:
# 2.6 MB/s unoptimised vs 13.3 optimised, a 5.1x measurement error. Both gates
# passed either way, so this only ever moved them in the passing direction —
# but a gate that measures a build CX does not ship is not measuring the
# threshold it claims to.
bench-code-pattern-compile: build-vcx
	$(PATCHED_V) -enable-globals -prod run vcx/tests/runners/code_pattern_compile_bench.v

# Gate 15 — streaming throughput on JSON-shape workloads:
# mean MUST be ≥ 200 MB/s + no trial below 80 % of mean.
#
# `-prod` is load-bearing, not decoration (#804). The recipe depends on
# `build-vcx`, which builds the SHIPPED artifacts optimised — but the bench
# links the evaluator as V SOURCE and compiles it fresh, so without `-prod`
# the gate measured an unoptimised build of the engine, which is not the
# artifact CX ships. Same corpus, same program, same threshold: 2.6 MB/s
# unoptimised vs 13.3 MB/s optimised. A perf gate has to measure the build
# under test; this is a measurement repair, and the §11.4.4 floor is
# untouched by it.
bench-code-streaming: build-vcx
	$(PATCHED_V) -enable-globals -prod run vcx/tests/runners/code_streaming_throughput_bench.v

# #804 leg-2 CEILING probe — not a gate, a decision instrument. Walks the
# gate-15 corpus doing only what a never-forced lazy record would do
# (scan the child, write its canonical image) and reports the upper bound
# any forcing discipline can reach. Answers, before the code is written,
# whether leg 2's architecture can clear the §11.4.4 floor at all. Re-run
# it when leg 2 lands: the real number must sit under this ceiling, and
# how far under is the discipline's measured cost.
bench-lazy-ceiling: build-vcx
	$(PATCHED_V) -enable-globals -prod run vcx/tests/runners/lazy_record_ceiling_probe.v

# #804 leg-9 ALLOCATION CENSUS — the instrument that answers "what generates
# the garbage", which sampling cannot. `sample` attributes CPU; collection work
# is triggered by allocation VOLUME but paid at whatever safepoint the mutator
# next reaches, so a call tree charges it to whoever polled rather than to
# whoever produced it. This meters bytes directly (vgc's monotone
# `gc_total_allocated`) across a ladder of rungs that each stop one stage
# earlier, so consecutive differences are one stage's allocation.
#
# It exists because leg 8 assumed a removed allocation would compound through
# the collector and it did not. Run it BEFORE choosing the next optimisation,
# and again after, with the same rung. Not a gate — a decision instrument.
#
# One rung per process (`LEG9_SHAPES=<name>`): three rungs in one process
# pollute each other's heap state and the jitter reads 45-70% of mean instead
# of ~90%. `LEG9_INPUT_MB` defaults to 64 — do not lower it below 16 or vgc's
# 1 MiB accounting flush swamps the reading (the probe says so itself).
bench-streamed-alloc: build-vcx
	$(PATCHED_V) -enable-globals -prod run vcx/tests/runners/streamed_for_alloc_probe.v

# Gate 16 — HTTP service throughput (in-process substrate per §1.2):
# mean MUST be ≥ 10K req/s AND p99 ≤ 10 ms.
#
# `-prod` is load-bearing here for the same reason it is on gate 15 (#804,
# #835): the recipe depends on `build-vcx`, which builds the SHIPPED artifacts
# optimised — but the bench links the evaluator as V SOURCE and compiles it
# fresh, so without `-prod` the gate measured an unoptimised build of the very
# code under test. Measured on gate 15's corpus, the same shape of workload:
# 2.6 MB/s unoptimised vs 13.3 optimised, a 5.1x measurement error. Both gates
# passed either way, so this only ever moved them in the passing direction —
# but a gate that measures a build CX does not ship is not measuring the
# threshold it claims to.
bench-code-http: build-vcx
	$(PATCHED_V) -enable-globals -prod run vcx/tests/runners/code_http_throughput_bench.v

# HTTP backend-direction isolation bench — settles whether the ~10k
# req/s ceiling is transport-bound (net.http socket stack) or
# interpreter-bound (code.eval + env.clone) before any backend rewrite.
# Two-point: in-process code.eval leg vs real net.http listener on :0
# with a trivial no-op handler. Prints a ratio + verdict, no PASS/FAIL.
#
# `-prod` for the #835 reason, and it matters MORE here than on a pass/fail
# gate: this bench exists to decide whether the ~10k req/s ceiling is
# transport-bound or interpreter-bound, and an unoptimised build inflates the
# INTERPRETER leg specifically — so the unoptimised verdict is biased toward
# the answer the bench is supposed to test for.
bench-code-http-isolation: build-vcx
	$(PATCHED_V) -enable-globals -prod run vcx/tests/runners/code_http_isolation_bench.v

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

# abi.md §4 performance-budget driver (#805/AF-6 — the table's FIRST
# measuring artifact). In-process ABI-call timing, full call semantics;
# budgets verbatim from the spec, never trued; exit 1 on any red cell.
# First honest verdict (2026-08-13): six conversion cells RED at
# 7.9-16.7x over budget (the #804 engine ceiling extends here);
# cx_events_next PASS at ~9 ns/event. 100 MB tier opt-in: ABI_S4_100MB=1.
bench-abi-s4: build-vcx
	$(PATCHED_V) -enable-globals run vcx/tests/runners/abi_s4_bench.v

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
# conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded).

# ── Gate 5 — resilience composition matrix ────────────────────────────────
# Drives the 67 resilience fixtures in conformance/code.txt (31 single-
# directive + 36 composition matrix) via vcx/tests/code_eval_fixtures_test.v
# whose `supported_fixtures` whitelist covers all 67. The fixture runner
# parses each block, evaluates in_code with $doc bound, and compares the
# rendered result against out_text. Asserts at runtime that at least one
# fixture executed. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 5.
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
# conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 6.
.PHONY: test-vcx-services
test-vcx-services: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_eval_fixtures_test.v

# ── Gate 9 — diagram round-trip (SVG / PNG / Mermaid) ─────────────────────
# Diagram round-trip coverage already lives under `test-code-diagram`
# (drives conformance/code_diagram.txt through cx_code_diagram +
# cx_code_tree with structural-equivalence — 29/29
# fixtures). This target is the §11.6-named alias plus the V-side
# diagram unit tests that exercise the emitter + round-trip directly.
# Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 9.
.PHONY: test-vcx-diagram-roundtrip
test-vcx-diagram-roundtrip: build-vcx
	$(MAKE) test-code-diagram
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_diagram_roundtrip_test.v \
		vcx/tests/code_units_umbrella_test.v

# ── Gate 12 — reference renderer (CLI + web + LSP) ────────────────────────
# Drives the V-side renderer test suite — `code_render_test.v` covers
# the production code renderer (vcx/code/render.v: body-quote selection,
# attribute serialisation, scalar typing, directive shape, structural
# vs. text round-trips); `path_renderer_test.v` covers the
# PathNode → source emitter introduced for the CXPath value kind. LSP CodeLens
# tests are not yet authored; this target tracks the V-side renderer
# coverage. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 12.
.PHONY: test-renderer
test-renderer: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/code_units_umbrella_test.v \
		vcx/tests/parser_units_umbrella_test.v

# ── Gate 28.7 — CXPath axis coverage (all 12 axes) ────────────────────────
# Drives the V-side per-axis test files: forward axes (21 tests:
# child / descendant / descendant-or-self / following-sibling / following
# / attribute / self / parent), reverse axes (17 tests: ancestor /
# ancestor-or-self / preceding-sibling / preceding), misc/expression
# scaffolding (21 tests: predicates, unions, integer-literal predicate,
# attribute-axis short-form), and dispatcher integration (3 tests:
# `[?find …/axis::…]` end-to-end). 62 tests total exercising the
# 12-axis vocabulary. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 28.7.
# (test-cxpath-axis-coverage RETIRED at the #795 batch, 2026-08-15 — its
# files died with the placeholder axis engine at the #805 sweep; see
# vcx/Makefile's conform-ns-cxpath retirement note.)

# ── Gate 28.8 — [?modify] action coverage (all 11 actions) ────────────────
# Drives the V-side modify test files: `modify_eval_test.v` covers
# the structural evaluator with one positive case per
# action (:set / :delete / :using / :rename / :set-attr / :delete-attr /
# :append / :prepend / :insert-before / :insert-after / :replace) plus
# action-chain semantics, focus-miss-skip-not-error, pure-functional
# invariant, multi-match focus, and Z79g path-aware dispatcher hop;
# `modify_node_test.v` + `_codec_test.v` cover the ModifyNode shape
# + binary codec round-trip; `modify_parser_test.v` covers the
# `[?modify]` directive parser. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate
# 28.8 (structural-sharing perf budget lives at gate 30.5).
.PHONY: test-modify-action-coverage
test-modify-action-coverage: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test vcx/tests/eval_semantics_umbrella_test.v \
		vcx/tests/node_units_umbrella_test.v \
		vcx/tests/modify_node_codec_test.v

# ── Gate 30.5 — [?modify] structural-sharing perf budget ──────────────────
# Drives vcx/tests/runners/code_modify_sharing_bench.v — single-match
# `:set` heap delta + 1000-match `:set-attr` heap delta + identity-hash
# invariant. Budget: < 1 KB new heap per matched node on
# 10 MB doc. v0.8.0 ships with sharing-ratio + identity invariants
# enforced; the absolute-byte budgets are ADVISORY per the bench
# header's Element + Attribute diet analysis (post-diet residual cost
# is spine-frame overhead that closes to v0.9.0+ with HAMT-backed
# items containers). Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 30.5.
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

## test-oriel-lane  ORIEL, the reference XAP, as its own CI lane (#869): boot
##                  the store at spec/03-approved/xap/demos/oriel/, run the
##                  five asserting instruments (drive 38, keys 9, voice,
##                  nokernel, diff drift=0), tear down. bench stays
##                  measured-not-asserted. Refuses if :8790 is already served.
.PHONY: test-oriel-lane
test-oriel-lane: build-vcx
	@bash scripts/oriel_lane.sh
