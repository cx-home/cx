# Vendored third-party assets

| File | What | Version | Source | sha256 |
|---|---|---|---|---|
| `htmx.min.js` | htmx | 1.9.10 | `https://unpkg.com/htmx.org@1.9.10/dist/htmx.min.js` | `b3bdcf5c741897a53648b1207fff0469a0d61901429ba1f6e88f98ebd84e669e` |

Verify:

```bash
shasum -a 256 reference/shop-web-client/shell/static/htmx.min.js
```

## Why vendored here and not loaded from a CDN

htmx is not incidental to CX: the engine emits `hx-post` / `hx-target` /
`hx-swap` **natively** (`xap_html_control`), so a served XAP produces htmx
markup whether the client asks for it or not, and the authoring process names
htmx the web-client default. A reference application that cannot demonstrate
the swap without network access is not demonstrating the thing.

The shipped demo at `spec/03-approved/xap/demos/d3-guestbook-web` uses the CDN
tag, and `cx xap init --client` scaffolds the CDN tag too — a generated
project has no vendored copy to point at. This reference vendors it so the
page works offline and so the version under test is pinned by hash rather
than by whatever the CDN serves.
