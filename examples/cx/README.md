# CX code examples

Two small CX data fixtures used as inputs for `cx eval` demos
elsewhere in the repo (the canonical tours: `examples/code-tour.cx`,
`examples/cxpath-tour.cx`, `examples/match-multi.cx`,
`examples/modify-crud.cx`).

## Files

| File | Shape |
| ---- | ----- |
| [`greet.cx`](greet.cx) | single `[user]` element with `name=`, `role=`, `active=` attributes |
| [`users.cx`](users.cx) | `[team]` with three `[member]` rows carrying boolean `active=` attributes |

## Use them as input

```sh
# Inspect the data
cx greet.cx
cx users.cx

# Drive a tour script over its sample document
cx ../code-tour.cx --data=../code-tour.input.cx
cx ../cxpath-tour.cx --data=../cxpath-tour.input.cx
cx ../modify-crud.cx --data=../modify-crud.input.cx
```

For the full Code surface, see [`docs/CX code.md`](../../docs/CX%20code.md)
and the v0.8.0 tour at [`examples/code-tour.cx`](../code-tour.cx).
