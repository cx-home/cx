# scripts/gen_guide/guide.mk — Make integration for the
# CX Data and Code Language Guide.
#
# Spliced into the top-level Makefile via `-include`. Provides:
#   gen-cx-data-language-guide       Build docs/guide/ from
#                                    docs-src/canonical/.
#   gen-cx-data-language-guide-diff  Show what publishing would change.
#   gen-cx-data-language-guide-clean Wipe docs/guide/.
#
# When the v0.8.0 cx binary is not yet runnable (CXL surface from
# ADR 0027 not implemented), the target still completes: it stages
# CSS / JS / logo / search index shell and writes fallback HTML
# pages whose body is the verbatim .cxd source. The full render
# materializes the moment cx is ready — no Make changes required.

GUIDE_SRC := docs-src/canonical
GUIDE_OUT := docs/guide
GUIDE_GEN := scripts/gen_guide

.PHONY: gen-cx-data-language-guide \
        gen-cx-data-language-guide-diff \
        gen-cx-data-language-guide-clean

## gen-cx-data-language-guide        Build docs/guide/ from
##                                   docs-src/canonical/.
gen-cx-data-language-guide:
	@bash $(GUIDE_GEN)/scaffold.sh

## gen-cx-data-language-guide-diff   Preview what re-running the
##                                   target would change in docs/guide/.
gen-cx-data-language-guide-diff:
	@stage="$$(mktemp -d -t cxguide-diff.XXXXXX)"; \
	 cp -R $(GUIDE_OUT) "$$stage/before" 2>/dev/null || mkdir -p "$$stage/before"; \
	 bash $(GUIDE_GEN)/scaffold.sh >/dev/null; \
	 diff -ruN "$$stage/before" $(GUIDE_OUT) || true; \
	 rm -rf "$$stage"

## gen-cx-data-language-guide-clean  Wipe docs/guide/.
gen-cx-data-language-guide-clean:
	@rm -rf $(GUIDE_OUT)
	@echo "gen-cx-data-language-guide-clean: removed $(GUIDE_OUT)/"
