# HTMX click-to-load

Adapted from <https://htmx.org/examples/click-to-load/>. Demonstrates
the list-composition pattern: a `[?for]` iteration over agents
followed by a `Load More` trigger row that swaps itself for the next
page of results.

The page number on the context document's `agents/@page` is
interpolated into the `hx-get` URL via J0 attribute-value
interpolation. The server returns the next page's fragment (more
agent rows + a fresh sentinel row with `page+1` in the URL).

## Files

| File | Purpose |
| ---- | ------- |
| `agents.cx` | Context document — `[agents page=N [agent …]*]` |
| `page.cxl` | Renders agent rows + the `Load More` trigger row |

## Cx features exercised

- `[?for a :in //agent :return …]` (A7)
- J0 attribute-value interpolation in `hx-get=/agents?page=[?=@page]`
  (the trigger row sits at root context so `@page` resolves to the
  `agents` element's `page` attribute)
- `[?=a/@name]` body interpolation

## Run

```sh
cx eval page.cxl --data=agents.cx
```
