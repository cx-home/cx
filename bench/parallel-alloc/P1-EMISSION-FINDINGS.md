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
