# scripts/gen_guide/guide.mk — Make integration for the
# CX Data and Code Language Guide.
#
# Spliced into the top-level Makefile via `-include`. Provides:
#   guide       Build docs/guide/ from
#                                    docs-src/canonical/.
#   guide-diff  Show what publishing would change.
#   guide-clean Wipe docs/guide/.
#
# Rendering pipeline (see scaffold.sh): cx eval scripts/gen_guide/build.cx
# is the engine that turns .cxd sections into CX render-trees; cx --xml
# projects to HTML; Python does chrome wrap + anchor resolution only.
# A section whose .cxd source can't be parsed/rendered by cx falls back
# to a banner + verbatim source so the page still lands and the failure
# is visible.

GUIDE_SRC := docs-src/canonical
GUIDE_OUT := docs/guide
GUIDE_GEN := scripts/gen_guide

.PHONY: guide \
        guide-diff \
        guide-clean

## guide        Build docs/guide/ from
##                                   docs-src/canonical/.
guide: build-playground-wasm-for-guide
	@bash $(GUIDE_GEN)/scaffold.sh

# Ensure the playground wasm is built with ASYNCIFY=1 + SINGLE_FILE=1:
#
#   - ASYNCIFY=1: lets bare wall-clock [?sleep DUR] yield through the
#     JS event loop on the main browser thread (ADR 0039 D8). Without
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
	@# Build BOTH playground wasm artifacts per ADR 0040 D9.1:
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
##                                   Per ADR 0040 D9.4 — this is the
##                                   playground mode (c) where :par
##                                   actually parallelises.
##                                   Per ADR 0065 — `[?http-service]`
##                                   with `[block true]` + `[$serve-file]`
##                                   replaces the historical V/veb shim.
.PHONY: guide-http
guide-http: guide
	@echo "[guide-http] starting cx-guide-serve via cx eval"
	@vcx/target/cx eval scripts/gen_guide/guide_serve.cx

## guide-diff   Preview what re-running the
##                                   target would change in docs/guide/.
guide-diff:
	@stage="$$(mktemp -d -t cxguide-diff.XXXXXX)"; \
	 cp -R $(GUIDE_OUT) "$$stage/before" 2>/dev/null || mkdir -p "$$stage/before"; \
	 bash $(GUIDE_GEN)/scaffold.sh >/dev/null; \
	 diff -ruN "$$stage/before" $(GUIDE_OUT) || true; \
	 rm -rf "$$stage"

## guide-clean  Wipe docs/guide/.
guide-clean:
	@rm -rf $(GUIDE_OUT)
	@echo "guide-clean: removed $(GUIDE_OUT)/"
