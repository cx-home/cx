# CX code examples

Runnable CX code templates against CX context documents. Each example
pairs a `.cx` data file with a `.cx` template file.

```sh
$ cx eval greet.cx --data=greet.cx
Welcome Alice! Role: admin.
```

## Files

| Example | What it demonstrates |
| ------- | -------------------- |
| `greet.{cx,cxl}` | `[?if cond :then … :else …]` + `[?= @attr]` interpolation |
| `users.{cx,cxl}` | `[?for var :in path :return …]` iteration over elements |

## Run them

```sh
cx eval greet.cx --data=greet.cx
cx eval users.cx --data=users.cx
```

For the full Programs reference: [`docs/CX code.md`](../../docs/CX code.md).
