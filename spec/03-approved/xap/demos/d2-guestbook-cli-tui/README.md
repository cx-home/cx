# D2 — `guestbook`, stateful capability (the cascade)

Adds **state** and **one control**. This one-shot program signs the guestbook
**twice** (as two clients would) — each sign commits **once** to the journal —
then renders the surface from the resulting fold. It's where server-authoritative
state first *earns its weight*: a single-client guestbook would need none of it
(xap.md §28.1). The *live two-client* story — sign in one client, watch another
re-materialize — is shown concretely in **D3** (`tui.cx`: a web bridge + a
terminal viewer over one in-process fold); here the two signs stand in for the
two clients and the program prints the shared surface once.

## Files

| File | Role |
|---|---|
| [`guestbook.cx`](guestbook.cx) | the `guestbook` capability + the runtime (`run`/`on`) + two clients signing + the synced render |
| [`expected-output.txt`](expected-output.txt) | the surface both clients display after both signs |

## Run

```sh
cx guestbook.cx
```

## Expected output

```
[surface name=guestbook [panel [list ([item 'Ada'], [item 'Lin'])] [control :sign [label 'Sign'] [input :name]]]]
```

Both names appear because both signs hit one authoritative journal, and the
surface is rendered from that fold. The list's children are the `(…)` sequence
the view's `[?for [in $g $gs] …]` comprehension yields — one `[item …]` per
signed name. (Render it in any medium and it's the same surface — D3 shows the
HTML and terminal renderings side by side.)

## What it demonstrates

- **The full intent loop / cascade** (xap.md §2.1): `[$xap:emit]` → PEP → journal
  append (commit, automatic — the committed `[do :sign]` *is* the event) → ordered
  bus dispatch. `"/guestbook"` is the live **fold** of those events; no
  client-side state, history + audit free.
- **Server-authoritative state as a journal fold** (§14): `[$xap:state]` /
  `bind /guestbook` is `fold(journal)` — no client-side state, history + audit
  free.
- **Server-authoritative, client-agnostic** (§16): the fold is the single source
  of truth; any number of clients render it without client-side state. Two signs
  here stand in for two clients; **D3** makes the two clients concrete (a browser
  + a terminal viewer over one in-process fold, live).

## Implements (the `cx-xap` slice)

The **cascade** — `[$xap:run]`, `[$xap:emit]`, `[$xap:state]` — wiring the
(already-shipped) `journal`. The `authz` PEP is trivial here: one fixed,
pre-granted dev principal, no login (xap.md §22.1 / R-A3).

## Status

Spec-conformant and **runs today** on the bundled `cx-xap` runtime: `cx
guestbook.cx` produces `expected-output.txt` exactly. The cascade slice
(`run` / `emit` / `state`, the journal fold) is implemented; the live in-process
`bus` feed is the §16 client-consistency primitive the TUI rides.
