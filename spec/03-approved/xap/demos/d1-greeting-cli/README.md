# D1 — `greeting`, one-shot CLI (pure)

The smallest real XAP: a **parameterized view** rendered by a one-shot CLI. It
exercises **only the pure constructors** — no journal, no bus, no cascade, no
socket — so it is the first, lowest-risk slice of the `cx-xap` runtime.

## Files

| File | Role |
|---|---|
| [`greeting.cx`](greeting.cx) | the whole demo — the `greeting` capability (component) + a one-shot CLI client that renders it |
| [`expected-output.txt`](expected-output.txt) | the exact output (the `application/cx` view-tree) |

## Run

```sh
cx greeting.cx          # from this dir; cx-xap is bundled (no install)
```

## Expected output

```
[surface name=hello [panel [text 'Hello, Ada.']]]
```

This is the surface **materialized as `application/cx`** (the view-tree value,
xap.md §3.5) — what an agent reads and what the CLI renderer prints. Pass a
different `name` prop (`[$xap:panel greeting {name: "Lin"}]`) and the projection
changes; nothing else does.

## What it demonstrates

- **A surface is medium-agnostic data; a client is a renderer** (N-MEDIUM-1 /
  N-CLIENT-1). The same `greeting` surface renders as HTML in D3 — only the
  client changes.
- The component **typed triple** (xap.md §17): the `props` (slice-in) and `view`
  (view-tree-out) arms; the intent-vocabulary arm is empty for a pure view.
- **Pure constructors only** (xap.md §3.2/§3.5): `component` / `surface` / `panel`
  / `render` are capability-free. No `[$xap:run]`, no journal, no socket.

## Status

Spec-conformant and **runs today** on the bundled `cx-xap` runtime: `cx
greeting.cx` produces `expected-output.txt` exactly. This demo's slice — the
pure constructors (`component` / `surface` / `panel` / `render`) + a CLI
renderer — is the first thing the runtime implements.
