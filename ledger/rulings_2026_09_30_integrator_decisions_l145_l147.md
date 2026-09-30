# Integrator decisions 2026-09-30 — Letters 145 to 147, taken under DELEG-3: bug batch A's three letter lines

**Status: RULED BY DELEGATION (the owner, 2026-09-30 ~04:0xZ, DELEG-3; the three letter lines are in
`_gate_evidence/pipeline_batcha/RESULTS.md` on the batch's graded sha `170a18808`, posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 12:1xZ with this taking; the owner may
reverse any of them on reading). SHIP-1, FIX-1, CXF-8, RS-38, 584 (the owner's 2026-07-23 ruling on
terminal-field unwrap), RP-6, REPRM-1.**

## The owner's words, verbatim

"no decisions for at least 8hrs. pause if limits are hit and resume when lifted. make best long term
decisions for cx. no deferring. no partial work. only complete, sound, performant implementation that
follows the expectations"

## PATHU-1 — a multi-step path in an operand slot keeps unwrapping its terminal field; #1580 closes on the ruled behaviour (L145 = (a))

Measured: `$a/detail/outbound` selects one child holding one item and reads the inner value, so
`[$first]` answers that value and `[$count]` its arity — exactly code.md §6.2's "Terminal labeled-field
unwrap" and the 2026-07-23 ruling on composition with aggregation (#584), which says code that wants
match-counting uses a node-set form (`$a//outbound`, `$a/detail/*`, a predicate). Taken: the ruling
stands, #1580 closes on the measurement, the connector cases keep their node-set spellings. Rejected:
unwrapping only a one-step path (every multi-step field read in the stdlib changes meaning); reads
unwrapped but aggregates not (two rules for one path).

## MAPC-1 — the map carrier becomes persistent: a hash-trie in cx-core-data, O(log N) put (L146 = (a); #1692 part 3)

Measured after the batch: a 20 000-key `$map-put` fold 60.2 s → 37.2 s and still O(N²) — every
constructed map of 64+ entries rebuilds both lookup indexes in `mk_map_node` and copies N entries.
Taken: a persistent map carrier (hash array mapped trie) in cx-core-data, structural sharing on put,
every `MapNode` reader touched, the design stated in `runtime_representation.md` with its bounds
(the EV-* register unchanged: order of entries as written, equality order-independent, canonical
sorted), fixture first (the fold's answer unchanged; a timing case under the perf ratchet's floor);
one opus round on cx-core-data after bug batch B's branch merges (the same repository). Rejected:
deriving the new index from the old (still O(N) a put); documenting the fold as O(N²) with
`[?to-map]` as the linear spelling (the class stays, and "performant by default" is the standard the
owner set).

## SIDEC-1 — the `cx:attr-types` sidecar omits an entry when the image re-types to its own type (L147 = (a); #1585)

Measured: `[r a=[cast 100 :decimal] b=1.50 c=[* 2 1.5]]` renders `a="100" b="1.50" c="3.0"` with
`cx:attr-types="a=decimal b=decimal c=decimal"`; `100` re-reads as an int, so a type-name list can never
admit `decimal`, while `1.50` and `3.0` carry entries they do not need. Taken: one rule for every type —
an entry is written only when the image would not re-type to its own type under `try_autotype` — so
sidecars shrink and no canonical image moves; fixture first in the codec corpus; in bug batch B's
repository and branch. Rejected: keeping the list (decimals always carry an entry); adding `decimal`
to the list and rendering integral decimals with `.0` (canonical images and hashes move).
