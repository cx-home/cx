NVIM_SITE    := $(HOME)/.local/share/nvim/site
PARSER_DIR   := $(NVIM_SITE)/parser
QUERY_DIR    := $(NVIM_SITE)/queries/cx
FTPLUGIN_DIR := $(NVIM_SITE)/ftplugin

.PHONY: build install-nvim

# Pin ABI 14: tree-sitter CLI >= 0.26 defaults to ABI 15, whose parser binary is
# NOT loadable by Neovim 0.11's bundled runtime (it segfaults on load despite
# both reporting max ABI 15). ABI 14 loads in every consumer (Neovim 0.10/0.11
# min 13/max 15, Helix, web-tree-sitter) and a highlighting grammar needs
# nothing ABI 15 adds. Keep src/parser.c + cx.dylib + tree-sitter-cx.wasm at 14.
TS_ABI := 14

build:
	tree-sitter generate --abi $(TS_ABI)
	tree-sitter build --output /tmp/cx.so

install-nvim: build
	mkdir -p $(PARSER_DIR) $(QUERY_DIR) $(FTPLUGIN_DIR)
	cp /tmp/cx.so $(PARSER_DIR)/cx.so
	cp queries/cx/highlights.scm $(QUERY_DIR)/highlights.scm
	cp queries/cx/injections.scm  $(QUERY_DIR)/injections.scm
	cp ../neovim/ftplugin/cx.vim $(FTPLUGIN_DIR)/cx.vim
	@echo "cx parser, queries, and ftplugin installed. Restart Neovim."
