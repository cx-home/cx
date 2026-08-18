# Partition evidence — vcx import-edge audit

**Campaign:** #651/#516 (see `partition_campaign_PLAN.md`). **Date:** 2026-08-04.
**Method:** exhaustive grep of `import` statements, `#flag`/`#include` directives,
and qualified cross-module references across `vcx/`, verified per-file.
**Status:** evidence, not normative.

## 1. The dependency DAG (production files, deduped)

```
cx        -> []                                  (V stdlib only — strict sink)
cxstore   -> [cx]
arrow     -> [cx]
code      -> [cx, cxstore, arrow, transport.picoev, transport.picohttpparser]
cmd       -> [cx, code]                          (arrow via dlopen only)
transport/* (picoev, pico_http_parser, picohttpparser) -> leaf, vendored, no cx/code deps
testenv   -> []                                  (os only)
```

No cycles. `cx` has in-degree 6+, out-degree 0. Nothing imports `cx` in reverse.

## 2. Seam-critical result: vcx/cx is CLEAN

Zero files in `vcx/cx/` (76 .v files) import `code`, `cxstore`, `transport.*`,
or `arrow`. Full external import set of the module: `compress.zstd,
crypto.blake3, crypto.sha256, crypto.sha512, encoding.base64, math, os,
strconv, strings` — V stdlib only. The one deliberate inversion is documented
in-source (`cx/data_bin.v:777-778`): date helpers are duplicated rather than
imported "so the cx core has no dependency on the optional arrow module."

**Implication for #516:** the Ring-0 extraction is not a disentanglement — the
import seam already holds. Extraction is packaging/build work plus the
stragglers below, gated by the byte-for-byte conformance corpus.

## 3. Ring-relevant placement facts

- **cxstore (the engine) sits BETWEEN cx and code**: `vcx/cxstore/` (20 files)
  is the content-addressed object-graph engine — packs, seqtree, indexes,
  planner, GC, reflog, encryption, mmap. It imports ONLY `cx`; links no
  external library (sole C touch: `<sys/mman.h>`). `vcx/code/store_*.v`
  (92 files) is the `[$store]` verb surface + URL dispatch + wire protocols
  (CSRP, gRPC, remote substrates); 70 import cxstore as thin adapters, 22 are
  pure protocol/policy with no object-graph contact. Direction strictly
  one-way: cxstore never imports code.
- **Single-artifact rationale is explicit** (`vcx/Makefile:157-161`): libcx is
  built from `vcx/code/` so the cabi exports of both cx and code ship in one
  library. The partition's per-ring artifacts replace exactly this decision.
- **cmd reaches Arrow only via dlopen** (`cmd/table_arrow.v`, `dl.sym_opt` on
  `cx_arrow_*`; `$CX_ARROW_LIB`) — the only `dl` use in the tree. Ring-friendly
  precedent for optional-capability linkage.
- **cmd has a direct cx channel bypassing code**: LSP diagnostics files and
  `cmd/table.v` import `cx` without `code` — the CLI already consumes the
  Ring-0 surface directly where evaluation isn't needed.
- **code carries the heavy external surface**: 6 DB drivers, net.mbedtls,
  net.unix, 12 crypto modules, 3 compression modules, 5 raw C files, libssh2
  pkgconfig; 15 of the tree's 17 build-flag-gated files live in code/.

## 4. Ring-0 straggler verdicts (answers plan §Known extraction risks)

| Straggler | Finding | Disposition for extraction |
|---|---|---|
| `cx/regex_re2.v` (re2) | Only in-cx caller: `schema_validate.v` (S008 pattern constraint). schema.md §7.1 makes RE2 **normative for cross-binding determinism**. Hard dep of every current build target. Out-of-module callers: code/stdlib_re, stdlib_jsonschema, stdlib_validate. | **Load-bearing for Ring 0** (schema validate is a Ring-0 capability). re2 stays a Ring-0 dependency; it is the ring's only heavy external. |
| `cx/arrow_pub.v` | 68 lines, `module cx`, zero imports, zero Arrow types — a re-export shim of cx internals for the arrow module to consume. Consumers: arrow/arrow.v + one conformance runner. | Harmless in Ring 0 (no dependency edge); could be renamed to drop "arrow" from Ring-0 vocabulary, cosmetic only. |
| GC shims (`gc_thread_shim*`) | Build-gated by `_d_gcboehm` filename convention; no-op fallback exists. Only 2 files in cx/ have `fn C.` decls (this + re2). | Stays — gated, self-contained, needed wherever libcx-core runs under Boehm. |
| `cx/fixture_loader.v` | Compiled unconditionally into libcx (198 lines, pub API, no build gate); consumers are ALL tests/runners; zero production consumers. | **Extraction cleanup**: move to a test-support module or gate it out of the shipped artifact. |

## 5. Debris / dead code found (cleanup candidates, tracker-worthy)

- **`vcx/cxstore/cxsqlite/` is a dead module** — nothing imports it; its
  module-boundary feature-gating approach was superseded by
  `code/store_sqlite_d_cxstore_sqlite.v` (`-d cxstore_sqlite`); root Makefile
  explicitly excludes it from the default surface.
- **`vcx/cx/cx.dylib`** (and `vcx/target/` .dSYM bundles) — build artifacts
  sitting inside source dirs.
- **`import code as _`** — one blank-alias (link-for-side-effects) import
  exists in the tree; exact location to pin down (hidden-edge check).

## 6. What this means for the layering verdict (#651)

The empirical layering is `cx → {cxstore, arrow, transport} → code → cmd`,
which maps onto rings as: Ring 0 = cx (already a strict sink); Ring 2's
store ENGINE (cxstore) is a clean, dependency-light module directly on
Ring 0; Ring 1 (evaluator/stdlib) and Ring 2's protocol/service surfaces are
currently fused inside `code` — **the real extraction frontier is inside
`code`, not around `cx`**. Any ring model that assumes "store sits above the
language" contradicts the shipped structure: the store engine depends only on
the value model (Ring 0), while the store's *verb surface* depends on the
evaluator (Ring 1). The partition spec should treat those as two different
things.
