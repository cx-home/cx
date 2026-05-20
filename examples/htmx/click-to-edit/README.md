# HTMX click-to-edit

Adapted from <https://htmx.org/examples/click-to-edit/>. Demonstrates
the canonical HTMX fragment-swap pattern using two cx evaluator
templates that share a single `.cx` data fixture.

This is the first v0.7.0 example to exercise **attribute-value
interpolation** (J0): `hx-get=/contact/[?=c/@cid]/edit` substitutes
`c/@cid` at evaluation time. Without J0 the HTMX URL story collapses,
so it gates the rest of the J row.

## Files

| File | Purpose |
| ---- | ------- |
| `contact.cx` | Context document — one `[contacts [contact …]]` element |
| `view.cxl` | Renders the read-only view fragment. `Click To Edit` button issues `hx-get=/contact/<cid>/edit` |
| `edit.cxl` | Renders the edit-form fragment. Submit issues `hx-put=/contact/<cid>`; Cancel reverts via `hx-get=/contact/<cid>` |

Both templates use `[?for c :in //contact :return …]` to bind the
contact element, then interpolate `c/@first`, `c/@email`, etc. both
inside element content and inside attribute values (J0).

## Run the templates

```sh
cx eval view.cxl --data=contact.cx
cx eval edit.cxl --data=contact.cx
```

## Server wiring

The HTMX example is server-agnostic. A minimal Python sketch
exercising both fragments:

```python
from cxlib import cx_eval

with open('contact.cx') as f: ctx = f.read()
with open('view.cxl') as f: view_tpl = f.read()
with open('edit.cxl') as f: edit_tpl = f.read()

# GET /contact/42        → view fragment
# GET /contact/42/edit   → edit fragment
# PUT /contact/42        → updated view fragment (after persisting form)

def render_view(ctx):  return cx_eval(ctx, view_tpl, '')
def render_edit(ctx):  return cx_eval(ctx, edit_tpl, '')
```

For a runnable full-stack demo (Flask + SQLite + HTMX), see
`server.py` (post-v0.7.0).
