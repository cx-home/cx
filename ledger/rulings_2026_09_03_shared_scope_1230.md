# Rulings 2026-09-03 — #1230 the root Scope shared by pointer across spawned bodies

**Status: RULED (1a) by the owner, 2026-09-03, on the #1229 landing report (bc2b07193).**

## The finding the ruling rests on

#1229 locked the six remaining `ProgramState` registries of the #1219 class. Its module_table
hammer stayed red with every registry locked — 2 of 20 runs SIGSEGV/SIGBUS inside a `Closure`
read — because `eval_worker` and `eval_async` pass the **root `Scope` pointer** to the spawned
thread (`spawn run_worker_thread(…, env.scope, …)`), and two evaluator paths write through it:
`eval_def` (`env.scope.closures[def.name] = …`) and `register_module_members` (`env.scope.closures`
/ `env.scope.bindings`, one entry per imported member). Bindings and closures are copied at
spawn; the Scope is the seventh writer the #1219 class audit's "per-frame, copied at spawn" line
did not cover. The module_table hammer is therefore NOT pinned by #1229 (its pre-imported variant
never reds even unlocked); it becomes the pin here.

## Q1 — how the shared root Scope is handled (RULED: 1a)

- (a) **TAKEN — copy the Scope at spawn**, as bindings and closures already are. A `[?def]` /
  `[?lib]` inside a body stays inside that body's thread, which is what lexical scoping says;
  today the def LEAKS into the program scope, racily. Same "copied at spawn" rule the rest of the
  per-frame state follows; nothing added to the closure-lookup hot path.
- (b) Lock the Scope maps (an RwMutex per Scope) — rejected: keeps the leak and puts a read lock on
  every closure lookup.
- (c) Refuse `[?lib]` / `[?def]` inside worker bodies — rejected: a surface restriction needing a
  spec statement, and it does nothing for the `[?async]` case.

## Execution notes for the wave

- Copy at BOTH spawn sites (`eval_worker`, `eval_async`) and any other body-on-a-thread site
  (`par_map` workers if they carry a scope).
- The behaviour change to record in the spec's concurrency section: a body's `[?def]` / `[?lib]`
  is scoped to that body; it is not visible to the program after the body returns.
- Pin: the growing module_table hammer attached to #1230 (seven threads importing math/array or
  map/fp with none imported at the top level; clean run `(0, 0, 0, 0, 0, 0, 0)`), red-proven
  against the tree before the copy, plus a `[?def]`-in-a-body variant.
