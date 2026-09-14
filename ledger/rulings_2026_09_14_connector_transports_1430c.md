# Owner letter 2026-09-14 ~05:20Z — the connector kit executes every protocol, DB included (RULED: 1430-c)

Owner, to "the kit as specified is HTTP-only": **"we're expecting full connectivity for a connector across
protocols including db"** → letter **(a)**: widen #1430 now.

| Id | Decision |
|---|---|
| **1430-c** | **(owner)** In v0.18 the connector kit EXECUTES `kind=http`, `kind=db`, `kind=graphql`, `kind=soap` and `kind=sftp`. Each non-http kind is a thin engine adapter behind the one walk/classify/budget contract of connector.md §3, over a protocol module: `db` over `core/db_access.md` (exists — no new module; a connector row/page walk is a query with a cursor column), `graphql` over the `graphql` codec module (#1429, pulled INTO v0.18 — GQL-1's placement stands), `soap` over a new `soap` codec module (XML envelope + WS-Security header over http), `sftp` over a new `sftp` protocol module. Order: http (the engine, #1430) → db → graphql → soap → sftp; each transport is its own issue, branch and spec section, spec first, the owner reads before code. connector.md §2.1's "`http` is the kind this module executes" and §1.1's "SOAP, GraphQL and SFTP as they land" are superseded by this row and trued by the first transport branch. |

## Placement, decided here before spec or code (OL-15)

| module | ring | namespace today → cutover | spec | corpus | code |
|---|---|---|---|---|---|
| `graphql` | 1 (pure codec; GQL-1) | `cx-stdlib/graphql` | `stdlib/graphql.md` | `conformance/stdlib/graphql.cxd` | `vcx/code/stdlib_graphql.v` |
| `soap` | 1 (pure codec: envelope, faults, WS-Security header construction; the transport is `http`'s) | `cx-stdlib/soap` | `stdlib/soap.md` | `conformance/stdlib/soap.cxd` | `vcx/code/stdlib_soap.v` |
| `sftp` | 2 (opens sockets) | `cx-stdlib/sftp` → `cx-platform/sftp` | `platform/sftp.md` | `conformance/platform/sftp.cxd` | `vcx/platform/stdlib_sftp.v` |
| `kind=db` adapter | inside `connector` (Ring 2) | — | connector.md §3.8 | `connector.cxd` | `vcx/platform/stdlib_connector_db.v` |

Paths are the post-#1427 tree (phase 2 is merging); a branch that lands before the moves places by the
registry's `-to` columns. Rows enter `registry/modules.cxd` as `planned` with this record.

## Why
- A kit that executes one transport is a client library, not a kit; `kind=` was designed as an open set for
  exactly this (connector.md §2.1).
- DB is the second transport because its protocol module already exists; GraphQL is a codec over HTTP; SOAP is a
  codec plus WS-Security over HTTP; SFTP needs a socket module and comes last.

## 1430-d — the kit is an OPEN adapter contract, wide and specialized (owner, 2026-09-14 ~05:35Z)

Owner: *"the connector kit must make it easy and cheap to add and plug in ANY new protocol, db, approach, etc. If
it's not sufficiently wide we get divergence and chaos. but it must allow specialization to take advantage of
the various axes and technologies — don't try to shove them all into the same vanilla box where we lose control
and details of the connection."*

| Id | Decision |
|---|---|
| **1430-d** | **(owner)** The engine owns ONLY the loop invariants every connection shares — the walk's totality and stop rule, the budget arithmetic and its two ledgers, retry classification into the closed set, the credential chain (scheme + handle, value never in a document), the audit record's core, failure isolation, the bounds ceiling. EVERYTHING kind-specific is the adapter's and is DECLARED by it, not hard-coded in the core: (1) the `[gateway]` attributes and children a kind accepts (a kind ships its own schema fragment; the core schema carries only `name= kind= priority= auth= signing= rung=`); (2) its pagination styles — the four of §2.2 are `http`'s, a kind registers its own (a cursor column, a directory listing, a change-feed offset, a GraphQL connection) under the one stop rule; (3) its classification table (driver errors, SOAP faults, SSH status codes → the closed set); (4) its audit `[detail]` vocabulary; (5) its discovery (information schema, introspection, WSDL, a listing); (6) its capability needs and its own bounds beneath the ceiling; (7) its deployment-binding fields (a `base-url=`, a backend handle, a host key handle). Adding a kind = one adapter (spec section + corpus section + one V file registered in the kind table) and NOTHING else changes — the kit ships an **adapter conformance harness**: a generic corpus every adapter must pass (walk totality, budget, refusal semantics, the credential refusals, the audit core) plus the adapter's own cases; `make placement-gate` and the kind table's own check refuse an adapter with no spec section, no corpus section or no registered kind. The engine never sees a transport's bytes, and the connection's details (a DB's isolation level, an SFTP host key, a GraphQL operation name, a SOAP action) are first-class in the kind's declaration and audit detail — never flattened into a generic field. |

Why: a kit that executes one transport is a client library; a kit that forces every transport through one
vocabulary loses what makes each connection controllable. The seam is the kind table; the discipline is
"declared by the adapter, enforced by the engine".
