# HTMX active-search

Adapted from <https://htmx.org/examples/active-search/>. Demonstrates
FLWOR `:where` clause filtering (A8) combined with HTMX's keyup
trigger producing a fragment swap.

In a real deployment the search input value is the filter parameter;
the server re-evaluates the template with the filter encoded in the
context document (or via a slot binding). The shipped template here
hard-codes a role-based filter (`:where u/@role = 'admin'`) to keep
the example self-contained; substituting a context-supplied filter
value is a server-side concern.

## Files

| File | Purpose |
| ---- | ------- |
| `users.cx` | Context document — `[users [user …]*]` |
| `search.cxl` | Renders the filtered table fragment. `tbody` carries `hx-post=/search`, `hx-trigger=keyup changed delay:500ms from:.search`, `hx-target=this` |

## Cx features exercised

- `[?for u :in //user :where u/@role = 'admin' :return …]` (A7/A8)
- `[?=u/@name]` interpolation inside `<td>` cells

## Run

```sh
cx eval search.cxl --data=users.cx
```

## Server wiring sketch

```python
from cxlib import cx_eval

with open('users.cx') as f: ctx = f.read()
with open('search.cxl') as f: tpl = f.read()

# POST /search { search: 'Al' }  → filtered fragment
# (the server rewrites ctx or tpl to inject the search term, then evaluates)
def render(ctx_with_filter): return cx_eval(ctx_with_filter, tpl, '')
```
