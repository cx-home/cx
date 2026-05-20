# Reproducible builds

Per `spec/v0_7_0_status.md` BB, a third-party builder must be able
to produce binaries whose SHA-256 hashes match the published
`dist/SHA256SUMS.txt` for any tagged release from v0.7.0 onward.

This document is the recipe: pinned toolchain versions, deterministic
compile flags, the build script, and the verification step.

## Tooling pin

| Component | Pin (v0.7.0 baseline) | Note |
|---|---|---|
| V compiler | 0.4.x — commit pinned per release | Embedded build-version macros are sensitive to V's own version. Bump policy: every cx release pins one V commit. |
| C compiler | Apple clang ≥ 15 (macOS) / gcc ≥ 11 (Linux) | The C-level `-Os -DNDEBUG -DNO_DEBUGGING -fwrapv` flags in `vcx/Makefile::PROD_CFLAGS` are stable across these compiler versions for the small libcx surface; any wider drift will be noted here. |
| `RE2` (`libcx_re2_shim`) | Homebrew `re2 ≥ 20240301` / `libre2-dev ≥ 20240301-1` | The shim itself emits no version-dependent code; the build pin guards against RE2 ABI changes. |
| Boehm GC | linked through V's `vlib/gc` | Tracked by V upstream; cx pulls in whichever version V pins. |

The published `dist/SHA256SUMS.txt` is signed off by the release
committer; reproducibility runs only need to match the bytes, not
re-derive the toolchain pin.

## Determinism levers

cx's release build sets:

```
PROD_CFLAGS := -Os -DNDEBUG -DNO_DEBUGGING -fwrapv
SOURCE_DATE_EPOCH := <commit time of the release tag>
```

`SOURCE_DATE_EPOCH` is the canonical environment knob for stripping
build-time timestamps from emitted binaries; ld / clang / V all
honor it. The reproduce script auto-sets it from the tagged commit
when not pre-supplied.

Other determinism notes:

- `strip -x target/libcx.dylib` runs in the release path. Strip
  output is deterministic across runs of the same Apple strip.
- V's `-prod` flag is **not** used at release — it pulls in libgc
  trampolines that conflict with macOS hardened runtime when the
  resulting dylib is dlopen'd from FFI bindings (per the
  `vcx/Makefile` comment at the `-shared` target).
- No `.cache` directories are committed; `lang/v/.cache/` is in
  `.gitignore` to keep V's per-build cache out of release archives.

## The script

```sh
scripts/reproduce_release.sh v0.7.0
```

What it does:

1. Checks out the tag (if supplied).
2. Records the observed V + cc versions (warns on drift from the
   pinned set, doesn't fail).
3. Forces `SOURCE_DATE_EPOCH` from the tag's commit time.
4. Runs `make clean && make build-vcx build-lib-arrow`.
5. Hashes the artifacts and writes `dist/SHA256SUMS.reproduced.txt`.
6. Diffs against `dist/SHA256SUMS.txt` if present; exits non-zero on
   mismatch.

CI runs this on every tag push (see V row item V5 release-artifact
CI). A non-zero exit fails the release-artifact pipeline and blocks
publication until the reproducibility regression is resolved.

## How to investigate a mismatch

If the diff is non-empty:

1. **V version drift.** Run `v --version` on the published builder
   and on the reproducer. If they differ, the V's embedded build-
   version macro is the most common drift source.
2. **`SOURCE_DATE_EPOCH` drift.** Confirm both runs used the tag's
   commit time. The script sets it automatically when not provided.
3. **Toolchain version drift.** Apple clang / gcc minor version
   bumps occasionally change optimiser output. Pin to a specific
   version (Xcode CommandLineTools or `apt install clang-15`).
4. **RE2 / Boehm GC version drift.** Both are linked dynamically;
   verify the runtime versions match (`brew info re2`,
   `dpkg -l libre2-dev`).
5. **Filesystem timestamps.** `make` decisions are timestamp-driven;
   `make clean` between runs eliminates intermediate-object reuse
   that can otherwise leak per-builder bytes.

When the mismatch is real (i.e., not a toolchain drift artifact),
file an issue with both `dist/SHA256SUMS.txt` and
`dist/SHA256SUMS.reproduced.txt` attached.

## Status

| Item | Status |
|---|---|
| BB1 Deterministic compile flags | ✅ — `PROD_CFLAGS` + `SOURCE_DATE_EPOCH` |
| BB2 `reproduce_release.sh` | ✅ — this directory's script |
| BB3 CI reproducibility gate | 📋 — wires into V5 release-artifact CI |
| BB4 `dist/SHA256SUMS.txt` | 📋 — generated at tag time |
| BB5 `docs/reproducible_builds.md` | ✅ — this document |
