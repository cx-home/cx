# Owner letter 2026-09-14 ~17:05Z — the platform's composition is stated once, checked, and read by the agents that build on it (RULED: COMP-1)

Owner: *"I stress again how important it is to have orthogonality in the cx platform among its components and
being able to be composed seamlessly to create patterns well aligned to solve a variety of enterprise needs and
come together for a xap and one or more surfaces. … Is there anything we need to do to materialize or simplify
how the cx platform composes? We don't want [an adopter's] agents dropping the ball and not seeing how they should
come together."* Measured on head `3cf48b671`: `cx primer` is 2454 lines of language only; `platform/README.md` is
a module index with no seams; 4 of ~30 platform specs carry an integration-map section (connector, sync, audit,
sso); no reference example composes more than one module yet. Letter **(a)** taken.

| Id | Decision |
|---|---|
| **COMP-1** | **(owner)** A normative page `spec/03-approved/platform/composition.md` (placement: the Ring 2 tree beside `platform/README.md`; not a module, no registry row; OL-15) in four parts. (1) **The seam table** — module × module: what crosses, in which direction, and the REFUSED directions (flow depends on features and never the reverse, CK-6; connector never reaches flow; sync is per source; fabric carries effects; a surface reads a feature's readout; audit records, never decides), one table, checked by a new step `check-composition-seams` that refuses a spec sentence naming a dependency the table forbids. (2) **The closed set of composition patterns**, each with a name, its declaration skeleton, the modules it uses and the reference example that grades it: poll–transform–sink; approval with pivot and compensation; async bulk export; inbound webhook; fan-out over a bus; incremental sync into a store; agent surface over verbs — a pattern with no reference example is a defect of the page. (3) **Every platform spec carries an integration-map section** (connector.md §12's shape: what it owes each module and what it refuses); `make placement-gate` refuses a platform spec without one. (4) **`cx primer` gains a platform chapter GENERATED from parts 1 and 2** so an adopter's agent reads the seams and patterns before its first line, and **`cx xap scaffold <pattern>`** emits a pattern's declaration skeleton with authoring TODOs, under the ingest's discipline (1430-g: what the pattern states becomes a declaration, what it does not becomes a TODO, never a guess). |

## Why

Orthogonality is the design objective (owner, 2026-09-14 and before); composition that lives in five specs and
an index is inferred by every agent that builds on it and inferred differently each time. Stated once and
checked, it is read the same way by every one of them.

## Order

Spec first (the owner reads), right after #1486's flow spec — the flow seam is the table's largest row — and
before the transports fill the pattern cells; part 3 is one mechanical branch after the page lands; part 4's
generator and scaffold follow the page.
