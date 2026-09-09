# RULED: 1317-h — the XSP responder's IDLE TICK and its HANDSHAKE BUDGET are two named constants, and xsp.md states the budget

Date: 2026-09-09 04:20 ET (posted on the issue 2026-09-09T07:17:15Z).
Issue: cx-home/cx-private#1317
Drafted by: worker B (Opus), campaign #1354, on #1317 at 05:03Z. Approved by:
Fable + owner, letter (a), recorded on #1317 and on #1354.
Related: `store_grpc_client.v:32` (`grpc_client_read_deadline_ms = 5000`, the
precedent this number is taken from, not invented);
`spec/03-approved/xap/xsp.md` §5.1; `spec/03-approved/xap/store.md` §6.4's
`CXER1101`; the step-2 served-writer bench row (`bench/flow/served.cx`,
`bench/flow/run.sh`, landed at `d76280d14` with floors UNPINNED).

## The defect

ONE literal `1000` served two unrelated jobs, and the code said so out loud:
`store_xsp_serve.v`'s accept site carried the comment *"idle tick: shutdown
poll + handshake budget"*. The two quantities pull in opposite directions —
the shutdown poll wants to be small (it bounds how long a listener takes to
notice a shutdown request) and the handshake budget wants to be generous (it
bounds attach latency under load) — so one number could only be wrong for one
of them.

MEASURED symptom: the N=64 served-writer row refuses its attach with `no M2`
(`xcl_connect_locked`, `store_xsp_client.v`), because a responder busy
accepting 63 other writers cannot answer inside a shutdown poll's worth of
time.

Verified before ruling: the literal appears at `store_xsp_serve.v:271` and
`:754`, `store_xsp_peer.v:220`, `fabric_service.v:920` and `:1520`, and on the
client at `store_xsp_client.v:112` and `:130` — seven sites, not the six the
letter estimated. The gRPC neighbour on the same box already NAMES its
equivalent (`grpc_client_read_deadline_ms = 5000`), and neither `xsp.md` nor
`xsp-auth.md` said anything about a budget at all.

## Ruled

1. Two named constants in the xsp platform code: **`xsp_idle_tick_ms = 1000`**
   (the shutdown poll, unchanged) and **`xsp_handshake_budget_ms = 5000`** (the
   gRPC precedent). The budget is the read deadline from accept/dial until M4
   is exchanged, on BOTH sides; after M4 the handle reverts to the idle tick.
   No `1000` literal survives at those sites.
2. `xsp.md` gains ONE normative sentence in the handshake section: the
   responder admits a session within a stated handshake budget, distinct from
   its idle tick; the budget is a property of the CARRIAGE, not of the store,
   and a client that does not see M2 within it refuses `CXER1101`.
3. Fixture-first where measurable: the N=64 served-writer row that produced
   `no M2` is the red-proof (pre-fix fails the attach, post-fix admits), taken
   in the bench lane with the row's own instrumentation; floors stay
   `unpinned` until the row measures.

**Refused:** (b) one constant raised everywhere — shutdown latency would go
from ≤1 s to ≤5 s on every idle connection; (c) a `store:open` opt — the bench
would pass by flag while the shipped default still failed at 64; (d)
client-side retry — makes `open` sometimes-slow instead of sometimes-failed, a
different contract from store.md's `CXER1101`.

## What landed, and the two places it reads wider than the letter

Both are recorded here rather than left for a reader to discover.

**(i) The spec sentence went into `spec/03-approved/xap/xsp.md`, not
`spec/03-approved/std-lib/xsp.md`.** The ruling named the latter; that file is
a CATALOG ENTRY whose own second paragraph says *"the normative reference is
`xap/xsp.md`"*. A normative sentence placed in a catalog stub that defers
elsewhere would not be normative, so the ruled TEXT went to the ruled
SECTION's actual home — §5.1, beside the liveness window it is most easily
confused with. Nothing else in either file moved.

**(ii) The handshake TURN's read count is derived from the budget, so the
ceiling does not move.** A handshake turn's real ceiling is
`reads × read_deadline_ms`, and both turn loops (`xcl_handshake_turn`,
`sx_peer_turn`) were written `for ticks < 10` against the 1000 ms deadline — a
10 s ceiling. Raising the deadline alone would have multiplied that to 50 s,
turning a fast refusal into a long hang, which the ruling asks for nowhere. So
`xsp_handshake_turn_reads = 2` holds it:

```
10 reads x 1000 ms (idle tick) = 10 s     <- before
 2 reads x 5000 ms (budget)    = 10 s      <- after
```

The change is in WHERE the waiting happens, not in how much of it there is:
one read now waits long enough for a loaded responder's M2, where ten short
reads used to give up between them.

**And one site the client did not have:** the responder and the fabric daemon
each already had a post-M4 revert line; the client had none (its `1000` was
set once at dial and never changed). Since the ruled budget runs *"from
accept/dial until M4 is exchanged"*, on both sides, the client's revert is
ADDED — which is also what keeps every post-attach client read on exactly the
deadline it has today.

`fabric_service.v:3207`'s `read_deadline_ms = 2000` is a different site and is
NOT in this ruling's list; it was left alone.
