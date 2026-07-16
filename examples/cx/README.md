# CX code examples

Two small CX data fixtures — standalone shape samples you can run
directly, and handy inputs for experimenting with the program tours one
directory up (`examples/code-tour.cx`, `examples/cxpath-tour.cx`,
`examples/match-multi.cx`, `examples/modify-crud.cx`).

## Files

| File | Shape |
| ---- | ----- |
| [`greet.cx`](greet.cx) | single `[user]` element with `name=`, `role=`, `active=` attributes |
| [`users.cx`](users.cx) | `[team]` with three `[member]` rows carrying boolean `active=` attributes |

## Run them

```sh
# Inspect the data (a data document renders as itself)
cx greet.cx
cx users.cx
```

The tour run line `cx ../code-tour.cx --data=../code-tour.input.cx`
binds the input document as `$doc` (the
[#415](https://github.com/cx-home/cx-private/issues/415) fix), so the
document-driven sections render against the sample data.

For the full Code surface, see the rendered guide chapter
[`docs/guide/code.html`](../../docs/guide/code.html) (built into
`docs/guide/` by the publish flow) and the tour at
[`examples/code-tour.cx`](../code-tour.cx).
