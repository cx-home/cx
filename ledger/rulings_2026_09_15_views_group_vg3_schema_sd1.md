# Owner letters 2026-09-15 ~01:20Z — the fourth clause of `[views]`, and the schema-as-data feature kind (RULED: VG-3, SD-1)

Owner, on "do we have features and kits defined sufficiently to build a board product": *"a and b if that's the
best long term option and approach to delivering in v0.18."* Measured on head `956253c1e`: `[views]` declares
three of the four clauses §4.5 names (#1496); a xap's grammar is composed at compose time and no feature kind lets a
tenant edit a noun's fields at run time; end-user automation authoring is not specified.

| Id | Decision |
|---|---|
| **VG-3** | **(owner, letter (a); VG-1's remainder — #1496)** `[views]` gains `[group field= dir=]`, zero or more, `dir ∈ {asc, desc}` default `asc`, declaration order = offer order (as `[sort]`); W8 conflicts on `[facet]`'s ground: a `[group]` naming no field of its noun, a `[group]` over a field typed as a sibling noun, a field declared twice in the `group` role — `[conflict code=:w8 …]`, report-every; within-group order is the noun's `[default-order]` or the chosen `sort=`; the composed grammar carries `[group]` verbatim (§4.5 ¶5); `ux.md` §10.6 gains `[ux:group]` admitted only for a declared `[group]` field, the shape of `[ux:facet]`. Additive: a noun with no `[group]` behaves as today. In v0.18: spec first (xap_grammar_composition.md §4.5, ux.md §10.6; the owner reads the delta), then `vcx/platform/stdlib_xap.v`'s children check and the projection, with xap-compose cases. |
| **SD-1** | **(owner, letter (b), conditioned on "best long term and deliverable in v0.18")** A schema-as-data FEATURE KIND: a feature whose nouns' FIELDS are tenant-edited records — a board's columns — validated at write time under the bounds discovery already uses (connector.md §3.6/§8), with the compose gate's guarantees restated for it (what the composed grammar fixes: the kind, the verbs, the projection contract; what the tenant's schema may vary: fields and their scalar types; what it may never do: add verbs, cross a noun, change effects). The spec is written in v0.18, spec first (the owner reads); its code lands in v0.18 only if it is READY before the final cut, which follows the transports (INT-3 addendum 2) — otherwise it is the next release's first item, stated now, not discovered at the cut. End-user automation authoring (a person composing "when X then Y" from the surface, through the studio and `cx xap scaffold`) is filed as a decision issue for the next release. |

## Why (b) is conditioned

The long-term answer is the platform's (the same reasoning as 1430-g and COMP-1: a need every adopter has is
inferred differently by each unless CX states it once). The delivery answer is measured: the critical path to the
final tag is the seven transports' specs, their code and the reference examples; a new feature kind's CODE beside
them is not a promise this page can make, so the spec is the v0.18 deliverable and the code is by measured pace.
