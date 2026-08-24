# Ruling 2026-08-22 — the bug campaign to cut-readiness (BC-1..BC-4)

**Status:** RULED by the owner ("1a 2a 4a" plus the order correction on
item 3, 2026-08-22) against the campaign plan posed in the MSS/#917
master session. Recorded BEFORE the work per R6.1. The campaign runs in a
NEW Opus 5 session (owner direction) as the successor single session;
scope is everything from tree 871aa82a through fixing remaining and
discovered bugs, EXCEPTIONS #804 and #834 (owner-named, untouched).

## BC-1 (1a) — #923: the program reading of a multi-dot bare attr value is the STRING, parity with the data reading

`[server host=0.0.0.0]` reads identically in both readings: attr value =
the whole ws-delimited token; a token that is not a number is a STRING
('0.0.0.0'). The data reading already ships this (golden-pinned); the fix
is the PROGRAM lexer's attr-value context, which today tokenizes numbers
greedily and silently truncates to float 0.0 while spilling `.0.0` into
two phantom body items — the #917 silent-mangle class in attribute
position. The rejected alternative (refuse multi-dot bare attr values in
both readers) would break shipped data behavior and move pinned corpus
for no gain. The pin-data-doc-tree golden moves once more when this
lands — DR-8, cause stated (it currently documents the mangled image on
purpose).

## BC-2 (2a) — examples/htmx/serve.py is REWRITTEN IN CX on [?http-service]

The one #922 item PYE-5 left undisposed. It is a web-serving example and
CX ships a serve surface; the dogfood rule makes this exactly the file
that must be CX. 497 lines of Python retire; the example then
demonstrates BOTH htmx integration and the CX serve surface.

## BC-3 (order, owner-corrected) — #925 is the first MAJOR; #923 alone cuts ahead as prio:high-ASAP

The owner rejected sequencing argv (#926) first: map:/array: are
LANGUAGE FUNDAMENTALS and the #922 CX rewrites lean on them hardest.
Order: Phase 0 (record pair at 871aa82a + close #918-#921 on green +
PYE-6 + the small #923 fix, which jumps only because the standing
prio:high-ASAP policy says silent mangles do not wait days) → Phase 1
#925 map:/array: IN FULL per PYE-1 (26 functions, new normative spec,
stdlib/map.cx + stdlib/array.cx, conformance) → Phase 2 #926 argv
cutover per PYE-2/3 + #924 regex per PYE-4 → Phase 3 #922 waves 2-3 per
the issue worklist (+ discovered-bug triage throughout) → Phase 4
close-out (record pair + ORIEL + release_linux.sh's one real docker run
+ the owner review package incl. G3 on the new map/array spec).

## BC-4 (4a) — the v0.16.0 cut WAITS on this campaign

#925's phantom registrations are the advertised-but-dead pattern the
owner has refused to ship before, and #926 is a breaking CLI change —
cheaper before the first tagged release that carries it than after. The
cut proceeds only from the campaign's final green tree.
