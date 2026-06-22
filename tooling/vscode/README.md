# CX Language — VS Code extension

Syntax highlighting + LSP (diagnostics, hover, completion, goto,
references, rename, formatting, outline, folding, smart selection,
signature help) + snippets for `.cx` / `.cxs` / `.cx` files.

## Highlights

- **CXPath as a value kind** (code.md §5.5) — `//user[@active=true]`
  highlights as a path; `name`, `count`, `matches`, etc. read as
  XPath 3.1 functions; the 13 standard axes (`ancestor::`,
  `descendant-or-self::`, etc.) are first-class.
- **Multi-arm `[?match]`** (code.md §8.2) — `[case PATTERN [where G]?
  BODY]`, `[when G BODY]`, `[else BODY]` clause-children tokenise as
  control keywords; the single-arm form's `[yield E]` clause too.
- **`[?modify]` pure-functional updates** (code.md §8.10) — the 11
  action clause-children (`[set]`, `[delete]`, `[using]`, `[rename]`,
  `[set-attr]`, `[delete-attr]`, `[append]`, `[prepend]`,
  `[insert-before]`, `[insert-after]`, `[replace]`) all colour as
  control keywords.
- **Atom literals** (code.md §3.6) — `:ok` / `:not-found` /
  `:running` highlight as `constant.other.atom`. Reserved names
  `:true` / `:false` / `:null` highlight as
  `constant.language.reserved` so the lex-time rejection is
  visually obvious.
- **`[?def]` module functions** (code.md §12.2) — `scope=public`,
  `[returns T]`, bare `pure` / `impure` modifiers, and per-parameter
  glued `$x::T` annotations all read as modifiers + type
  expressions. Type kinds (`string`, `int`, `atom`, `sequence`, …)
  and capitalized element-type names (`Person`, `Token`) are
  distinguished.
- **`[?const]` + `[?lib]` module loading** (code.md §12.1/§12.3) —
  bare `lazy` / `in-memory`, `scope=public|private`, `as=alias`,
  `only=(…)`, `version='…'` modifiers highlight throughout. Snippets
  cover file-path, registered-name, and HTTPS resolver forms.

## Requirements

- VS Code ≥ 1.75
- `cx` binary on `$PATH` (or configure `cx.serverPath`)

Install `cx`:

```sh
brew install cx-home/tap/cx                              # macOS / Linuxbrew
cargo install --git https://github.com/cx-home/cx cx-cli # from source
```

## What you get

| Feature | Source |
| --- | --- |
| Syntax highlighting | TextMate grammar (`syntaxes/cx.tmLanguage.json`) |
| Live diagnostics | LSP `publishDiagnostics` from libcx parse |
| Hover docs | LSP `textDocument/hover` |
| Completion | LSP `textDocument/completion` (snippet-flavoured) |
| Goto definition | LSP `textDocument/definition` (`#id` resolution) |
| Find references | LSP `textDocument/references` |
| Rename symbol (`F2`) | LSP `textDocument/rename` (cross-document `#id`) |
| Outline view | LSP `textDocument/documentSymbol` |
| Code folding | LSP `textDocument/foldingRange` |
| Smart selection | LSP `textDocument/selectionRange` (alt-shift-Right) |
| Signature help | LSP `textDocument/signatureHelp` (directive params) |
| Formatting | LSP `textDocument/formatting` (wraps `cx fmt`) |
| Semantic colouring | LSP `textDocument/semanticTokens/full` |
| Snippets | `snippets/cx.json` (`?if`, `?for`, `?def`, `?const`, `?lib`, `?match-multi`, `?modify`, `atom`, `path`, …) |

## Snippet cheat sheet

| Prefix | Expansion |
| --- | --- |
| `?if` / `?for` / `?for-array` / `?for-map` / `?let` / `?fn` | conditional / comprehensions / binding |
| `?match` | single-arm form — bare pattern + `[yield E]` (raises on miss) |
| `?match-multi` / `?match-when` / `?match-where` | multi-arm `[case]` / `[when]` / guard arms (code.md §8.2) |
| `?match-err` / `?else` | errors-as-values recovery + coalesce (code.md §9.3/§8.13) |
| `?modify` / `?modify-delete` / `?modify-using` / `?modify-append` | pure-functional updates (code.md §8.10) |
| `?def` / `?defp` / `?def-pure` / `?def-impure` / `?def-rest` | module functions (code.md §12.2) |
| `?const` / `?const-pub` / `?lconst` | module constants (code.md §12.3) |
| `?lib` / `?libas` / `?libonly` / `?lib-file` / `?lib-https` | module imports (code.md §12.1) |
| `?pipe` / `?pipe-tap` | prefix pipeline + `[tap]` (code.md §8.9) |
| `?str` | compile-time string interpolation (code.md §8.12) |
| `atom` | `:NAME` atom literal |
| `path` / `path-child` / `path-axis` / `path-pred` / `path-bind` | CXPath surfaces |
| `type-or` / `type-seq` | `[or T1 T2]` and `[sequence T]` |
| `elid` / `elanchor` / `table` | elements with `#id` / `&anchor` / typed table |
| `code` | embedded-language code block |

## Settings

| Key | Default | Effect |
| --- | --- | --- |
| `cx.serverPath` | `"cx"` | Binary to run for the language server |
| `cx.serverArgs` | `["lsp"]` | Arguments passed to the binary |
| `cx.trace.server` | `"off"` | LSP-protocol tracing (`off` / `messages` / `verbose`) |
| `cx.formatOnSave` | `false` | Run `cx fmt` on save |

## Commands

| Command | Effect |
| --- | --- |
| `CX: Restart Language Server` | Reload after editing settings |
| `CX: Show Server Version` | Confirm which `cx` is running |

## Build

```sh
cd tooling/vscode
npm install
npm run build
npm run package      # produces cx-language-<version>.vsix
code --install-extension cx-language-<version>.vsix
```

The build is intentionally vendored-free — the only dependency that
ships in the `.vsix` is `vscode-languageclient` (the LSP-client glue).
The language server itself is the `cx` binary, installed separately.

## Marketplace publication

This package is set up for publication under the `cx-home` publisher
ID. Per-tag publication runs from the release workflow.
