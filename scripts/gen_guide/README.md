# scripts/gen_guide — CX Data and Code Language Guide renderer

Renders `docs-src/canonical/manifest.cxd` + `docs-src/canonical/sections/*.cxd`
into a multi-page HTML site at `docs/guide/`.

## Run

```
make gen-cx-data-language-guide
```

Output lands in `docs/guide/`:

- `docs/guide/index.html` — landing page with the manifest TOC.
- `docs/guide/<slug>.html` — one page per top-level section
  (slug = section filename with the leading `NN-` stripped and
  `.cxd` removed, e.g. `02-data-language.cxd` → `data-language.html`).
- `docs/guide/playground.html` — self-contained playground page with
  50 starter examples baked into `playground/playground.js`. Works
  under `file://` so cloning the repo and opening the file directly
  in a browser is sufficient.
- `docs/guide/style.css`, `docs/guide/highlight/`, `docs/guide/search/`,
  `docs/guide/playground/`, `docs/guide/wasm/`, `docs/guide/assets/` —
  static assets, copied from `scripts/gen_docs/` and `docs-src/assets/`.
- `docs/guide/search-index.js` — populated by `scaffold.sh` after
  pages render.

## Pipeline

```
docs-src/canonical/sections/NN-*.cxd
        │
        │  scaffold.sh hands each section file to _render.py
        ▼
_render.py
        │
        │  Parses .cxd as a bracket tree (triple-quote / single-quote /
        │  attribute / nested-element aware). Walks the tree and emits
        │  an HTML body fragment for each [section]/[child]/[intro]/
        │  [body]/[example]/[note]/[list]/[table]/[row] element.
        ▼
post_process_body  (python in scaffold.sh)
        │
        │  Resolves [[anchor]] cross-refs against manifest.cxd,
        │  collapses any stray code fences.
        ▼
wrap_page  (bash heredoc in scaffold.sh)
        │
        │  Sidebar nav built from manifest.cxd; doctype, CSS,
        │  highlight.js, search.js, search-index.js link tags.
        │  For playground.html, additionally wires
        │  playground.css / playground.js / wasm/libcx.js /
        │  wasm/cxlib.js / tree-view.js / diagram-view.js.
        ▼
docs/guide/<slug>.html
```

## Why Python-side rendering instead of `cx eval`?

`scripts/gen_docs/build.cx` (the v0.7.x docs renderer) walks its
input via `[?for $s :in //section :yield … [?match $c :case [prose $p]
:yield [p $p] …]]`. That works because the `.cx` content under
`docs-src/content/` always wraps prose in **bare-token** or
**single-double-quote** bodies, which body-binding auto-unwraps cleanly
into `$p`.

The `.cxd` guide sources under `docs-src/canonical/sections/` use a
richer surface: triple-quoted multi-line bodies with embedded
backticks, single-quote literals, markdown links, and bracket markup
(e.g. `[?for ... :yield ...]` shown as example code). Body-binding on
a triple-quoted body in the current cx binary does not auto-unwrap; it
binds `$p` to the entire parent element, producing `<p>[body  ...]</p>`
in the output rather than `<p>...</p>`.

`_render.py` sidesteps that by parsing `.cxd` directly with a small
bracket-walker (triple-quote / attribute / nesting aware). The `.cxd`
vocabulary is small and known, so the Python parser stays under 500
lines and has no third-party dependencies. The CX evaluator may take
over rendering in a future pass once body-binding around triple-quoted
text settles in v0.8.0.

`build.cx` is preserved in the directory as a design reference for
that future migration.

## Mapping: .cxd directives → HTML

| .cxd directive                                | HTML element                                  |
| --------------------------------------------- | --------------------------------------------- |
| `[section title='T' …]`                       | `<h1>T</h1>` + body                           |
| `[child id=ID n=X.Y title='T' …]`             | `<section id=ID><hN>T</hN>…</section>` (N=2..6) |
| `[intro """prose"""]`                         | `<p>prose</p>`                                |
| `[body """prose"""]`                          | `<p>prose</p>`                                |
| `[note """prose"""]`                          | `<p class="note">prose</p>`                   |
| `[example lang=X """code"""]`                 | `<pre><code class="language-X">code</code></pre>` |
| `[list [item """..."""] …]`                   | `<ul><li>...</li>…</ul>`                      |
| `[table [row [cell """..."""] …] …]`          | `<table><tr><td>…</td></tr>…</table>`         |
| `[[anchor]]` (inside prose)                   | `<a class="xref" href="<target>">anchor</a>`  |

In-prose markup processed by `_render.py`:

| .cxd inline      | HTML                              |
| ---------------- | --------------------------------- |
| `` `code` ``     | `<code>code</code>`               |
| `**strong**`     | `<strong>strong</strong>`         |
| `_emphasis_`     | `<em>emphasis</em>`               |
| `[label](url)`   | `<a href="url">label</a>`         |
| `[[anchor]]`     | passed through for `scaffold.sh`  |

The anchor resolver consults the manifest: top-level section IDs map
to the file (e.g. `[[data]]` → `data-language.html`); child IDs map
to a fragment under their owning section file (e.g. `[[hello]]` →
`intro.html#hello`). Unknown anchors render as
`<span class="xref-unresolved">[[name]]</span>` so authors notice
breakage at review time rather than silently dead-linking.

## Playground

`docs/guide/playground.html` is fully self-contained: all CSS / JS /
WASM paths resolve relative to `docs/guide/`. The widget markup is
lifted verbatim from `scripts/gen_docs/playground/playground.html`
(source of truth), with two rewrites:

- The gen_docs snippet's trailing `<link>` / `<script src="/playground/…">`
  tags are stripped (they're root-relative for the nested gen_docs
  layout, and `wrap_page` re-issues the relative equivalents).
- Any `concepts/wasm.html` link (gen_docs nested page) is rewritten
  to `concepts.html` (the flat guide layout's equivalent).

The 50 starter examples are baked into `playground.js`'s
`programExamples` array; the dropdown is populated at page load.

## Open follow-ups

- **Migrate rendering to `cx eval build.cx`** once body-binding around
  triple-quoted text is reliable. The `.cxd` surface won't need to
  change.
- **Per-page TOC.** Sections with many children deserve a right-rail
  TOC. Trivial once anchor resolution is in cx.
- **Cross-link audit.** `xref-unresolved` spans should be promoted to
  a CI lint that fails the build when present.
- **Replace `_fallback.py`** — currently unused; kept on disk for one
  release in case the Python renderer needs a quick disable switch.
