# Owner decisions 2026-09-18 ~16:40Z — "recommendations accepted": twenty-one issues closed by the owner's word on the triage list (TRIAGE-1); the soap version is the string '1.1' (1575-b); unknown Security members are carried (1456-b)

Owner, 2026-09-18 16:3xZ, on the integrator's three open recommendations. Measured before the rows: 197 issues open at 16:30Z
(175 at 02:4xZ; the day filed 29 and closed 1); the triage list posted on the board at 13:08Z named 36 issues closable only by the
owner's word, in six groups, with the integrator recommending four of them (21 issues) and leaving two (15 issues: twelve long-horizon
design proposals, two investigations, one cx-gap) to the owner; `soap.md` §2.1 / §4.3 spell the SOAP version as the atom `:1.1`, which
1575-a makes unwritable; §6's sentence "a Security member this module neither builds nor reads is `CXER6608`" contradicts soap-003 and
soap-005, which plant a decoy inside `wsse:Security` and expect the scope refusal `CXER6612`.

| Id | Decision |
|---|---|
| **TRIAGE-1** | **(owner; the closes are the owner's word, not a run's)** Twenty-one issues close as *not planned* with the citation of the ruling that already disposed of each, nothing deleted, each reopenable at the release whose planning it names: (1) the nine archived for the record — 98 103 288 (ARCH-0916), 1277 1278 (INT-13 (b)), 1413 1414 1415 1416 (1085-e) — the ledger row is the record; (2) the five folded into the analytics campaign epic 800 (ruled 2026-08-13) — 751 786 797 798 799; (3) the six deferred to a later release by a ruling — 1207 (v0.19.0, owner 2026-09-07), 1325 (INT-3 addendum 2), 1540 (1540-a), 1042 (CO-18), 1060 (CO-19), 1386 (1386-b); (4) 1077 (a recorded NO-GO). **Not closed** (the owner's call, left open): the twelve long-horizon design proposals under the release label — 728 729 731 732 733 734 735 747 748 750 784 801 — the two investigations 517 521, and 1525. The count moves 197 → 176 by this row; the board says so as *closed by the owner's word*, never as *closed by a passing run*. |
| **1575-b** | **(owner, completing 1575-a; `soap.md` §2.1 and §4.3; `cx-stdlib/soap`)** The SOAP version is the STRING `'1.1'` / `'1.2'` — a version is a value, not a name. The two page sentences are edited to exactly that spelling (the only spec edit; the owner reads them); the corpus cases that assert the envelope's rendering (soap-020, soap-021, soap-022) are re-blessed BY ID to `version='1.1'` with the reason in the commit; `opts.version` is a string. Rejected: an atom-shaped name (`:v1-1`, `:soap11`) — a name for a number. Issue 1575 closes on the passing run of the merge carrying 1575-a's refusals and this spelling. |
| **1456-b** | **(owner, completing 1456-a; `soap.md` §6; `cx-stdlib/soap`)** An unknown member of `wsse:Security` — one this module neither builds nor reads — is CARRIED unchanged, and `mustUnderstand` decides refusal, as WS-Security itself says; `CXER6608` keeps its one meaning, two `Security` blocks for one role. §6's sentence is corrected to say so (the only spec edit; the owner reads it), and a case pins a carried unknown member beside soap-003/005 so the scope check stays the wrapping defence whatever the decoy looks like. Rejected: refusing unknown members — it masks the scope check and refuses every endpoint that carries an extension token (Workday's own headers among them). |

## Sequencing

1575-b and 1456-b are one small branch of Agent C after c4 (the `kind=stream` adapter). TRIAGE-1's closes were made at 16:3xZ.
