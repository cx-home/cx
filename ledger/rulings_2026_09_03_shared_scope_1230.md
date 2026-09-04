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

## Execution record (2026-09-03, the wave that landed 1a)

- **Red-proof against the pre-change tree (fcab2e97e, every #1229 registry locked, Scope still shared).**
  The issue's hammer (math/array | map/fp, none imported at top level): 0 of 20 and 5 of 20 red here
  (2 of 20 on the owner's runs — the Scope grows only in each thread's first round, so the window is
  narrow). A rotating-import variant (a ring of twenty defs, each importing a different stdlib module
  and calling the next, so every thread grows the Scope twenty times per lap): 19 of 20 and 18 of 20
  red — SIGSEGV in vmemcpy / fast_string_eq / build_param_call_env / invoke_partial_l, SIGBUS,
  `[ham-1 'h1' 299]` rendered as data, "partial application over-applied", "unbound variable $w", a
  false CXER0216. A `[?def]`-in-a-body variant (twelve workers plus main, four hundred distinct defs
  each, every one called through a top-level def): 10 of 10 red (six workers × 150 defs: 5 of 20;
  six × 800: 13 of 20). All three: 0 of 20 on the fixed tree. Pinned as the umbrella's `#1230` section.
- **A second reader the finding did not name.** Copying the Scope at spawn removes the WORKER-side
  writes, but a top-level callable's call env ALIASES its defining scope's maps (build_param_call_env,
  build_param_call_env_record, invoke_positional_l), and a top-level def's defining scope is the ROOT
  Scope — so a body calling one read the root maps while the MAIN thread wrote them (a top-level
  `[?def]` / `[?lib]` / `[?const]` after the spawn, or a `[?lib]` inside a def main runs; the ring
  hammer reds on exactly this). Mechanism: each copy records its `parent`, and the three call-env
  builders substitute the executing thread's Scope for a defining scope that is an ancestor of it
  (`MatchEnv.call_scope_of`) — one pointer compare per spawn depth, no lock, nothing on
  lookup_closure. Rewriting every carrier of a defining_scope pointer at spawn (the closures maps,
  the Closures riding on `[?fn]` sentinel values, their captured_bindings, parked iterator closures)
  was rejected as a whole-world walk. This stays inside 1a: the copy is the snapshot, and the
  substitution is what makes the snapshot the body's world. Copy-on-first-write on the worker side
  was rejected on soundness, not cost: a worker that still aliases the root maps until its first
  write is exactly the reader the main thread races.
- **Clone cost (2,000 spawns of `[+ 1 1]`, same-state builds, interleaved).** Dev (-O0): a root
  Scope holding twenty stdlib modules (~1,100 public members) 1.18 s → 1.61 s, ~215 µs per spawn;
  an empty Scope 0.99 s → 1.10 s. At -Os: the heavy shape +1.5 G instructions over 2,000 spawns
  (~750 k per spawn, the two map clones); the empty-Scope shape and `cx --version` are
  cycle-identical. The dev-binary +10 ms boot delta (117 → 127 ms, identical instruction counts,
  +9 % cycles) is an -O0 code-layout artefact, not work: it vanishes at -Os.
- **Behaviour change recorded** in code.md's `[?worker]` and `[?async]` sections ("Lexical-scope
  capture-at-spawn"). Pinned: a sibling def's body no longer resolves a body's `[?def]` / `[?lib]`
  (it answered 6 / 5 / 4 on the shared Scope); a body sees every def and lambda made before the
  spawn, its own defs and imports, and a nested body sees the outer body's defs.
- **Observation → #1232.** A body's `[?lib]` still registers the module ALIAS program-wide
  (module_table is a ProgramState registry), so main's `[$math:abs]` after the body answers CXER0216
  "non-exported member" rather than "not imported". Members are body-scoped; the alias is not.

## Addendum — #1232 (2026-09-03)

The observation above became #1232 and is fixed with the #1228 follow-up commit: `module_member_visibility_error`
(eval.v) now answers CXER0216 only when the named member EXISTS AND IS PRIVATE. Its comment used to argue
"a public member would already have dispatched as a closure" — true while alias and members were registered
together, false once a body's `[?lib]` registers its members in the body's own Scope copy while the alias
stays in the program-wide module_table. A public member of an aliased module that this frame never imported
now falls through to the ordinary undefined call (`no callable "math:abs"`), which is the truthful answer;
the module alias itself stays program-wide (it is the loader's cache, not a scope). The #1230 pin asserts the
exact new answer.
