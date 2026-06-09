# D3 — `guestbook`, + web client (serve + html)

Attach another client — a browser — to the *same* `guestbook` runtime. The
surface materializes as **HTML** (htmx); a terminal client rides a live **SSE**
feed of the same fold (`tui.cx`). Same capability, same intents, new media. Live
server-*push* is real (§24): `[$xap:serve]` holds `GET /events` open and pushes a
surface frame on every committed intent — the terminal client consumes it with
`[$http:sse-events]`, no polling.

## Files

| File | Role |
|---|---|
| [`serve.cx`](serve.cx) | **process 1 — the server**: the `guestbook` capability (reused from D2) + `[$xap:serve]` over a real socket; hosts the authoritative runtime |
| [`tui.cx`](tui.cx) | **process 3 — the TUI client**: a *separate process* that holds no runtime; it opens ONE held-open `GET /events` SSE stream (`[$http:sse-connect]`) and repaints the view-tree in place (ANSI clear+home) on each pushed frame — live, no polling |
| [`sign.cx`](sign.cx) | the terminal client's **sign** half — a one-shot that POSTs `/intent/sign` over the http client (the same control the web client fires) |
| [`shell/layout.html`](shell/layout.html) | the **bridge document shell** — doctype / `<head>` / `<link>` / htmx `<script>` + the surface mount point (NOT part of the surface; served as a static `[resource]`) |
| [`shell/static/app.css`](shell/static/app.css) | the stylesheet (a static asset served beside the cascade, never by xap) |
| [`expected-output.txt`](expected-output.txt) | the HTTP request/response transcript (initial GET + a sign POST) |

> The shell loads htmx from a CDN (`<script src="https://unpkg.com/htmx.org…">`);
> to vendor it instead, drop `htmx.min.js` into `shell/static/` and point the
> `<script>` at `/static/htmx.min.js` (the static route serves it).

## Run

Run from the **repo root** (the `shell:` path is repo-root-relative). `--allow-net`
grants the `net` capability `[$xap:serve]` needs to bind the socket (it opens none
of its own — it bootstraps the core `[$http:serve]` engine).

**Web bridge alone** (`serve.cx`) — drive it from a second shell / a browser:

```sh
cx --allow-net spec/03-approved/xap/demos/d3-guestbook-web/serve.cx &   # long-running; binds 127.0.0.1:8443
curl -s http://127.0.0.1:8443/
curl -s -X POST http://127.0.0.1:8443/intent/sign -d 'name=Sam'
```

**Three processes** — open three terminals (the server seeds the D2 signatures
Ada, Lin first):

```sh
# terminal 1 — the server (process 1)
cx --allow-net spec/03-approved/xap/demos/d3-guestbook-web/serve.cx        # binds 127.0.0.1:8443

# a browser at http://127.0.0.1:8443 — the web client (process 2); sign there

# terminal 2 — the TUI client (process 3): a SEPARATE process, no runtime; it
# opens a live GET /events SSE stream and repaints in place on each pushed frame.
cx --allow-net=127.0.0.1:8443 --allow-write spec/03-approved/xap/demos/d3-guestbook-web/tui.cx

# sign from the terminal client too (same control the web client fires):
cx --allow-net=127.0.0.1:8443 spec/03-approved/xap/demos/d3-guestbook-web/sign.cx   # POSTs name=Sam
```

Sign in the browser (or run `sign.cx`) and the new name repaints in the TUI the
moment the server pushes it — **three processes, one authoritative fold, the same
view in every medium**, all over the wire. `--allow-write` is the TUI's extra
grant (stdout).
The clients dial loopback, so they need the **literal-IP grant**
`--allow-net=127.0.0.1:8443` — bare `--allow-net` is refused for 127.0.0.0/8 by
the §4.5 SSRF deny-set (reaching loopback requires the explicit IP/`localhost`
grant; the server only *binds*, so it's fine with `--allow-net`).

> **No longer one program.** The earlier compromise (web bridge + TUI in one
> process over the process-global fold) is gone: with the real cx http **client**
> (`[$http:get]`/`[$http:post]` now do real socket I/O) and the real
> `[$http:serve]` engine, the TUI is a genuine *separate-process* client that
> attaches over HTTP (xap.md §16). The server owns the runtime; clients hold none.
> Live server-*push* is real (§24): `[$xap:serve]` holds `GET /events` open and
> pushes a surface frame on each committed intent, event-driven (no reactor
> blocked); the remote client rides it with `[$http:sse-events]`. (`GET /surface`
> remains for a one-shot read / agents.)

## What it demonstrates

- **`serve` opens no socket of its own** — it bootstraps the surface onto the
  core `[?http-service]` directive / `[$http:serve]` engine (xap.md §9).
- **Content-negotiated render** (§5): the *same* `guestbook` surface is served as
  `text/html` for the browser (`GET /`, controls bound inline as htmx attributes)
  and as `application/cx` — the view-tree value — for a terminal/agent client
  (`GET /surface`). Two media, one surface.
- **HTML / CSS / shell live in three layers** (the §13.2 split): the panel
  *fragment* is xap-rendered; the `class` hooks ride on the view-tree; the
  stylesheet + document shell are **static assets served beside the cascade**,
  never by xap. The initial GET sends the shell + CSS once; each sign POST
  returns only the re-rendered fragment.
- **Two clients on one runtime** (§16): the browser (htmx) and `tui.cx` (a
  separate-process SSE client) both ride the *same* server-authoritative fold —
  sign in either and the other updates live. Both are clients of one journal;
  only the medium differs.

## Implements (the `cx-xap` slice)

`[$xap:serve]` (on `http` / `[?http-service]`) + the `html` render leg + `session`
attach (one fixed dev principal, **no login** yet — the §22.1 / R-A3 seam) + the
live **SSE feed** (§24): `[$xap:serve]` holds `GET /events` open and pushes a
surface frame on each committed intent — event-driven, no reactor blocked.

## Status

Spec-conformant and **runs today** on the bundled `cx-xap` runtime + the bridge
shell: `[$xap:serve]` binds the core picoev engine, content-negotiates the surface
to `text/html`, serves the shell + static CSS, runs the cascade on the sign POST,
**and pushes the live `GET /events` SSE feed** (§24, held-open + event-driven).
The transcript in `expected-output.txt` is captured from a live run. The full
loop — GET shell / POST cascade / live SSE push — is complete.
