# Integrator decision 2026-09-15 — the file-surface contract is its own normative page (RULED: INT-18)

1430-e ruled that `sftp` (#1457) and `ftp` (#1458) carry **"one file-surface contract"**, and the
owner's deliverable for both issues states it in full: *"ONE file-surface contract (`list`, `stat`,
`get`, `put`, `rename`, `delete`, `mkdir`; resumable transfers; size and time bounds; a bound root
no path or symlink escapes) specified once and instantiated by both modules, so a connector feature
written against a drop directory does not care which of the two carries it."*

**Where that contract LIVES was not decided.** OL-15 requires placement — ring, spec directory, code
directory, namespace — to be decided before a specification is written, so this row decides it
before #1457's and #1458's spec branch writes a line.

| Id | Decision |
|---|---|
| **INT-18** | **(integrator, under 1430-e and OL-15)** The shared file surface is its **OWN normative page**, `spec/03-approved/platform/file_surface.md`: a page and **not a module** — no namespace, no `[?lib]` surface, no source file, no corpus of its own and **no `[module]` row in `registry/modules.cxd`** — claimed by one `[catalog ring=2]` row the way `composition.md` and `deployment-topology.md` are (RULED: 1427-a, 1427-g, COMP-1), and carrying an **"Integration map"** heading because `placement-gate` demands one on every page under the Ring 2 specification directory. It states, once: the seven verbs' signatures and semantics; the resumable transfer (offset plus size, and the idempotency statement that buys); the bounds (entries per listing, octets per transfer, seconds per transfer, and the stall floor beneath them); the bound root and the path and link refusals; and the closed set of error classes every instantiation maps its own protocol codes onto. `platform/sftp.md` and `platform/ftp.md` each **INSTANTIATE** it — one section named *"The file surface — the instantiation of `file_surface.md`"*, mapping each verb onto the protocol's operations and each protocol code onto a class — and **restate none of it**. A later object-storage kind instantiates the same page (1430-e's catalog, #1464). |

## Placement — in the shape the connector-transports ruling's table uses

| artifact | ring | namespace | spec | corpus | code | registry row |
|---|---|---|---|---|---|---|
| the file-surface **contract** | 2 (a page, not a module) | — | `spec/03-approved/platform/file_surface.md` | — (its decisions are graded through the two instantiations) | — | **`[catalog ring=2]` only** — no `[module]` row |
| `sftp` | 2 | `cx-stdlib/sftp` → `cx-platform/sftp` | `spec/03-approved/platform/sftp.md` | `conformance/platform/sftp.cxd` | `vcx/platform/stdlib_sftp.v` | `[module … status=planned]`, already present from 1430-c |
| `ftp` | 2 | `cx-stdlib/ftp` → `cx-platform/ftp` | `spec/03-approved/platform/ftp.md` | `conformance/platform/ftp.cxd` | `vcx/platform/stdlib_ftp.v` | `[module … status=planned]`, already present from 1430-e |
| `kind=sftp` adapter | inside `connector` (Ring 2) | — | `connector.md` §3.13 | `connector.cxd` `connector-700 … 749` | `vcx/platform/stdlib_connector_sftp.v` | this module's own row |
| `kind=ftp` adapter | inside `connector` (Ring 2) | — | `connector.md` §3.14 | `connector.cxd` `connector-800 … 849` | `vcx/platform/stdlib_connector_ftp.v` | this module's own row |

Both module rows stay `status=planned` on the spec branch: spec and corpus on disk, source and code
absent — the stale-planned rule, exactly as #1429's `graphql` row and #1456's `soap` row.

## The three placements this row rejected, and why

1. **A section of `sftp.md`, cited by `ftp.md`.** Cheapest to write, and it makes `ftp` depend on
   `sftp` for a contract neither owns. The first time one of the two needs a sentence changed, the
   other is edited by the change or diverges from it — which is the divergence 1430-d was written
   against, reproduced inside the pair 1430-e created to prevent it.
2. **A module of its own.** A module is a namespace with a public surface, a corpus and code. This
   contract has none of those and must not: it would need a namespace nobody imports, an
   implementation with no protocol beneath it, and a corpus grading a surface that never runs — and
   each instantiation would then be a *wrapper* around it rather than an instantiation of it.
3. **Restated in both module pages, kept in step by review.** Two normative copies of one contract
   is two contracts with a convention between them. `check-composition-seams` cannot see it and no
   step can, so the first divergence is found by a connector feature that behaved differently
   against two drops.

## How the one contract is kept ONE, mechanically

- **`placement-gate`** reads the `[catalog]` row and the `Integration map` heading, so the page can
  neither become an unclaimed specification nor lose its seam section.
- **The corpora are twinned.** The cases that grade the contract's OWN decisions — the resume
  arithmetic and the bounds — carry the **same inputs and the same expected answers** in both files
  (`sftp-050 … 066` and `ftp-050 … 066`), and every other case with a twin shares its last two
  digits. A reviewer diffing `conformance/platform/sftp.cxd` against `conformance/platform/ftp.cxd`
  is reading the contract; a divergence shows up as two cases that no longer line up.
- **The two adapter sections are twinned the same way** (`connector-700 … 724` and
  `connector-800 … 824`, both instantiating the §10.1 harness), so the claim "a feature does not
  care which of the two carries it" is asserted at the kit's seam as well as at the module's.
- **The error-code bands are aligned**: `CXER6700–6799` for `sftp` and `CXER6800–6899` for `ftp`,
  with the **last two digits equal wherever the error class is the same**, so `CXER6708` and
  `CXER6808` read as "not found, over SFTP" and "not found, over FTP". The classes are the page's;
  the codes are each module's, so the page asserts no band it has no case for.

## What this row does NOT decide

The **SSH transport** — whether V's fork gains a vetted C library or SSH is written in V over `net`
and `crypto` — is the owner's, stated with its trade-off and a recommendation in `sftp.md` §1.3, and
it is taken **before the code phase** of #1457. Nothing in this placement depends on it.
