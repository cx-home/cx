# Owner letter 2026-09-14 ~19:05Z — the platform's runtimes, and every cross-runtime seam over XSP (RULED: COMP-2)

Owner, on composition.md: *"I'm not sure we're addressing composition of platform components that are running in
different runtimes — store in its own runtime, fabric in its own, flow, etc."* → letter **(b)**, a separate page; and:
*"It's no different than all in the same runtime except that they're communicating over xsp — is that right?"*

Measured on head `6fe82064f`: composition.md's 43 seam rows are in-process relations and no spec names the runtimes
together. The daemons exist — `cx store-serve`, `cx fabric-serve`, `cx flow serve`, the xap host — and each already
speaks XSP under its profile: the store's wire IS the XSP store profile (store.md §6.4; `grpc` is a separate
"integration edge" for non-CX clients); fabric is "durable + transient planes over XSP" (fabric.md; the NATS bridge is
an external bridge, not a CX-to-CX seam); flow's runner emits acts through authenticated XSP sessions with signed
transcripts (flow.md §… line 1124, xsp.md §5.0); the xap host serves XSP over the web binding (xsp.md §4.1).

| Id | Decision |
|---|---|
| **COMP-2** | **(owner)** A normative page `spec/03-approved/platform/deployment-topology.md` (beside composition.md; not a module, no registry row; OL-15). (1) **The runtimes:** store, fabric, the flow runner, the xap host (features, and inside them the connector engine and sync), each with its daemon, its XSP profile and its binding fields; the same-process shape (every component in-process, `mem://`) and the distributed shape (each its own daemon) are BOTH first-class and the declarations are IDENTICAL in both — only the deployment binding changes. (2) **The carrier rule:** every cross-runtime seam between CX components is an XSP session under the callee component's profile, declared in the deployment binding, never discovered; `grpc` (store) and the NATS bridge (fabric) are integration edges to NON-CX parties and are named as such. (3) **What differs from in-process, stated as rules a pattern may rely on:** identity crosses as signed claims (the DID / transcript model of `xap_identity_model.md`, `[xsp [grants …]]`), never as an in-memory `$host`; a session can drop mid-act — xsp.md §5's heartbeat, credit flow control and reconnect-resume apply, so a cross-runtime step is at-least-once with an acknowledgment and every act it emits is idempotent or recorded as not; each runtime keeps its own journal and no seam reads another runtime's journal (federation without shared state, flow.md) — a cross-runtime seam exchanges records (acts, acknowledgments, effects), never shared state. (4) composition.md §2 gains a **carrier** column referencing this page (in-process `[?lib]`, or the XSP profile and binding field); `check-composition-seams` refuses a seam row with no carrier. (5) **The check:** at least one reference example is graded in the distributed shape — order-pipeline's production binding (`store-serve` + the fabric daemon + `flow serve` + the xap host) booted by `verify-examples`' platform scenarios, with the readiness rule #1477 asks for. |

## Why

Orthogonality across placement: a pattern must compose identically in one process and across four. Stating the
runtimes, the one carrier and the three things that change (identity, failure, truth) once is what lets an adopter's
agent deploy without inferring them; composition.md keeps the logical seams and only points here.

## Order

Spec first (the owner reads). Ahead of COMP-1 parts 3 and 4 (the primer chapter teaches both axes at once);
after #1480 lands.
