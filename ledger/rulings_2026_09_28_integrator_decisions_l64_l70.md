# Integrator decisions 2026-09-28 (night), under the owner's delegation — Letters 64, 65, 66, 67, 69 and 70; and the owner's answer to Letter 68, the v0.18.0 cut

**Status: RULED by the integrator (2026-09-28, 03:2xZ through 09:2xZ) under the owner's word of
2026-09-27 15:2xZ on [#1591](https://github.com/cx-home/cx-private/issues/1591) — "away for next
5-6hrs make the best long term cx decisions and don't blow our usage credits" — each on the letter
posted there with the merge or READY it arose from; every one reversible by the owner's word. The
last section is the OWNER's own answer (10:2xZ, in session, "a") to Letter 68. Pages written by the
next session (11:xxZ) before any commit cites them, as the HANDOFF of 10:0xZ required. #1467f,
#1690, #1498, #1434, PIVOT-2, SYNC-3, SYNC-6, KIT4-1, KIT4-2, RS-38, D83a, K10.**

## The delegation, verbatim

"away for next 5-6hrs make the best long term cx decisions and don't blow our usage credits"

## DBNUL-1 — a kind=db parameter may be absent, and the kit binds NULL for a cursor on page one (L64 = (a))

Measured in #1467f (cx-platform-connector#11): with `size-param=` bound, a statement
`WHERE key > coalesce(:after, '') … LIMIT :limit` is refused CXER6320 on page one — `:after` is
unbound before the bound `:limit` — because db_access.md §7.1 makes every parameter a string and the
kit has no NULL to hand it; SYNC wave 1 met the same with `:since`. Ruled: db_access gains an absent
parameter — `[param name= null=true]`, one sentence in §7.1 with its case (cx-platform-db) — and the
kit binds NULL for the cursor parameter on page one. A missing cursor is SQL's own absence, what
`coalesce` and `IS NULL` already expect; one round in two repositories. Rejected: (b) the kit binding
`''` on page one — `:after IS NULL` false on page one and backends disagreeing on `''` against NULL,
a convention to remember; (c) keeping the refusal and ordering the size placeholder first —
correctness by placeholder order.

## YIELD-2 — a yielded pair in an element body is one child (L65 = (a))

program-for-023 pins that `[box [?for … [yield (k, 1)]]]` contributes ONE child per yield, the pair
as a sequence child — parity with `[?splice]`, and YIELD-1's rule read at the element boundary.
Ruled so: one sentence in code.md §6.4.1 carrying program-for-023 (RS-38, inside this decision; the
boundary rule already says one sibling per yield). A comprehension's yield is a directive's
contribution, not a value adopted as content, and the case already grades it. Rejected: (b)
refusing a sequence-valued yield in an element body as §6.4.1 refuses a sequence value in element
content — a refusal of what the corpus already grades green.

## NAMES-1 — the names #1498 wave 2 chose get fixture-backed sentences (L66 = (a))

Wave 2 named five things no sentence rules: the `automations` stream, `[automation-retired flow=]`,
the `ux-automate-*` codes, the deployment's root `[claims-map]` for the `ux:automate` claim, and the
skeleton's `[paths …]` template. Ruled: each is written as a fixture-backed sentence inside the
section its ruling names — AA-4, AA-5, AA-6 and §3.10 — with its case id (RS-38), in the sync/spec
truing round. Rejected: (b) renaming first — churn on merged, graded code for no semantic gain; (c)
leaving them unnamed — a shipped surface no sentence rules.

## SYNCT-1 — SYNC wave 2a's four choices get sentences in their sections (L67 = (a))

Wave 2a chose four things beside the spec: open/run's effect sets are wider than §6.2's list, a delta
carries `opts.stream` (default the source name), `sync:reseed` is its own capability, and
pause/resume write no audit record. Ruled: each is a fixture-backed sentence in its section of
sync.md (RS-38), written in the sync/spec truing round together with §10's hermetic claim, its status
lines and §14.3, and NAMES-1's sentences. Rejected: (b) narrowing the code to §6.2's list — measured
refusing; (c) leaving them unspelled.

## OPXAP-1 — order-pipeline's scenario moves under the XAP host (L69 = (b))

PIVOT-2 left order-pipeline's scenario on `drive.cx`: the program face has no store slot and no
deployment document, so a projected connector verb refuses CXER4965 (measured). Ruled: the scenario
moves under the XAP host as crm-rest's did (KIT4-1, KIT4-2) and `drive.cx` is retired, a small round
after the cut. Rejected: (a) a new CLI word booting connectors under `cx flow run` — a second boot
path; (c) keeping the script — a scenario the program face cannot run as written.

## CAPEX-1 — `[capture]` is exempt from the connector's credential scan (L70 = (a))

The connector's credential scan treats `[capture key=…]` as a credential, so a feature with two
captured gateways is refused CXER6310 at boot (SYNC wave 2b's lane uses one). Ruled: `[capture]` is
exempt from the scan — the scan is about a gateway's auth rows, and `key=` here is an identity path,
not a secret — fixture first, in the connector, in the sync/spec truing round. Rejected: (b) renaming
`key=` to `identity=` — a SYNC-3 spec change for a scanner's misreading; (c) one captured gateway per
feature — a limit with no reason behind it.

## CUT-1 — the v0.18.0 cut comes after the docs and playground items, on the owner's "cut" (L68 = (a), the owner's word)

The owner answered Letter 68 in session at 10:2xZ: "a". The v0.18.0 cut (K10) comes in the next
window AFTER DOCS-4's design pass, PLAY-1 and CICD-1 land, in this order: the release notes trued to
the merges since K10p → the bump commit on `release/0.18` → REFRESH-7 (the filter, a fast-forward)
→ `release.sh --dry-run v0.18.0` in the filtered clone, read whole → `release.sh --from-bump=<sha>
v0.18.0` (D83a) — and only on the owner's "cut" at that moment; the integrator runs no publishing
phase unasked. The truing rounds (DBNUL-1, YIELD-2, NAMES-1, SYNCT-1, CAPEX-1) ride inside the
window. Rejected: (b) cutting on the handoff head with the docs as they are — a release whose public
docs the owner rates 1/5 and whose playground is broken online; (c) cutting after every truing round
but before the docs redo — a cleaner spec, the same docs problem.
