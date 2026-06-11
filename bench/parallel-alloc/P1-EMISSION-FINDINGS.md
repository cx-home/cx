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
