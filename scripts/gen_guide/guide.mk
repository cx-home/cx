# scripts/gen_guide/guide.mk — Make integration for the
# CX Data and Code Language Guide.
#
# Spliced into the top-level Makefile via `-include`. Provides:
#   guide       Build docs/guide/ from
#                                    docs-src/canonical/.
#   guide-diff  Show what publishing would change.
#   guide-clean Wipe docs/guide/.
#
# Rendering pipeline: scripts/gen_guide/guide_build.cx is a single CX
# program (run via `cx <file>`, CLI default-eval) that reads
# docs-src/canonical/ and emits the whole docs/guide/ site —
# render = .cx, dogfooded end to end (read → [$cx:parse] → transform →
# [$xml:emit] → [$io:write-file]; no subprocess, no Python). It needs
# --allow-read / --allow-write capability grants.

GUIDE_SRC := docs-src/canonical
GUIDE_OUT := docs/guide
GUIDE_GEN := scripts/gen_guide

# The cx binary the guide render runs, rebuilt (dev, fast) ONLY when a vcx/*.v
# source is newer than it — real up-front, only-when-needed dependency tracking.
# A clean tree renders instantly: no per-run -prod recompile ("hang"), no V
# compile notices. Opt OUT of the rebuild check with
# `make guide GUIDE_SKIP_CX_BUILD=1` (reuse the binary as-is); to force a fresh
# optimized binary, run `make build-vcx` first.
GUIDE_CX_BIN  := $(CURDIR)/vcx/target/cx
GUIDE_CX_SRCS := $(shell find $(CURDIR)/vcx/cx $(CURDIR)/vcx/code $(CURDIR)/vcx/cmd -name '*.v' 2>/dev/null)

$(GUIDE_CX_BIN): $(GUIDE_CX_SRCS)
	@$(MAKE) --no-print-directory build-vcx-dev

ifeq ($(GUIDE_SKIP_CX_BUILD),)
  GUIDE_CX_DEP := $(GUIDE_CX_BIN)
else
  GUIDE_CX_DEP :=
endif

.PHONY: guide \
        guide-wasm \
        guide-diff \
        guide-clean \
        guide-check \
        guide-snippets-check \
        check-retired-surface \
        playground-examples-regen

## guide        Build docs/guide/ from docs-src/canonical/. The "Standard
##                                   library" / "Reference" pages are projected
##                                   from co-located [module-doc]/[fn-doc] +
##                                   [directive-doc]/[syntax-doc]; gate them with
##                                   `make guide-check` + `make directive-docs-check`.
##
## The cx binary is rebuilt (dev) only when a vcx/*.v source changed — never a
## per-run -prod recompile. The playground wasm is NOT rebuilt (guide_build.cx
## copies the existing dist/wasm/ via copy-if); use `make guide-wasm` when the
## engine changed and the playground must reflect it. The render's own stdout
## (write-file results) is discarded; real errors still surface.
guide: $(GUIDE_CX_DEP)
	@$(GUIDE_CX_BIN) $(GUIDE_GEN)/guide_build.cx --allow-read --allow-write >/dev/null
	@echo "guide: built $(GUIDE_OUT)/ via $(GUIDE_GEN)/guide_build.cx (render = .cx)"

## guide-snippets-check  Docs-example gate (#425): run every
##                                   [example lang=cx] snippet in
##                                   docs-src/canonical/sections/*.cxd against
##                                   the built binary (no capability grants;
##                                   [example … check=none] opts a
##                                   deliberately-illustrative fragment out).
##                                   Nonzero exit on any failing snippet or any
##                                   unparseable section file.
guide-snippets-check: $(GUIDE_CX_DEP)
	@CX_BIN="$(GUIDE_CX_BIN)" $(GUIDE_CX_BIN) $(GUIDE_GEN)/snippet_check.cx \
	  --allow-read --allow-write --allow-subprocess --allow-env
	@$(GUIDE_GEN)/check_retired_surface.sh

## check-retired-surface  Companion scan to the snippet gate: rejects
##                                   retired forms that PARSE as something
##                                   else (`:table[`, spaced `:T` body
##                                   annotations, `:T[]` arrays) and so slip
##                                   through a parse-only gate. Waive a
##                                   deliberate retired-form panel with a
##                                   `retired-ok` marker on the line.
.PHONY: check-retired-surface
check-retired-surface:
	@$(GUIDE_GEN)/check_retired_surface.sh

## playground-examples-regen  Regenerate + re-audit
##                                   scripts/gen_guide/playground/
##                                   playground.examples.js from its generator
##                                   (gen_examples.py: every entry CLI-audited
##                                   against the current binary, then the file
##                                   is rewritten). Run after any engine/syntax
##                                   change the playground must reflect.
playground-examples-regen: $(GUIDE_CX_DEP)
	@python3 $(GUIDE_GEN)/playground/gen_examples.py

## guide-wasm    Rebuild the playground wasm AND regenerate the playground
##                                   examples, then render the guide. Use when
##                                   the cx engine changed and the in-browser
##                                   playground must reflect it.
##
## COUPLING INVARIANT: the shipped wasm bundle (dist/wasm/*, staged to
## docs/guide/wasm/) and playground.examples.js (staged to
## docs/guide/playground/) must always be of the same syntax era — the
## examples run inside that wasm engine. So the wasm is never rebuilt
## without regenerating the examples in the same invocation; `guide` runs
## from the recipe (not the prerequisite list) so the render always stages
## AFTER both, even under `make -j`. Drift between the generator and the
## checked-in examples.js is gated by `make verify-playground-examples`
## (top-level Makefile, in TEST_TARGETS next to guide-check).
guide-wasm: build-playground-wasm-for-guide playground-examples-regen
	@$(MAKE) --no-print-directory guide

## guide-check  Gate the co-located stdlib docs against drift
##                                   (presence parity, purity agreement,
##                                   examples backed by the conformance
##                                   corpus). CX-native; defined in the
##                                   top-level Makefile.

# Ensure the playground wasm is built with ASYNCIFY=1 + SINGLE_FILE=1:
#
#   - ASYNCIFY=1: lets bare wall-clock [?sleep DUR] yield through the
# JS event loop on the main browser thread. Without
#     this, file:// playgrounds can only run :mock examples.
#
#   - SINGLE_FILE=1: base64-embeds the .wasm payload inside libcx.js.
#     The docs/guide deployment is designed to work under both http://
#     and file:// — and Chrome/Edge refuse a `fetch()` of sibling
#     file:// resources from a `null`-origin page, so a separate
#     libcx.wasm sibling can't be loaded under file://. SINGLE_FILE
#     trades ~3-4MB extra .js size (libcx.js grows to ~5.6MB with
#     ASYNCIFY) for a self-contained playground that opens by double-
#     click. Browsers that hit the historical "unknown type form: 61"
#     base64-decode bug were workaround'd elsewhere; ASYNCIFY builds
#     appear unaffected.
#
# Idempotent — emcc skips re-link when sources are unchanged.
.PHONY: build-playground-wasm-for-guide
build-playground-wasm-for-guide:
	@# Build BOTH playground wasm artifacts:
	@#   libcx-async.{js,wasm}    — single-threaded ASYNCIFY runtime.
	@#                              Loaded by playground when the host
	@#                              is NOT cross-origin-isolated (file://,
	@#                              GitHub Pages, generic HTTP without
	@#                              COOP/COEP). :par produces correct
	@#                              output but doesn't accelerate.
	@#   libcx-pthreads.{js,wasm} — ASYNCIFY + emscripten pthreads.
	@#                              Loaded by playground when
	@#                              `crossOriginIsolated === true`
	@#                              (the make guide-http mode, which
	@#                              ships COOP+COEP headers). :par runs
	@#                              on real OS threads via Web Workers
	@#                              with SharedArrayBuffer-backed
	@#                              linear memory.
	@# libcx-async ships as a single self-contained .js (SINGLE_FILE=1)
	@# so all three playground modes Just Work:
	@#   - file:// double-click: Chrome blocks fetch() of sibling file://
	@#     resources from a null-origin page, so a separate .wasm sibling
	@#     can't load. Inline base64 sidesteps the fetch entirely.
	@#     (The historical "base64-decode bug" comment in earlier
	@#     revisions was stale — verified working 2026-05-25.)
	@#   - GitHub Pages / generic HTTP: one file, no MIME-type pitfalls.
	@#   - HTTP fallback when COOP+COEP missing: same single file.
	@# libcx-pthreads keeps SINGLE_FILE=0 because emscripten's pthread
	@# runtime needs the separate .wasm to spawn Worker threads sharing
	@# the same wasm module instance via SharedArrayBuffer.
	@SINGLE_FILE=1 ASYNCIFY=1 PTHREADS=0 OUT_NAME=libcx-async    ./scripts/wasm/build_libcx_wasm.sh
	@SINGLE_FILE=0 ASYNCIFY=1 PTHREADS=1 OUT_NAME=libcx-pthreads ./scripts/wasm/build_libcx_wasm.sh

## guide-http   Build docs/guide/ + boot the dog-food CX HTTP static
##                                   server (scripts/gen_guide/guide_serve.cx)
##                                   with COOP+COEP+CORP headers so the
##                                   pthreads wasm runtime can load.
## Per this is the
##                                   playground mode (c) where :par
##                                   actually parallelises.
## Per `[?http-service]`
##                                   with `[block true]` + `[$serve-file]`
##                                   replaces the historical V/veb shim.
.PHONY: guide-http
guide-http: guide
	@echo "[guide-http] starting cx-guide-serve via cx"
	@vcx/target/cx scripts/gen_guide/guide_serve.cx

## guide-diff   Preview what re-running the
##                                   target would change in docs/guide/.
## Honors GUIDE_SKIP_CX_BUILD=1 (reuse the existing binary), same as `guide`.
ifeq ($(GUIDE_SKIP_CX_BUILD),)
guide-diff: build-vcx
else
guide-diff:
endif
	@stage="$$(mktemp -d -t cxguide-diff.XXXXXX)"; \
	 cp -R $(GUIDE_OUT) "$$stage/before" 2>/dev/null || mkdir -p "$$stage/before"; \
	 $(CURDIR)/vcx/target/cx $(GUIDE_GEN)/guide_build.cx --allow-read --allow-write >/dev/null; \
	 diff -ruN "$$stage/before" $(GUIDE_OUT) || true; \
	 rm -rf "$$stage"

## guide-clean  Wipe docs/guide/.
guide-clean:
	@rm -rf $(GUIDE_OUT)
	@echo "guide-clean: removed $(GUIDE_OUT)/"
