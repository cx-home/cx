# scripts/gen_docs/docs.mk — Make integration for the LLM onboarding layer
# (#938).
#
# Spliced into the top-level Makefile via `-include`. Provides:
#   docs        Regenerate docs/llm/ from docs-src/llm/ + the corpus.
#   docs-check  The DRIFT GATE: regenerate in memory and fail if anything
#               moved. In TEST_TARGETS; carries a tools/release-verify.sh row.
#   docs-diff   Show what regenerating would change.
#   docs-clean  Wipe docs/llm/.
#
# Why `docs/llm/` is COMMITTED while `docs/guide/` is gitignored: `cx primer`
# $embed_file()s docs/llm/primer.md at COMPILE time, so the file has to exist
# in a fresh clone before anything is built. That makes it a generated-and-
# committed artifact — the same arrangement as
# scripts/gen_guide/playground/playground.examples.js, and gated the same way,
# by a --check mode wired into the test matrix.
#
# The generator is a single CX program (dog-food: read -> [$cx:parse] ->
# replay via [$process:run] -> write, no Python, no shell). It needs
# read/write (the corpus and the output tree), subprocess (it EXECUTES every
# cited fixture against the binary — that is the whole point), and env (CX_BIN
# / TMPDIR).

DOCS_SRC := docs-src/llm
DOCS_OUT := docs/llm
DOCS_GEN := scripts/gen_docs
DOCS_CAPS := --allow-read --allow-write --allow-subprocess --allow-env

# The binary the generator replays fixtures against. The
# rebuild-only-when-a-.v-moved rule for this path is OWNED by
# scripts/gen_guide/guide.mk (included just above this file); redefining it
# here would make GNU make warn about overriding the recipe and silently drop
# one of the two. So this file declares the path and the opt-out, and depends
# on the rule already in scope.
DOCS_CX_BIN := $(CURDIR)/deps/cx-core-code/vcx/target/cx

ifeq ($(DOCS_SKIP_CX_BUILD),)
  DOCS_CX_DEP := $(DOCS_CX_BIN)
else
  DOCS_CX_DEP :=
endif

.PHONY: docs docs-check docs-diff docs-clean

## docs         Regenerate the LLM onboarding layer (docs/llm/: primer.md,
##                                   reference-*.md, playbook-*.md, llms.txt,
##                                   llms-full.txt) from
##                                   docs-src/llm/ templates + conformance fixtures.
##                                   Every cited fixture is EXECUTED and its output
##                                   re-recorded; a fixture the binary no longer
##                                   reproduces fails the run by name. The site's
##                                   landing page, docs/index.html, regenerates
##                                   with it (site-index, scripts/gen_site/site.mk;
##                                   RULED: RS-28, RS-30).
##
## Rebuild `cx` afterwards (`make build-vcx`) so `cx primer` carries the new text —
## the subcommand $embed_file()s docs/llm/primer.md at compile time.
##
## Verify the embed landed: `vcx/target/cx primer | diff - docs/llm/primer.md`.
## vcx's up-to-date guard decides by MTIME over BUILD_INPUT_DIRS (docs/llm is in
## the set), so a build that was already running when `make docs` rewrote the
## file can finish AFTER it and leave the guard satisfied by a binary that
## embedded the older text. `touch docs/llm/primer.md` then rebuild. Only
## tools/release-verify.sh's `cx primer == docs/llm/primer.md` row catches this
## otherwise — docs-check proves the FILE is fresh, never the EMBED.
docs: $(DOCS_CX_DEP) site-index
	@CX_BIN="$(DOCS_CX_BIN)" $(DOCS_CX_BIN) $(DOCS_CAPS) $(DOCS_GEN)/primer_build.cx
	@# PLAY-1: the playground picker is the primer's own fixtures, projected
	@# from the same template and corpus (scripts/gen_guide/playground/
	@# primer_examples.cx) — regenerated here so a fixture change moves both.
	@$(DOCS_CX_BIN) --allow-read --allow-write scripts/gen_guide/playground/primer_examples.cx
	# #954: refresh the README's self-reported CX-share badge alongside the
	# docs layer (Linguist can't count CX until cx-tooling's tooling/linguist/ upstreams).
	@$(DOCS_CX_BIN) --allow-read --allow-write --allow-subprocess scripts/lang_stats.cx

## docs-check   DRIFT GATE. Regenerates the layer without writing and fails if
##                                   (a) any cited fixture's live output no longer
##                                   matches what the fixture records, (b) the
##                                   committed docs/llm/ differs from a fresh
##                                   generation, or (c) docs/llm/ holds a file no
##                                   [output] entry claims (an ORPHAN — a document
##                                   the freshness contract cannot reach). (a)/(b):
##                                   run `make docs` and commit the result in the
##                                   same change. (c): delete the file, or declare it.
##                                   The landing page docs/index.html is held the
##                                   same way (site-index-check: its fixtures
##                                   replayed, its links declared, no drift),
##                                   and so is the playground's picker,
##                                   scripts/gen_guide/playground/playground.primer.js
##                                   (PLAY-1: the primer's fixtures, projected).
docs-check: $(DOCS_CX_DEP) site-index-check
	@CX_BIN="$(DOCS_CX_BIN)" $(DOCS_CX_BIN) $(DOCS_CAPS) $(DOCS_GEN)/primer_build.cx --check
	@$(DOCS_CX_BIN) --allow-read --allow-write scripts/gen_guide/playground/primer_examples.cx --check

## docs-diff    Preview what `make docs` would change under docs/llm/.
docs-diff: $(DOCS_CX_DEP)
	@stage="$$(mktemp -d -t cxdocs-diff.XXXXXX)"; \
	 cp -R $(DOCS_OUT) "$$stage/before" 2>/dev/null || mkdir -p "$$stage/before"; \
	 CX_BIN="$(DOCS_CX_BIN)" $(DOCS_CX_BIN) $(DOCS_CAPS) $(DOCS_GEN)/primer_build.cx >/dev/null; \
	 diff -ruN "$$stage/before" $(DOCS_OUT) || true; \
	 rm -rf "$$stage"

## docs-clean   Wipe docs/llm/ (regenerate with `make docs`).
docs-clean:
	@rm -rf $(DOCS_OUT)
	@echo "docs-clean: removed $(DOCS_OUT)/"
