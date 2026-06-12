# E integration — A3 flag-unify finding (the front line and backstop don't compose as-built)

Forward-phase step (B), first task: A3 flag-unify — collapse `-autofree -d perceus`
(Perceus front line) + `-gc vgc` (backstop) into one `-gc e` mode. Implementing the
CLI arm was trivial; **running it surfaced that E's two validated halves cannot be
composed as currently built.** This is the dominant remaining E-integration finding.

## What was tried
Added a `-gc e` arm to `vlib/v/pref/pref.v` that sets `gc_mode=.vgc` +
`parse_define('vgc')` + `parse_define('perceus')` + `autofree=true`. Confirmed via
generated C that the single flag wires BOTH fronts (defines `vgc,perceus`;
`vgc_init` present; spawn-root registry present; +763 C lines of Perceus/autofree
emission vs `-gc vgc` alone). The CLI surface works.

## The crash
`-gc e` SIGSEGVs **12/12** on the canonical `g_churn 100 1 30`, while `-gc vgc`
alone is **190/190** clean (same `v2` build — not a compiler-rebuild regression).

## Decomposition (each on the same v2; the proven `-gc vgc` baseline = control)
| build | result |
|---|---|
| `-gc vgc` (backstop only) | **PASS** (8/8 churn; 190/190 historically) |
| `-gc e` (= vgc + autofree + perceus) | FAIL 12/12 |
| `-gc e -d builtin_free_nop` (Perceus drops/frees neutralized) | FAIL 10/10 |
| `-gc vgc -autofree` (no perceus define) | FAIL 6/6 |
| `-gc vgc -autofree -d builtin_free_nop` | FAIL 6/6 |
| `-gc vgc -d perceus` (perceus define, NO autofree → emission inert) | PASS 6/6 |
| `-gc vgc -autofree`, **single-threaded** (`5000 0 0`, no spawn churn) | FAIL 3/3 |

Then on a clean alloc workload (`/tmp/alloc_churn.v`, no vgc-specific hooks),
single-threaded:
| build | result |
|---|---|
| `-autofree` alone (libc, no GC) | **PASS** |
| `-gc none` / `-gc boehm` / `-gc vgc` (each alone) | **PASS** |
| `-gc boehm -autofree` | **FAIL 4/4** |
| `-gc vgc -autofree` | **FAIL 4/4** |

## Root finding
**`-autofree` + ANY garbage collector is fundamentally incompatible in V — Boehm
*and* vgc, even single-threaded, independent of the explicit-free path
(`builtin_free_nop` doesn't help).** This is a general V property: `-autofree` and
`-gc` are mutually-exclusive memory-management modes. `-autofree` mode is far more
than "insert frees" — it restructures codegen (auto-`.clone()` insertion, temporary
management, object lifetimes) under the assumption that it solely owns memory.
Layering a tracing/sweeping collector on top double-manages objects and corrupts.

It is NOT Perceus-specific and NOT my collector's fault: the `perceus` define
without `autofree` is inert (passes), and `-gc vgc` alone is rock-solid.

## Why this matters for E (the architectural consequence)
The P1/P2 Perceus emission was built as a **modification of V's `-autofree` pass**
(drop-at-last-use replaces autofree's scope-exit free; it rides on `pref.autofree`)
and validated as `perceus == autofree == -gc none` **in the no-GC world**. But E
requires the Perceus front line to run **alongside** the tracing backstop — and
that is impossible while Perceus is entangled with `-autofree` mode, because
`-autofree` cannot run under any GC at all.

So A3 is not a CLI alias: delivering a working `-gc e` requires **decoupling Perceus
emission from V's `-autofree` mode** — re-hosting the validated drop/reuse emission
as its own cgen pass that fires WITHOUT enabling `pref.autofree` (no autofree
clone-insertion / temp / lifetime restructuring), emitting only the Perceus-proven
drops and routing reclamation into the vgc allocator GC-safely. That is real
compiler work (the front-line/backstop seam), the true substance of E integration.

The `-gc e` pref.v arm was reverted (it produced a crashing binary and would be a
misleading surface); re-add once the decoupled emission lands. `-gc e` remains the
intended target surface (recorded in INTEGRATION-SCOPE §C / spec §6 Phase 4).

## Decision → (a) DECOUPLE — chosen by user, and DELIVERED 2026-06-12
Re-host the validated Perceus emission so it fires WITHOUT enabling `pref.autofree`.
It turned out cleaner than feared — when autofree is off, autofree's scope-exit
freeing simply doesn't run, so there are no duplicate frees to suppress and no
clone/temp machinery; the Perceus drops become the program's sole frees. The
classifier already models V's no-clone value-sharing (it pins assignment-aliases),
so it stays sound without autofree's clones.

**Changes (clone, in vgc-collector-linux.patch):**
1. `fn.v` — drive Perceus off the `perceus` define alone (drop the `g.is_autofree
   &&` gate); with autofree off the suppress-set is inert.
2. `autofree.v::needs_scope_cleanup()` — also true when `g.perceus_dropping` (set
   only transiently inside `perceus_drop`), so the free dispatch fires under E
   without enabling any other scope cleanup.
3. `autofree.v` user-ref drop — under `-gc vgc`, emit `builtin___v_free` (routes to
   `vgc_free`) instead of the bare libc `free`. **Bug found + fixed en route:** the
   `&Foo` drop hardcoded libc `free`, which aborts on a GC-arena pointer ("pointer
   being freed was not allocated"); arrays/maps/strings were already fine (they
   route through `builtin___v_free`). Manual/autofree-no-gc keeps libc `free`, so
   the validated path is byte-identical.
4. `pref.v` — `-gc e` = `.vgc` + define `vgc` + define `perceus` (NO autofree).
   `-gc boehm` stays default; `-gc e` is opt-in.

**Validation (all green):**
- `-gc e` corpus G-DIFF (uref/reuse/hazard/loop-hazard) `none == -gc e`: 4/4.
- `-gc e` churn gate `g_churn 100 1 30`: 12/12 (also 15/15 as `-gc vgc -d perceus`).
- Perceus front line is REAL under E: in-place map reuse marker fires (== the
  validated autofree path).
- Flag-off default build BYTE-IDENTICAL; validated `-autofree -d perceus` path
  intact (uref_corpus correct).

**E now composes:** Perceus front line (drops + reuse) + vgc backstop run together,
churn-clean and corpus-correct, opt-in via one `-gc e` flag. A3 flag-unify COMPLETE.

## Residual / next
- **vgc_free concurrency:** `vgc_free` mutates span bits lock-free; under E it is now
  exercised by mutator-thread drops. The churn gate is clean so far (Perceus frees
  are rare + the unique objects it drops are thread-local), but harden `vgc_free`
  (take the central[class] lock, consistent with the collector's lock-before-suspend
  discipline) before heavy multi-thread E workloads. Tracked for B13 ([par]).
- Next B-tasks: A7 fork forward-port (dominant risk) · B10-15 cx builds/eval/[par]/
  full gate/picoev under `-gc e`.
