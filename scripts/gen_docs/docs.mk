# scripts/gen_docs/docs.mk — v0.7.0 documentation pipeline targets.
#
# Spliced into the top-level Makefile via `-include`. Re-running
# scripts/gen_docs/scaffold.sh writes _docs_staging/ (markdown) and
# _site_staging/ (html). `docs-publish` promotes staging → docs/;
# `site-publish` promotes staging → _site/ (which stays gitignored).

DOCS_STG     := _docs_staging
SITE_STG     := _site_staging
DOCS_OUT     := docs
SITE_OUT     := _site
DOCS_SRC     := docs-src
DOCS_GEN     := scripts/gen_docs

.PHONY: docs docs-diff docs-publish docs-clean \
        site site-publish site-clean \
        docs-all docs-check

## docs              Build markdown into $(DOCS_STG)/. Depends on the
##                   repo's own cx binary so docs always build against
##                   the source tree they describe.
docs: build-vcx
	bash $(DOCS_GEN)/scaffold.sh

## docs-diff         Summarize what docs-publish would change.
docs-diff: docs
	@diff -ruN $(DOCS_OUT) $(DOCS_STG) || true

## docs-publish      Promote $(DOCS_STG)/ → $(DOCS_OUT)/.
docs-publish: docs
	@mkdir -p $(DOCS_OUT)
	@cp -R $(DOCS_STG)/. $(DOCS_OUT)/
	@echo "docs-publish: promoted $(DOCS_STG)/ → $(DOCS_OUT)/"

## docs-clean        Wipe $(DOCS_STG)/.
docs-clean:
	@rm -rf $(DOCS_STG)
	@echo "docs-clean: removed $(DOCS_STG)/"

## site              Build html into $(SITE_STG)/ (XML stand-in until
##                   CXL HTML emit ships — see design §12 #3).
site: docs

## site-publish      Promote $(SITE_STG)/ → $(SITE_OUT)/ (gitignored).
site-publish: site
	@mkdir -p $(SITE_OUT)
	@cp -R $(SITE_STG)/. $(SITE_OUT)/
	@echo "site-publish: promoted $(SITE_STG)/ → $(SITE_OUT)/"

## site-clean        Wipe $(SITE_STG)/.
site-clean:
	@rm -rf $(SITE_STG)
	@echo "site-clean: removed $(SITE_STG)/"

## docs-all          docs + site in one shot (same scaffold pass).
docs-all: docs

## docs-check        Link-check + example-drift + rubric (no writes).
##                   Thinnest-slice stub — wires up in v0.7.0 build out.
docs-check:
	@echo "docs-check: stub (pending v0.7.0 build out)"
