# Changelog

## 0.12.0

- Packaging: the extension is now bundled with esbuild — the packaged
  `.vsix` is self-contained (`out/extension.js` includes the LSP client
  glue) and activates without `node_modules`.
- Engine floor raised to VS Code 1.82 (required by vscode-languageclient 9).
- Grammar: added the dynamic-construction directive family
  (`element` / `attr` / `entry` / `name` / `quote` / `unquote` /
  `splice` / `eval` / `meta`), directive + module-call highlighting
  inside element bodies and at top level, dotted atoms and the terminal
  `.*` atom glob, triple-quoted / raw-triple-quoted strings, and
  lexicon-accurate numeric / datetime / duration / period literals.
  Retired infix predicate operators are no longer highlighted; a
  body-position `#` now reads as the line comment the parser makes it.
- Snippets: `path` and `code` emit the current surface
  (`//name[= $_@attr value]`, `[code lang=… [|…|]]`).
- Watcher covers `**/*.{cx,cxd,cxs}` (`.cxl` retired, `.cxd` added).
