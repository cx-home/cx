# CX code examples

Two small CX data fixtures used as inputs for `cx eval` demos
elsewhere in the repo (the canonical tours: `examples/code-tour.cx`,
`examples/cxpath-tour.cx`, `examples/match-multi.cx`,
`examples/modify-crud.cx`).

## Files

| File | Shape |
| ---- | ----- |
| [`greet.cx`](greet.cx) | single `[user]` element with `name=`, `role=`, `active=` attributes |
| [`users.cx`](users.cx) | `[team]` with three `[member]` rows showing `+flag` / `-flag` shorthand |

## Use them as input

```sh
# Inspect the data
cx eval greet.cx
cx eval users.cx

# Drive a tour script over one of them
cx eval ../code-tour.cx --data=../code-tour.input.cx
cx eval ../cxpath-tour.cx --data=users.cx
```

For the full Code surface, see [`docs/CX code.md`](../../docs/CX%20code.md)
and the v0.8.0 tour at [`examples/code-tour.cx`](../code-tour.cx).
