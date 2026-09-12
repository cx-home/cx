# RULED: 1427-a…1427-j — the ring-legible tree (owner, 2026-09-12 ~13:40Z, option (a) on every dimension of the integrator's table)

The full option table (facts, dimensions D1-D11, costs, and the integrator's recommendation
of (a) on every line) is the first comment on #1427. The owner's ruling is the second comment
on #1427 (`gh issue view 1427 --comments`, owner, 2026-09-12 ~13:40Z): option (a) on every
dimension. Its text is copied verbatim into the table below, one row per id.

| Id | Dimension | Decision |
|---|---|---|
| **1427-a** | D1 spec tree | `stdlib/` + `platform/` (non-module specs leave the catalog) |
| **1427-b** | D2 namespace | `cx-stdlib/` + `cx-platform/`, parser-based migration, both `bundled:` |
| **1427-c** | D3 conformance tree | split, directory = suite ring, per-case tags stay |
| **1427-d** | D4 code | names and registrations follow the declared ring; declared halves allowed |
| **1427-e** | D5 mixed modules | `http` → `cx-stdlib/http-client` + `cx-platform/http` with `:as http` inserted for client-only programs; `smtp`/`imap` whole to `cx-platform`; `email` re-classified by the import test; saml/oidc/scim/sasl stay Ring 1; diagram/ft/io/sched stay Ring 1 with per-case tags; `term` gets a corpus; non-module specs get `kind=` |
| **1427-f** | D6 registry | `registry/modules.cxd` is the declaration; new step `placement-gate`; every path-keyed check re-pointed; the count canary reads the registry |
| **1427-g** | D7 docs | two READMEs, docs regenerated, hand-written docs through the tool's pass |
| **1427-h** | D8 lockfile | one `bundled:` row per namespace used; lockfile.md and code.md §12.1 gain the prefix |
| **1427-i** | D9 migration tool | `cx --migrate-namespace`, parser-based, idempotent; fixed-string pass for the V test literals |
| **1427-j** | D10 sequence and shape of the merge | one branch `impl/cx-A-1427`, one merge, full step set; open branches run the tool once before their merge |

## Not this issue

D11 is restated so the record carries it: a repo split (Ring 2 first) is a recorded trigger,
not a plan for this issue — the first client that needs Ring 2 released on a cadence different
from the binary. No third namespace beyond `cx-stdlib`/`cx-platform` (and the existing
`cx-xap`, `cx-x`) is in scope.

Sequence: the registry, the placement check and the migration tool start at once; the moves
happen after the routes, #1404 and #1428 branches have merged; one branch `impl/cx-A-1427`,
one merge (1427-j); M2 phase 2 lands in the new tree (OL-14).
