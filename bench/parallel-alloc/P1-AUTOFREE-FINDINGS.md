# P1 groundwork — V's current `autofree`, and what Perceus would formalize

Source: upstream `vlang/v` master `a83aabb` (2026-06-11), `vlib/v/gen/c/autofree.v`
+ hook points in `cgen.v`/`fn.v`. This is the starting point for spec §4.1 (the
Perceus front line) and the P1/P2 phases.

## 1. What `-autofree` actually does today

**It is scope-based, not ownership/RC-based.** At each scope exit the codegen
walks the scope's declared variables and emits a `_free()` call for each, with a
set of syntactic exceptions. There is **no reference counting anywhere** — grep
for `refcount`/`retain`/`dup` finds only `prealloc_scope_retain` (arena mode) and
pointer-`deref_count` (unrelated). The residual that autofree doesn't free is
left to the GC.

### Mechanism
- `autofree_scope_vars2` (`autofree.v:59`) iterates `scope.objects`; for each
  `ast.Var` it calls `autofree_variable` unless excluded.
- `autofree_variable` (`autofree.v:144`) dispatches the free by type kind:
  array/map → `get_free_method`; string → `string_free` (skips string
  *literals*); user **reference** types (ptr to a Capitalized type) → freed
  **only under `-experimental`** (`autofree.v:201-209`); any type with a `free()`
  method → call it.
- `autofree_var_call` (`autofree.v:215`) emits the actual `_free(&var)` /
  `_free(var)` line, with option/shared/ptr-depth handling.

### Escape analysis (the only ownership reasoning)
- `returned_var_names` (`cgen.v:274`, populated by `detect_used_var_on_return`,
  `autofree.v:284`): a var returned from the function is **not** freed —
  ownership transfers to the caller. This is the single ownership concept present.
- Other exclusions (`autofree.v:65-119`): tmp/loop vars, `or {}` vars, inherited
  (closure-captured) vars, if-guard vars, and vars declared after the current
  scope position.

### Hook points (where scope-exit frees are injected)
- Block ends: `cgen.v:3539` (`free_parent_scopes=false`).
- Return statements: `cgen.v:10511/10563/10569/10840/10866/10871`
  (`free_parent_scopes=true` — free this scope AND all enclosing scopes before
  returning).
- Per-function reset: `fn.v:1174` clears `returned_var_names`.

## 2. Why this is unsound / incomplete (the v1.0 gap)

- **No aliasing/sharing analysis.** "Free every local at scope exit" is only
  correct if each local is the *unique* owner of its heap data at that point.
  If a local was aliased — stored into a heap structure, captured, shared across
  a channel/thread, or assigned to another live var — the scope-exit free is a
  use-after-free or double-free. autofree has no way to prove non-aliasing.
- **The `-experimental` gate on pointer/user-ref frees** (`autofree.v:204`) is
  exactly this admission: freeing heap references at scope exit is *known* to be
  unsound in general, so it's off by default. That gate is the boundary between
  "handled" and "left to the GC."
- **No reuse / in-place mutation.** `arr = arr.map(f)` allocates a fresh array
  and frees the old one at scope exit (if it can); there is no detection that the
  old allocation is uniquely owned and could be mutated in place.
- **Residual → GC.** Whatever isn't scope-freed leaks to the Boehm/GC backstop —
  which is the very MP-scaling bottleneck this whole effort (§1.1, #14) is about.

## 3. What a Perceus pass would replace / add (maps to spec §4.1)

| Today (scope-based autofree) | Perceus (ownership-flow) |
|---|---|
| Free *all* scope locals at scope exit | Insert `drop` exactly where the **last owner** relinquishes (may be mid-scope, not at exit) |
| `returned_var_names` escape list | Ownership transfer is the general case, not a special-cased list |
| No sharing handling → `-experimental` gate | Insert `dup` where ownership is **shared** (aliased into heap, captured, multi-use); soundness by construction |
| No reuse | **Reuse analysis**: a `drop` immediately followed by an alloc of compatible shape → mutate in place (the R1-beating optimization, P2) |
| Residual → GC (unbounded) | Residual = genuinely-shared/cyclic only → small, precise backstop (§5.3) |

### Where it would hook
- Perceus operates on an **IR with explicit ownership**, ideally *before* C
  codegen. V's current free-insertion is late (in `cgen`, driven by the scope
  tree). A faithful Perceus port wants an analysis pass over V's AST/SSA-ish IR
  that annotates each binding's last-use and ownership, then *drives* the same
  `_free`/new `dup`/`drop` emission — i.e. `autofree_scope_vars2`'s "walk the
  scope" is replaced by "walk the ownership-annotated IR."
- The existing per-type free dispatch (`autofree_variable`) and the `_free`
  method machinery (`auto_free_methods.v`) are **reusable** as the `drop`
  implementation; Perceus changes *when/whether* they fire, not the free bodies.

## 4. Implications for the phased plan

- **P1 (insertion / soundness)** = build the ownership/last-use analysis and make
  `drop` placement ownership-driven instead of scope-driven; behavior on
  autofree-clean code stays identical (those are the cases where "free at scope
  exit" already coincides with "last owner relinquishes at scope exit"). The
  `-experimental` ptr gate can be removed *once* sharing is tracked soundly —
  that removal is the concrete P1 success signal.
- **P2 (reuse)** = add the reuse pass on top; gate with G-REUSE (assert 0 allocs
  on unique `map`/`<<`).
- **Residual + cycles (P3)** = whatever `dup`/`drop` can't make unique goes to the
  precise backstop (§5.3: MMTk/minimal, NOT vgc per the GC investigation).

### Open questions to resolve before writing the P1 pass
1. Does V expose an IR layer with enough last-use/def-use info, or must the pass
   reconstruct ownership from the AST + scope tree? (Determines pass placement.)
2. Atomicity of the residual `dup`/`drop` on shared objects — the §5.1 crux —
   intersects here: shared-ownership `dup`/`drop` must be thread-correct.
3. Interaction with V's value-semantics arrays/strings (already copy-on-assign in
   some paths) — reuse analysis must not double-optimize.

Next loop increments: (2) scope MMTk-for-V binding feasibility (§5.3 backstop);
(3) prototype the ownership/last-use analysis shape against V's AST.
