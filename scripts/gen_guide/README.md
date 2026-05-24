# scripts/gen_guide — CX Data and Code Language Guide renderer

Renders `docs-src/canonical/manifest.cxd` + `docs-src/canonical/sections/*.cxd`
into a multi-page HTML site at `docs/guide/`.

## Status

**Live, cx-eval-driven.** `build.cx` runs through the v0.8.0
CXPath / `[?match]` / `[?modify]` surface landed in ADRs 0027–0033;
`.cxd` body content is parsed and projected by the cx evaluator,
never by Python. Sections whose source contains a cx-eval-blocking
shape (e.g. an attribute value with both single and double quotes
that the eval-side renderer cannot losslessly re-emit) fall back to
a banner + verbatim source so the page still lands and the failure
is visible on the build console.

## Run

```
make guide
```

Output lands in `docs/guide/`:

- `docs/guide/index.html` — landing page with the manifest TOC.
- `docs/guide/<slug>.html` — one page per top-level section
  (slug = section filename with the leading `NN-` stripped and
  `.cxd` removed, e.g. `02-data-language.cxd` → `data-language.html`).
- `docs/guide/style.css`, `docs/guide/highlight/`, `docs/guide/search/`,
  `docs/guide/assets/` — static assets, copied from `scripts/gen_docs/`
  and `docs-src/assets/`.
- `docs/guide/search-index.js` — populated by scaffold.sh after
  pages render; empty array until then.

## Pipeline

```
docs-src/canonical/sections/NN-*.cxd
        │
        │  scaffold.sh wraps each section in [doc ...]
        ▼
cx eval scripts/gen_guide/build.cx --data=<ctx>
        │
        │  build.cx walks [section]/[child]/[intro]/[body]/
        │  [example]/[note]/[list] and emits an HTML-shaped
        │  CX render tree (h1/h2/h3/h4/p/pre/code/section/ul/li/a).
        ▼
cx --xml
        │
        │  XML projection produces an HTML body fragment.
        ▼
_post.py (Python — glue only, no .cxd body parsing)
        │
        │  Resolves [[anchor]] cross-refs against manifest.cxd;
        │  rewrites <code lang="X"> into <code class="language-X">
        │  for highlight.js.
        ▼
wrap_page  (bash heredoc in scaffold.sh)
        │
        │  Sidebar nav built from manifest.cxd; doctype, CSS,
        │  highlight.js, search.js, search-index.js link tags.
        ▼
docs/guide/<slug>.html
```

## Mapping: .cxd directives → HTML

| .cxd directive                     | HTML element                                  |
| ---------------------------------- | --------------------------------------------- |
| `[section title='T' …]`            | `<h1>T</h1>` + body                           |
| `[child n=X.Y title='T' …]`        | `<section id=…><hN>T</hN>…</section>` (N=depth+1) |
| `[intro "prose"]`                  | `<p>prose</p>`                                |
| `[body "prose"]`                   | `<p>prose</p>`                                |
| `[note "prose"]`                   | `<p class="note">prose</p>`                   |
| `[example lang=X "code"]`          | `<pre><code lang=X>code</code></pre>` then `_post.py` rewrites to `class="language-X"` |
| `[list [item "..."] …]`            | `<ul><li>...</li>…</ul>`                      |
| `[table [row ...] …]`              | `<table><row …/>…</table>` (lossless; styled per columns) |
| `[[anchor]]` (inside prose)        | `<a class="xref" href="<target>">anchor</a>`  |

The anchor resolver consults the manifest: top-level section IDs map
to the file (e.g. `[[data]]` → `data-language.html`); child IDs map
to a fragment under their owning section file (e.g. `[[hello]]` →
`intro.html#hello`). Unknown anchors render as
`<span class="xref-unresolved">[[name]]</span>` so authors notice
breakage at review time rather than silently dead-linking.

## Playground page

`docs/guide/playground.html` is the self-contained playground inside
the guide. The page wraps the `<cx-playground>` widget (sources live
at `scripts/gen_guide/playground/`) with the guide chrome (sidebar,
search). The wasm bundle (`docs/guide/wasm/{libcx,cxlib}.js`) is
mirrored from `dist/wasm/`; the JS/CSS for the widget plus the
starter examples are mirrored from `scripts/gen_guide/playground/`
into `docs/guide/playground/`.

The sidebar's `Playground →` link is page-relative (`playground.html`)
so the guide is portable as a directory tree — `file://…/docs/guide/`
loads everything without a web server.

## Open follow-ups

- **cx-eval renderer attr-quote bug.** `vcx/code/render.v` `render_attr_value_to`
  always wraps attribute values in double-quote, even when the value contains
  embedded `"`. This breaks downstream re-parsing for `.cxd` rows whose attribute
  values carry XML/JSON examples with both quote styles (currently affects
  `03-surfaces.cxd`, `04-identity.cxd`, and partially `05-analytics.cxd`).
  Fix: route through the same `choose_render_quote()` policy as scalar bodies.
- **05-analytics.cxd bracket-balance error.** Line 700 in that source file
  ends `"""]]]]` with one closing bracket too many — a source authoring bug
  that this renderer cannot fix in scope.
- **Anchor resolution into `build.cx`.** Once `[?include]` can load the
  manifest alongside the section context, the python anchor pass in
  `_post.py` migrates into a `[?modify]` pass over the render tree.
- **Recursion via named function.** The four-level dispatch in `build.cx`
  is unrolled because the locked v0.8.0 surface does not include
  user-defined functions. If a future ADR adds them, collapse the
  unrolled chain into a `render-child/2` call.
- **Cross-link audit.** `xref-unresolved` spans should be promoted to a
  CI lint that fails the build when present.
