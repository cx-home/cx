NVIM_SITE    := $(HOME)/.local/share/nvim/site
PARSER_DIR   := $(NVIM_SITE)/parser
QUERY_DIR    := $(NVIM_SITE)/queries/cx
FTPLUGIN_DIR := $(NVIM_SITE)/ftplugin
INDENT_DIR   := $(NVIM_SITE)/indent

# macOS: build the parser universal (arm64 + x86_64) — Rosetta Neovims
# abort loading a single-arch .so of the other architecture (#420).
DARWIN_ARCHES := $(if $(filter Darwin,$(shell uname -s)),-arch arm64 -arch x86_64,)

# macOS: cc's automatic ad-hoc linker signing does NOT survive universal
# (fat) output — the arm64 slice ships UNSIGNED, and on Apple Silicon the
# kernel SIGKILLs any process that dlopens it (nvim dies with "Code
# Signature Invalid", taking its spawning TUI — e.g. lazygit — down with
# it; #883, the recurring per-release editor kill). Ad-hoc sign every
# produced parser binary explicitly.
DARWIN_SIGN := $(if $(filter Darwin,$(shell uname -s)),codesign -f -s -,true)

.PHONY: build build-artifacts install-nvim

# Pin ABI 14: tree-sitter CLI >= 0.26 defaults to ABI 15, whose parser binary is
# NOT loadable by Neovim 0.11's bundled runtime (it HANGS / segfaults despite
# both reporting max ABI 15). ABI 14 loads in every consumer (Neovim 0.10/0.11
# min 13/max 15, Helix, web-tree-sitter) and a highlighting grammar needs
# nothing ABI 15 adds. Keep src/parser.c + cx.dylib + tree-sitter-cx.wasm at 14.
TS_ABI := 14

# Generate the parser at ABI 14, then compile it DIRECTLY with cc.
# DO NOT use `tree-sitter build` here: with CLI >= 0.26 it silently RE-generates
# at the default ABI 15 — overriding `generate --abi 14` on the line above — and
# the resulting parser hangs Neovim's bundled runtime (the bug that shipped a
# crashing nvim parser). Compiling the already-ABI-14 src/parser.c with cc keeps
# the shipped binary at ABI 14. (No external scanner — src/parser.c is the whole
# grammar; `cc -shared` produces a loadable module on both macOS and Linux.)
build:
	tree-sitter generate --abi $(TS_ABI)
	cc -shared -fPIC $(DARWIN_ARCHES) -I src -o /tmp/cx.so src/parser.c
	$(DARWIN_SIGN) /tmp/cx.so

# Refresh the committed prebuilt parser libs at ABI 14 (run after a grammar
# change, then commit). The .dylib uses the same cc path. The wasm is compiled
# DIRECTLY with emcc from the already-ABI-14 src/parser.c (same reasoning as
# the cc path above: `tree-sitter build --wasm` silently RE-generates at the
# CLI's default ABI 15) — a SIDE_MODULE exporting `_tree_sitter_cx`, which is
# exactly what web-tree-sitter dlopens. Verified loading + ABI 14 via
# web-tree-sitter 0.26 (I1 epoch tooling pass, 2026-08-06); the historical
# "wasm may lag at 15" note is discharged.
build-artifacts:
	tree-sitter generate --abi $(TS_ABI)
	cc -shared -fPIC -I src -o cx.dylib src/parser.c
	$(DARWIN_SIGN) cx.dylib
	emcc -o tree-sitter-cx.wasm -Os -fno-exceptions -fvisibility=hidden \
	  -s SIDE_MODULE=2 -s TOTAL_MEMORY=33554432 \
	  -s NODEJS_CATCH_EXIT=0 -s NODEJS_CATCH_REJECTION=0 \
	  -s "EXPORTED_FUNCTIONS=['_tree_sitter_cx']" \
	  -I src src/parser.c

install-nvim: build
	mkdir -p $(PARSER_DIR) $(QUERY_DIR) $(FTPLUGIN_DIR) $(INDENT_DIR)
	rm -f $(PARSER_DIR)/cx.so   # fresh inode: macOS caches signature validity per vnode — overwriting in place gets running/future dlopens SIGKILLed even with a valid signature (#883)
	cp /tmp/cx.so $(PARSER_DIR)/cx.so
	cp queries/cx/highlights.scm $(QUERY_DIR)/highlights.scm
	cp queries/cx/injections.scm  $(QUERY_DIR)/injections.scm
	cp ../neovim/ftplugin/cx.vim $(FTPLUGIN_DIR)/cx.vim
	cp ../neovim/indent/cx.vim $(INDENT_DIR)/cx.vim
	@if command -v nvim >/dev/null 2>&1; then \
	  nvim --headless --clean '+lua assert(pcall(vim.treesitter.language.add, "cx", {path="$(PARSER_DIR)/cx.so"})); io.write("parser load-proof: OK\n")' '+qa!' \
	    || { echo "parser load-proof FAILED — the installed cx.so is not loadable (see #883); NOT safe to open .cx files"; exit 1; }; \
	else \
	  echo "nvim not on PATH — skipped the load-proof"; \
	fi
	@echo "cx parser, queries, ftplugin, and indent installed. Restart Neovim."
