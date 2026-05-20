# scripts/gen_docs/docs.mk — v0.7.0 documentation pipeline targets.
#
# Spliced into the top-level Makefile via `-include`. Re-running
# scripts/gen_docs/scaffold.sh writes _docs_staging/ (markdown, kept
# as a build artifact for diffing) and _site_staging/ (html, the
# canonical output). `docs-publish` promotes the html tree into
# docs/ for GitHub Pages serving (Pages source = /docs on main on
# the public cx-home/cx mirror). The markdown set is no longer
# promoted to docs/ — README.md plus the html docs are the only
# user-facing surface.

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
	@diff -ruN $(DOCS_OUT) $(SITE_STG) || true

## docs-publish      Promote $(SITE_STG)/ → $(DOCS_OUT)/ so GitHub
##                   Pages on cx-home/cx (source = /docs on main)
##                   serves the html tree. A .nojekyll file is
##                   dropped at the publish root so Pages skips
##                   Jekyll on our pre-built html.
docs-publish: docs
	@mkdir -p $(DOCS_OUT)
	@cp -R $(SITE_STG)/. $(DOCS_OUT)/
	@touch $(DOCS_OUT)/.nojekyll
	@echo "docs-publish: promoted $(SITE_STG)/ → $(DOCS_OUT)/"

## docs-clean        Wipe $(DOCS_STG)/ and $(SITE_STG)/.
docs-clean:
	@rm -rf $(DOCS_STG) $(SITE_STG)
	@echo "docs-clean: removed $(DOCS_STG)/ and $(SITE_STG)/"

## site              Alias for docs (one scaffold pass produces both
##                   markdown and html).
site: docs

## site-publish      Promote $(SITE_STG)/ → $(SITE_OUT)/ (gitignored,
##                   for local file:// preview without touching docs/).
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
