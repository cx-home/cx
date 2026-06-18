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
CONFORMANCE_DATA_BIN_CHUNKED  := ../conformance/data_bin_chunked.cxd
CONFORMANCE_DATA_BIN_COMPRESS := ../conformance/data_bin_compression.cxd
CONFORMANCE_DATA_BIN_SCHEMA   := ../conformance/data_bin_schema_driven.cxd
CONFORMANCE_DATA_BIN_ARROW    := ../conformance/data_bin_arrow.cxd
CONFORMANCE_SCHEMA_VALIDATE   := ../conformance/schema_validate.cxd

.PHONY: all build build-dev lib lib-dev lib-arrow lib-arrow-dev re2-shim cli cli-dev conform conform-core conform-ext conform-xml conform-md conform-diff conform-lint conform-ns conform-ns-cxpath conform-table conform-identity conform-atoms conform-delimited conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate clean

# ── Targets ───────────────────────────────────────────────────────────────────

all: build

build: re2-shim lib cli

# Unoptimised dev build (lib + cli without -prod/-Os). Functionally
# identical for testing; compiles much faster. The test path uses this;
# the shipped binary uses `build`.
build-dev: re2-shim lib-dev cli-dev

# ── RE2 shim (Phase 7.74c-schema-validator-v-core) ───────────────────────────
# Compiles the C++ wrapper at vcx/deps/re2_shim/re2_shim.cc into a
# static archive that libcx + cli link against. RE2 itself is a system
# dep (Homebrew `re2` on macOS, `libre2-dev` on Debian/Ubuntu);
# submodule-pinned RE2 source ships post-tag for full
# determinism. See spec/abi.md §3 capability bit 25 +
# spec/schema.md §7 for the centralisation rationale.

RE2_SHIM_SRC := deps/re2_shim/re2_shim.cc
RE2_SHIM_LIB := $(TARGET)/libcx_re2_shim.a

ifeq ($(UNAME_S), Darwin)
  RE2_INC := -I/opt/homebrew/include
else
  RE2_INC := -I/usr/include
endif

re2-shim: $(RE2_SHIM_LIB)

$(RE2_SHIM_LIB): $(RE2_SHIM_SRC) deps/re2_shim/re2_shim.h | $(TARGET)
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
# Build target = vcx/code/. The code module imports cx, so every
# cx_* export from vcx/cx/cabi.v ships in the same libcx — plus the
# v0.8.0 cx_code_eval* family exported from vcx/code/cabi.v
# (Phase 3.11). Building from vcx/cx/ in isolation would leave the
# code-eval family out of the shared library.
lib: re2-shim $(TARGET)
	$(V) $(VQUIET) $(PROD_FLAGS) $(CX_GC) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB) code/
	$(STRIP) $(LIB)

# Unoptimised build for local development (faster compile, debuggable).
# `-cc cc` (clang): tcc on macOS cannot compile the patched builtin's C11 atomics
# (`atomic_fetch_*_explicit`) or `@[thread_local]` TLS (see the `cli` note). `-prod`
# builds already force clang; the dev builds must opt in explicitly.
lib-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) -shared -o $(LIB) code/

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
	$(V) $(VQUIET) -cc cc $(CX_GC) $(VERSION_DEFINES) -cflags "$(PROD_CFLAGS)" -o $(CLI) cmd/
	$(STRIP) $(CLI)

# CLI binary — unoptimised dev build (faster compile, debuggable, unstripped)
cli-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(VERSION_DEFINES) -o $(CLI) cmd/

# ── Conformance ───────────────────────────────────────────────────────────────

conform: conform-core conform-ext conform-xml conform-md conform-ns conform-ns-cxpath conform-table conform-identity conform-atoms conform-delimited conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-diff conform-lint

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
	$(V) -cc cc test tests/v08_cxpath_dispatcher_test.v tests/v08_cxpath_forward_test.v tests/v08_cxpath_reverse_test.v tests/v08_cxpath_misc_test.v

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

conform-data-bin-chunked:
	@echo "── data_bin_chunked.txt ──────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_DATA_BIN_CHUNKED)

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
