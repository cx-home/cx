SHELL  := /bin/bash
# Use the patched V from third_party/v/ which carries the
# vlang/v#27178 (shared-lib GC thread-init) + #27179 (gc.h
# standalone-C) fixes plus the macOS hardened-runtime libgc
# source-compile bypass. Falls back to PATH-resolved `v` when
# the submodule isn't present.
V      := $(if $(wildcard $(CURDIR)/../third_party/v/v),$(CURDIR)/../third_party/v/v,v)
TARGET := target

# v0.9.0 — cx's DEFAULT memory model is architecture E (`-gc e`): the
# Perceus-disciplined RC front line + the precise STW vgc tracing backstop.
# Every cx build (lib + cli, prod + dev) passes it explicitly. The flip lives at
# the cx build level — NOT V's global pref.v default — so the patched V stays a
# general-purpose compiler whose own default (boehm) keeps the full V test suite
# green; cx is simply E's first first-class adopter. Concurrent mark remains a
# separate opt-in (`-d vgc_concurrent`); STW E is the default path. Override for
# debugging with e.g. `make CX_GC='-gc boehm' build`.
CX_GC  ?= -gc e

# ── Platform detection ────────────────────────────────────────────────────────

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Darwin)
  LIB_EXT  := dylib
  LIB_NAME := libcx.dylib
  STRIP    := strip -x
else
  LIB_EXT  := so
  LIB_NAME := libcx.so
  STRIP    := strip --strip-unneeded
endif

LIB  := $(TARGET)/$(LIB_NAME)
CLI  := $(TARGET)/cx

ifeq ($(UNAME_S), Darwin)
  LIB_ARROW_NAME := libcx_arrow.dylib
else
  LIB_ARROW_NAME := libcx_arrow.so
endif
LIB_ARROW := $(TARGET)/$(LIB_ARROW_NAME)

# Production C flags: size-optimized, all debug overhead removed.
# -Os    : optimize for size (smaller than -O3 for this codebase)
# -DNDEBUG -DNO_DEBUGGING : remove assertions and V debug helpers
# -fwrapv: defined integer overflow semantics (matches -prod behaviour)
PROD_CFLAGS := -Os -DNDEBUG -DNO_DEBUGGING -fwrapv

CONFORMANCE_CORE := ../conformance/core.cxd
CONFORMANCE_EXT  := ../conformance/extended.cxd
CONFORMANCE_XML  := ../conformance/xml.cxd
CONFORMANCE_MD   := ../conformance/md.cxd
CONFORMANCE_DIFF := ../conformance/diff.cxd
CONFORMANCE_LINT := ../conformance/lint.cxd
CONFORMANCE_NS       := ../conformance/namespaces.cxd
CONFORMANCE_TABLE    := ../conformance/table.cxd
CONFORMANCE_IDENTITY := ../conformance/identity.cxd
# v0.8.0: atom scalar kind.
CONFORMANCE_ATOMS    := ../conformance/atoms.cxd
CONFORMANCE_DELIMITED := ../conformance/delimited.cxd
CONFORMANCE_YAML      := ../conformance/yaml.cxd
CONFORMANCE_CONVERSIONS := ../conformance/conversions.cxd
CONFORMANCE_DATA_BIN_CHUNKED  := ../conformance/data_bin_chunked.cxd
CONFORMANCE_DATA_BIN_COMPRESS := ../conformance/data_bin_compression.cxd
CONFORMANCE_DATA_BIN_SCHEMA   := ../conformance/data_bin_schema_driven.cxd
CONFORMANCE_DATA_BIN_ARROW    := ../conformance/data_bin_arrow.cxd
CONFORMANCE_SCHEMA_VALIDATE   := ../conformance/schema_validate.cxd
# #421: [?cx include] no-resolution baseline (inc-001..inc-003). The suite
# existed but was never wired into `conform`, so the gate stayed silently
# green while the CLI's program reading regressed on [?cx …].
CONFORMANCE_INCLUDE  := ../conformance/include.cxd

.PHONY: all build build-dev check-prod lib lib-dev lib-arrow lib-arrow-dev arrow-shim lib-arrow-files lib-arrow-files-dev re2-shim cli cli-dev conform conform-core conform-ext conform-xml conform-md conform-diff conform-lint conform-ns conform-ns-cxpath conform-table conform-identity conform-atoms conform-delimited conform-yaml conform-conversions conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-include clean

# ── Targets ───────────────────────────────────────────────────────────────────

all: build

build: re2-shim lib cli

# Unoptimised dev build (lib + cli without -prod/-Os). Functionally
# identical for testing; compiles much faster. The test path uses this;
# the shipped binary uses `build`.
build-dev: re2-shim lib-dev cli-dev

# ── RE2 shim (Phase 7.74c-schema-validator-v-core) ───────────────────────────
# Compiles the C++ wrapper at vcx/deps/re2_shim/re2_shim.cc into a
# static archive that libcx + cli link against. RE2 itself is VENDORED
# (#573): third_party/re2, submodule-pinned to the last pre-abseil
# release (2023-03-01) and built as a static archive in-tree — so the
# shipped binaries carry no system-re2 dependency (the Homebrew re2
# dylib drags ~60 abseil dylibs; bare runners aborted at dyld until
# `brew install re2`) and the build is fully source-deterministic.
# The shim uses only the stable compile/match/replace RE2 API, which is
# identical across that pin and later releases. See spec/abi.md §3
# capability bit 25 + spec/schema.md §7 for the centralisation
# rationale; BSD-3 license text ships with the release tarballs.

RE2_SHIM_SRC := deps/re2_shim/re2_shim.cc
RE2_SHIM_LIB := $(TARGET)/libcx_re2_shim.a
RE2_VENDOR   := $(CURDIR)/../third_party/re2
RE2_STATIC   := $(RE2_VENDOR)/obj/libre2.a
RE2_INC      := -I$(RE2_VENDOR)

.PHONY: re2-static
re2-static: $(RE2_STATIC)

$(RE2_STATIC):
	# -fPIC: the archive links into libcx.so — Linux refuses non-PIC
	# objects in a shared library ("dangerous relocation"); macOS is
	# PIC-by-default so the flag is explicit-but-harmless there.
	$(MAKE) -C $(RE2_VENDOR) CXXFLAGS="-O3 -g -fPIC" obj/libre2.a

re2-shim: $(RE2_SHIM_LIB)

$(RE2_SHIM_LIB): $(RE2_SHIM_SRC) deps/re2_shim/re2_shim.h $(RE2_STATIC) | $(TARGET)
	c++ -std=c++17 -O2 -fPIC $(RE2_INC) -Ideps/re2_shim -c $(RE2_SHIM_SRC) -o $(TARGET)/cx_re2_shim.o
	ar rcs $(RE2_SHIM_LIB) $(TARGET)/cx_re2_shim.o

$(TARGET):
	mkdir -p $(TARGET)

# Shared library — production build: size-optimised, stripped.
#
# Passes `-prod` when using the patched V at third_party/v/ — that build
# carries the vlang/v#27178 / #27179 fixes plus the macOS-hardened-runtime
# libgc source-compile bypass (skips the precompiled gc.o that requires
# rwx pages). Falls back to the workaround (PROD_CFLAGS only, no -prod)
# when using a system V without the patches. Detected by checking for
# our patched-V marker file.
PROD_FLAGS := $(if $(wildcard $(CURDIR)/../third_party/v/v),-prod,)
# P4 guard (evict_cx_from_v): third_party/v/v is the patched V that BOTH supplies
# the -gc e/vgc runtime AND is what flips -prod on above. If it is absent the
# build silently falls back to PATH `v` (line 7) with PROD_FLAGS empty — NO -prod
# — so binaries run ~5x slower and may link an unpatched GC. That degradation is
# easily mistaken for a real perf regression (see the worktree-prod-bench trap).
# Warn LOUDLY rather than fail, since the no-prod fallback is a documented mode.
ifeq ($(wildcard $(CURDIR)/../third_party/v/v),)
$(warning *** [cx build] patched V NOT FOUND at third_party/v/v — falling back to PATH `v` with -prod SILENTLY DROPPED (≈5x slower, GC may be unpatched). This is NOT a code regression. Fix: `git submodule update --init --recursive third_party/v && $(MAKE) -C ../third_party/v`. In a git worktree, symlink the main checkout's third_party/v. ***)
endif
# Quiet the V compiler's informational notices (-n) and warnings (-w) from the
# build output — they're benign (unused stub params, signed-shift notices) and
# drown the real signal. Override with `make VQUIET= …` to see them.
VQUIET ?= -n -w
# Default DB engines (#520): every shipped-shape build carries sqlite + redis.
# sqlite adds only V's binding code — the library stays a dynamic link to the
# system libsqlite3 (macOS: SDK header + /usr/lib dylib; Linux: libsqlite3-dev
# at build time, libsqlite3 at run time); redis is a pure-V RESP client linking
# nothing. Measured cost on the stripped CLI: +155 KB (+2.1%). pg/mysql stay
# opt-in via CX_DFLAGS ('-d cx_db_pg' → libpq, '-d cx_db_mysql' →
# libmysqlclient) because they add runtime library deps the installer base
# can't assume. Override CX_ENGINES='' for an engine-free build (size audits,
# constrained targets); the wasm path (scripts/wasm/) never passes this
# variable, so wasm stays engine-free. `cx -v` reports the compiled-in set.
CX_ENGINES ?= -d cx_db_sqlite -d cx_db_redis
# Build target = vcx/code/. The code module imports cx, so every
# cx_* export from vcx/cx/cabi.v ships in the same libcx — plus the
# v0.8.0 cx_code_eval* family exported from vcx/code/cabi.v
# (Phase 3.11). Building from vcx/cx/ in isolation would leave the
# code-eval family out of the shared library.
lib: re2-shim $(TARGET)
	$(V) $(VQUIET) $(PROD_FLAGS) $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB) code/
	$(STRIP) $(LIB)

# Unoptimised build for local development (faster compile, debuggable).
# `-cc cc` (clang): tcc on macOS cannot compile the patched builtin's C11 atomics
# (`atomic_fetch_*_explicit`) or `@[thread_local]` TLS (see the `cli` note). `-prod`
# builds already force clang; the dev builds must opt in explicitly.
# CX_DFLAGS — extra `-d` build flags for opt-in, gated backends that link an
# external library the default build must NOT pull in (e.g. `-d cx_sftp` →
# libssh2 for store sftp://, #106; `-d cx_db_pg` → libpq). Default empty, so
# the standard build links nothing beyond the CX_ENGINES defaults above.
# Works on the shipped-shape targets too (#520):
#   make -C vcx build CX_DFLAGS='-d cx_db_pg'
CX_DFLAGS ?=
lib-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) -shared -o $(LIB) code/

# -prod strictness gate (#338): run the V *checker* with the same -prod flags
# `lib` compiles with. -prod enables strict map-index checks (`or {}` required
# on sum-type / pointer-carrying map values) that the dev build tolerates, so
# a dev-green tree can still fail the shipped-artifact build. Checker-only
# (`-check`, no codegen, no cc), so it runs in ~2s and never touches target/.
# `-prod` is passed explicitly — NOT $(PROD_FLAGS) — because PROD_FLAGS goes
# empty when third_party/v is absent (the documented fallback keeps *builds*
# working); the checker needs no patched runtime, so the gate must still bite.
check-prod:
	$(V) $(VQUIET) -prod $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) -check -shared code/

# Optional Apache Arrow C-Data interop library (libcx_arrow per
# spec/abi.md §2.11). Separate from libcx; bindings dlopen
# this library independently. Capability bit 23 (0x800000) is
# advertised via libcx_arrow's own cx_arrow_features symbol — libcx
# itself does not set bit 23. Module-level state requires
# -enable-globals.
lib-arrow: $(TARGET)
	$(V) $(VQUIET) -enable-globals $(CX_GC) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB_ARROW) arrow/
	$(STRIP) $(LIB_ARROW)

lib-arrow-dev: $(TARGET)
	$(V) $(VQUIET) -cc cc -enable-globals $(CX_GC) -shared -o $(LIB_ARROW) arrow/

# ── Optional Apache Arrow FILE I/O: Parquet + Arrow IPC ("Phase C").
# Gated `-d cx_arrow_files`; links libarrow/libparquet (which YOU supply — cx
# ships only the thin C++ connector shim, never Arrow itself) into libcx_arrow.
# The base lib-arrow above stays fully dependency-free; core libcx never links
# Arrow at all. Apache Arrow is discovered via pkg-config.
#
#   macOS:  brew install apache-arrow   (keg-only; pkgconfig dir added below)
#   Linux:  apt install libarrow-dev libparquet-dev   (or dnf/conda/vcpkg)
#
# LEAN PRODUCTION BUILD: the brew bottle is full-featured and drags S3/aws +
# flight/gandiva (llvm/grpc) you don't need. For a minimal footprint build
# Arrow from source with Parquet on and the rest off:
#   cmake -DARROW_PARQUET=ON -DARROW_S3=OFF -DARROW_FLIGHT=OFF \
#         -DARROW_GANDIVA=OFF -DARROW_BUILD_SHARED=ON …
# Our path links only libarrow + libparquet (+ thrift/compression) ≈ tens of MB.
ARROW_SHIM_SRC := arrow/shim/cx_arrow_shim.cc
ARROW_SHIM_LIB := $(TARGET)/libcx_arrow_shim.a
ifeq ($(UNAME_S), Darwin)
  ARROW_PKGCONFIG := /opt/homebrew/opt/apache-arrow/lib/pkgconfig
else
  ARROW_PKGCONFIG :=
endif
ARROW_PC := PKG_CONFIG_PATH="$(ARROW_PKGCONFIG):$$PKG_CONFIG_PATH"
ARROW_CXXFLAGS := $(shell $(ARROW_PC) pkg-config --cflags arrow parquet 2>/dev/null)

arrow-shim: $(ARROW_SHIM_LIB)

$(ARROW_SHIM_LIB): $(ARROW_SHIM_SRC) arrow/shim/cx_arrow_shim.h | $(TARGET)
	c++ -std=c++20 -O2 -fPIC $(ARROW_CXXFLAGS) -c $(ARROW_SHIM_SRC) -o $(TARGET)/cx_arrow_shim.o
	ar rcs $(ARROW_SHIM_LIB) $(TARGET)/cx_arrow_shim.o

lib-arrow-files: arrow-shim $(TARGET)
	$(ARROW_PC) $(V) $(VQUIET) -enable-globals $(CX_GC) -d cx_arrow_files -cflags "$(PROD_CFLAGS)" -shared -o $(LIB_ARROW) arrow/
	$(STRIP) $(LIB_ARROW)

lib-arrow-files-dev: arrow-shim $(TARGET)
	$(ARROW_PC) $(V) $(VQUIET) -cc cc -enable-globals $(CX_GC) -d cx_arrow_files -shared -o $(LIB_ARROW) arrow/

# CLI binary — size-optimized (-Os via PROD_CFLAGS), NOT V `-prod`. `-prod`
# turns warnings into errors, and the cmd/ semantic-token legend carries
# intentionally-unset constants (e.g. tt_property — a protocol index slot, not
# dead code, so it can't be removed without shifting the legend). The heavy
# logic ships -prod in libcx; the cli is a thin dispatch layer, so -Os is the
# right trade. (To enable -prod cli later: reference the legend slots so V
# doesn't flag them, then add $(PROD_FLAGS) here.)
# `-cc cc` (clang) — NOT V's default tcc: cx's builtin carries `@[thread_local]`
# globals (cx_region) + the vgc per-thread cache, and tcc on macOS cannot compile
# `__thread` TLS ("';' expected (got 'bool')"). The upstream-V forward-port dropped
# the old fork's TLS-patched tcc, so clang is required for any cx build.
# Build-stamped version info, injected as V compile-time string defines and shown
# by `cx --version`. CX_VERSION is the single declared source of truth — the
# repo-root VERSION file (the release tag is derived FROM and checked AGAINST it;
# see scripts/bump_version.sh + the check-version-consistency gate). CX_COMMIT is
# the build commit (distinguishes dev builds); CX_VFORK is the third_party/v
# gitlink; CX_GC_NAME is the active collector. Each value is a single shell token.
CX_VERSION    := $(shell cat $(CURDIR)/../VERSION 2>/dev/null || echo 0.0.0-dev)
CX_COMMIT     := $(shell git -C $(CURDIR)/.. rev-parse --short HEAD 2>/dev/null || echo unknown)
CX_VFORK      := $(shell git -C $(CURDIR)/../third_party/v rev-parse --short HEAD 2>/dev/null || echo unknown)
CX_BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
CX_GC_NAME    := $(lastword $(CX_GC))
VERSION_DEFINES := -d cx_version=$(CX_VERSION) -d cx_commit=$(CX_COMMIT) -d cx_build_date=$(CX_BUILD_DATE) -d cx_gc=$(CX_GC_NAME) -d cx_vfork=$(CX_VFORK)

cli: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) $(VERSION_DEFINES) -cflags "$(PROD_CFLAGS)" -o $(CLI) cmd/
	$(STRIP) $(CLI)

# CLI binary — unoptimised dev build (faster compile, debuggable, unstripped)
cli-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_ENGINES) $(VERSION_DEFINES) $(CX_DFLAGS) -o $(CLI) cmd/

# ── Conformance ───────────────────────────────────────────────────────────────

conform: conform-core conform-ext conform-xml conform-md conform-ns conform-ns-cxpath conform-table conform-identity conform-atoms conform-delimited conform-yaml conform-conversions conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-diff conform-lint conform-include

conform-include:
	@echo "── include.cxd ───────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_INCLUDE)

conform-core:
	@echo "── core.txt ──────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_CORE)

conform-ext:
	@echo "── extended.txt ──────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_EXT)

conform-xml:
	@echo "── xml.txt ───────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_XML)

conform-md:
	@echo "── md.txt ────────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_MD)

conform-ns:
	@echo "── namespaces.txt ────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_NS)

conform-ns-cxpath:
	@echo "── cxpath conformance (v08_cxpath_*_test.v) ──────────────────────────"
	$(V) -cc cc test tests/cxpath_dispatcher_test.v tests/cxpath_forward_test.v tests/cxpath_reverse_test.v tests/cxpath_misc_test.v

conform-table:
	@echo "── table.txt ─────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_TABLE)

conform-identity:
	@echo "── identity.txt ──────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_IDENTITY)

# v0.8.0: atom scalar kind suite.
conform-atoms:
	@echo "── atoms.txt ─────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_ATOMS)

conform-delimited:
	@echo "── delimited.txt ─────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_DELIMITED)

conform-yaml:
	@echo "── yaml.cxd ──────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_YAML)

conform-conversions:
	@echo "── conversions.cxd ───────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_CONVERSIONS)

conform-data-bin-chunked:
	@echo "── data_bin_chunked.txt ──────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_DATA_BIN_CHUNKED)

# Runs under the shipped default `-gc e`/vgc. cmp-005-fd-streaming-write-bounded-memory
# asserts the fd-streaming write path keeps RSS O(1) in the number of row-groups:
# the #71 adaptive pacer bounds the loop's transients on its own trigger (no
# call-site gc_collect crutch — retired), and the runner's explicit gc_collect()
# before each RSS snapshot returns the collector's reuse pool to the OS (#52),
# so the snapshots measure retention, not the pacer's committed working set.
# The other cases here are encoding-correctness (GC-agnostic).
conform-data-bin-compress:
	@echo "── data_bin_compression.txt ──────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_DATA_BIN_COMPRESS)

conform-data-bin-schema:
	@echo "── data_bin_schema_driven.txt ────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_DATA_BIN_SCHEMA)

conform-data-bin-arrow:
	@echo "── data_bin_arrow.txt ────────────────────────────────────────────────"
	$(V) -enable-globals run tests/runners/conformance/data_bin_arrow_run.v $(CONFORMANCE_DATA_BIN_ARROW)

conform-schema-validate:
	@echo "── schema_validate.txt ───────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_SCHEMA_VALIDATE)

conform-diff:
	@echo "── diff.txt ──────────────────────────────────────────────────────────"
	$(V) run tests/runners/diff_lint/diff_lint_conform.v diff $(CONFORMANCE_DIFF)

conform-lint:
	@echo "── lint.txt ──────────────────────────────────────────────────────────"
	$(V) run tests/runners/diff_lint/diff_lint_conform.v lint $(CONFORMANCE_LINT)

conform-all:
	@echo "── all suites ────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v

# ── Clean ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(TARGET)
