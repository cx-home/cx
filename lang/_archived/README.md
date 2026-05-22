# Archived bindings

These bindings were active through v0.7.x but are not part of the
v0.8.0 release scope. The decision is documented in
[backlog `d-2026-05-22-03`](../../docs-src/canonical/backlog.cx):
four bindings (V/Python/Go/Rust) cover the static/dynamic ×
compiled/interpreted spectrum; concurrent maintenance of ten
bindings during v0.7.6 development was masking design issues
(TS GC, Rust ABI catchup, Python decoder ceiling) that consumed
Tier-1 design time.

The archived snapshots preserve the v0.7.6 C ABI surface
(`cx_program_eval*` rather than v0.8.0's `cx_code_eval*`). They will
not receive v0.8.x updates from the core team.

## Bindings here

| Binding | Last active version | Notes |
|---|---|---|
| typescript | v0.7.6 | koffi-based; had Boehm GC issues (workaround landed pre-archive). |
| java | v0.7.6 | maven-built. Smoke + Arrow lanes were green. |
| csharp | v0.7.6 | dotnet 8. Smoke + Arrow lanes were green. |
| ruby | v0.7.6 | ffi gem. Smoke green; no Arrow. |
| kotlin | v0.7.6 | gradle-built; jna-based. Smoke + Arrow green. |
| swift | v0.7.6 | swift package manager; C interop. Smoke green. |

## Restoration

Community contributions to restore any of these for v0.8.x+ are
welcome. The path is:

1. Update FFI extern decls to `cx_code_eval*` (mechanical — see
   [`docs/migrations/v0_8_0.md`](../../docs/migrations/v0_8_0.md)).
2. Adopt the Layer-1 16-method surface per
   [`spec/bindings.md §2.1`](../../spec/bindings.md).
3. Add a Layer-2 idiom pack per host conventions
   ([`spec/bindings.md §3`](../../spec/bindings.md)).
4. Verify byte-identical results against
   [`conformance/binding_api.txt`](../../conformance/binding_api.txt)
   (Layer-1 parity, gate 28.6).
5. PR the binding back to `lang/<name>/`; the Makefile and
   `tooling/binding_native_status.json` add it to the test matrix.

Restoration is not blocked by the core team — once the binding
clears gate 28.6, it ships.

## Why archive rather than delete

History is preserved. A future contributor wanting to restore a
binding can `git mv lang/_archived/<lang> lang/<lang>` and pick up
where v0.7.6 left off — every commit, comment, and test is intact.
The directory move is a single commit, easily reversible.

## Build / test

These directories are deliberately NOT wired into `make test` or
`make build`. They will not compile against the v0.8.0 ABI as-is —
expect undefined-symbol errors from any v0.7.6 binding linked
against a v0.8.0 `libcx.{dylib,so,dll}`. That's the whole point of
the archive.

To build/test against v0.7.x sources, check out the `v0.7.5` tag.
