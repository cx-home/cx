# Owner letters 2026-09-14 ~04:50Z — #1430 and #1434 (RULED: 1430-b, 1434-b)

Owner: "1a 2a 3a 4a if those are the best long term for cx" — each was recommended as the long-term choice
and is taken as ruled.

| Id | Decision |
|---|---|
| **1430-b** | **(owner, letters 1(a), 2(a))** (1) The example connector's feature package lives under `reference/`, beside the other shipped feature packages — not under `x/`, which is the `cx-x` module tier; #1430's placement paragraph is corrected by this row. (2) Retry and rate-limit: the SHAPE (`[paginate]`, the retry and rate-limit directives) is declared in the feature; the ENVELOPE (budgets, windows) is the deployment binding's — `[gateway]` stays the transport declaration (CK-2) and a feature never states its own budget (the CK-10 escalation surface). The code phase on `impl/cx-A-1430c` builds to connector.md as landed, which already follows both. |
| **1434-b** | **(owner, letters 3(a), 4(a))** (3) `feature.cxs` gains the `[capture]` element sync.md §2.1 makes the declaration's shape — in #1434's code phase, under 1434-a; capture is not folded under `[gateway]`'s attributes. (4) `audit.md` §11's closed module registry gains the `connector` and `sync` rows now, in one doc-only branch: `audit.md` §11 says a specification sentence that says "audit" with no row is a defect, and connector.md §4.4 / sync.md §4.4 both say it. |

## Why, briefly

- `reference/` holds `shop`, `shop-web-client`, `archetypes` — every shipped feature package; `x/` holds
  `cx-x` modules (`mcp-server`, `ux`, `tools`). One tree per kind of artifact (OL-15).
- A budget in the feature would let a package escalate its own reach; the deployment binding is where the
  operator's envelope lives (connector.md §4, CK-10).
- The schema follows the spec: the spec is the only truth, the schema is its checkable form.
- A closed registry that a checker (`CXER6201`) reads is complete or it is wrong; both new modules emit.
