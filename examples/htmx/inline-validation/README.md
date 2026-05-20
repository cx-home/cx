# HTMX inline-validation

Adapted from <https://htmx.org/examples/inline-validation/>. Each
form field carries `hx-post=/signup/validate` + `hx-trigger=changed`,
so the server validates and returns just the updated field fragment.
The shipped template renders the initial form with whatever
validation state the context document carries.

## Files

| File | Purpose |
| ---- | ------- |
| `signup.cx` | Context document — `[signup [field name=… value=… valid=yes/no error=…]*]` |
| `form.cxl` | Renders one `[div class=field]` per `field`, conditionally including the error fragment via `?if` |

## Cx features exercised

- `[?for f :in //field :return …]` (A7)
- J0 attribute-value interpolation: `name=[?=f/@name]` `value=[?=f/@value]`
- `[?if [cond, body]]` single-branch conditional (positional 2-slot)

## Run

```sh
cx eval form.cxl --data=signup.cx
```
