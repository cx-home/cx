NVIM_SITE    := $(HOME)/.local/share/nvim/site
PARSER_DIR   := $(NVIM_SITE)/parser
QUERY_DIR    := $(NVIM_SITE)/queries/cx
FTPLUGIN_DIR := $(NVIM_SITE)/ftplugin

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
	cc -shared -fPIC -I src -o /tmp/cx.so src/parser.c

# Refresh the committed prebuilt parser libs at ABI 14 (run after a grammar
# change, then commit). The .dylib uses the same cc path. The wasm is built for
# web-tree-sitter consumers; web-tree-sitter accepts ABI 15, so it may lag at 15
# until a tree-sitter toolchain that emits ABI-14 wasm without re-generating is
# available — it is NOT a Neovim consumer, so it does not cause the nvim crash.
build-artifacts:
	tree-sitter generate --abi $(TS_ABI)
	cc -shared -fPIC -I src -o cx.dylib src/parser.c

install-nvim: build
	mkdir -p $(PARSER_DIR) $(QUERY_DIR) $(FTPLUGIN_DIR)
	cp /tmp/cx.so $(PARSER_DIR)/cx.so
	cp queries/cx/highlights.scm $(QUERY_DIR)/highlights.scm
	cp queries/cx/injections.scm  $(QUERY_DIR)/injections.scm
	cp ../neovim/ftplugin/cx.vim $(FTPLUGIN_DIR)/cx.vim
	@echo "cx parser, queries, and ftplugin installed. Restart Neovim."
