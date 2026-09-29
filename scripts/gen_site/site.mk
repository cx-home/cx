# scripts/gen_site/site.mk — Make integration for cxhome.org, the ONE site
# (RULED: RS-28, D57a, D58a, RS-30, D86b, D51d).
#
# Spliced into the top-level Makefile via `-include`, after the guide and the
# LLM layer it assembles. Provides:
#
#   site              Build the guide (`make guide`), then assemble the site into
#                     site/ (gitignored) with publish.sh's old map — the guide at
#                     the root (its home page as guide.html), the landing page
#                     as index.html, docs/llm/ under llm/ with llms.txt and
#                     llms-full.txt at the root too, the dev/ door, install, CNAME
#                     and .nojekyll. The Pages workflow
#                     (.github/workflows/site.yml) uploads exactly this directory.
#   site-check        Render the guide through guide-render-gate (so it can run
#                     inside `make test`'s -j block beside that step without two
#                     renders writing docs/guide/ at once), assemble, and list
#                     site/ against docs-src/site/manifest.cxd: a declared file
#                     missing, or an assembled file no line declares, fails it.
#   site-index        Regenerate the landing page docs/index.html (tracked) from
#                     docs-src/site/index.md. `make docs` runs it.
#   site-index-check  The landing page's DRIFT step: every cited fixture replayed
#                     and verified, every {{PAGE:…}} link a file the manifest
#                     declares, and the committed page byte-identical to a fresh
#                     generation. `make docs-check` runs it.
#
# The playground's wasm engine is not built here: `make guide` copies dist/wasm/
# when it exists and says so when it does not (emcc builds it: `make guide-wasm`).
# site-check lists its five files as declared-but-optional, and as REQUIRED
# under CX_SITE_REQUIRE_WASM=1, which the Site workflow sets once its pinned
# emsdk has built them (PLAY-1; docs-src/site/manifest.cxd's required-when=).

SITE_GEN    := scripts/gen_site
SITE_CX_BIN := $(CURDIR)/deps/cx-core-code/vcx/target/cx
SITE_CAPS   := --allow-read --allow-write --allow-subprocess --allow-env

ifeq ($(SITE_SKIP_CX_BUILD),)
  SITE_CX_DEP := $(SITE_CX_BIN)
else
  SITE_CX_DEP :=
endif

.PHONY: site site-check site-index site-index-check

site: guide
	@$(SITE_CX_BIN) --allow-read --allow-write $(SITE_GEN)/site_assemble.cx

site-check: guide-render-gate
	@$(SITE_CX_BIN) --allow-read --allow-write $(SITE_GEN)/site_assemble.cx
	@$(SITE_CX_BIN) --allow-read --allow-write --allow-env $(SITE_GEN)/site_assemble.cx --check

site-index: $(SITE_CX_DEP)
	@CX_BIN="$(SITE_CX_BIN)" $(SITE_CX_BIN) $(SITE_CAPS) $(SITE_GEN)/site_build.cx

site-index-check: $(SITE_CX_DEP)
	@CX_BIN="$(SITE_CX_BIN)" $(SITE_CX_BIN) $(SITE_CAPS) $(SITE_GEN)/site_build.cx --check
