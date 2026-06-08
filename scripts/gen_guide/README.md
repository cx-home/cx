# scripts/gen_guide — CX Data and Code Language Guide renderer

Renders `docs-src/canonical/manifest.cxd` + `docs-src/canonical/sections/*.cxd`
into a multi-page HTML site at `docs/guide/`.

## Status

**CX-native, single program.** `guide_build.cx` is one CX program that reads the
canonical sources and emits the entire site — render = `.cx`, dogfooded end to
end. There is **no Python and no shell logic** in the build: the program globs
and reads the `.cxd` files, parses them with `[$cx:parse]`, transforms them with
`[?match]`/`[?modify]`/CXPath into an HTML-shaped CX tree, projects that to HTML
with `[$xml:emit]`, resolves `[[anchor]]` cross-refs, wraps each page in the
chrome, copies the static assets, and builds the search index — all in memory
(`codec.md §1`), no subprocess.

(The standard-library section generator, `scripts/gen_guide_libraries.py`, is
still Python — see "Generated section" below; converting it to CX is the one
remaining Python piece.)

## Run

```
make guide        # builds the cx binary + playground wasm, then runs guide_build.cx
```

or directly:

```
cx scripts/gen_guide/guide_build.cx --allow-read --allow-write
```

The `--allow-read` / `--allow-write` grants are required (the program reads
`docs-src/` and writes `docs/guide/`).

Output in `docs/guide/`:

- `index.html` — landing page with the table of contents.
- `<slug>.html` — one page per top-level section (slug = section filename with
  the leading `NN-` stripped and `.cxd` removed, e.g. `02-data-language.cxd` →
  `data-language.html`).
- `about.html` — the hand-authored `docs-src/canonical/about.html`, wrapped in
  the guide chrome (its body is copied verbatim, never regenerated).
- `playground.html` — the standalone playground, copied verbatim (no chrome).
- `style.css`, `highlight/`, `search/`, `assets/`, `playground/`, `wasm/` —
  static assets copied from `scripts/gen_guide/`, `docs-src/assets/`, and
  `dist/wasm/` (wasm/playground bundles are copied only if present).
- `search-index.js` — `window.CXSearchIndex = [{slug,title,summary,text}, …]`,
  built from the freshly rendered pages.

## Pipeline (all inside `guide_build.cx`)

```
docs-src/canonical/sections/NN-*.cxd
        │  [$io:glob] + [$io:read-file] + [$cx:parse]  → DocumentNode
        ▼
render-doc:  //section → walk [child]/[intro]/[body]/[example]/[note]/[list]/
        │    [table], retagging prose in place ([?modify … [rename …]]) and
        │    emitting an HTML-shaped CX tree (h1/h2/h3/h4/p/pre/code/section/ul/li)
        ▼
[$xml:emit]  → HTML body fragment
        │     post-body: strip the empty-name <>/</> sequence wrappers,
        │     rewrite <code lang="X"> → <code class="language-X">
        ▼
resolve-anchors:  fold the manifest's section/child ids over the body,
        │    [[name]] → <a class="xref" href="slug.html#frag">name</a>;
        │    unknown [[name]] → <span class="xref-unresolved"> (via re:replace)
        ▼
wrap-page:   sidebar nav (from the section metadata) + <head> + script tags
        ▼
[$io:write-file]  docs/guide/<slug>.html
```

Section metadata (number, slug, title) is read straight from each section
file's own `[section n= id= title=]` header; glob order is the reading order.

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
| `[table [row ...] …]`              | `<table><row …/>…</table>`                    |
| `[[anchor]]` (inside prose)        | `<a class="xref" href="<target>">anchor</a>`  |

The anchor resolver consults the manifest: top-level section IDs map to the
file (`[[data]]` → `data-language.html`); child IDs map to a fragment under
their owning section file (`[[hello]]` → `intro.html#hello`). Unknown anchors
render as `<span class="xref-unresolved">[[name]]</span>` so authors notice
breakage at review time.

## Generated section: Standard library (§16)

`docs-src/canonical/sections/16-libraries.cxd` is a **generated artifact —
never hand-edit it.** It is emitted from the conformance coverage data document
by `scripts/gen_guide_libraries.py` (the one remaining Python tool):

```
make guide-libraries          # uses vcx/target/cx by default
make guide-libraries CX_BIN=$(which cx)
```

Data flow: `spec/std-lib/*.md` + `conformance/stdlib/*.cxd` →
(`make stdlib-coverage`) → `conformance/stdlib/coverage.cx` →
(`gen_guide_libraries.py`, reading via `cx --ast --json` + each module's §1
prose) → `16-libraries.cxd` + the section-16 TOC block in `manifest.cxd`.
**To refresh:** run `make stdlib-coverage` first, then `make guide-libraries`.

## Playground page

`docs/guide/playground.html` is the self-contained playground (sources at
`scripts/gen_guide/playground/`), copied verbatim. The wasm bundle
(`docs/guide/wasm/…`) is mirrored from `dist/wasm/`; the widget JS/CSS +
starter examples are mirrored from `scripts/gen_guide/playground/`. The
sidebar's `Playground →` link is page-relative so the guide is portable as a
directory tree (opens under `file://`).

## Open follow-ups

- **Triple-quote `\"` escape semantics + render bijection.** A few code
  examples that embed inner `"""` via `\"\"\"` render with literal backslashes
  under the in-memory path (the old multi-subprocess pipeline masked this via a
  non-idempotent text round-trip). This is a core-language question, tracked in
  `spec/02-inprogress/triple_quote_escape_bijection.md` — not a renderer bug.
- **`gen_guide_libraries.py` → CX.** Converting the §16 generator to CX would
  remove the last Python from the guide toolchain.
- **Collapse the 4-level child unroll.** `render-doc` unrolls `[child]` nesting
  to four levels; now that CX has user-defined functions (`[?def]`), it could be
  a single recursive `render-block` call.
- **Cross-link audit.** Promote `xref-unresolved` spans to a CI lint that fails
  the build when present.
