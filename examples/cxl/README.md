# CXL examples

Runnable CXL templates against CX context documents. Each example
pairs a `.cx` data file with a `.cxl` template file.

```sh
$ cx eval greet.cxl --data=greet.cx
Welcome Alice! Role: admin.
```

## Files

| Example | What it demonstrates |
| ------- | -------------------- |
| `greet.{cx,cxl}` | `[?if cond :then … :else …]` + `[?= @attr]` interpolation |
| `users.{cx,cxl}` | `[?for var :in path :return …]` iteration over elements |

## Run them

```sh
cx eval greet.cxl --data=greet.cx
cx eval users.cxl --data=users.cx
```

For the full CXL reference: [`docs/CXL.md`](../../docs/CXL.md).
