# CX — V (internal C-binding test layer)

> **V users:** install the pure V package instead — no C dependency required:
> ```sh
> v install --git https://github.com/cx-home/cx-v
> ```
> See [cx-home/cx-v](https://github.com/cx-home/cx-v) for the full API and docs.

---

This directory (`lang/v/cxlib/`) is the **internal C-ABI test layer** for the CX
project. It is not a user-facing package.

Its purpose is to verify that `libcx` (compiled from the native V source in
`vcx/`) exports correct behavior through its C ABI (`cabi.v`). Every other
language binding — Go, Rust, Python, TypeScript, Swift, Java, Kotlin, C# — links
the same `libcx`. V is the one language that can directly compare the C ABI
output against the known-correct pure V implementation, making this the
authoritative integration test for the shared library.

## Requirements

- V 0.5 or later (`v --version` to check)
- `libcx` built: `make build-vcx` from the repo root

## Running the tests

```sh
make test-v
```

## Examples

```sh
v run lang/v/examples/demo.v
v run lang/v/examples/transform.v
```
