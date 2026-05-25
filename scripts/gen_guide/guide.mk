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

# Ensure the playground wasm is built with ASYNCIFY=1 (so file:// can
# do wall-clock [?sleep]) + SINGLE_FILE=0 (so the loader fetches the
# .wasm sibling instead of base64-decoding an inline blob that some
# browsers reject — ADR 0039 D8). The scaffold.sh script then copies
# the freshly built artifacts into docs/guide/wasm/. Idempotent —
# emcc skips re-link when sources are unchanged.
.PHONY: build-playground-wasm-for-guide
build-playground-wasm-for-guide:
	@SINGLE_FILE=0 ASYNCIFY=1 ./scripts/wasm/build_libcx_wasm.sh

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
