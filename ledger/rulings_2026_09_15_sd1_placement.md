# Integrator placement 2026-09-15 — where the schema-as-data feature kind lives (RULED: INT-14)

SD-1 (`ledger/rulings_2026_09_15_views_group_vg3_schema_sd1.md`) decided that the schema-as-data
FEATURE KIND is written in this release, spec first. OL-15 asks that placement — ring, spec
directory, code directory and namespace — be **decided before the spec is written**, so that a
surface's four statements about where it lives cannot disagree. This page is that decision for
#1497; `registry/modules.cxd` is where it is declared and `make placement-gate` is what holds the
tree to it.

| Id | Decision |
|---|---|
| **INT-14** | **(integrator, OL-15)** The schema-as-data kind is a **feature KIND, not a module**: it adds no `[?lib]`, no def, no namespace and no error code, so its row carries `ns=none kind=suite` and its artifacts are a spec page and a corpus. **Ring 2** — the kind is reached through `[$xap:compose]` and the runtime cascade, both Ring 2. The **spec** is a normative page in the xap tier, `spec/03-approved/xap/xap_schema_as_data.md`, beside `xap_grammar_composition.md`, which it EXTENDS BY REFERENCE and never restates. The **corpus** is `conformance/xap/xap-schema.cxd` (`ring=2`), `gate=advisory` until the code lands, with a `conformance/gates.cxd` row in the `xap-compose` row's shape and a `vcx/tests/fixtures_grader/fixture_shards.cxd` row. The **code phase** lands in `vcx/platform/stdlib_xap.v` — its own file if the kind's synthesis proves large enough to warrant one, which is the code phase's call and not this page's. |

## The placement table

| surface | ring | namespace | spec | corpus | source | code |
|---|---|---|---|---|---|---|
| `xap-schema` | 2 | none (a kind, not a module) | `spec/03-approved/xap/xap_schema_as_data.md` | `conformance/xap/xap-schema.cxd` | none | `vcx/platform/stdlib_xap.v` (the code phase) |

## Why the registry row is `status=current` and not `planned`

`scripts/placement_gate.cx` refuses a `status=planned` row whose declared artifacts are **all** on
disk — the `[stale planned]` rule (the file's header, and the check at its `$v-stale-planned`
binding). A `kind=suite` row's declared artifacts are its `spec=` and its `corpus=`, with
`source=none code=none half=none`; both land on this branch, so `planned` would be a second,
silent statement that the writing is not done, sitting next to the writing. The row is `current`
from the commit that lands the two files.

This is where `xap-schema` differs from `graphql` and `soap` (RULED: 1430-c), whose rows stay
`planned`: those are `kind=module` rows declaring a `source=` and a `code=` that are not yet on
disk, so `planned` is still true of them.

## What this page does NOT decide

- **The kind's semantics.** Those are the spec page's, under SD-1.
- **Whether the code lands this release.** SD-1 already answered: only if it is ready before the
  final cut, which follows the transports; otherwise it is the next release's first item.
- **A `composition.md` seam row.** The kind introduces no module-to-module dependency the seam
  table lacks — every edge is `xap` reading `xap` — so none is added, and
  `make check-composition-seams` is a step of the branch rather than a file it edits.
