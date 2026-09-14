# Owner letter 2026-09-14 ~16:50Z — a flow step binds its intent from the run record, and a `:runner` transform step maps one connector's result onto another's intent (RULED: WF-42)

Owner, to "as connectors are features, multiple connectors may be brought into a xap and combined, mapped to
each other in a flow, yes?" — the answer measured on head `3cf48b671` was PARTLY: combining holds (connector.md
§2.8, §4.5, §12.3/CK-6; the order-pipeline design), mapping does not — a step's intent binds from `$args` only,
`$steps/<name>/result/…` is readable in `when=` guards alone (flow.md §4.4, WF-2), and no transform construct
exists. Letter **(a)** taken.

| Id | Decision |
|---|---|
| **WF-42** | **(owner)** (1) A step's intent argument may be a CXPath over the RUN RECORD — `$args` and `$steps/<name>/result/…` (inside or after an `until`, the WF-18 iteration rule) — under exactly WF-2's domain rule: a path that addresses outside the record refuses at validation with the same code as a guard's; a reference to a step that is not a `needs=` ancestor refuses at validation (the record cannot hold it). The binding is evaluated by the runner when the step activates and the resolved intent is recorded with the step, so the run record stays the only truth an act was made from. (2) A `:runner` TRANSFORM step: `by=:runner` with a `[compute …]` naming a PURE def over the record (its arguments bound by (1)); its result is recorded like any step's and read by later steps through `$steps/<name>/result/…`. It is the place a mapping between two connectors' nouns lives — declared, pure, graded like any def — and the answer to §4.4's "add a `:runner` step that computes and records it". (3) The reference example `order-pipeline` (#1468) reads `pull-contacts`' result in `enrich-orders` through a transform step and teaches it. Nothing else in flow.md changes: guards, authority, the pivot, compensation and the courier are untouched; a flow with no `$steps` binding behaves exactly as before. |

## Why

The kit's promise is that integration is declaration (1430-d, 1430-g). Without (1) and (2) every integration
between two connectors is hand-written adapter code in one of them — the per-integration cost the owner is
removing — and the `:runner` sentence in §4.4 named a step it never specified.
