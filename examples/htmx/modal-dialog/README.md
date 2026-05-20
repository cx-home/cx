# HTMX modal-dialog

Adapted from <https://htmx.org/examples/modal-custom/>. The template
walks a `[modal]` element + nested `[body [field …]*]` to produce a
backdrop + dialog markup. Each `[field]` element acts as a "slot" —
its `label` / `value` attributes determine the rendered row.

This is the J row's exercise of the **tree-as-template-parameters**
pattern: a context document describes the modal's title + subtitle +
fields, and the cx template renders the corresponding HTML without
the cx file knowing anything about presentation.

## Files

| File | Purpose |
| ---- | ------- |
| `modal.cx` | Context document — modal title + subtitle + slot fields |
| `modal.cxl` | Renders the backdrop + dialog markup |

## Cx features exercised

- Two-level `[?for]` (outer modal, inner field iteration over `m/body/field`)
- J0 attribute-value interpolation in `hx-get=/modal/[?=m/@mid]/close`
- Element-content interpolation of titles + field values

## Run

```sh
cx eval modal.cxl --data=modal.cx
```
