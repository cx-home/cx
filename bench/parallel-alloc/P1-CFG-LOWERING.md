# P1 build — CFG lowering for V's AST (Perceus prerequisite)

Loop increment 8 / first real P1 build step (2026-06-11). Keyed to V's REAL node
set (`vlib/v/ast/ast.v` @ a83aabb): `Stmt` (29 members) and `Expr` (control-flow
subset). The CFG is the prerequisite for backward last-use/liveness
(P1-PERCEUS-ANALYSIS-DESIGN.md §2). This catalogs how each control-flow node
lowers to basic blocks + edges, and flags the Perceus-relevant points
(ownership-transfer / sharing / defer interaction).

## Cross-cutting complications (these shape the whole design)

1. **Control flow lives in EXPRESSIONS, not just statements.** V's `if`, `match`,
   `or`, `select`, `if-guard` are `Expr`s that yield values and branch. So the CFG
   builder cannot walk statements only — it must thread CFG edges *through
   expression evaluation*. Practical approach: lower expressions left-to-right
   into the current block, spawning sub-blocks at any embedded `IfExpr`/`MatchExpr`/
   `OrExpr`/`SelectExpr` and re-joining.
2. **Implicit error-exit edges from `?`/`!` and `or{}`.** Any `CallExpr` to a
   fallible fn (option/result return) has an implicit edge: on error → the `or{}`
   block, or (with `?`/`!` propagation) → an early function exit. These edges are
   pervasive and must be modeled or last-use is wrong on the error path.
3. **`defer` runs at every scope/function exit** — including early `return`,
   propagated errors, and (V) at function end. Drops inserted by Perceus must be
   ordered correctly w.r.t. deferred statements (defers see the pre-drop values).
4. **Loops create back-edges** → liveness is a fixpoint, not one backward pass: a
   value defined before a loop and used in it is live across the back-edge.
5. **`spawn`/closures = ownership escape** — the key *sharing* inputs to the
   uniqueness classifier (§3 of the analysis design).

## Statement lowering

| `Stmt` node | CFG lowering | Perceus note |
|---|---|---|
| `Block` | nested scope; child blocks; scope-exit point | drops for block-locals at analysed last-use (≤ block end) |
| `AssignStmt` | straight-line; def of LHS, use of RHS | the canonical def/use site; RHS last-use may enable reuse (`x = x.map()`) |
| `ExprStmt` | lower the expr (may embed branches) | — |
| `Return` | edge → function exit block; runs pending `defer`s | transfers returned values to caller (no drop); drop all other live locals on this edge |
| `BranchStmt` (break/continue) | edge → loop exit (break) / loop header (continue) | drop locals dead on that edge |
| `ForStmt` / `ForInStmt` / `ForCStmt` | header → body → back-edge → header; exit edge | back-edge ⇒ liveness fixpoint; `ForIn` binds an iteration var (def each iter); iterator value lifetime |
| `DeferStmt` | record deferred body; emit at every exit edge of its fn | drops must not free values a later defer reads |
| `GotoStmt` / `GotoLabel` | explicit edge to the label block | arbitrary edges ⇒ general CFG (not just structured); keep liveness a true fixpoint |
| `AssertStmt` | normal edge + (on fail) → panic/exit edge | panic edge: conservatively treat as exit (drops or leak-to-GC) |
| `ComptimeFor` | expand at comptime → lower the produced stmts | post-expansion only |
| decls (`Const/Struct/Enum/Fn/Global/Type/Interface/Import/Module`), `AsmStmt`, `HashStmt`, `Empty/Semicolon/Debugger` | no intraprocedural CF (or opaque) | none / opaque (treat asm/hash as a barrier) |

## Expression lowering (control-flow-bearing)

| `Expr` node | CFG lowering | Perceus note |
|---|---|---|
| `IfExpr` | cond block → then/else sub-blocks → join; yields a value | **join rule**: a binding consumed on one arm but live on the other ⇒ drop on the other arm |
| `MatchExpr` (`MatchBranch`) | cond → N branch blocks → join | same join rule across N arms; exhaustiveness affects the default edge |
| `OrExpr` (`OrKind`: `.block`/`.propagate_option`/`.propagate_result`) | success edge (continue) + error edge (→ or-block / fn-exit) | the error edge is where many "early drop" cases live |
| `IfGuardExpr` (`if x := f() or {}`) | conditional binding of `x` on success edge only | `x` live only on success arm |
| `SelectExpr` | N channel-case blocks → join | channel ops move values (send transfers ownership) |
| `CallExpr` | straight-line + implicit error edge if fallible; args evaluated L→R | **arg passing = ownership transfer or borrow** (the consume-vs-borrow call, §3 open Q); `?`/`!` adds the error edge |
| `SpawnExpr` / `GoExpr` | spawns a thread; captured args | **captured values ESCAPE → mark shared (dup, not drop)** — a primary sharing input |
| `LambdaExpr` / `AnonFn` | closure; captures by value/ref | captured vars escape into the closure → shared |
| `LockExpr` | rlock/lock block → body → unlock | body is a critical section; `shared` values are already non-unique |
| `InfixExpr`/`PrefixExpr`/`PostfixExpr`/`IndexExpr`/`SelectorExpr`/`CastExpr`/`ParExpr`/`ConcatExpr`/inits | straight-line sub-expression evaluation | ordinary uses; `&x` (PrefixExpr `.amp`) takes address → escape (`is_auto_heap`) |

## What the CFG builder must produce (interface for the liveness pass)

- **Basic blocks** with a single entry; each block = ordered list of (stmt|expr-eval)
  steps with def/use sets per step.
- **Edges**: normal, branch (if/match/select arms), back (loops), error (`or`/`?`/`!`),
  exit (return/panic) — every exit edge annotated with the `defer` stack to run.
- **Per-binding def site + every use site**, so backward liveness can compute
  last-use as a fixpoint (loops + goto ⇒ must iterate to fixpoint, not one pass).
- **Escape/share annotations** at `spawn`/closure-capture/`&`/`shared`/channel-send
  sites, feeding the uniqueness classifier.

## Next build increment

(9) Prototype a **CFG builder over one real V function's AST** — start with the
structured subset (Block/Assign/If/Match/For/Return/Branch), defer goto + full
`or`/`?`/`!` error edges to a second pass. Validate by dumping the CFG for a
hand-written V fn and checking blocks/edges by inspection. Then (10) backward
liveness/last-use over that CFG. Each step is analysis-only (no codegen change
yet) so nothing can regress; G-DIFF/G-LEAK gates apply once drop-placement
actually moves.
