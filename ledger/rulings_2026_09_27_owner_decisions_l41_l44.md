# Owner decisions 2026-09-27 — Letters 41–44 (from #1467, R-1492 and #1463): the graded orders-db partial merges (ODB-1); L41, L43, L44 pending

**Status: RULED (owner, 2026-09-27 ~00:4xZ and ~00:5xZ, in session, on the letters posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 00:2xZ–00:3xZ).** All four are ruled here;
L41 (the call spread, #1686), L43 (R-1492's flow over the socket, cx-platform-flow#12) and L44
(#1463's audit `subject=`, #1683) were asked back for explanation, explained in session, and answered (a) each at ~00:5xZ.

## The owner's word, verbatim

"l41 what's a call spread? need more info on this and how it impacts cx / l42a / l43 whats this /
l44 whats this" — then, after the explanations: "l41a / l43a / l44a".

## ODB-1 — the graded orders-db partial merges now; #1467 finishes after L41's fix and #1434's code (Letter 42 = (a))

`impl/cx-F-1467` (the orders-db package spelled per connector.md §3.8.1, fixtures 001–004 and 007
enforced 5/0, 005/006/008 advisory until `cx-platform/sync` has source and `[capture]` is in
feature.cxs — #1434's code phase — and the FIX-1 fix #1687: `connector:validate` answered an `[err]`
for every clean declaration, connector-141) merges as graded; it closes nothing. #1467 closes on the
scenario after #1686's fix (L41) and #1434's code, when 005/006/008 flip to enforced. Rejected: (b)
holding everything; (c) narrowing #1467 to no capture.

## SPREAD-1 — a call spread in the language (Letter 41 = (a); #1686)

`[$f $a *$rest]` passes each item of the sequence `$rest` as its own argument, in place, mirroring
the pattern rest marker of code.md §6.4.3; every variadic builtin and every def with a rest
parameter gains it; a spread of a non-sequence value is refused with its own code; `[?splice]` in
call-argument position stays refused (children and arguments are different things, and the spec
sentence says so). One rule in cx-core-code, fixture first in code.cxd, one sentence in code.md's
call section with its case ids (RS-38). The first consumer: `c--db-perform` binds by the statement's
`:name` placeholders, and the kind=db corpus gains a case that reaches `perform` against sqlite.
Rejected: (b) an array operand for db_access only; (c) an arity ladder in the adapter.

## BEX-1 — R-1492 merges as graded; the socket-driven flow follows cx-platform-flow#12 (Letter 43 = (a))

The bulk-export example merges with its flow graded offline (eight fixtures) and its scenario
ordering the three verbs by script; cx-platform-flow#12 (a) — a flow step's act runs under the
process grant, so a connector verb inside a flow is no longer refused CXER0271 — is the follow-up,
after which the scenario switches to the flow and #1492 closes. L43.2 (a): composition.md §3.3's
example flow gains `pivot=true` on its submit step, fixture-first, in the xap commit at merge.
Rejected: (b) holding the example; (c) the script-driven scenario as the permanent shape.

## BUS-1 — the bus audit record's subject (Letter 44 = (a))

L44.1 (a): the record's own `subject=` carries the bus subject or queue; the detail keeps
`group= ack= sequence=`; connector.md §3.18.4's sentence is corrected to say so, fixture-backed by
the bus cases (#1683). L44.2 (a): `ack=on-process` acknowledges after the kit's walk has taken the
batch; landing a message is the consumer's `[on …]` binding's job, not the kit's. Rejected: a new
attribute word (`topic=`); an exemption from audit.md §3.5; the kit appending to the caller's journal.
