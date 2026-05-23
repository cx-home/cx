# scripts/gen_guide/guide.mk — Make integration for the
# CX Data and Code Language Guide.
#
# Spliced into the top-level Makefile via `-include`. Provides:
#   gen-cx-data-language-guide       Build docs/guide/ from
#                                    docs-src/canonical/.
#   gen-cx-data-language-guide-diff  Show what publishing would change.
#   gen-cx-data-language-guide-clean Wipe docs/guide/.
#
# Rendering is Python-side (scripts/gen_guide/_render.py) — the
# target has no dependency on the v0.8.0 cx binary. See _render.py
# header for the rationale (triple-quoted body-binding in current cx
# doesn't auto-unwrap, and the .cxd surface uses triple-quoted bodies
# pervasively, so doing the parse in Python is cleaner than fighting
# the body-binding shape).

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
