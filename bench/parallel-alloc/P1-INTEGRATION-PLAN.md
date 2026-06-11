# P1 integration plan — wiring the Perceus analysis into V's compiler

Loop increment 14a (2026-06-11). Maps the validated prototype
(`cfg_proto.v`: CFG → liveness → per-stmt last-use → uniqueness → drop placement)
onto V's real codegen (`vlib/v/gen/c/autofree.v` + `cgen.v` @ a83aabb). Behind a
`-d perceus` define; default build path untouched.

## The key integration fact

V's `-autofree` emits `_free()` calls **during cgen, at scope-exit positions**
(`autofree_scope_vars2` walks `scope.objects` at block ends / returns —
`cgen.v:3539, 10511, …`). **Perceus needs drops at *last-use* positions
(mid-scope, often earlier than scope exit).** So the integration is NOT merely
"swap the scope-walk." It is:

1. A **per-function pre-pass** (the prototype's analysis) that runs on the
   `ast.FnDecl` body before/at the start of cgen-ing that fn, producing a
   **drop map**: `map[int][]DropTarget` keyed by **statement position**
   (`stmt.pos.pos`), each entry = the values to `drop` *after* that statement
   (plus any `dup` to emit *before* a non-last consuming use).
2. cgen's statement loop, when `-d perceus` is set, after emitting each
   statement, consults the drop map for that `stmt.pos` and emits the pending
   `drop`s — reusing the existing per-type free dispatch as the drop body.

## Component mapping (prototype → compiler)

| Prototype piece (`cfg_proto.v`) | Compiler home | Notes |
|---|---|---|
| `Cfg` build (`lower_stmt`/`lower_expr`) | new `vlib/v/gen/c/perceus.v` analysis | run per `ast.FnDecl`; reuse `parse`d AST already in cgen |
| liveness fixpoint + per-stmt last-use | same module | produces last-use program points |
| uniqueness (`scan_escapes`) + `returned` | same module | escape via `&`/closure/spawn/channel/`shared`; returned = ownership transfer |
| drop placement report | becomes the **drop map** (`stmt.pos → drops`) | the report's print sites become map entries |
| `drop x` | **reuse `autofree_variable(x)`** (`autofree.v:144`) | Perceus changes WHEN it fires, not the free body |
| `dup x` | new: shallow refcount bump / copy for the shared residual | only on the shared path; the unique path needs neither |

## Insertion points (gated by `-d perceus`)

- **`autofree.v:autofree_scope_vars2`** — when `g.pref.is_perceus`, do NOT
  scope-walk; the drop map already covers this fn's drops at their precise
  positions. (Default: unchanged scope-walk.)
- **`cgen.v` stmt loop** (`stmt()` / `stmts()`) — after emitting a stmt, if
  `is_perceus` and `drop_map[stmt.pos.pos]` is non-empty, emit those drops via
  `autofree_var_call`. (Default: no-op.)
- **`pref`** — add `is_perceus bool` set from `-d perceus` (V already threads
  custom `-d` defines; mirror how `cx_regions`/`vgc` are read).
- **`fn.v:1174`** — alongside `returned_var_names.clear()`, build the drop map
  for the fn being generated.

## Bring-up, each step gated

1. **Seam only:** add `is_perceus` + the gated branches as **no-ops that fall
   back to the existing autofree** (clearly logged "perceus: not yet driving
   drops"). Build V with `-d perceus` OFF → must be **byte-identical** to today;
   ON → identical behavior too (falls back). Commit.
2. **Drop map from the pre-pass**, drops emitted for the **straight-line +
   unique + non-returned** subset only (what the prototype proves). Everything
   else still falls to GC. Gate: G-DIFF + G-LEAK vs `-gc none`/`-gc boehm` on the
   autofree corpus; `-d perceus` ON must stay correct.
3. **Widen coverage** (branches/loops/`or`/`defer`) incrementally, each widening
   re-gated. Then attempt to drop the `-experimental` ptr-free gate.
4. **G-CHURN** once shared `dup`/`drop` is threaded (atomicity = §5.1 crux).

## Honest scope flag (for the user)

The prototype proves the *analysis*. Full compiler integration is **substantial**
and multi-tick because: (a) V has **no IR/CFG layer** — the pass must build the
CFG from `ast` for every fn and cover *all* stmt/expr kinds (the prototype covers
a structured subset); (b) emitting drops at arbitrary stmt positions during cgen
touches a hot, intricate path; (c) `dup`/`drop` atomicity for the shared residual
is the unresolved §5.1 crux. None of these is a *blocker* — the seam (step 1) is
safe and the unique-value subset (step 2) is real, incremental value — but
"autofree becomes fully Perceus" is weeks, not ticks. Will proceed step-by-step,
gated; if any step needs surgery that can't be done soundly behind the flag, I'll
stop and surface it.

Next increment (14b): implement step 1 — the `-d perceus` seam, verified
byte-identical with the flag off.
