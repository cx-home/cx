# P1 — Perceus ownership/last-use analysis design (vs V's AST)

Loop increment 3 (2026-06-11). Design only (no code). Spec §4.1 front line.
Builds on `P1-AUTOFREE-FINDINGS.md` (V's autofree is scope-exit free, no RC).
Grounded in `vlib/v/ast/ast.v` (`ast.Var`) + `vlib/v/ast/scope.v` (`Scope`) at
upstream `a83aabb`.

## 1. What V's AST provides vs what Perceus needs

`ast.Var` carries: `is_used` (bool — used *somewhere*, not where), `is_changed`,
`is_auto_heap` (address escapes scope), `is_stack_obj`, `is_arg`, `is_mut`,
`share` (`.shared_t` for `shared`), `pos`, `expr`, `typ`. `Scope` is a tree
(`objects`, `parent`, `children`, `start_pos`/`end_pos`).

| Perceus needs | In V's AST today? | Gap |
|---|---|---|
| **Per-occurrence last use** (final read on each path) | No — only a single `is_used` bool | Must compute liveness/last-use |
| **Control-flow graph** (branches, loops, joins) | No — statement/expr tree + scope tree | Must build a CFG or do CF-aware traversal |
| **Aliasing / sharing** (is this value stored into a heap field / captured / shared?) | Partial — `is_auto_heap` flags address-escape, `share` flags `shared` | No general alias analysis |
| **Consuming vs borrowing use** (does this use take ownership or just read?) | No — V has no `&`/`&mut` distinction | Must classify conservatively |
| Type info / size | **Yes** — `typ` + the type table | reuse V's existing per-type `_free`/scan |
| Scope nesting + positions | **Yes** — `Scope` tree | reuse for scope-bounded fallback |

**Conclusion:** V's AST has the *types* and *scope structure* but not the
*dataflow* (last-use, CFG, aliasing) Perceus is formulated on. A Perceus pass
must add that dataflow; it cannot be read off the AST.

## 2. The analysis to build (3 layers)

1. **CFG per function body.** Lower V's stmt/expr tree into a control-flow graph
   (basic blocks + edges for `if`/`match`/`for`/`or`/early-return/`defer`).
   Perceus's drop-at-join and drop-on-unused-branch rules are CFG rules; the
   scope tree alone can't express them.
2. **Liveness / last-use.** Backward dataflow over the CFG: for each owned
   binding, the program points that are its **last use** on each path. This is
   the refinement over autofree's "free at scope exit" → "drop at last use"
   (often earlier; enables earlier reuse).
3. **Uniqueness / ownership classification.** Decide, per value, whether it is
   **provably uniquely owned** at a given point. V has no borrow annotations, so
   default **conservative**: a value is treated as *possibly shared* once its
   address escapes (`is_auto_heap`), it is stored into a heap field, captured by
   a closure (`is_inherited`/`has_inherited`), or sent on a channel / is
   `shared`. Only provably-unique values get deterministic `drop`.

## 3. Insertion rules (Perceus, adapted to V's imperative+alias reality)

- **`drop x`** at `x`'s last use on a path, **iff** `x` is provably uniquely
  owned there. (Refines autofree: earlier than scope exit, and only when sound.)
- **`dup x`** before a *consuming* use that is **not** the last use (value needed
  later) — e.g. value passed to a function/struct that takes ownership while `x`
  is still live afterward.
- **Join rule:** if a binding is consumed on one CFG branch but still live on
  another, insert `drop` on the branch where it is *not* consumed, so ownership
  is uniform at the join.
- **Conservative fallback = the GC residual.** Any value not provably unique
  (escaped/shared/aliased/cyclic) gets **no deterministic drop** → it falls to
  the §5.3 backstop. This is sound by construction and matches "autofree handles
  the unique majority, GC handles the rest." It also means **P1 can ship before
  perfect alias analysis**: more precision = more deterministic frees = smaller
  GC residual, monotonically.
- **Reuse (P2, later):** a `drop x` immediately dominating an allocation of
  compatible shape ⇒ reuse `x`'s storage in place (the R1-beating win).

## 4. Relationship to the existing autofree pass

This **replaces the driver, reuses the machinery.** `autofree_scope_vars2`'s
"walk the scope, free every local at exit" becomes "walk the CFG, drop each
owned binding at its analysed last use." The per-type free dispatch
(`autofree_variable` / `auto_free_methods.v`) is the **`drop` implementation**
unchanged; `dup` is new (a shallow refcount bump for the shared residual, or a
copy where V already has value semantics). `returned_var_names` (escape) becomes
a special case of "ownership transferred to caller."

The **`-experimental` gate on pointer frees** (`autofree.v:204`) is the litmus:
it exists because scope-exit frees of heap refs are unsound without alias
analysis. **Removing that gate soundly = the concrete P1 success signal** — it
means the uniqueness classification (layer 3) is trustworthy enough to free
references deterministically.

## 5. Incremental, gated implementation plan

1. **Straight-line last-use** (no branches): compute last-use within basic
   blocks; drop provably-unique locals at last use instead of scope exit.
   Gate: differential output identical to `-gc none`/`-gc boehm` (G-DIFF) + no
   leak regression (G-LEAK) on the autofree test corpus.
2. **Branch/loop CFG + join rule.** Extend to full control flow.
3. **Uniqueness classifier** (escape/share/capture conservative). Then attempt to
   drop the `-experimental` ptr gate; the gate-removal must stay green under
   G-DIFF + G-LEAK + (eventually) G-CHURN once shared `dup`/`drop` is threaded.
4. **Reuse pass** (P2), gated by G-REUSE.

Each step is behaviour-preserving on already-autofree-clean code (where "scope
exit" already equals "last use of a unique value") and never ships a partial
collector — it only changes *when* existing frees fire, with the GC as the
always-safe residual.

## 6. Open questions (carry forward)

1. **Pass placement:** build the CFG over `ast` in a new analysis module, or
   introduce a small SSA-ish IR? (V has no CFG/IR layer today; the CFG is the
   prerequisite and the bulk of the work.)
2. **Consuming-vs-borrowing without annotations:** how aggressively to infer
   ownership transfer at call sites. Conservative = treat most non-last uses as
   borrows (keep alive); err toward GC residual, not toward unsound early drop.
3. **`dup`/`drop` atomicity for the shared residual** = the §5.1 crux; intersects
   here — shared-ownership ops must be thread-correct (thread-local-with-handoff
   vs atomic).
4. **V value-semantics interaction:** arrays/strings already copy on some
   assignments; reuse analysis must not double-optimize an already-copied path.

Next loop increment: (4) prototype a standalone `suspend_world()` (mach/signals)
— the shared backstop glue (§5.3) both MMTk and a minimal collector need, and
the piece `vgc-stw-partial-fixes.patch` was reaching for. Real, testable C.
