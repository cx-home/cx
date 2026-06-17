# PR #27458 — CI triage + draft maintainer comment (2026-06-15)

CI run: 55 pass / 38 fail. All 38 triaged to **4 root causes**, all ours, all
cheap; fixed on `pr/mem-mgmt-poc` (commits not yet pushed — pushing is what makes
the draft below truthful).

## Full triage (every failing job mapped; representative jobs log-confirmed)

| Root cause | Mechanism | Jobs (confirmed ✓ / inferred) | Fix | Commit |
|---|---|---|---|---|
| **A. `vgc_wb_store` undefined in non-vgc builds** | `-os cross` (and the checker) walk the inactive `$if vgc_concurrent ?` branches in array.v/map.v that call `vgc_wb_store`; its only definition is in `vgc_gc_d_vgc.c.v` (compiled under `-d vgc`). Default GC here is boehm (PR excludes the default-flip), so the symbol is absent. | build-vc ✓, bootstrap-v ×2 ✓, cross-linux ✓, clang-openbsd ✓, clang-freebsd ✓, (gcc/tcc-freebsd, tcc-openbsd inferred) | no-op `vgc_wb_store` fallback in `vgc_wb_fallback_notd_vgc.c.v` (mutually exclusive with real def via file suffix) | `150cec7` |
| **B. `perceus.v` + `cgen.v` not vfmt'ed** | `v fmt -verify` runs in the `test-cleancode` gate of nearly every build/test job → whole job aborts there. | code-formatting ✓, clang/gcc-linux ✓, clang-macos ✓, tcc-linux/-windows ✓, gcc/msvc-windows ✓, docker-ubuntu-musl ✓, all sanitize-* ✓(2 confirmed, rest same gate) | `v fmt -w` (+ 2 POC bench files) | `1bd22eb` |
| **C. `unused parameter: typ` notice** | `write_heap_alloc[_close]` no longer use `typ`; V prints a notice **to stderr** even at exit 0. The `tools-*` harness fails any tool whose compile writes to stderr. | tools-linux(tcc) ✓, riscv64 ✓, (tools-{linux,macos,freebsd,openbsd,docker} family inferred) | mark param `_` | `94be71f` |
| **D. missing fn-doc** | `report-missing-fn-doc` (missdoc `--diff`) requires a name-leading doc comment on new `pub fn`s: `vgc_init`, `vgc_set_watch`. | report-missing-fn-doc ✓ | doc comments | `843469f` |

**Local verification (all on the fixed tree):** fmt -verify clean on all 24 changed/new `.v`;
missdoc clean; `v -gc boehm -os cross` regenerates `v.c` with no `vgc_wb_store` error
(reproduced the failure first, then confirmed the fix); `v -W` tool build emits 0 stderr
lines; `v -gc e` still builds + runs.

**Key correction to our prior worry:** these CI jobs build V's **default** configuration.
`-gc e` is opt-in and not in the standard matrix, so the new vgc code (C11 atomics,
`@[thread_local]`, conservative-mark scanner) is **not compiled or exercised here.** The
tcc-* and sanitize-* reds were the shared fmt/lint gate (cause B), **not** tcc-can't-do-atomics
or sanitizer-vs-conservative-scan. Those concerns are real but only for explicit `-gc e` use.

---

## DRAFT comment (for posting to PR #27458 — requires pushing the 4 commits first)

> Thanks for approving the CI run — that surfaced exactly what we needed.
>
> I triaged the 38 failures; they collapse to **four root causes, all on our side and all
> low-risk**, now addressed on the branch:
>
> 1. **`-os cross` / bootstrap break (real regression, the important one).** The
> concurrent-mark write barrier `vgc_wb_store` is defined only under `-d vgc`
> (`-gc e`), but its call sites in `array.v`/`map.v` sit in `$if vgc_concurrent ?`
> blocks. `v -os cross` emits *every* comptime branch into `v.c`, and the checker walks
> inactive branches too — so in a default (boehm) build the symbol is unresolved and
> `bootstrap-v`, `build-vc`, `cross-*` and the BSD cross-compiles fail with
> `unknown function: vgc_wb_store`. Fixed by adding a no-op `vgc_wb_store` fallback in a
> `_notd_vgc.c.v` sibling (mutually exclusive with the real definition via file suffix;
> zero behavioral change — the barrier is only ever live under `-gc e -d vgc_concurrent`).
>
> 2. **`vfmt`.** `vlib/v/gen/c/perceus.v` and `cgen.v` weren't `vfmt`-clean. Since
> `test-cleancode` runs early in most jobs, this alone reddened the linux/macos/windows
> compilers, the docker images, and the sanitize-* and tcc-* jobs (they abort at the fmt
> gate before reaching their namesake work). Reformatted.
>
> 3. **`unused parameter: typ`.** `write_heap_alloc[_close]` no longer use their `typ`
> arg (the precise-pointer-map `HEAP_vgc` variant is intentionally dead — see the note
> there). V prints a notice to stderr even on a successful build, and the `tools-*`
> harness treats any stderr from a tool compile as failure, so the whole `tools-*` matrix
> (and the riscv64 build) went red. Marked the param `_`.
>
> 4. **Missing doc comments** on `pub fn vgc_init` / `vgc_set_watch`. Added.
>
> Worth flagging: this CI matrix builds V's **default** configuration, so the `-gc e`
> code paths (C11 atomics, `@[thread_local]`, the conservative scanner) aren't actually
> compiled or exercised by these jobs — the failures above are all default-build
> lint/cross issues, not anything specific to the new backend. If it'd be useful, I'm
> happy to add a small opt-in `-gc e` lane so the new collector gets real coverage; the
> two known limitations there are (a) tcc can't compile the C11 atomics the barrier/STW
> code uses, so a `-gc e` lane would need a non-tcc compiler, and (b) the conservative
> mark scan will trip ASan/MSan/UBSan without suppressions. I'd rather take your steer
> on whether you even want that lane than guess.
>
> A couple of things I'd like direction on before going further:
>
> - **Fallback approach for (1):** the no-op `_notd_vgc` stub is the minimal fix, but if
> you'd prefer the barrier machinery never reference a vgc-only symbol from `builtin`
> at all (e.g. gating the call sites differently), I'll restructure to match your
> conventions.
> - **v1 vs v2:** this POC targets the current C backend (`vlib/v/gen/c`). Is that the
> right place for an experiment like this, or would you want it oriented toward `v2`?
>
> This is still a POC / "needs verification" — happy to adjust scope, split it, or hold
> any of it pending your read on the architecture.
