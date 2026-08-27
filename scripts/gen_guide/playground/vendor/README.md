# `scripts/gen_guide/playground/vendor/` — the playground's vendored renderer

## Why this directory exists

The playground used to load Mermaid from jsDelivr at runtime:

```html
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"
        crossorigin="anonymous" defer></script>
```

That made §8.11.3's promise — "the playground works without an internet
connection" — **half true** (#1007). Evaluation was genuinely offline: the wasm
engine is built `SINGLE_FILE=1`, so `libcx-async.js` carries its own `.wasm`
inline and a `file://` visitor gets a working Run button. The **Graph pane was
not**. Open the page on a plane, or behind a filtering proxy, or during a CDN
incident, and the renderer never arrives; the pane keeps its placeholder and the
reader concludes the feature is broken.

The pin was also **floating**. `mermaid@10` is a range, not a version: jsDelivr
served whatever the newest 10.x was on the day of the request. So the bytes that
drew the reader's diagram could change under a *released tag* — after the tag was
cut, tested and signed — and the release had no way to know. Meanwhile
`scripts/test_playground_mermaid.mjs` (the 2070-diagram validity gate, #992)
resolved its own `mermaid` from `scripts/playground-gate/node_modules`, so the
gate and the page were two independently-drifting pins that only *happened* to
agree.

Vendoring closes both. The renderer is now bytes in the repo, moved by commits,
and the gate loads **this same file** — gate and page cannot diverge, because
there is only one artifact.

This follows the repo's own precedent rather than inventing a posture:
`third_party/re2` is pinned to a specific release for self-containment (#573,
after a shipped darwin binary turned out to need ~60 abseil dylibs it did not
carry), and its `LICENSE` ships beside the artifact in every release tarball as
`LICENSE-re2.txt`. Same shape here.

## The pin of record

| | |
|---|---|
| Package | `mermaid` |
| Version | **10.9.8** (exact — no range) |
| File | `mermaid.min.js` — the UMD bundle, minified |
| Bytes | 3,337,857 (3.18 MiB) |
| SHA-256 | `8d607d7ef1d077a8aa202e18e62212bfa992c68bfeabc5cf45d51a128fe6675d` |
| SHA-384 (SRI) | `sha384-N3QqR/7q+xm3BGX+CBbNI8AUmRRqcsDzToy+0z1NLDI0QmTKW8zvwLvqulJgk3dP` |
| Source tarball | `https://registry.npmjs.org/mermaid/-/mermaid-10.9.8.tgz` |
| Tarball integrity | `sha512-gmIhmkmD/3DL5lErDV71E/cFUkEbBW4VTFpsJH1HSYjeBICRKOoc4AZem+RNz/FhhCXKBMZiD75bIfBlb2A4yA==` |
| License | MIT — `LICENSE-mermaid.txt`, fetched from the `v10.9.8` tag |

**10.9.8 was the newest 10.x when the pin was taken**, which is the whole point:
vendoring froze the bytes visitors were *already* getting from
`mermaid@10`. Nothing about how diagrams render changed on the day this landed —
only whether the renderer can go missing.

**UMD-minified, not ESM.** `dist/mermaid.esm.min.mjs` is a 76-byte re-export shim
over ~150 sibling chunk files, which is not a thing you can vendor as one asset
or open over `file://` without a module-capable server. `dist/mermaid.min.js` is
one self-contained file — verified: **zero** `import(` sites, and every
`http(s)://` string in it is an XML namespace URI (`w3.org/2000/svg`, ELK's Ecore
URIs) or MIT-license comment text, so there is no fetchable asset hiding inside.
It is also the exact file the CDN `<script>` was pointing at.

**Size.** 3.18 MiB, against 7.2 MiB for the unminified `dist/mermaid.js`. That is
marginally over a 3 MB rule of thumb, and it is the honest floor for this
capability: Mermaid bundles its own parsers (flowchart, ER, class, state,
sequence, …) plus d3, dagre and ELK layout. It is a static asset that gzips to
roughly a quarter of that over HTTP, it is fetched once and cached, and the
alternative on the table was documenting the Graph pane as online-only — i.e.
retracting the offline promise instead of keeping it.

## Upgrading

The **only** network act in this dependency's whole life is the vendor-time
fetch. Never at page load. Never in the gate.

```sh
npm view mermaid@<version> dist.tarball dist.integrity   # record both
npm pack mermaid@<version>                               # the one network act
shasum -a 512 -b mermaid-<version>.tgz | cut -d' ' -f1 | xxd -r -p | base64
#   ^ must equal the registry's dist.integrity (minus the `sha512-` prefix)
tar xzf mermaid-<version>.tgz
cp package/dist/mermaid.min.js scripts/gen_guide/playground/vendor/
curl -sSL -o scripts/gen_guide/playground/vendor/LICENSE-mermaid.txt \
  https://raw.githubusercontent.com/mermaid-js/mermaid/v<version>/LICENSE
#   ^ the npm tarball ships no LICENSE file; it comes from the tag
```

Then update the table above **in the same commit** — it is the human-auditable
half of the pin — and run the gate:

```sh
make build-playground
node scripts/test_playground_mermaid.mjs
```

The gate parses every diagram the playground can put on screen (example ×
{auto,instance} × {source,output} × {min,compact,full}) against this file, so a
Mermaid upgrade that changes grammar acceptance shows up as a red gate rather
than as a broken pane a reader meets first. That is the whole reason the gate
loads the vendored bundle instead of its own copy.

## Not in scope here

`playground.html` still links **Google Fonts** for IBM Plex Mono, as does every
other guide page (`guide_build.cx`'s `wrap-page`). That is a site-wide
typography decision, not the playground's renderer, and it degrades cleanly: the
CSS carries a full local fallback stack (`ui-monospace, "SF Mono", Menlo,
Consolas, monospace`), so an offline visitor gets a working playground in a
system mono face. `scripts/test_playground_smoke.sh` allowlists exactly those
three font URLs and fails on any *other* off-origin reference — so the exception
is named and bounded rather than a hole, and a new CDN dependency cannot slip in
unnoticed.
