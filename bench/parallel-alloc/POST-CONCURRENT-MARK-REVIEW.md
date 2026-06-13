# Combined session brief — CX memory representation + typing + perf (issues #36 + #37)

Self-sufficient entry point for a single future session that addresses
**#37 (architecture review)** and **#36 (per-call bindings allocation)** TOGETHER.
They are coupled: #37's representation/typing decisions can reshape or subsume
#36, so **decide #37 first, then implement #36 in that light.**

## Prerequisite
Run AFTER concurrent mark lands (Phase 4 of `CONCURRENT-MARK-PROMPT.md` / the
topic-file "CONCURRENT MARK" block). Concurrent mark is the low-pause *backstop*;
this session decides what reduces *what must be collected* and how data is
represented. Read `CONCURRENT-MARK-FINDINGS.md` (when written) for the landed
state + measured `[par]` scaling before deciding.

## Framing lens (author, locked)
**All software = access data → transform it → move it on** — the universal base of
computation (Church-Turing / von Neumann; control flow, abstraction, code, I/O all
reduce to it; the only sliver that doesn't is synchronization/ordering). So this is
a **general-purpose, data-centric *foundation*, NOT a narrowing. CX is
general-purpose.** XQuery is a useful comparator for the data/query *shape*, not a
bound on scope. Consequence: CX must serve the FULL workload spread — bulk
record/stream transforms AND tight scalar loops AND pointer-chasing/irregular
graphs AND low-latency coordination — which want *different* representations. Hence
the execution decision below is "both", not "columnar-only."

## State entering this session
- **B17 DONE+SHIPPED** (commit e77775a5): COW closures fix — cut #14 GC pressure
  ~7×, serial 3.5× / par 5.4× under `-gc e`. `bench/parallel-alloc/B17-FINDINGS.md`.
- **B16 DONE+SHIPPED** (fork 72edb9e533): dynamic span registry + env-gated GC
  pacing. `B16-FINDINGS.md`.
- **Concurrent mark**: see topic file — backstop, removes STW.
- **CX typing reality (verified this session):** dynamic/gradual, boxed `cx.Node`,
  NO inference pass, eval == runtime (not a pre-exec check). `::T` advisory
  (enforced only `--strict`, partial); schema validation is the real opt-in type
  layer. Static-pass effort: MVP weeks–2mo / full quarters.

## Core decisions to make (with current leans)
| Decision | Options | Lean |
|---|---|---|
| Own vs rent runtime | V / JVM / .NET / Graal | **Own (V)** + *isolation-for-scaling* doctrine (linear scaling = per-thread/per-batch heap isolation, NOT a better shared GC; JVM optimizes pauses, wrong axis) |
| Scaling memory | concurrent mark / regions / RC / generational | **Per-batch/per-request regions + off-heap Store** primary; concurrent mark = backstop; generational next; interpreter-RC optional |
| Typing | dynamic / gradual-shape / full-static | **Schema/shape typing at boundaries** (XQuery-style, gradual). A static pass, if built = *shape/schema inference over the pipeline*, NOT general expression typing. Not mandatory Scala-static. |
| Execution (GP workload spread) | tree-walk boxed nodes / fast general core (unbox+specialize/VM) / columnar-vectorized | **BOTH: a fast general execution core (unbox/specialize — the VM path) for scalar/control/irregular work, AND columnar/vectorized (Arrow — already integrated: libcx_arrow, data_bin_arrow) for bulk data movement.** Not either/or — general-purpose requires the full spread. (Earlier "columnar-only, demote VM" was downstream of the wrong narrow framing; corrected.) |
| **Representation vs homoiconicity (the crux)** | uniform nodes / dual representation | **Dual** — see below |

## The crux: representation vs homoiconicity
Boxed `cx.Node` sum types may be the wrong *runtime* representation for moving/
transforming bulk data — but nodes exist because CX is **homoiconic** (code = data;
`[?eval]`, `cx:eval-tree`, dynamic construction). Tension.

**Proposed reframing to evaluate (the key idea): *representation ≠ surface model.***
Homoiconicity governs how **code** is expressed; it does NOT require bulk **data**
to be physically boxed node trees at runtime.
- Keep **nodes as the logical/homoiconic surface + metaprogramming form.**
- Use a **typed columnar/unboxed runtime representation for data-in-flight**,
  materializing to node form **lazily**, only when code/inspection/metaprogramming
  touches it.
- Reconciles "homoiconic data language" with "access/transform/move data fast",
  and lines up with regions + off-heap Store + Arrow.

## Comparators (for the typing decision)
Lisp(SBCL) / Clojure / XQuery = dynamic core + *optional* static layer (advisory
annotations for perf). Scala = mandatory-static + compiled (the "eval catches all
before run" model — biggest jump). All four COMPILE; CX uniquely tree-walks with
no inference. CX's `::T` ≈ CL `declare` / Clojure `^hint`; CX schema validation ≈
`clojure.spec` / XSD. **Closest blueprint = XQuery** (structural sequence types +
cardinality + formal type-inference rules over a document language).

## How to run this session
1. **Read** #37, #36, B16/B17-FINDINGS, CONCURRENT-MARK-FINDINGS, topic file.
2. **#37 decisions WITH the user** (the forks above are user calls; present
   leans + trade-offs, don't auto-decide). Especially: dual-representation
   direction, and whether to build the gradual shape-typing pass.
3. **Then #36** — implement the bindings-frame fix *in light of* #37. If the
   representation decision changes call-frame/value handling, #36 may be reshaped
   or absorbed; don't implement it blind first.
4. Scope any representation/columnar work that #37 greenlights as its own phased
   effort (likely large; measure first, like B16/B17).

## Pointers
- Issues: #36 (bindings alloc), #37 (architecture review, umbrella).
- Docs: `B16-FINDINGS.md`, `B17-FINDINGS.md`, `CONCURRENT-MARK-{PROMPT,DESIGN,FINDINGS}.md`.
- Memory topic: `project_v_runtime_memory_mgmt_spec`.
- Prior art in-repo: `cx_regions` (`-d cx_regions`, 2–6× bounded compute — the
  regions lever), Arrow (`libcx_arrow`, `data_bin_arrow`).
