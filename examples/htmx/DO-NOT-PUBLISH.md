# DO NOT PUBLISH — htmx demos are on the back burner

**Status:** parked 2026-05-19. Not part of v0.7.0 release. Reconsider
after the cx-eval improvements listed below.

## Why this is parked

The demo's stated value proposition is *"CXL is a better template
engine than Jinja/Handlebars for HTMX-style apps because CX is markup-
native and the query layer is built in — the server is just routing."*

The implementation does not deliver on that promise. Look at the
current `serve.py`:

- **~400 lines of Python**
- Significant **HTML embedded in Python strings** (`INDEX_PAGE_HEAD`,
  `DEMO_PAGE_HEAD`, `SHARED_STYLE` — most of the rendered chrome is
  Python, not CX)
- **Server-side validation logic in Python** (`validate_field()`)
- **Data filtering in Python** (`filter_users_by_search()`)
- **In-memory state in Python** (`CONTACT_STORE`)
- Per-demo route wiring + body parsing + form decoding in Python

The CX/CXL files are thin slivers (5–15 lines each); the demo is
overwhelmingly a Python app that happens to use `cx eval` for a small
fragment of the rendering. That's the opposite of the pitch.

## Why the Python is large — gaps in `cx eval` today

The ideal "thin Python, fat CXL" demo is blocked on these CXL/eval
limitations:

1. **`cx eval` can't take query parameters from the request.** There's
   no way to pass `search=al` from the POST body into the template's
   eval context as a value the FLWOR `:where` clause can compare
   against. The CLI takes `--data=FILE` or `-d 'INLINE_CX'` only;
   there's no `--param key=value` flag, and no template variable
   substitution.

2. **`:where` can't compare an attribute to another attribute via path
   expression.** `u/@name = //users/@search` returns empty (verified
   in `examples/htmx/active-search` — that's why the filter is
   currently done Python-side). Only literal-value comparisons work.

3. **No request-context handle in templates.** Even if (1) is fixed, the
   template still has no way to read the HTTP method, headers, form
   body, query string, or session — all of which a real template
   engine would expose for routing decisions.

4. **No state primitives.** The "click to edit" demo needs to update
   the contact and serve it back. There's no `cx:store` / `cx:bind`
   primitive for write-modify-render flows. Today it's pure Python
   dict.

5. **No validation primitives.** Inline-validation expresses
   "username must be ≥ 3 chars" as a Python function. CXL has no
   declarative validators (regex/length/range/predicate) that can
   render an error message.

6. **`fn:contains`, `fn:lower-case`, etc.** don't reliably parse in
   `:where` slots (the `:` in `fn:contains` gets read as a slot label
   token). At minimum a `fn(...)` shorthand or robust namespace
   parsing in slot expressions is needed.

7. **Default HTML layout / CSS / chrome doesn't belong in templates.**
   The current demo has `INDEX_PAGE_HEAD`, `DEMO_PAGE_HEAD`,
   `SHARED_STYLE` as Python strings because writing the full HTML
   page wrapper in CX/CXL works structurally but doesn't render
   without going through `cx --to=xml`, which produces XHTML-style
   self-closing tags (`<input/>`, `<div class="error"/>`) that
   confuse browsers. We need a `cx --to=html` target (HTML5 — empty
   element rules, no self-closing on `<div>`/`<span>`/`<form>`/etc.).
   The current `cx --to=xml` produces `<div class="error"/>` which
   browsers interpret as "open `<div>` never closed", causing the
   exact malformed-DOM failure we saw with inline-validation.

## What the ideal demo would look like

```
examples/htmx/
  serve.py              ← 30–50 lines: routing + form-body → CX context only
  index.cxl             ← landing page; renders the list of demos
  active-search/
    page.cxl            ← input + table; uses request-bound :where
    users.cx
  click-to-edit/
    view.cxl            ← read-only contact card
    edit.cxl            ← form
    contact.cx          ← persisted via cx:store primitive
  inline-validation/
    form.cxl            ← validators declared in CXL
    signup.cx
  click-to-load/
    page.cxl            ← reads page-size + offset from request context
    agents.cx
  modal-dialog/
    modal.cxl
    modal.cx
```

Total: maybe 200 lines of CXL across all demos, 50 lines of Python,
no HTML strings in Python.

## What lives in this directory now (do not promote in release notes)

```
serve.py                  — 400-line Python server, much HTML in strings
DO-NOT-PUBLISH.md         — this file
active-search/{search.cxl, search-rows.cxl, users.cx, README.md}
click-to-edit/{view.cxl, edit.cxl, contact.cx, README.md}
click-to-load/{page.cxl, page-final.cxl, agents.cx, README.md}
inline-validation/{form.cxl, signup.cx, README.md}
modal-dialog/{modal.cxl, modal.cx, README.md}
```

The .cxl + .cx files are themselves fine and showcase real CXL
constructs (FLWOR `:where`, interpolation, conditionals). The
*demo wrapper* is the part that fell short.

## Reconsider when

Cancel "do-not-publish" when:

- A `cx eval --param k=v` (or equivalent) flag lands
- Attribute-vs-path-attribute comparison works in `:where`
- `cx --to=html` HTML5-aware target lands
- CXL gains a validation / state-management primitive (or we decide
  these belong outside the language and document the boundary clearly)

Until then, the demo materially undersells CXL and would invite the
exact criticism *"this is just Jinja in 400 lines of Python"* —
which is a fair critique of this implementation as currently shipped.
