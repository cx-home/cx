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

## Open decision (surfaced to user)
How to deliver E's front line given autofree+GC incompatibility:
- (a) Decouple Perceus into an independent cgen pass (recommended; the only path
  that yields true E). Substantial.
- (b) Root-cause and fix `-autofree`+`-gc` coexistence in V generally. Murkier,
  larger blast radius, fights autofree's design.
- (c) Re-scope E's front line (e.g. Perceus without a tracing backstop, or backstop
  only). Contradicts the decided architecture.
