# Owner decisions 2026-09-27 (afternoon) — Letters 52, 53 and 54: XCO's two readings (ACK-1, RT-1), a list verb through the host walks every page (WALK-1), the vendor budget is per process (BUDGET-1)

**Status: RULED (owner, 2026-09-27 ~14:1xZ, in session, on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 05:5xZ (L52) and 08:4xZ (L53, L54)).**

## The owner's word, verbatim

"l52a l53a l54a"

## ACK-1 — `by=` on the `:peer` step's ack is a space-separated list of DIDs (L52.1 = (a))

An attribute cannot hold the sequence the XCO ruling wrote; `by=` on `[ack tier=:t2 …]` is the
space-separated list form the vocabulary already uses for lists, merged as graded in XCO's round.
Rejected: a child element `[by [did …]…]` — a new construct for one attribute.

## RT-1 — the `[runtime …]` rows' sentence and the delegated-intent frame are written in the host rounds, fixture-backed (L52.2 = (a))

The `[runtime [secrets] [authz] [connectors]]` rows' sentence written in KIT-4's round (the
distribution spec §6.3.1) stands. The delegated-intent frame at `/.cx/flow/act` gets its one
sentence in xap.md's ingress section in the next host round (HOSTB-1's), carrying XCO's case ids
(RS-38). Rejected: a spec-only round of its own.

## WALK-1 — a list verb performed by the host walks every page (L53 = (a))

Through the host each act is one `connector:run` call; `apply` walks every page for a list verb
when the host performs it — the kit's walk under the one stop rule, `[seen]` and `max-pages=` as
on the library path — so the host and the library answer the same list. One connector round with
a host-lane case. Rejected: (b) the host returning the first page and a cursor the caller
re-submits; (c) a list through the host staying one page.

## BUDGET-1 — the vendor budget is per process under one host per tenant; §4.3 says so (L54 = (a))

One host per tenant (KIT4-2) makes connector.md §4.3's vendor budget a per-process limit; the
section says so in one sentence with its case (two hosts, one vendor, each host's budget its own).
The cross-host budget is a later design — a shared counter needs a store the hosts share.
Rejected: (b) one host serving every tenant (reverses KIT4-2); (c) a shared budget store now.
