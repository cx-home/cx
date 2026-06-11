# §5.3 backstop trade study — MMTk-for-V feasibility

Loop increment 2 (2026-06-11). Scopes spec §5.3 option (b) "bind MMTk" as the
precise/parallel tracing backstop behind the Perceus front line. Compares
against (a) harden-vgc (rejected, see VGC-MULTITHREAD-BUG.md) and (c) a minimal
hand-written mark-region collector.

Sources: mmtk.io/code, docs.mmtk.io porting guide (NoGC howto + next-steps),
github.com/mmtk/mmtk-core, existing bindings (mmtk-openjdk / -v8 / -jikesrvm /
-julia / -ruby).

## 1. What MMTk is and why it inverts the vgc problem

MMTk is a **Rust** GC framework: `mmtk-core` implements the *collectors*
(NoGC, MarkSweep, Immix, GenImmix, …) — production-tested, parallel, precise —
and is language-agnostic. Each host VM provides a **binding** that implements the
`VMBinding` trait so MMTk can call into the VM.

The decisive contrast with vgc: **with MMTk the collector is already correct;
the binding is plumbing.** vgc failed because the *collector itself* was unsound
(STW counting, alloc-white, missed roots — 5 fixes didn't fix it). MMTk moves
that burden to a maintained, tested core. We would never again be debugging "the
collector freed live data."

## 2. What V must implement (the binding)

Two code bases (per MMTk's model): a V/C-side part close to the runtime, and a
small Rust part implementing `VMBinding`. The traits V must satisfy:

| Trait | What V provides | Difficulty for V |
|---|---|---|
| **ObjectModel** | where GC metadata lives | **Easy-ish.** V objects have no GC header; MMTk supports **side metadata** (mark bits on the side) → header-free works. Need object size/type derivable at scan time. |
| **Scanning — object refs** | enumerate pointer fields of an object | **V's structural advantage.** V has full compile-time type info → emit **precise per-type pointer maps**. No Boehm conservative-scan tax. |
| **Scanning — roots** | scan mutator stacks/registers/globals | **The hard part (same as vgc/Boehm).** Pragmatic path: **conservative stack scan** (MMTk supports it; Boehm proves it's sound). Precise path = compiler-emitted stack maps (large). |
| **Collection** | stop/resume mutators at a safepoint | **The other hard part.** MMTk drives the cycle and provides the handshake framework; the binding implements **thread suspension** (OS-level, à la Boehm mach/signals). This is the exact glue vgc botched — but here it's "suspend + scan," not "implement a correct collector." |
| **ActivePlan** | enumerate live mutators | Easy — V already tracks threads. |
| Allocation | route V allocs through MMTk's fast path | Replaces `GC_malloc`; Immix bump-pointer fast path → strong single-thread + per-mutator scaling. |

## 3. Bring-up path (de-risked, incremental)

MMTk's documented **NoGC** plan = allocation only, no collection. So the port is
staged: (1) route V allocation through MMTk NoGC (proves object model + alloc),
(2) add precise object scanning + conservative root scan + thread suspension →
turn on **MarkSweep** (simplest collecting plan), gate with **G-CHURN + the
oracle**, (3) switch to **Immix/GenImmix** for throughput. Each stage is
independently testable. This is exactly the gated-increment discipline the spec
requires, and unlike vgc each stage rests on a correct collector.

## 4. Risks / costs

1. **Rust build dependency — the main adoption risk.** V prizes fast,
   C-only, dependency-light builds; the core team may resist cargo in the build.
   *Mitigation:* MMTk links as a **static lib** (`crate-type = staticlib`); ship a
   **prebuilt `.a`** (as V already ships prebuilt `tcc`/`libgc`) so end users need
   no Rust, gated behind `-gc mmtk`. Building V-from-source-with-mmtk still needs
   cargo. This is a governance/acceptance question, not a technical blocker.
2. **Root scanning is still unsolved glue** — thread suspension + (conservative)
   stack scan. But this is *Boehm-equivalent and known-sound*, not novel: the
   binding does "suspend all mutators (mach/signals) + conservatively scan their
   stacks," which Boehm already does correctly on every platform V targets.
3. **Effort** — a binding is a multi-week project, but well-trodden: 5+ reference
   bindings, an official porting guide, and the NoGC incremental path. Far lower
   risk than the open-ended "finish a correct concurrent collector" that hardening
   vgc represents.

## 5. Recommendation (refines §5.3)

- **(b) MMTk** is the soundest backstop **iff** the V core team accepts a
  (prebuilt-static-lib) Rust dependency. It gives precise + parallel + tested
  collection with the binding reduced to plumbing.
- **(c) minimal STW mark-region** is the fallback if the Rust dep is rejected:
  write a *simple, non-concurrent, stop-the-world* precise mark-region collector
  in V/C. Crucially it must use **OS-level suspend** (the part vgc skipped) and
  stay non-concurrent (Perceus makes collection rare, so no need for the
  concurrent machinery that made vgc unsound). This is far more tractable than
  vgc's Go-runtime port precisely because it drops concurrency.
- **(a) harden vgc** stays rejected.

**Reusable insight:** both (b) and (c) need the *same* correct STW glue —
OS-level thread suspend + (conservative-stack / precise-heap) root scan. That
glue is the real hard part and is independent of the backstop choice. It is also
the thing the `vgc-stw-partial-fixes.patch` was reaching for and is worth
prototyping standalone (a clean `vgc_suspend_world()` using mach/signals) — it
would (i) unblock either backstop and (ii) be the one piece that could even make
vgc's *own* collector testable, if the V team ever wants that.

Next loop increment: (3) begin the Perceus ownership/last-use analysis design
against V's AST (the front line, spec §4.1 / P1), per P1-AUTOFREE-FINDINGS.md.
