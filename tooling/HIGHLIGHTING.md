# CX syntax-highlighting design notes

## Bracket de-emphasis (design intent — 2026-06-02; APPROVED in review same day: same-hue one-shade-dim, default `#ab9434` against bracket-pair gold)

CX surface is bracket-dense (`[` `]` open/close every element, directive, and
clause — roughly a third of all glyphs in idiomatic code). The highlighting
design intent is:

> **Brackets stay visible but carry LESS contrast than the tokens that should
> stand out** — head names, directive heads (`?match`, `?for`), `$bindings`,
> `:atoms`, strings, and numbers. The eye should parse structure by the
> emphasized tokens; brackets are the quiet scaffolding.

The conventional name for this is **punctuation de-emphasis** (sometimes
"dimmed brackets" / "low-contrast punctuation").

### How it maps to each tooling system

The *grammar* layer only assigns a scope/capture to brackets; the *theme*
layer decides their color. Our job in `tooling/` is (1) make sure brackets
are captured under the standard punctuation scope (so any theme that dims
punctuation dims them), and (2) ship recommended dim overrides for users
whose theme doesn't.

| System | Capture/scope for `[` `]` | De-emphasis mechanism |
|---|---|---|
| tree-sitter (`tooling/tree-sitter-cx/queries/highlights.scm`) | `@punctuation.bracket` | Editor theme colors `@punctuation.bracket` dimmer (Neovim: `hl-@punctuation.bracket`) |
| VS Code TextMate (`tooling/vscode/syntaxes/cx.tmLanguage.json`) | `punctuation.section.brackets.cx` | Theme rule or user `editor.tokenColorCustomizations` |
| Neovim regex syntax (`tooling/neovim/syntax/cx.vim`) | `cxBracket` group | `:highlight` link to a dim group (`Comment`-level fg, NOT italic) |

### Recommended user overrides

VS Code (`settings.json`):

```json
"editor.tokenColorCustomizations": {
  "textMateRules": [
    { "scope": "punctuation.section.brackets.cx",
      "settings": { "foreground": "#7d8590" } }
  ]
}
```

Neovim (init.lua):

```lua
vim.api.nvim_set_hl(0, "@punctuation.bracket.cx", { fg = "#ab9434" })
```

Guideline (revised in review 2026-06-02): de-emphasize by **keeping the
theme's bracket HUE and dropping ~one shade of luminance (to ~55–65%)** —
do NOT grey brackets out. Greying (`#6b7280`, `#7d8590`) read as "disabled";
a dimmed-gold `#ab9434` next to bracket-pair gold `#ffd700` reads as quiet
structure. With VS Code bracket-pair colorization active, set the pair colors
themselves one shade dimmer:

```json
"workbench.colorCustomizations": {
  "editorBracketHighlight.foreground1": "#ab9434",
  "editorBracketHighlight.foreground2": "#8f679c",
  "editorBracketHighlight.foreground3": "#2f7ab5"
}
```

### Status / follow-ups

- [ ] Audit the three grammars: brackets must be captured under the scopes
      above everywhere (not lumped into a generic source scope).
- [ ] Apply the approved defaults wherever we ship colors (web demo
      highlighters, playground, any bundled theme) — approved 2026-06-02.
- [ ] Consider shipping the dim values as defaults in the bundled VS Code
      theme contribution (if/when we ship one) rather than as user overrides.
- Visual comparison demo: `tooling/web/highlight-contrast-demo.html`
  (open via `file://`).
