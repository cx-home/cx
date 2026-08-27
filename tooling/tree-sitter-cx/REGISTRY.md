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

---

## Submission status — READ BY THE RELEASE GATE

`scripts/check_editor_distribution.cx` (a `tools/release-verify.sh` row) reads
this table on every release. Each submission must either name the release it was
last submitted for, or carry an explicit deferral with a reason. A blank row
FAILS the release — that is the point: these two PRs went unnoticed for four
days after their payloads were prepared (#874), because nothing anywhere
recorded that they were owed.

`submitted-for` takes a version (`0.17.0`). `deferred` takes a reason in prose.
Exactly one of the two per row; a row with both, or neither, fails.

| submission | submitted-for | deferred |
|---|---|---|
| nvim-treesitter | — | branch READY on the fork (eptx/nvim-treesitter `add-cx-parser`, pinned to mirror ee8fffb54; their own check-parsers/check-queries/ts_query_ls all green; PR body staged in scratch + reproducible from the branch) — BLOCKED UPSTREAM: the repo has GitHub interaction limits set to collaborators-only (the compare page says so verbatim; measured: zero non-maintainer PRs since 2026-07, so it is standing, not a 24h window). Not a token or account problem — no outsider can open a PR by ANY route until they lift it. Retry `gh pr create -R nvim-treesitter/nvim-treesitter --head eptx:add-cx-parser` periodically, or ask in their Matrix room (#nvim-treesitter:matrix.org, their documented channel) for a maintainer to take the branch. Meanwhile the in-repo `{ dir = '…/cx/tooling/neovim' }` path serves users — the registry entry is reach, not function. |
| mason | 0.17.0 | — |

When a submission lands, replace its `deferred` cell with `—` and put the
version in `submitted-for`. Do not delete a row: the gate counts rows, so a
deleted obligation reads as no obligation.
