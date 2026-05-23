# scripts/gen_guide — CX Data and Code Language Guide renderer

Renders `docs-src/canonical/manifest.cxd` + `docs-src/canonical/sections/*.cxd`
into a multi-page HTML site at `docs/guide/`.

## Status

**Design artifact, pending v0.8.0 cx binary.** The renderer
(`build.cx`) is authored against the CXL surface locked in ADR 0027
(`spec/decisions/0027-unified-pattern-query-transform.md`) and the
`.cxd` directive vocabulary used by the canonical guide. The v0.8.0
cx binary that runs CXL is not yet built; until it is, the Make
target stages all static assets and produces fallback pages whose
body is the verbatim `.cxd` source — the chrome (sidebar, search,
styling) is already live so the site shell can be reviewed
immediately.

## Run

```
make gen-cx-data-language-guide
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
post_process_body  (python in scaffold.sh)
        │
        │  Resolves [[anchor]] cross-refs against manifest.cxd,
        │  collapses any stray code fences.
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
| `[example lang=X "code"]`          | `<pre><code class="language-X">code</code></pre>` |
| `[list [item "..."] …]`            | `<ul><li>...</li>…</ul>`                      |
| `[[anchor]]` (inside prose)        | `<a class="xref" href="<target>">anchor</a>`  |

The anchor resolver consults the manifest: top-level section IDs map
to the file (e.g. `[[data]]` → `data-language.html`); child IDs map
to a fragment under their owning section file (e.g. `[[hello]]` →
`intro.html#hello`). Unknown anchors render as
`<span class="xref-unresolved">[[name]]</span>` so authors notice
breakage at review time rather than silently dead-linking.

## `VALIDATE-WHEN-CX-BINARY-READY` markers

Every block in `build.cx` carries a marker calling out the v0.8.0
CXL surface assumption it relies on. When the v0.8.0 cx lands, the
expectation is:

1. Run `make gen-cx-data-language-guide`.
2. For each VALIDATE marker, confirm the surface behaves as
   described in the comment (with the cited ADR section as the
   normative source).
3. Where the surface has drifted from the comment, update the
   comment first, then the code — the markers exist to make drift
   visible.

## Open follow-ups

- **Anchor resolution moves into `build.cx`.** Once the v0.8.0
  `[?include]` directive (spec/include.md) can load the manifest
  alongside the section context, the python anchor pass in
  `scaffold.sh post_process_body` migrates into a `[?modify]`
  pass over the render tree.
- **Recursion via named function.** The four-level dispatch in
  `build.cx` is unrolled because the locked v0.8.0 surface does
  not include user-defined functions. If a future ADR adds them,
  collapse §1d into a `render-child/2` call.
- **Per-page TOC.** Sections with many children deserve a
  right-rail TOC. Trivial to add once anchor resolution is in cx;
  punted for the scaffold pass.
- **Cross-link audit.** `xref-unresolved` spans should be promoted
  to a CI lint that fails the build when present.
