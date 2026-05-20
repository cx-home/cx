SHELL  := /bin/bash
# Use the patched V from third_party/v/ which carries the
# vlang/v#27178 (shared-lib GC thread-init) + #27179 (gc.h
# standalone-C) fixes plus the macOS hardened-runtime libgc
# source-compile bypass. Falls back to PATH-resolved `v` when
# the submodule isn't present.
V      := $(if $(wildcard $(CURDIR)/../third_party/v/v),$(CURDIR)/../third_party/v/v,v)
TARGET := target

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

CONFORMANCE_CORE := ../conformance/core.txt
CONFORMANCE_EXT  := ../conformance/extended.txt
CONFORMANCE_XML  := ../conformance/xml.txt
CONFORMANCE_MD   := ../conformance/md.txt
CONFORMANCE_DIFF := ../conformance/diff.txt
CONFORMANCE_LINT := ../conformance/lint.txt
CONFORMANCE_NS       := ../conformance/namespaces.txt
CONFORMANCE_TABLE    := ../conformance/table.txt
CONFORMANCE_IDENTITY := ../conformance/identity.txt
CONFORMANCE_DELIMITED := ../conformance/delimited.txt
CONFORMANCE_DATA_BIN_CHUNKED  := ../conformance/data_bin_chunked.txt
CONFORMANCE_DATA_BIN_COMPRESS := ../conformance/data_bin_compression.txt
CONFORMANCE_DATA_BIN_SCHEMA   := ../conformance/data_bin_schema_driven.txt
CONFORMANCE_DATA_BIN_ARROW    := ../conformance/data_bin_arrow.txt
CONFORMANCE_SCHEMA_VALIDATE   := ../conformance/schema_validate.txt
CONFORMANCE_EVAL              := ../conformance/eval.txt

.PHONY: all build lib lib-dev lib-arrow lib-arrow-dev re2-shim cli conform conform-core conform-ext conform-xml conform-md conform-diff conform-lint conform-ns conform-ns-cxpath conform-table conform-identity conform-delimited conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-eval clean

# ── Targets ───────────────────────────────────────────────────────────────────

all: build

build: re2-shim lib cli

# ── RE2 shim (Phase 7.74c-schema-validator-v-core) ───────────────────────────
# Compiles the C++ wrapper at vcx/deps/re2_shim/re2_shim.cc into a
# static archive that libcx + cli link against. RE2 itself is a system
# dep (Homebrew `re2` on macOS, `libre2-dev` on Debian/Ubuntu) at
# v0.6.0; submodule-pinned RE2 source ships post-tag for full
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
lib: re2-shim $(TARGET)
	$(V) $(PROD_FLAGS) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB) cx/
	$(STRIP) $(LIB)

# Unoptimised build for local development (faster compile, debuggable)
lib-dev: re2-shim $(TARGET)
	$(V) -shared -o $(LIB) cx/

# Optional Apache Arrow C-Data interop library (libcx_arrow per ADR
# 0015 D9 / spec/abi.md §2.11). Separate from libcx; bindings dlopen
# this library independently. Capability bit 23 (0x800000) is
# advertised via libcx_arrow's own cx_arrow_features symbol — libcx
# itself does not set bit 23. Module-level state requires
# -enable-globals.
lib-arrow: $(TARGET)
	$(V) -enable-globals -cflags "$(PROD_CFLAGS)" -shared -o $(LIB_ARROW) arrow/
	$(STRIP) $(LIB_ARROW)

lib-arrow-dev: $(TARGET)
	$(V) -enable-globals -shared -o $(LIB_ARROW) arrow/

# CLI binary — production
cli: re2-shim $(TARGET)
	$(V) -cflags "$(PROD_CFLAGS)" -o $(CLI) cmd/
	$(STRIP) $(CLI)

# ── Conformance ───────────────────────────────────────────────────────────────

conform: conform-core conform-ext conform-xml conform-md conform-ns conform-ns-cxpath conform-table conform-identity conform-delimited conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-diff conform-lint conform-eval

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
	@echo "── ns_cxpath/cxpath_test.v ───────────────────────────────────────────"
	$(V) test tests/ns_cxpath/cxpath_test.v

conform-table:
	@echo "── table.txt ─────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_TABLE)

conform-identity:
	@echo "── identity.txt ──────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_IDENTITY)

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

conform-eval:
	@echo "── eval.txt ──────────────────────────────────────────────────────────"
	$(V) run tests/runners/eval/eval_conform.v $(CONFORMANCE_EVAL)

conform-all:
	@echo "── all suites ────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v

# ── Clean ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(TARGET)
