# Owner decisions 2026-09-18 ~23:45Z — the set module's code band (1173-c); the deployment binding's spelling enters connector.md §4.6 (1466-a); the adapter contract gains a `binding-of` hook (1483-a)

Owner, 2026-09-18 23:3xZ–23:5xZ, on three letters from Agent F: "1a … 3a", then "A" on the second after a plain-language restatement.
Measured before the rows (head `d3ad59c32`): the refusal-code registry (`spec/03-approved/process/governance.md` §9.6) has nothing at or
above `CXER7000`, and the set module ruled by 1173-b / 1174-b has no band; connector.md §4.6 states what a deployment binding carries as a
table with no code fence, no ledger row rules a spelling, `reference/connectors/README.md` §8's open decision 1 says so, and the only
written form is the worked block in `spec/03-approved/platform/deployment-topology.md` §2.1, which that page labels a proposal — so the
seven reference connectors (issues 1466 1467 1468 1469 1470 1471 1472), each shipping `deploy/sandbox.cx` and `deploy/production.cx`,
cannot be written without deciding it; connector.md §3.9.4's adapter contract has twelve hooks and none that describes a kind's binding,
so the bind scaffold (issue 1483) has no data to read.

| Id | Decision |
|---|---|
| **1173-c** | **(owner, letter (a); issues 1173 and 1174, completing 1173-b / 1174-b)** `cx-stdlib/set` is allocated the band **`CXER7000–7009`** — ten codes on the `fp` module's precedent — as one row in governance §9.6 (the only spec sentence; the owner reads it); the non-scalar-member refusal reuses the map module's code exactly as 1173-b defines it by reference, so it mints nothing. Rejected: (b) borrowing from an existing module's band; (c) holding the module to the next release. |
| **1466-a** | **(owner, letter (a); connector.md §4.6; the seven reference connectors)** The deployment binding is SPELLED as the worked block of `deployment-topology.md` §2.1 — `[deployment [runtime [connectors [connector feature=… [gateway …] [tenant …] …]]]]` with the fields §4.6's table names — and §4.6 gains that block as its code fence and ONE sentence: *a binding is a `[deployment]` document spelled as follows; `reference/` examples carry one per environment* (the owner reads both); the deployment-topology page's block is then a citation of §4.6, not a proposal. Written as its own small spec pair (fixture first: a `connector.cxd` case that reads a binding of that shape through the kit's harness) BEFORE any reference connector; the seven examples build against it. Rejected: (b) writing the examples against the proposal and flagging — a core shape decided from inside `reference/`; (c) leaving the seven open. |
| **1483-a** | **(owner, letter (a); issue 1483; connector.md §3.9.4)** The adapter contract gains a THIRTEENTH hook, **`binding-of`**: an adapter answers the fields its kind's deployment binding carries (name, type, required, meaning), so the bind scaffold emits a binding with every kind-declared field as a TODO and is correct for an operator's own kind, not only the eleven cx ships; §4.6's table becomes a projection of the adapters' answers. One §3.9.4 row and the §10.1 harness row (the owner reads them) as a spec pair FIRST, then the eleven adapter implementations (small each) and the scaffold, in one code branch. Rejected: (b) a hard-coded roster in the core — a twelfth kind's scaffold silently omits its fields; (c) narrowing to the two base-URL kinds — a partial implementation. |

## Sequencing

Agent F: #1088 (in flight) → the 1466-a spec pair → #1466 → #1467 (with `[capture]`, still absent from `feature.cxs`, as its own
question if the issue's dependency on issue 1434 has not landed) → #1173 + #1174 under 1173-c. The 1483-a spec pair and its code branch
take the next free slot on the connector kit (Agent E after the kinds, or Agent F after the set module).
