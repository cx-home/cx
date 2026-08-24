# CX — public build & test Makefile.
#
# This is the Makefile shipped to the public repo (github.com/cx-home/cx).
# It is intentionally small: clone → build → test, plus the docs render.
# (The private development repo has a much larger Makefile with CI gates
# that depend on internal scripts not shipped here.)
#
# Prerequisites:
#   • a C and C++ compiler (cc / c++)
#   • re2  (macOS: `brew install re2`; Debian/Ubuntu: `apt install libre2-dev`)
#   • sqlite3 headers — the default build carries the sqlite DB engine
#     (macOS: ships with the SDK, nothing to install;
#      Debian/Ubuntu: `apt install libsqlite3-dev`)
#   • the V compiler submodule (built automatically by `make build`):
#       git submodule update --init --recursive
#
# Quick start:
#   git submodule update --init --recursive
#   make build        # builds the V toolchain, libcx, and the `cx` CLI
#   make test         # runs the V test suite + the conformance corpus

V := $(if $(wildcard $(CURDIR)/third_party/v/v),$(CURDIR)/third_party/v/v,v)

.PHONY: all build build-dev test conform guide guide-clean clean v-toolchain help

all: build

## v-toolchain  Build the bundled (patched) V compiler from the submodule.
v-toolchain:
	@if [ ! -f third_party/v/v ]; then \
	  if [ ! -e third_party/v/Makefile ]; then \
	    echo "third_party/v is empty — run: git submodule update --init --recursive"; exit 1; \
	  fi; \
	  echo "building the V toolchain (third_party/v) ..."; \
	  $(MAKE) -C third_party/v; \
	fi

## build        Build libcx + the cx CLI (release).
build: v-toolchain
	$(MAKE) -C vcx build

## build-dev    Build libcx + the cx CLI (fast, unoptimised) — used by tests.
build-dev: v-toolchain
	$(MAKE) -C vcx build-dev

## test         Run the V unit/test suite + the conformance corpus.
##              `-cc cc`: V's bundled tcc cannot compile the patched builtin
##              (C11 atomics / @[thread_local]) — same flags the private
##              test gate uses. `-gc e` is cx's shipped memory model.
# A handful of real-socket lanes are load-flaky ONLY under full -j
# parallelism (ephemeral-port/deadline contention). On a suite failure,
# those enumerated lanes get one serial retry — any other failure, or a
# serial failure here, still fails the build.
SERIAL_RETRY := vcx/tests/net_udp_read_deadline_test.v \
                vcx/tests/net_dtls_test.v \
                vcx/tests/net_real_socket_test.v \
                vcx/tests/a2a_real_test.v

# `-d cx_db_sqlite -d cx_db_redis` — the default build carries these DB
# engines (see vcx/Makefile CX_ENGINES), so the suite compiles with the same
# gates: the engine tests and the engine-dependent conformance fixtures
# (conformance/stdlib/db.cxd) run against what `make build` actually ships.
test: build-dev conform
	@$(V) -cc cc -gc e -d cx_db_sqlite -d cx_db_redis test vcx/tests/ || { \
	  echo "── suite failed under -j; serial retry of the known real-socket contention lanes ──"; \
	  $(V) -cc cc -gc e -d cx_db_sqlite -d cx_db_redis test $(SERIAL_RETRY); }

## conform      Run the conformance corpus against the built cx binary.
conform: build
	$(MAKE) -C vcx conform

## guide        Render docs/guide/ from docs-src/canonical/ (playground wasm
##              ships pre-built under docs/guide/playground/).
guide: build
	$(CURDIR)/vcx/target/cx --allow-read --allow-write scripts/gen_guide/guide_build.cx
	@echo "guide: rendered docs/guide/"

## guide-clean  Remove the rendered guide.
guide-clean:
	rm -rf docs/guide

## clean        Remove build artifacts.
clean:
	$(MAKE) -C vcx clean

## help         List targets.
help:
	@grep -E '^## ' $(firstword $(MAKEFILE_LIST)) | sed 's/^## /  /'
