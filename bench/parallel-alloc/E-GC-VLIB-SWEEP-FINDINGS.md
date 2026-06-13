# `-gc e` vlib sweep — codegen bugs flushed (2026-06-12)

After the two map fixes (MAP-TINY-FREE-FINDINGS.md), a curated `-gc e` sweep over the
memory-relevant vlib modules + the compiler feature suite was run to flush more
latent `-gc e` bugs (the cx B14 gate at 125/125 never exercised these shapes).

## Sweep result
- **Core memory modules: ALL GREEN under `-gc e`** — builtin, strings, strconv,
  datatypes, arrays, maps, math, hash, rand, bitfield, encoding (56), os (24),
  regex, time, sync (37). The map fixes hold across the board.
- **`vlib/v/tests` (compiler feature suite): 34 failed / 2146.** Every failure
  confirmed **`-gc e`-specific** (passes `none` AND `boehm`) and **pre-existing**
  (reproduces on the no-fix compiler → unrelated to the tiny-free / perceus map
  fixes). These are E-codegen gaps.

## Bug 1 — `HEAP_vgc` macro arity (✅ FIXED) — cleared 22 of the 34
Dominant family (ORM ×18, reflection, sql, generics, interfaces, fns). The
`HEAP_vgc(type, expr, ptrmap, nptrs)` macro (4 args) was emitted with only 2:
`write_heap_alloc` opened `HEAP_vgc(type,(` based on `vgc_ptrmap(typ)`, while a
close path (notably the option-auto-heap close in assign.v, and any open/close
`vgc_ptrmap` disagreement) wrote `))` → 2-arg call → clang "too few arguments to
function-like macro invocation" (+ cascade "undeclared identifier HEAP_vgc").

**Root insight:** `HEAP_vgc`'s `ptrmap`/`nptrs` are **dead at runtime** —
`vgc_malloc_typed_opts` ignores them (the unsound per-span precise scan was removed;
the conservative-mark backstop scans every scannable span). So `HEAP_vgc` and plain
`HEAP` allocate identically. **Fix: stop emitting `HEAP_vgc` entirely — always emit
plain `HEAP` under vgc** (write_heap_alloc / write_heap_alloc_close in cgen.v + the
auto-heap open/close in assign.v). Eliminates the whole arity-mismatch class and
realigns codegen with the conservative-mark runtime. Patch: `heap-vgc-arity-fix.patch`
(CX-free); folded into `E-canonical.patch`. The vestigial `vgc_ptrmap` helper is left
defined-but-unused.

Validated: 34 → 12 failures. All ORM/sql/most interfaces+options+fns now pass under
`-gc e`; core modules unaffected.

## Remaining 12 (grouped by root cause) — NOT yet fixed
1. **Undeclared `_free` (compile, 3):** `shared_generic` (generic `Foo_T_int_free`),
   `modules/sub/sub_test` (`sub__Foo_free`), `option_ifguard_array` (`_option_string_free`).
   A user/auto `free()` for a generic / sub-module / option type is CALLED by the
   autofree/Perceus drop path but never declared+defined — free-method registration
   vs `-skip-unused` dead-code elimination interaction under `-gc e`. (`gen_free_for_*`
   bodies string-construct nested `_free` names without registering the nested type;
   `gen_free_methods` is a single pass, no worklist.) Autofree/boehm regression risk —
   needs care.
2. **Reflection / generic-anon-fn segfaults (runtime, 4):** `reflection_test`,
   `reflection_sym_test`, `reflection_attr_quotes_test`,
   `generics/generic_anon_fn_inside_generic_fn_test`. Likely one shared root cause
   (reflection metadata reclaimed under `-gc e`).
3. **String-output corruption (runtime assert, 3):** `tmpl_test`,
   `comptime_call_tmpl_dollar_literal`, `interface_auto_str_test` — truncated/aliased
   strings; smells like a Perceus/free early-drop of a builder/string.
4. **`option_init_ptr_test` (compile, 1):** "extraneous `)` before `;`" — a distinct
   option-ptr-init close-paren codegen bug (NOT a `_free` issue).
5. **`vgc_malloc_noscan` panic (runtime, 1) — ✅ FIXED.** `thread_wait_ptr_test`
   spawns ~999 concurrent `go` threads, far exceeding the fixed `[vgc_max_threads=64]`
   cache table. `vgc_register_thread` deliberately leaves `cache_idx = -1` when the
   table is exhausted, but the alloc fast path then indexed `caches[-1]` → `V panic:
   fixed array index out of range (index: -1, len: 64)` (and the panic's own message
   formatting re-entered malloc → infinite recursion). Two unguarded `caches[cache_idx]`
   sites: `vgc_cache_get_span` and `vgc_acct_alloc` (`vgc_acct_free`/`vgc_safepoint`
   already guarded `idx<0`). **Fix:** `cache_idx<0` → `vgc_cache_get_span` allocates
   straight from central (locked, no per-thread cache); `vgc_acct_alloc` folds bytes
   into the global atomics (mirrors `vgc_acct_free`). Patch:
   `vgc-overflow-thread-alloc-fix.patch`. thread_wait_ptr passes; concurrency suite
   67/69 (the 1 fail is `shared_generic`, the `_free` bug #1).
   **KNOWN LIMITATION (pre-existing, not introduced here):** an overflow (>64th)
   thread has no cache slot and is therefore NOT in the collector's suspend/root-scan
   set, so heap objects reachable ONLY from such a thread's stack across a GC could be
   reclaimed (UAF). The fix turns a guaranteed crash into correct behavior *when
   overflow threads hold no cross-GC heap roots* (the common case — workers compute &
   return values, as here). Fully sound >64-thread support needs overflow-thread root
   scanning (or a larger cap) — a separate design item.

## Status (this sweep)
Fixed this pass: **HEAP_vgc arity (22 files)** + **vgc_malloc_noscan overflow panic (1)**.
Original 34 `-gc e` failures → **~11 remaining**: undeclared `_free` ×3 (#1), reflection/
generic-anon-fn segfaults ×4 (#2), string-output corruption ×3 (#3), `option_init_ptr`
paren ×1 (#4). All deeper (DCE/reflection/Perceus-string) — distinct follow-ups.

All V-only / CX-agnostic. Fixes live in the clone working tree; captured via
`E-canonical.patch` + per-bug standalone patches.
