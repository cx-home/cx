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
