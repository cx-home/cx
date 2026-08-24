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
CONFORMANCE_TABLE_TRANSPARENCY := ../conformance/table_transparency.cxd
CONFORMANCE_IDENTITY := ../conformance/identity.cxd
# corpus audit G1/G4 (C8/I0): Tier-1 hash + binary-AST codec families.
CONFORMANCE_IDENTITY_HASH := ../conformance/identity_hash.cxd
CONFORMANCE_AST_BIN       := ../conformance/ast_bin.cxd
# I1 manifest row 8 (audit C4): pre-I1 operator-head pins.
CONFORMANCE_OPERATOR_HEADS := ../conformance/operator_heads.cxd
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
# G12 (corpus audit, pre-I2): the streaming-write family gets a V lane — the
# reference implementation was untested against its own 17 fixtures (incl.
# the W001–W013 negative contract); only the FFI harnesses drove them.
CONFORMANCE_STREAMING_WRITE := ../conformance/streaming_write.cxd
# G10 (corpus audit, pre-I2): the lockfile Ring-0 document surface.
CONFORMANCE_LOCKFILE := ../conformance/lockfile.cxd
# fmt.cxd — the G6 formatting suite (I3); runner tests/runners/fmt/.
CONFORMANCE_FMT := ../conformance/fmt.cxd

.PHONY: all build build-dev check-prod lib lib-dev lib-arrow lib-arrow-dev arrow-shim lib-arrow-files lib-arrow-files-dev re2-shim cli cli-dev conform conform-streaming-write conform-lockfile conform-core conform-ext conform-xml conform-md conform-diff conform-lint conform-ns conform-table conform-table-transparency conform-identity conform-identity-hash conform-ast-bin conform-operator-heads conform-atoms conform-delimited conform-yaml conform-conversions conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-include conform-fmt clean

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

# ── §4 profile gates (I4, #651/#516) ─────────────────────────────────────────
# CX_PROFILE_PLATFORM compiles the Ring-2 platform verb surface + the
# platform module import into cmd/ (`*_d_cx_platform.v`): the DEFAULT cx is
# the platform profile — today's shipped shape, unchanged. A cmd/ build
# WITHOUT it is the cli profile (no Ring-2 code in the artifact).
# CX_PACKS_OFF is the embed profile's exclusion set: the nine Ring-1
# local-effect packs (spec §4's seven + the http-client pack + sched by
# dependency closure), each behind a `_notd_cx_no_pack_*` file gate in
# vcx/code. Default builds pass NO exclusion flags, so every existing lane
# keeps the full Ring-1 composition; only the embed targets pass this set.
CX_PROFILE_PLATFORM := -d cx_platform
CX_PACKS_OFF := -d cx_no_pack_io -d cx_no_pack_env -d cx_no_pack_process \
	-d cx_no_pack_time -d cx_no_pack_random -d cx_no_pack_log \
	-d cx_no_pack_term -d cx_no_pack_http_client -d cx_no_pack_sched
# Build target = vcx/platform/ (I3 module split, #651/#516). The platform
# module imports code, which imports cx — so every
# cx_* export from vcx/cx/cabi.v ships in the same libcx, plus the
# v0.8.0 cx_code_eval* family exported from vcx/code/cabi.v and the
# iowatch C-callback exports riding in vcx/platform (N4) — libcx keeps
# the FULL 0-2 surface during I3 (the ABI gate pins all 713 symbols).
# Building from vcx/cx/ in isolation would leave the
# code-eval family out of the shared library.
# BUILD_INPUT_DIRS — everything whose bytes reach the shipped artifacts:
# V sources (all module dirs incl. transport/deps), the $embed_file()
# estates (../stdlib, ../x, ../docs/llm), VERSION (feeds CX_VERSION), this
# Makefile, and the V compiler binary itself. Used by the up-to-date
# guards below; a path missed here is a STALE-BINARY hazard, so prefer
# over-inclusion.
BUILD_INPUT_DIRS := cmd cmd_data code cx platform transport deps testenv v.mod Makefile ../stdlib ../x ../docs/llm ../VERSION $(V)

# Up-to-date guard (#902's race, root-fixed): every target here is .PHONY,
# so each recursive `$(MAKE) build-vcx` RELINKED the shipped cx/libcx
# unconditionally (the cx_build_date define changes per invocation) — while
# a parallel `make -j12 test` lane was exec'ing/dlopening it. Measured
# fallout on the v0.16.0 cut: 'Exec format error' in the extraction gate
# (twice), and cli_run_surface reading rc-0/empty-output from a mid-relink
# binary (once) — all green on quiet re-runs. The guard skips the relink
# iff the artifact exists, the define IDENTITY (everything except the
# build date) is unchanged, and no input is newer than the artifact.
# A real source/define/compiler change still rebuilds — checked by find
# -newer over BUILD_INPUT_DIRS, the same mechanism real file targets use.
define UPTODATE_GUARD
	if [ -e "$(1)" ] && [ -f "$(1).buildid" ] && [ "$$(cat '$(1).buildid')" = "$(2)" ] \
	   && [ -z "$$(find $(BUILD_INPUT_DIRS) -newer '$(1)' -print -quit 2>/dev/null)" ]; then \
		echo "$(notdir $(1)): up to date (identity + inputs unchanged; relink skipped)"; \
	else \
		$(3) && printf '%s' "$(2)" > '$(1).buildid'; \
	fi
endef

LIB_BUILD_ID := $(V)|$(PROD_FLAGS)|$(CX_GC)|$(CX_ENGINES)|$(CX_DFLAGS)|$(PROD_CFLAGS)|lib
lib: re2-shim $(TARGET)
	@$(call UPTODATE_GUARD,$(LIB),$(LIB_BUILD_ID),$(V) $(VQUIET) $(PROD_FLAGS) $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB) platform/ && $(STRIP) $(LIB))

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
# #902 — the dev library gets its OWN path. It used to write $(LIB), the same
# file the -prod `lib` recipe writes, so under `make test -j` one recipe could
# be writing (or stripping) the dylib while another lane dlopened it — and,
# worse, WHICH build the lanes tested was decided by which recipe finished
# last. Nothing links this artifact (cli-dev compiles cmd/ directly); it exists
# only so a dev build leaves a loadable library behind, so giving it a distinct
# name costs nothing and makes the collision impossible by construction.
LIB_DEV := $(TARGET)/$(basename $(LIB_NAME))-dev$(suffix $(LIB_NAME))

lib-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) -shared -o $(LIB_DEV) platform/

# ── Ring-0 artifacts (I2, partition spec §5): libcx-core + data-profile cx ──
# libcx-core builds ONLY vcx/cx/ — the Ring-0 strict sink — so the shared
# library carries the cx_* C ABI family (cabi.v) and nothing above it: no
# evaluator, no cx_code_* exports, no DB engines, no protocol stack. The
# monolith libcx (built from code/) is UNCHANGED and keeps shipping — the
# strangler rule; the I2 extraction gate proves the two byte-identical over
# the Ring-0 corpus. No CX_ENGINES here: those are code-module `$if` gates
# with no Ring-0 references. re2 rides in via vcx/cx/regex_re2.v #flags
# (schema §7.1 makes RE2 normative — a Ring-0 dependency by spec).
ifeq ($(UNAME_S), Darwin)
  LIB_CORE_NAME := libcx-core.dylib
else
  LIB_CORE_NAME := libcx-core.so
endif
LIB_CORE := $(TARGET)/$(LIB_CORE_NAME)

.PHONY: lib-core lib-core-dev cli-data cli-data-dev build-data build-data-dev
lib-core: re2-shim $(TARGET)
	$(V) $(VQUIET) $(PROD_FLAGS) $(CX_GC) $(CX_DFLAGS) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB_CORE) cx/
	$(STRIP) $(LIB_CORE)

lib-core-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_DFLAGS) -shared -o $(LIB_CORE) cx/

# data-profile cx (partition spec §4): one binary NAME (cx), profile-decided
# verb set — parse/emit/convert/canonical/hash/eq/diff/validate (+ version),
# NO run/eval verb. Built from cmd_data/ which imports only cx + the shared
# Ring-0 verb layer cli/, so cannot-execute is a property of the artifact.
# Lands under target/profiles/data/ so the basename stays `cx` without
# clobbering the monolith CLI; the I4 profile/installer wiring picks the
# install path.
CLI_DATA := $(TARGET)/profiles/data/cx

cli-data: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/data
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_DFLAGS) $(VERSION_DEFINES) -cflags "$(PROD_CFLAGS)" -o $(CLI_DATA) cmd_data/
	$(STRIP) $(CLI_DATA)

cli-data-dev: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/data
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_DFLAGS) $(VERSION_DEFINES) -o $(CLI_DATA) cmd_data/

build-data: lib-core cli-data
build-data-dev: lib-core-dev cli-data-dev

# -prod strictness gate (#338): run the V *checker* with the same -prod flags
# `lib` compiles with. -prod enables strict map-index checks (`or {}` required
# on sum-type / pointer-carrying map values) that the dev build tolerates, so
# a dev-green tree can still fail the shipped-artifact build. Checker-only
# (`-check`, no codegen, no cc), so it runs in ~2s and never touches target/.
# `-prod` is passed explicitly — NOT $(PROD_FLAGS) — because PROD_FLAGS goes
# empty when third_party/v is absent (the documented fallback keeps *builds*
# working); the checker needs no patched runtime, so the gate must still bite.
check-prod:
	$(V) $(VQUIET) -prod $(CX_GC) $(CX_ENGINES) $(CX_DFLAGS) -check -shared platform/

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
# -dirty suffix (#666): a stamp naming a commit that does not reproduce the
# artifact is unfalsifiable — rev-parse is silent about uncommitted changes,
# so a binary built from an edited tree claimed the clean commit. Any tracked
# modification (the submodule gitlink counts in the parent's porcelain) marks
# the stamp. Downstream pins (BOM record == checkout) depend on this.
CX_DIRTY      := $(shell test -n "$$(git -C $(CURDIR)/.. status --porcelain --untracked-files=no 2>/dev/null)" && echo -dirty)
CX_COMMIT     := $(addsuffix $(CX_DIRTY),$(shell git -C $(CURDIR)/.. rev-parse --short HEAD 2>/dev/null || echo unknown))
CX_VFORK_DIRTY := $(shell test -n "$$(git -C $(CURDIR)/../third_party/v status --porcelain --untracked-files=no 2>/dev/null)" && echo -dirty)
CX_VFORK      := $(addsuffix $(CX_VFORK_DIRTY),$(shell git -C $(CURDIR)/../third_party/v rev-parse --short HEAD 2>/dev/null || echo unknown))
CX_BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
CX_GC_NAME    := $(lastword $(CX_GC))
VERSION_DEFINES := -d cx_version=$(CX_VERSION) -d cx_commit=$(CX_COMMIT) -d cx_build_date=$(CX_BUILD_DATE) -d cx_gc=$(CX_GC_NAME) -d cx_vfork=$(CX_VFORK)

CLI_BUILD_ID := $(V)|$(CX_GC)|$(CX_PROFILE_PLATFORM)|$(CX_ENGINES)|$(CX_DFLAGS)|$(PROD_CFLAGS)|$(CX_VERSION)|$(CX_COMMIT)|$(CX_GC_NAME)|$(CX_VFORK)|cli
cli: re2-shim $(TARGET)
	@$(call UPTODATE_GUARD,$(CLI),$(CLI_BUILD_ID),$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_PROFILE_PLATFORM) $(CX_ENGINES) $(CX_DFLAGS) $(VERSION_DEFINES) -cflags "$(PROD_CFLAGS)" -o $(CLI) cmd/ && $(STRIP) $(CLI))

# CLI binary — unoptimised dev build (faster compile, debuggable, unstripped)
cli-dev: re2-shim $(TARGET)
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_PROFILE_PLATFORM) $(CX_ENGINES) $(VERSION_DEFINES) $(CX_DFLAGS) -o $(CLI) cmd/

# ── §4 profile binaries + embed library (I4, #651/#516) ──────────────────────
# One binary NAME (cx), profile-decided surface, each under
# target/profiles/<name>/ (the I2 cli-data precedent). The cli profile =
# cmd/ without the platform gate (Rings 0–1, all local-effect packs + http
# client; daemon verb words refuse by name). The embed profile additionally
# passes CX_PACKS_OFF, so the evaluator carries no local-effect packs — and
# ships with the embed-shape libcx: the spec §5 Rings-0–1 library artifact
# (built over code/, same declared cx_*/cx_code_* ABI families; the DEFAULT
# libcx keeps the full 0–2 surface until I5 stream 4 — ledger R1).
CLI_CLI   := $(TARGET)/profiles/cli/cx
CLI_EMBED := $(TARGET)/profiles/embed/cx
LIB_EMBED := $(TARGET)/profiles/embed/$(LIB_NAME)

.PHONY: cli-cli cli-cli-dev cli-embed cli-embed-dev lib-embed lib-embed-dev \
	build-profiles build-profiles-dev

cli-cli: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/cli
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_DFLAGS) $(VERSION_DEFINES) -cflags "$(PROD_CFLAGS)" -o $(CLI_CLI) cmd/
	$(STRIP) $(CLI_CLI)

cli-cli-dev: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/cli
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_DFLAGS) $(VERSION_DEFINES) -o $(CLI_CLI) cmd/

cli-embed: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/embed
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_PACKS_OFF) $(CX_DFLAGS) $(VERSION_DEFINES) -cflags "$(PROD_CFLAGS)" -o $(CLI_EMBED) cmd/
	$(STRIP) $(CLI_EMBED)

cli-embed-dev: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/embed
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_PACKS_OFF) $(CX_DFLAGS) $(VERSION_DEFINES) -o $(CLI_EMBED) cmd/

lib-embed: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/embed
	$(V) $(VQUIET) $(PROD_FLAGS) $(CX_GC) $(CX_PACKS_OFF) $(CX_DFLAGS) -cflags "$(PROD_CFLAGS)" -shared -o $(LIB_EMBED) code/
	$(STRIP) $(LIB_EMBED)

lib-embed-dev: re2-shim $(TARGET)
	mkdir -p $(TARGET)/profiles/embed
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_PACKS_OFF) $(CX_DFLAGS) -shared -o $(LIB_EMBED) code/

# The full §4 matrix: data (I2) + embed + cli profiles; the platform profile
# is the default `build` (target/cx + target/libcx.*).
build-profiles: build-data cli-embed lib-embed cli-cli
build-profiles-dev: build-data-dev cli-embed-dev lib-embed-dev cli-cli-dev

# ── I4 profile corpus gate (spec §4/§7 exit clause) ──────────────────────────
# Runs tests/runners/profile_gate/profile_gate.v at BOTH profile engine
# compositions: bare = cli (Rings 0–1, all packs — every ring≤1 eval fixture
# must grade identically to the platform battery, proving the ring tags
# against the artifact frontier); CX_PACKS_OFF = embed (pack suites +
# `packs=`-tagged cases out, per-pack + ring-2 refusal probes in). Each run
# also probes the profile BINARY (profile line, daemon verb-word refusals,
# pure eval) — the data profile's corpus clause is the I2 extraction gate.
.PHONY: test-profile-gate
# Built with explicit -o into target/ (NOT `v run`): `v run` leaves the
# compiled executable next to the source, where an interrupted run strands
# it for the text-scanning gates to trip over (R3.11 wave-run finding).
test-profile-gate: build-profiles-dev
	$(V) $(VQUIET) -cc cc $(CX_GC) -o target/profile_gate_cli tests/runners/profile_gate/ && target/profile_gate_cli --bin=target/profiles/cli/cx
	$(V) $(VQUIET) -cc cc $(CX_GC) $(CX_PACKS_OFF) -o target/profile_gate_embed tests/runners/profile_gate/ && target/profile_gate_embed --bin=target/profiles/embed/cx

# ── Conformance ───────────────────────────────────────────────────────────────

conform: conform-core conform-ext conform-xml conform-md conform-ns conform-table conform-table-transparency conform-identity conform-identity-hash conform-ast-bin conform-operator-heads conform-atoms conform-delimited conform-yaml conform-conversions conform-data-bin-chunked conform-data-bin-compress conform-data-bin-schema conform-data-bin-arrow conform-schema-validate conform-diff conform-lint conform-include conform-streaming-write conform-lockfile conform-fmt

# fmt.cxd (G6, I3): byte-pinned `cx fmt` output + the formatting.md §1
# purity invariant + §7 idempotence, enforced mechanically per case by
# the runner (see tests/runners/fmt/fmt_conform.v).
conform-fmt:
	@echo "── fmt.cxd ───────────────────────────────────────────────────────────"
	$(V) run tests/runners/fmt/fmt_conform.v $(CONFORMANCE_FMT)

conform-lockfile:
	@echo "── lockfile.cxd ──────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_LOCKFILE)

conform-streaming-write:
	@echo "── streaming_write.cxd ───────────────────────────────────────────────"
	$(V) run tests/runners/streaming_write/streaming_write_run.v $(CONFORMANCE_STREAMING_WRITE)

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

# (conform-ns-cxpath RETIRED at the #795 batch, 2026-08-15: its three test
# files were consolidated by #700 and then deliberately deleted with the
# placeholder CxNode axis engine at the #805 retirement sweep (b78a3b4c);
# the live cxpath coverage is the code.cxd eval corpus + the #809 kind-test
# work. The target had been failing silently-unrun since then — found when
# the full `conform` aggregate was wired into test-vcx.)

conform-table:
	@echo "── table.txt ─────────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_TABLE)

conform-table-transparency:
	@echo "── table_transparency.cxd (§9 pair family, lanes a/b/c) ──────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_TABLE_TRANSPARENCY)

conform-identity:
	@echo "── identity.txt ──────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_IDENTITY)

conform-identity-hash:
	@echo "── identity_hash.cxd ─────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_IDENTITY_HASH)

conform-ast-bin:
	@echo "── ast_bin.cxd ───────────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_AST_BIN)

conform-operator-heads:
	@echo "── operator_heads.cxd ────────────────────────────────────────────────"
	$(V) run tests/runners/conformance/conformance_run.v $(CONFORMANCE_OPERATOR_HEADS)

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
	@echo "── data_bin_arrow.txt (+ §9 pair-family lane d) ──────────────────────"
	$(V) -enable-globals run tests/runners/conformance/data_bin_arrow_run.v $(CONFORMANCE_DATA_BIN_ARROW) $(CONFORMANCE_TABLE_TRANSPARENCY)

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
