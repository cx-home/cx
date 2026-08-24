# Registry submissions — ready-to-send payloads (#874)

Prepared at the 0.16 release cut. Both submissions are external-repo PRs that
depend on the PUBLIC mirror (`cx-home/cx`) being current; submit after
the release publishes. Neither changes anything in this repo.

## 1. nvim-treesitter (parser registry)

PR against `nvim-treesitter/nvim-treesitter` (master), adding to
`lua/nvim-treesitter/parsers.lua` (alphabetical position):

```lua
list.cx = {
  install_info = {
    url = 'https://github.com/cx-home/cx',
    location = 'tooling/tree-sitter-cx',
    files = { 'src/parser.c' },
    branch = 'main',
  },
  filetype = 'cx',
  maintainers = { '@cx-home' },
}
```

Plus queries: nvim-treesitter vendors queries in its own tree — copy
`tooling/tree-sitter-cx/queries/cx/{highlights,injections}.scm` to the
PR's `queries/cx/`. Their CI compiles the grammar from the URL+location
above; the committed `src/parser.c` must be current (`make -C
tooling/tree-sitter-cx` regenerates).

## 2. mason registry (language-server + CLI package)

PR against `mason-org/mason-registry`, new file `packages/cx/package.yaml`.
Mason resolves the release assets by their stable names from
`scripts/release.sh` (platform tarball carries the `cx` binary that
serves `cx lsp`):

```yaml
name: cx
description: CX — the data and code language. One binary carries the CLI, the language server (cx lsp), and libcx.
homepage: https://cxhome.org
licenses:
  - Apache-2.0
languages:
  - CX
categories:
  - LSP
  - Compiler
source:
  id: pkg:github/cx-home/cx@vX.Y.Z  # pin to the publishing release tag (version-literal-ok)
  asset:
    - target: darwin_arm64
      file: cx-darwin-arm64.tar.gz
bin:
  cx: cx
```

Linux targets join when the dockerized Linux release lane ships its
tarballs (same stable-name scheme, `cx-linux-x86_64.tar.gz`).

## Sequencing

1. Release publishes (Phase 2) → assets exist at
   `releases/latest/download/…`.
2. Submit both PRs (owner or a session with the owner's go — outward
   publication).
3. When merged: LazyVim users get `ensure_installed = { 'cx' }` for the
   grammar and `:MasonInstall cx` for the server; the in-repo
   `{ dir = '…/cx/tooling/neovim' }` path keeps working for
   from-source users.
