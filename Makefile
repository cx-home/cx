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
test: build-dev conform
	$(V) -cc cc -gc e test vcx/tests/

## conform      Run the conformance corpus against the built cx binary.
conform: build
	$(MAKE) -C vcx conform

## guide        Render docs/guide/ from docs-src/canonical/ (playground wasm
##              ships pre-built under docs/guide/playground/).
guide: build
	$(CURDIR)/vcx/target/cx scripts/gen_guide/guide_build.cx --allow-read --allow-write
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
