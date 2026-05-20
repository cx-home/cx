# ── v0.7.0 doc pipeline ───────────────────────────────────────── BEGIN gen_docs
# Auto-managed include: makes `make docs`, `make site`, `make docs-publish`,
# etc. first-class targets. Generated layer — regenerate via the
# cx-docs-author skill if/when scaffolding moves. Remove the stanza between
# BEGIN gen_docs and END gen_docs to detach the doc pipeline.
-include scripts/gen_docs/docs.mk
# ── v0.7.0 doc pipeline ─────────────────────────────────────────── END gen_docs

CONFORMANCE_CORE := conformance/core.txt
CONFORMANCE_EXT := conformance/extended.txt
CONFORMANCE_XML := conformance/xml.txt
CONFORMANCE_MD := conformance/md.txt
CONFORMANCE_EVAL := conformance/eval.txt

LIB_NAME := libcx
VCX_DYLIB := vcx/target/$(LIB_NAME).dylib
VCX_SO := vcx/target/$(LIB_NAME).so
DIST_DIR := dist
PREFIX ?= /usr/local

UNAME_S := $(shell uname -s)

# ── Python / Ruby / Go / TypeScript / Java / Kotlin / C# / Swift toolchain paths ──────
PYTHON ?= python3
RUBY := /opt/homebrew/opt/ruby/bin/ruby
SWIFT := /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
SWIFT_FLAGS := SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DOTNET := DOTNET_ROOT=/opt/homebrew/opt/dotnet/libexec /opt/homebrew/opt/dotnet/libexec/dotnet
JAVA_HOME_ARM64 := /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

.PHONY: all build build-vcx build-lib build-lib-arrow build-rust build-rust-arrow \
 build-ruby build-go build-go-arrow build-typescript build-java build-java-arrow build-kotlin build-kotlin-arrow build-csharp build-csharp-api build-csharp-arrow build-swift \
 build-vscode \
 publish publish-push \
 publish-v publish-v-push \
 publish-org \
 release release-v release-all \
 dist install uninstall install-cli uninstall-cli verify-cli promote-cli \
 test test-no-parallel test-python test-python-arrow test-vcx test-rust test-rust-arrow \
 test-ruby test-ruby-api test-go test-go-arrow test-typescript test-java test-java-arrow test-kotlin test-kotlin-arrow test-csharp test-csharp-api test-csharp-arrow test-swift \
 test-python-api test-python-stream test-v test-vcx-api test-vcx-stream test-typescript-api test-go-api \
 abi-c-test \
 conform conform-vcx conform-md bench bench-python \
 examples example-python example-v example-go example-rust example-typescript \
 example-java example-kotlin example-csharp example-ruby example-swift \
 demos demo-v demo-go demo-rust demo-typescript demo-java demo-kotlin demo-csharp demo-ruby demo-swift \
 clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

# Active binding set per ADR 0022 §D4 — V + Python + Go + Rust + TypeScript.
# Python has no compile step. Frozen bindings (Java/Kotlin/C#/Ruby/Swift)
# are still buildable via their individual targets but excluded from
# the default `build` so the v0.7.0 ABI rename doesn't make `make`
# error out of the gate. See lang/<binding>/FROZEN.md for rationale.
build: build-vcx build-rust build-go build-typescript

build-vcx:
	$(MAKE) -C vcx build

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

build-ruby: build-vcx
	@echo "Ruby binding: no compile step needed"

build-go: build-vcx
	cd lang/go/cxlib && go build ./...

# Arrow C-Data Go binding (Phase 7.74c-cont-bindings-multi-go,
# spec/abi.md §2.11). Gated behind `-tags arrow` so the default
# `build-go` does not require the apache/arrow/go module.
build-go-arrow: build-vcx build-lib-arrow
	cd lang/go/cxlib && go build -tags arrow ./...

build-typescript: build-vcx
	cd lang/typescript/cxlib && npm install --silent && npm run build

build-java: build-vcx
	mvn -f lang/java/cxlib/pom.xml -q package -DskipTests

# Apache Arrow C-Data interop binding — gated behind libcx_arrow + the
# `arrow` Maven profile (pulls arrow-c-data / arrow-vector / arrow-memory-netty).
# Mirrors test-go-arrow / test-rust-arrow / test-csharp-arrow
# (Phase 7.74c-cont-bindings-multi-java).
build-java-arrow: build-vcx build-lib-arrow
	mvn -f lang/java/cxlib/pom.xml -q -Parrow package -DskipTests

build-kotlin: build-vcx
	cd lang/kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle assemble -q

# Apache Arrow C-Data interop binding — gated behind libcx_arrow + the
# `arrow` Gradle source-set (pulls arrow-c-data / arrow-vector /
# arrow-memory-netty). Mirrors test-go-arrow / test-rust-arrow /
# test-csharp-arrow / test-java-arrow
# (Phase 7.74c-cont-bindings-multi-kotlin).
build-kotlin-arrow: build-vcx build-lib-arrow
	cd lang/kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle compileArrowKotlin -q

build-csharp: build-vcx
	$(DOTNET) build lang/csharp/cxlib/cxlib.csproj -c Release --nologo -v:m

build-csharp-api: build-csharp
	$(DOTNET) build lang/csharp/api_test/api_test.csproj -c Release --nologo -v:m

# Apache Arrow C-Data interop binding — gated behind libcx_arrow + the
# Apache.Arrow NuGet package; mirrors test-go-arrow / test-rust-arrow
# (Phase 7.74c-cont-bindings-multi-csharp).
build-csharp-arrow: build-vcx build-lib-arrow
	$(DOTNET) build lang/csharp/cxlib_arrow/cxlib_arrow.csproj -c Release --nologo -v:m

build-swift: build-vcx
	$(SWIFT_FLAGS) $(SWIFT) build --package-path lang/swift/cxlib -c release

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

# V3 — conformance fixture coverage gate. Validates that
# conformance/eval.txt is structurally sound, meets the v0.7.0
# minimum fixture count, and tags every required v0.7.0 surface.
check-conformance-coverage:
	@python3 scripts/check_conformance_coverage.py

# V2 — upstream V patch tracking. Reports status of the vlang/v
# issues that block cx v0.7.0 per ADR 0022 §D7. Exit non-zero only
# on a closed-unfixed (upstream-rejected) outcome.
check-v-upstream:
	@python3 scripts/check_v_upstream_patches.py

# V6 — pre-commit lint rules over .cx / .cxl files. Catches the
# pre-ADR-0017 syntax forms the v0.7.0 parser rejects, plus the
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
# Active binding set per ADR 0022 §D4 — V + Python + Go + Rust + TypeScript.
# Frozen bindings (Java/Kotlin/C#/Ruby/Swift) retain their `test-<lang>`
# targets for ad-hoc / re-promotion use but are not run by default `test`.
TEST_TARGETS := abi-c-test test-python test-vcx test-v test-rust test-go test-typescript

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

test-python: build-vcx
	$(PYTHON) lang/python/conformance.py
	$(PYTHON) lang/python/test_api.py
	$(PYTHON) lang/python/test_stream.py
	$(PYTHON) lang/python/test_cxpath.py
	$(PYTHON) lang/python/test_transform.py
	$(PYTHON) lang/python/test_immutability.py
	$(PYTHON) lang/python/test_data_bin_one_shots.py
	$(PYTHON) lang/python/test_namespaces.py
	$(PYTHON) lang/python/test_identity.py
	$(PYTHON) lang/python/test_id_abi.py
	$(PYTHON) lang/python/test_delimited.py

# Apache Arrow C-Data interop tests (Phase 7.74c-cont-bindings).
# Skip-cleanly if pyarrow is not installed; otherwise builds libcx_arrow
# and exercises the full 9-type round-trip surface. Install the optional
# dep with `pip install pyarrow` (or `pip install lang/python[arrow]`).
test-python-arrow: build-vcx build-lib-arrow
	$(PYTHON) lang/python/test_arrow.py

# Arrow conformance — runs the canonical conformance/data_bin_arrow.txt
# fixtures through the Python binding. Cross-binding parity (W3 / W9)
# means each active binding will have an equivalent runner over the
# same fixture file. Per spec/v0_7_0_status.md W3.
test-python-arrow-conformance: build-vcx build-lib-arrow
	$(PYTHON) -m unittest lang.python.test_arrow_conformance -v

# Per spec/v0_7_0_status.md H2 — exercise the new v0.7.0 evaluator
# surface through the Python binding (cross-binding parity check
# against V conformance/eval.txt). 18 tests covering ?let, FLWOR,
# ?fn + apply, ?partial w/ [?_], ?try multi-catch, CXPath axes,
# operator-token forms, attribute-value interpolation, fn library
# (regex + current-date), and streaming.
test-python-eval-v0-7-0: build-vcx
	$(PYTHON) -m unittest lang.python.test_eval_v0_7_0 -v

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
# and test-go-arrow-conformance. Per spec/v0_7_0_status.md W3.
test-rust-arrow-conformance: build-vcx build-lib-arrow
	cargo test --features arrow --manifest-path lang/rust/cxlib/Cargo.toml \
		--test arrow_conformance -- --nocapture

# Per spec/v0_7_0_status.md H4 — Rust-binding parity check for the
# v0.7.0 evaluator surface (16 tests).
test-rust-eval-v0-7-0: build-vcx
	cargo test --manifest-path lang/rust/cxlib/Cargo.toml \
		--test eval_v0_7_0

# Per spec/v0_7_0_status.md H5 — TypeScript-binding parity check for
# the v0.7.0 evaluator surface (16 tests).
test-typescript-eval-v0-7-0: build-vcx build-typescript
	npx tsx lang/typescript/eval_v0_7_0_test.ts

test-vcx: build-vcx
	$(MAKE) -C vcx conform-all

test-v: build-vcx
	v run lang/v/conformance.v
	v test lang/v/tests/api_test.v
	v test lang/v/tests/stream_test.v
	v test lang/v/tests/table_test.v

test-vcx-api: build-vcx
	v test lang/v/tests/api_test.v

test-vcx-stream: build-vcx
	v test vcx/tests/stream_test.v

test-ruby: build-vcx
	$(RUBY) lang/ruby/conformance.rb
	$(RUBY) lang/ruby/test_api.rb
	$(RUBY) lang/ruby/cxlib/test/test_data_bin_one_shots.rb
	$(RUBY) lang/ruby/cxlib/test/test_table.rb
	$(RUBY) lang/ruby/test_namespaces.rb
	$(RUBY) lang/ruby/test_identity.rb
	$(RUBY) lang/ruby/test_id_abi.rb
	$(RUBY) lang/ruby/test_delimited.rb

test-ruby-api: build-vcx
	$(RUBY) lang/ruby/test_api.rb

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
# both consume the same fixture file. Per spec/v0_7_0_status.md W3.
test-go-arrow-conformance: build-vcx build-lib-arrow
	cd lang/go/cxlib && go test -tags arrow -v -run TestArrowConformance

# Per spec/v0_7_0_status.md H3 — Go-binding parity check for the
# v0.7.0 evaluator surface (17 tests).
test-go-eval-v0-7-0: build-vcx
	cd lang/go/cxlib && go test -v -run TestEvalV070

test-typescript: build-typescript
	cd lang/typescript/cxlib && npm run conform
	npx tsx lang/typescript/api_test.ts
	npx tsx lang/typescript/data_bin_one_shots_test.ts
	npx tsx lang/typescript/delimited_test.ts
	npx tsx lang/typescript/namespaces_test.ts
	npx tsx lang/typescript/identity_test.ts

test-typescript-api: build-typescript
	npx tsx lang/typescript/api_test.ts

# W3 v0.7.0 — TS Arrow conformance. Mirrors Python/Go/Rust arrow-conformance
# targets; consumes the same fixtures at conformance/data_bin_arrow.txt and
# round-trips them through the W7 IPC bridge (apache-arrow JS).
test-typescript-arrow-conformance: build-typescript
	npx tsx lang/typescript/arrow_conformance_test.ts

test-java: build-java
	mvn -f lang/java/cxlib/pom.xml -q test

# Apache Arrow C-Data interop tests for the Java binding
# (Phase 7.74c-cont-bindings-multi-java). Mirrors test-csharp-arrow:
# builds libcx_arrow then exercises the round-trip surface for the
# 10 v0.6.0 supported column types under the `arrow` Maven profile.
test-java-arrow: build-vcx build-lib-arrow
	mvn -f lang/java/cxlib/pom.xml -q -Parrow test -Dtest=ArrowTest

test-kotlin: build-kotlin
	cd lang/kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle test -q

# Apache Arrow C-Data interop tests for the Kotlin binding
# (Phase 7.74c-cont-bindings-multi-kotlin). Mirrors test-java-arrow:
# builds libcx_arrow then exercises the round-trip surface for the
# 10 v0.6.0 supported column types under the Apache Arrow Java JAR.
test-kotlin-arrow: build-vcx build-lib-arrow
	cd lang/kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle arrowTest -q

test-csharp: build-csharp build-csharp-api
	$(DOTNET) run --project lang/csharp/conformance/conformance.csproj -c Release
	$(DOTNET) run --project lang/csharp/api_test/api_test.csproj -c Release

test-csharp-api: build-csharp-api
	$(DOTNET) run --project lang/csharp/api_test/api_test.csproj -c Release

# Apache Arrow C-Data interop tests for the C# binding
# (Phase 7.74c-cont-bindings-multi-csharp). Mirrors test-go-arrow:
# builds libcx_arrow then exercises the round-trip surface for the
# 10 v0.6.0 supported column types under the Apache.Arrow NuGet pkg.
test-csharp-arrow: build-vcx build-lib-arrow build-csharp-arrow
	$(DOTNET) run --project lang/csharp/cxlib_arrow_test/cxlib_arrow_test.csproj -c Release

test-swift: build-swift
	$(SWIFT_FLAGS) $(SWIFT) test --package-path lang/swift/cxlib

conform-md: build-vcx
	$(MAKE) -C vcx conform-md

# ── Conformance ────────────────────────────────────────────────────────────────

conform: conform-vcx

conform-vcx: build-vcx
	$(MAKE) -C vcx conform

# ── Examples (transform showcase) ────────────────────────────────────────────

examples: example-python example-v example-go example-rust example-typescript \
 example-java example-kotlin example-csharp example-ruby example-swift

example-python: build-vcx
	$(PYTHON) lang/python/examples/transform.py

example-v: build-vcx
	v run lang/v/examples/transform.v

example-go: build-go
	cd lang/go/cxlib && go run ./examples/transform/

example-rust: build-rust
	cargo run --example transform --manifest-path lang/rust/cxlib/Cargo.toml

example-typescript: build-typescript
	npx tsx lang/typescript/cxlib/examples/transform.ts

example-java: build-java
	mvn -f lang/java/cxlib/pom.xml -q exec:java -Dexec.mainClass=cx.examples.Transform

example-kotlin: build-kotlin
	cd lang/kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle run -q

example-csharp: build-csharp
	$(DOTNET) run --project lang/csharp/examples/transform/transform.csproj

example-ruby: build-vcx
	$(RUBY) lang/ruby/cxlib/examples/transform.rb

example-swift: build-swift
	$(SWIFT_FLAGS) $(SWIFT) run --package-path lang/swift/cxlib transform

# ── Demos (Document Model + Streaming + CXPath + Transform) ──────────────────

demos: demo-v demo-go demo-rust demo-typescript demo-java demo-kotlin demo-csharp demo-ruby demo-swift

demo-v: build-vcx
	v run lang/v/examples/demo.v

demo-go: build-go
	cd lang/go/cxlib && go run ./examples/demo/

demo-rust: build-rust
	cargo run --example demo --manifest-path lang/rust/cxlib/Cargo.toml

demo-typescript: build-typescript
	npx tsx lang/typescript/cxlib/examples/demo.ts

demo-java: build-java
	mvn -f lang/java/cxlib/pom.xml -q exec:java -Dexec.mainClass=cx.Demo

demo-kotlin: build-kotlin
	cd lang/kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle demo -q

demo-csharp: build-csharp
	$(DOTNET) run --project lang/csharp/examples/readme_demo/readme_demo.csproj -c Release

demo-ruby: build-vcx
	$(RUBY) lang/ruby/cxlib/examples/demo.rb

demo-swift: build-swift
	$(SWIFT_FLAGS) $(SWIFT) run --package-path lang/swift/cxlib Demo

# ── Publish to public repo ────────────────────────────────────────────────────

publish:
	@bash scripts/publish.sh

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

# T1 — Evaluator-feature microbench. Covers the v0.7.0 evaluator
# surface additions (FLWOR clauses, ?fn calls, partial application,
# pipeline/arrow operators, ?match, regex via RE2, range, tumbling
# windows). Output is parsed by scripts/run_bench_json.py into the
# T1.* benchmark keys for the V7 perf regression gate.
bench-eval: build-vcx
	v run vcx/tests/runners/eval_features_bench.v

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	$(MAKE) -C vcx clean
	rm -rf $(DIST_DIR)
	cargo clean --manifest-path lang/rust/cxlib/Cargo.toml
	find lang/csharp -type d \( -name bin -o -name obj \) -exec rm -rf {} + 2>/dev/null || true
	rm -rf lang/kotlin/cxlib/.gradle
	find lang/python -name '*.pyc' -delete
	find lang/python -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
