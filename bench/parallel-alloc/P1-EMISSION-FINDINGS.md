# P1 — Perceus drop EMISSION (the behavior-changing core), delivered & gated

2026-06-11. Branch `wip/v-runtime-memmgmt`. Work done in the upstream clone
`/Users/ep/git-repos/cx/vlang-v-latest` (vlang/v @ `a83aabb`); artifacts mirrored
here. This is step 14c-iii — the risky step the prior sessions deferred: actually
emitting Perceus drops at last-use positions and suppressing the matching
scope-exit autofree, behind `-d perceus`, gated hard.

## What now exists (4 files, ~68 lines of cgen wiring + a 1046-line analysis)

`vlib/v/gen/c/perceus.v` (analysis) + `fn.v` / `cgen.v` / `autofree.v` (emission).
Full diff: `perceus-emission.patch` (applies to clean vlang/v @ a83aabb).

Pipeline, per `ast.FnDecl`, only when `-autofree -d perceus`:
1. **`gen_fn_decl`** computes the emittable drop map + the suppress set, stores
   them on `Gen`, sets `g.is_perceus`. (Flag off ⇒ none of this runs.)
2. **`cgen.stmt()` tail** — after a statement at a drop site, resolves each name
   to its `ast.Var` via the scope and emits the free **inline** (`perceus_drop`,
   which reuses the exact per-type free dispatch as scope-exit autofree — same
   free body, earlier position). Guarded to real, non-redirected output
   (`!skip_stmt_pos && inside_ternary == 0`).
3. **`autofree_scope_vars2`** skips the scope-exit free for any var Perceus
   already dropped (matched by `ast.Var.pos.pos`) — no double free.

Observed in generated C (`straight()` in the corpus): `Array_int_free(&a)` fires
right after `total += a.len` instead of at the function's end. That is the
Perceus last-use discipline realized in the V backend.

## The two correctness theorems this rests on

1. **Use-collection must be TOTAL; CFG precision is only a performance dial.** A
   *missed* use makes a live var look dead → free-too-early → UAF. An *over-counted*
   use just delays a free (safe). So `pcs_collect` / `pcs_collect_stmt` enumerate
   **every** `ast.Expr` (55) and `ast.Stmt` (29) variant with **no `else`** — V's
   match-exhaustiveness check fails the build if a future compiler adds a node
   kind, forcing a decision instead of a silent unsound leaf. (The original
   prototype's `else {}` was exactly the latent UAF: it hid uses inside
   `StringInterLiteral`, `or`-blocks, `ForIn` iterables, `assert`, …)
2. **Emit only on the provably-unconditional subset.** Drops are restricted to
   the entry basic block (the straight-line prefix before any branch/loop/return),
   where every step runs exactly once — so the inline free replaces the scope-exit
   free one-for-one, with no double free and no path-dependent leak.

## NO bail. Variable-level conservative fallback only.

An earlier draft "bailed" a whole function on any unmodeled construct. Rejected as
a shortcut unfit for upstream: it would disable drops for most real functions and
hides, rather than does, the work. The sound design keeps a value alive when it
**can't be proven uniquely owned** — Perceus's documented "GC residual" — at
*variable* granularity, never function granularity. Imprecision costs a missed
optimization, never correctness; precision is monotonically improvable.

## The uniqueness/aliasing classifier (Perceus layer 3) — the real depth

V arrays/strings/maps are **reference types that share heap buffers** across
`filter`/slice/`map`/append/store/return. So "last read" ≠ "safe to free": e.g.
`tests := files.filter(...)` makes `tests` share `files`' string-element buffers;
freeing `files` early corrupts `tests` (this is the `builtin_overflow_test`
failure the gate caught — a real UAF, deterministic). Sound deterministic drop
therefore needs an ownership classifier. `pcs_scan_share` (exhaustive, no `else`)
marks a heap value **shared / not-droppable** when its buffer may be aliased or
retained:
- address taken (`&x`), captured by a closure, passed to `spawn`/channel;
- appended (`a << x`) or stored into an aggregate (`ArrayInit`/`MapInit`/`StructInit` element);
- **passed as a call argument or receiver** — without interprocedural escape
  analysis we must assume the callee may store it;
- **assignment-aliasing**: in `y := f(x)` with both heap, the result may alias the
  argument, so both `x` and `y` are pinned.

This is deliberately conservative (e.g. `b := a.map(...)` pins both `a` and `b`
even though `map` actually allocates fresh) — sound, and the precision is the
documented multi-week follow-on (borrow inference, slice/share tracking → smaller
residual, monotonically).

## Gate results (all green)

| Gate | Result |
|---|---|
| Default build (`-d perceus` OFF) byte-identical | ✅ (only diff anywhere is the compiler's own `@VEXE` self-path) |
| Patched compiler self-builds | ✅ |
| G-DIFF corpus: `-gc none` == `boehm` == `autofree` == `autofree -d perceus` | ✅ `21\|[10,20,30]\|6\|8\|2` |
| G-SAN/G-LEAK: ASan on `-autofree -d perceus` corpus | ✅ clean (no UAF/double-free) |
| V autofree test corpus (6 files) `autofree` rc == `autofree -d perceus` rc | ✅ 6/6 |
| Broad differential sample (40 vlib tests) | ✅ 40/40 rc-equal, 0 regressions |
| `builtin_overflow_test` (the UAF the gate caught) | ✅ fixed by the classifier |

The gate did its job twice: it caught the hidden-use UAF (→ total collection) and
the aliasing UAF (→ sharing classifier). "Passes the tests I ran" was never
trusted; both fixes are sound-by-construction, not test-chasing.

## Honest scope / what remains

- **Coverage is intentionally narrow now**: entry-block only, and the
  conservative classifier pins anything passed to a function or feeding another
  heap value. Real reclamation benefit on hot paths is therefore limited until
  the classifier and CFG coverage widen.
- **Next, each separately re-gated (G-DIFF + G-LEAK + G-CHURN):**
  1. widen emission past the entry block (branch/loop/join drops; needs the
     path-uniform-drop / join rule so suppression stays double-free-safe);
  2. sharpen the classifier (recognize buffer-fresh ops like `map`/`+`-concat as
     non-aliasing; begin interprocedural borrow/escape inference) → unpins the
     common cases, shrinking the GC residual;
  3. `dup` for the shared residual + thread-correct RC (§5.1) before G-CHURN;
  4. then attempt to drop autofree's `-experimental` pointer-free gate — the
     spec's concrete P1 success signal.
- Full P1 is still weeks; this delivers the *mechanism* (proven sound end-to-end)
  and the *conservative floor*, which is the correct, monotonic foundation.

## Classifier sharpening — increment 1: buffer-fresh string ops (2026-06-11)

First step of "sharpen the classifier" (the chosen next direction). In V, string
concatenation (`a + b`) and interpolation (`'${a}${b}'`) **always allocate a new
buffer** — the result aliases neither operand. The assign-aliasing rule was
over-pinning them (`path := dir + '/' + name` pinned `dir`, `name`, *and* `path`).
`pcs_rhs_is_fresh_string` now exempts a single assignment whose target is
`string`-typed and whose RHS (modulo `ParExpr`) is `InfixExpr(.plus)` or
`StringInterLiteral`; those operands + result become droppable (iff their *other*
uses are non-retaining). Deliberately excludes substrings/slices (`IndexExpr` +
`RangeExpr`) and array/map concat, which DO share buffers and stay pinned.

Effect: string-building locals now reclaim at last use. Verified
(`build(dir,name)` in the corpus): `a := dir+'/'` drops right after `b := a+name`;
`b`, `c` drop at their last reads. Re-gated green: corpus G-DIFF
(`…|28` added) + ASan clean (confirms freeing `a` after `b:=a+name` is no UAF),
autofree corpus 6/6, broad 40/40, default-off byte-identical.

**Next sharpening step (the dominant pin): interprocedural borrow/escape
inference.** The call-arg/receiver rule pins everything passed to any function.
Plan: per-`FnDecl` parameter-escape summary (a param escapes iff the body's
`pcs_scan_share` marks it shared, or it is returned), fixpoint over the call
graph, external/generic callees conservatively escaping; then at a call site,
only pin args bound to escaping params. This is its own careful, separately-gated
pass (G-DIFF + G-LEAK), not bolted onto this increment.

## Classifier sharpening — increment 2: interprocedural escape inference (2026-06-11)

The dominant residual pin. Before this, **every** value passed to **any** function
(receiver or argument) was marked shared, because without knowing what the callee
does we had to assume it might retain the buffer. That single rule pinned most
heap locals on any real (call-bearing) code path. This increment replaces it with
a whole-program parameter-escape analysis.

**Summaries.** `build_escape_summaries` (run ONCE in `cgen.gen()`, before the
parallel/serial per-file split, gated on `-autofree -d perceus`) computes a map
`fkey() -> []bool` (per-parameter "does this parameter's heap buffer escape the
callee"). For methods, `vec[0]` is the receiver and the explicit params follow.
The result is read-only during emission, so the parallel cgen workers (clones of
`global_g`) share it safely; it is copied onto each worker `Gen` alongside
`is_autofree`.

**A parameter escapes** iff, after the existing local sharing classifier
(`pcs_scan_share`) runs over the body, its name is marked shared (address-taken,
`<<`-appended, captured, spawned, channel-sent, stored in an aggregate, or passed
on to another *escaping* slot) OR it appears in a return expression. To close the
`y := param; return y` **alias-return hole**, heap-owning parameters are seeded
into `heap_vars` for the summary computation, so the assignment-aliasing rule
fires on them too — copying a heap param into a heap local pins the param.

**Fixpoint.** The call rule is mutually recursive (param P of f escapes iff f
passes P to an escaping slot of g, which depends on g's summary), so the analysis
is an **ascending fixpoint from "nothing escapes"**: a param flips false→true only
when evidence appears, never back. Monotone over a finite domain ⇒ it is the LEAST
(most precise) sound fixpoint and it terminates. Mutual recursion
(`a(x){b(x)}`/`b(y){a(y)}`) correctly settles non-escaping — a descending/greatest
fixpoint would miss it. A round cap (200) is a pure backstop; if ever exhausted it
falls back to all-escaping (sound). Real programs (incl. full vlib) converge in a
few rounds.

**Conservative defaults (unchanged worst case).** `pcs_call_escape` returns
all-escape — i.e. the exact pre-interprocedural behavior — whenever the callee
cannot be soundly summarized: non-V (`C`/`JS`) callees, no-body, **generic**
functions (skipped: behaviour varies per instantiation), and indirect calls
(`is_fn_var`/`is_field`) or any callee with no recorded summary. Arguments beyond
the declared params (variadic spread / arity mismatch) also fall back to escape.
So the change can only ever REMOVE pins, never license an unsound early drop.

**Proof it works (generated C).** For `r := classify(a)` where `classify(xs []int)`
only reads `xs.len` in a condition (xs neither returned nor stored): the
interprocedural summary marks `classify`'s param non-escaping, so the call no
longer pins `a`, and `Array_int_free(&a)` now fires **immediately after the call**
(a's true last use) instead of at scope exit several statements later. The
matching escaping case `passthru(ys) { return ys }` keeps its arg pinned.

**Re-gated green (each independently):**
| Gate | Result |
|---|---|
| Flag-off (`-d perceus` off) byte-identical, old (pre-interproc) vs new compiler | ✅ 7/7 real example programs identical |
| G-DIFF corpus: `none` == `boehm` == `autofree` == `autofree -d perceus` | ✅ `21\|[10,20,30]\|6\|8\|2\|28` |
| G-SAN/G-LEAK: ASan on `-autofree -d perceus` corpus + 6 heavier vlib tests | ✅ clean (no UAF/double-free) |
| V autofree test corpus (6 files), `v test` rc parity | ✅ 6/6 |
| Broad differential (45 vlib tests, many modules), `autofree` rc == `perceus` rc | ✅ 45/45, 0 regressions |

(`array_test`/`arrays_test` return rc=1 under `-autofree` with AND without perceus —
a pre-existing upstream autofree limitation, identical either way; default GC
passes. Not a perceus regression.)

**Still monotone.** The summary's "escape" is over-approximate in the aliasing
direction (any heap param copied into a heap local is pinned; generic/indirect
callees fully escape). Precision is the documented follow-on (slice/borrow
tracking, generic-instantiation summaries, return-of-scalar-projection
refinement).

## Emission widening — increment 3: the always-executed "spine" (2026-06-11)

Removes the entry-basic-block-only restriction on WHERE drops may be emitted.
Before, a heap local was droppable only if its last use preceded the function's
first branch/loop/return; the common "compute, branch in the middle, keep using
the value, return at the end" shape reclaimed nothing.

**The spine.** Emission now drops a variable if its last use lands in any block on
the **spine**: the chain of top-level body statements that always execute exactly
once. The spine is recorded during a top-level lowering pass
(`pcs_lower_body_spine`) and **stops at the first top-level statement that may exit
the function early** — `return`, `goto`, or a `?`/`!` error propagation
(`pcs_stmt_has_early_exit` / `pcs_expr_has_exit`, which recurse through control
flow but not into closures; `break`/`continue` are loop-local at function scope and
are NOT exits). Every step in a spine block runs exactly once on every execution,
so an inline drop there replaces the scope-exit free 1:1 — no double free, no
path-dependent leak.

**Why this needs no branch-balancing / no cgen surgery (the STOP-and-FORK condition
is avoided).** A variable whose last use is *inside* a branch or loop, or *after*
an early exit, simply lands in a NON-spine block and is left to scope-exit autofree
— never dropped early, never suppressed. So we never have to insert balancing drops
on sibling branches, and the emission hook (keyed by `stmt.pos`) is unchanged. The
only soundness obligation is "the drop site is always-executed," which the spine
guarantees by construction.

**Memory safety is unconditional; only leak-tightness depends on exit detection.**
We only ever SUPPRESS a scope-exit free, never add one, and only drop a variable
proven dead (unique, non-returned, non-shared, past its last use) at an
always-executed point — so a UAF or double-free is impossible regardless of the
exit detector. A *missed* early exit could at worst leak on that exit path; the
detector therefore errs toward reporting an exit, and the claim is gated directly
(below).

**Proof (generated C).** `widen(c)`: `a`'s last use `n += a.len` sits AFTER a
non-exiting `if c { n += 1 }`; the free now fires right there (across the if),
two statements before scope exit. `used_in_branch(c)`: `a`'s last use is inside
`if c { n += a.len }` → non-spine → free stays at scope exit. `early_return(c)`:
the `if c { return 0 }` ends the spine, so `a` (used afterwards) is freed by normal
autofree at BOTH returns — never suppressed (exactly what prevents the leak that
keeping the spine open would cause).

**Re-gated green (each independently):**
| Gate | Result |
|---|---|
| Flag-off (`-d perceus` off) byte-identical, pre-spine vs new compiler | ✅ 7/7 example programs identical |
| G-DIFF corpus: `none` == `boehm` == `autofree` == `autofree -d perceus` | ✅ `21\|[10,20,30]\|6\|8\|2\|28` |
| G-SAN: ASan on corpus + 6 heavier vlib tests under `-d perceus` | ✅ clean |
| **G-LEAK: macOS `leaks --atExit` delta, propagation+loop+spine workload** | ✅ **0 leaks**, autofree == perceus (no leak introduced across `!`/`?`) |
| V autofree test corpus (6 files), `v test` rc parity | ✅ 6/6 |
| Broad differential (45 vlib tests), `autofree` rc == `perceus` rc | ✅ 45/45, 0 regressions |

**Next:** `dup` for the shared residual + thread-correct RC (§5.1) before G-CHURN;
then attempt to drop autofree's `-experimental` pointer-free gate (the spec's P1
success signal). Further coverage (drops inside provably-balanced branches/loops)
remains future work but now sits behind a clean, sound floor.

## The P1 SUCCESS SIGNAL — increment 4: sound user-reference (`&Foo`) drops (2026-06-11)

The spec's named P1 success signal: retire autofree's `-experimental` pointer-free
gate by making `&Foo` frees **sound** instead of blanket. Today autofree refuses to
free user-reference pointers without `-experimental` (autofree.v `is_user_ref`),
because it cannot tell unique from shared — so heap `&Foo` allocations leak. Perceus
can tell, so unique ones can be reclaimed.

**Two independent proofs are required to free a `&Foo`, and the gate needs BOTH:**
1. **Uniqueness** — the share classifier proves the pointer is not aliased/retained.
2. **Ownership** — the binding OWNS fresh memory: its defining RHS is `&Foo{...}`
   (`pcs_rhs_is_fresh_ref`; parsed as `PrefixExpr(.amp, StructInit)`). A *borrowed*
   pointer (`p := other`, `p := obj.f`, `p := f()`) points to memory it does not
   own; freeing it would corrupt the real owner. This is the ownership half that
   autofree's separate `is_auto_heap` gate (autofree.v:273) encodes — and which
   uniqueness ALONE does not replace. The earlier increments' `has_method('free')`
   path admitted `&FooWithFree` pointers as drop candidates unconditionally; this
   increment tightens **all** pointer-typed candidates to owned-fresh (strictly
   safer — fewer drops, closes that latent borrowed-pointer aliasing risk).

**Classifier hardening for pointer aliasing (pointers don't clone; arrays do).**
`obj.field = p` / `a[i] = p` / `*q = p` stores aliase a pointer (V clones
arrays/strings/maps on such stores, so they were safe before, but NOT pointers):
`pcs_is_store_target` now pins every heap ident on the RHS of a field/index/deref
store. Casts and `unsafe { … }` (which can launder a pointer into an opaque
binding) pin their operands. Combined with the pre-existing `&`/append/aggregate/
call-escape(interproc)/return/copy-alias rules, every pointer-escape route is pinned.

**Emission.** `Gen.perceus_dropping` is set only inside `perceus_drop`; under it
both autofree gates relax — `is_user_ref` frees without `-experimental`, and the
`is_auto_heap` early-return is skipped — because Perceus has supplied the
ownership+uniqueness proof those gates lacked. Reuses the exact `free(p)` dispatch.

**Proof (generated C + leaks).** Hostile corpus `uref_corpus.v` (`@[heap] Node`):
`unique_ref` now emits `free(p); // autofreed ptr var` at p's last use; the four
escape cases — `aliased_ref` (`q := p`), `returned_ref`, `field_store_ref`
(`b.p = p`), `call_escape_ref` (`keep(p)` returns it) — all stay pinned (no free).
`leaks --atExit` on the corpus: **autofree 5 leaks / 80 B → perceus 4 leaks / 64 B**
— Perceus reclaims the one owned-fresh unique `&Node` autofree leaks, introduces no
new leak (the 4 residual are the genuinely-escaping pointers).

**Re-gated green (each independently):**
| Gate | Result |
|---|---|
| Flag-off byte-identical, pre-uref vs new compiler | ✅ 7/7 |
| G-DIFF: corpus + uref_corpus `none == perceus` | ✅ (`…\|28`; `14 22 13 34 38`) |
| **G-SAN: ASan on uref_corpus + 30 pointer/struct-heavy vlib tests** (linked_list/heap/bst/…) | ✅ **30/30 + corpus clean, 0 UAF/double-free** |
| G-LEAK: `leaks --atExit` delta | ✅ perceus 4 < autofree 5 (reclaims unique `&Foo`, no new leak) |
| V autofree test corpus (6 files) rc parity | ✅ 6/6 |
| Broad differential (45 vlib tests) rc parity | ✅ 45/45, 0 regressions |

**P1 status.** Spec §6 Phase-1 gate ("autofree corpus byte-identical; soundness
argument documented") was already met by increments 1–3; this increment delivers
the explicit **P1 success signal** — sound, gated reclamation of user-reference
pointers that the `-experimental` flag could only do unsafely. Residual precision
(borrowed-but-provably-owned pointers via richer ownership analysis; deep free of
nested heap fields) and the §5.1 thread-correct RC for the shared residual are
**Phase 3** (gated by G-R2s/G-CHURN, needs the per-thread mcache allocator). P2
(reuse analysis, the R1 win) is the next spec phase in order.

---

# P2 — reuse analysis (the R1 win)

Spec §6 Phase 2 gate: R1 met (≥ Boehm single-thread) + `arr.map`/`arr << x`
confirmed in-place on unique data.

## Landscape (measured on generated C, 2026-06-11)

- **`arr << x` is ALREADY in-place** on unique arrays: V emits `array_push(&a, …)`,
  which grows `a`'s own buffer (realloc only when cap is exceeded) — no clone. So
  the "confirm `<<` in-place" half of the gate is satisfied as-is; nothing to do.
- **`arr.map(f)` allocates a fresh buffer**: `_t1 = __new_array(0, a.len, sizeof T)`
  then a push loop reading `_t1_orig = a`. THIS is the reuse target — when `a` is
  unique + dead after the map + same element size, the result can reuse `a`'s
  buffer instead of allocating. (`gen_array_map`, array.v:866/947.)

The reuse requires two coupled pieces: **(P2.1)** prove `a` stays uniquely owned
*through* the map (today the conservative call-receiver + assign-aliasing rules pin
it), then **(P2.2)** the buffer-reuse codegen, which makes `b.data == a.data` and
must therefore ELIDE `a`'s free (double-free risk). P2.2 is its own focused turn.

## P2.1 — fresh-array classifier refinement (the reuse precondition) — DONE 2026-06-11

`b := a.map(f)` / `a.filter(f)` produces a brand-new buffer; for **primitive
element types** that buffer shares no heap with the receiver, so the receiver
neither escapes into the call nor is aliased by the result — `a` stays uniquely
owned and is droppable at the map. `pcs_is_fresh_array_call` (keyed on
`CallExpr.kind == .map/.filter`, NOT `name` — the builtins dispatch by kind)
guards on `!pcs_is_heap_owning(elem_type)`: `[]int.map(it*2)` qualifies, but
`[]string.filter(…)` does NOT — its result copies string *headers* that share the
receiver's element buffers, so freeing `a` would corrupt `b` (a real UAF). The
refinement exempts such calls from BOTH the call-receiver escape pin and the
assign-aliasing pin (mirroring the increment-#1 buffer-fresh-string exemption).

Effect (generated C): `map_prim()` now frees `a` right after the map (its last use)
instead of at scope exit; `filter_strings()` correctly keeps `a` to scope-exit
(string elements alias). This is a real drop-coverage win for the very common
`b := a.map(…)` primitive pattern AND the precondition the P2.2 reuse will consume
(`a` in the drop map at the map statement = "safe to reuse its buffer").

**Gated green:** flag-off byte-identical 6/6; G-DIFF `p2_reuse_corpus` + corpus
`none == perceus`; ASan clean (`p2_reuse_corpus` incl. the `[]string` hazard + 29
array/map/datatypes/strings-heavy vlib tests, 0 UAF/double-free); autofree corpus
6/6; broad differential 45/45 rc-equal, 0 regressions. Corpus banked:
`bench/parallel-alloc/p2_reuse_corpus.v`.

## P2.2 — in-place map buffer reuse codegen — DONE (mechanism), R1 BLOCKED on loop emission (2026-06-11)

`gen_array_map` now reuses the receiver's buffer for the result when the receiver
is a bare heap-array local that the analysis proved **unique + dead at this very
statement** (`recv_name in g.perceus_drops[g.perceus_cur_stmt_pos]`) AND
`inp_elem_styp == ret_elem_styp` (same element size). It emits
`_t1 = _t1_orig; _t1.len = 0;` (reuse the receiver's data ptr + cap; refill in
place — cap == orig.len, so the push loop never reallocs) instead of
`__new_array`, and ELIDES the receiver's free via `perceus_reused` (keyed by the
var's `pos.pos`; the drop hook skips it). The shared buffer is freed exactly once,
via the result `b`. New `Gen.perceus_cur_stmt_pos` (set in `stmt()`, save/restored)
gives `gen_array_map` the drop-map key for "is this dropped HERE".

**Soundness:** the read `_orig.data[i]` and the in-place write (push at index i)
alias the same buffer, but slot i is written only after it was read this iteration
and i increases monotonically, so no element is clobbered before use (valid for
equal element size). Eligibility = membership in this statement's drop set, which
already means unique + dead + non-shared + non-returned — so no other reference to
the buffer survives. Verified on the hazard corpus: `aliased_map` (`c := a`),
`used_after_map` (`a` live after), `size_change` (`[]int`→`[]string`) all correctly
**suppress** reuse; only the unique+dead+same-size `safe_reuse` reuses.

**Gated green:** flag-off byte-identical 7/7 (incl. the `stmt()` change); G-DIFF
corpus + uref_corpus + hazard corpus `none == perceus`; ASan clean (corpus +
hazard corpus + 34 array/map/datatypes/encoding/strings-heavy vlib tests, 0
UAF/double-free); autofree corpus 6/6; broad differential 45/45 rc-equal. Corpora
banked: `p2_hazard_corpus.v`, `p2_reuse_bench.v`.

**HONEST R1 status — NOT met yet, and exactly why.** The reuse mechanism is
correct, but on the micro-bench (`p2_reuse_bench.v`: 8M × `a := […]; b := a.map(…)`)
it fires **0 times** and perceus ties autofree (−prod: boehm 0.38s, autofree 0.43s,
perceus 0.43s). Cause: the map sits **inside a loop**, and drop emission is
restricted to the function's top-level **spine** (increment #3) — loop bodies are
not spine, so the receiver is never in `perceus_drops` there, so reuse never fires.
**Any** measurable bench drives the map in a loop, so G-R1 cannot be met until drop
emission widens into loop bodies. Reuse DOES fire and is measured-correct for
spine-level (top-level) maps; it's the hot-loop case that's gated.

**Next — the unlocking increment: per-iteration loop-body emission.** Extend the
spine to the straight-line prefix of each loop body (statements that run exactly
once per iteration, before any nested branch/early-exit). A heap local defined and
last-used within one iteration (dead across the back-edge) becomes droppable each
iteration — which both lands P2's R1 reuse on hot loops AND is the largest
remaining drop-coverage lever generally. Its own careful, separately-gated pass
(cross-iteration liveness, break/continue/return within the body). Then re-run the
G-R1 micro-bench (expect the map allocation eliminated per iteration). After that:
the deferred §5.1 thread-correct RC for the shared residual (Phase 3).
