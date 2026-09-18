# Decisions 2026-09-18 ~16:20Z — the ws defs' placement between the two http halves (1461-a); an atom the renderer writes must read back (1575-a)

Integrator (cx-private-6c) under the owner's delegation, and the owner on issue 1575 ("1a"), 2026-09-18 15:5xZ–16:2xZ. Measured
before the rows (head `dd5772670`): `http.md` §3.7 lists ten `ws-*` defs as one surface on a page covering both http halves, which
have been two modules since 1427-e — `cx-stdlib/http-client` (Ring 1) and `cx-platform/http` (Ring 2); six of the ten hold a
connection, two are pure decisions, one takes a server `[exchange]`; `sse-connect` / `sse-events`, whose shape §3.7's opening
sentence says the ws defs follow, live in the client module. `conformance/platform/http.cxd`'s cases 090…096 open
`[?lib 'cx-platform/http']` and call `$http:status` / `$http:header`, which are the client module's, against the file's own stated
convention; `http-090` reads `[$text [$http:header …]]` where the header's value is an attribute. `eval.v::is_valid_atom_name`
admits `[A-Za-z_][A-Za-z0-9_-]*`, yet an attribute built with `dtype: .atom_type` and the value `1.1` renders `:1.1`, which the
program reader refuses as a map value, reads as the STRING `':1.1'` as a bare term, and the data reader accepts.

| Id | Decision |
|---|---|
| **1461-a** | **(integrator, applying 1427-e and §3.7's opening sentence; issue 1461's §3.7 surface, Ring 1 + Ring 2)** `ws-accept` alone lives in `cx-platform/http` (the serving half: it takes a server `[exchange]`); the other nine `ws-*` defs live in `cx-stdlib/http-client`, the same module and pack as `sse-connect` / `sse-events`. No spec sentence moves. Because a live single-use iterator is a member of `IteratorKind` (`vcx/cx/ast.v`) with dispatch arms in `vcx/code/eval.v`, and the arm cannot compile apart from the walker, the branch that adds `ws-messages` makes exactly those Ring 0 edits — the enum member beside `iter_sse_events` and the three arms copied from the sse arm — named file:line in RESULTS.md, with the Ring 0 umbrella steps run (VERIFY-2). The socket-touching ws verbs gain their `net` rows in `security.md` §2.1 (direction 1 of `check-effect-alignment`). Probe corrections under #1573's class D: `http-090…096`'s `[?lib]` lines take the file's convention `[?lib 'cx-stdlib/http-client' :as http]`, and `http-090` reads the header's `@value`; asserted values unchanged, listed by id. Rejected: (b) all ten in the client module — a serving def in a Ring 1 pack; (c) all ten in the platform module — a `-d cx_no_pack_http_client` artifact carrying half of one surface. Issue 1461 closes on the passing run of the merge that completes all three of its surfaces (ws codec — merged as c3; §3.7 — c4; the `kind=stream` adapter). |
| **1575-a** | **(owner, letter (a); issue 1575, Ring 0 — the renderer and the atom constructor)** An atom whose name fails the atom-name production has no readable rendering, so it is never written: the constructor refuses it (as `$cast` already does) and the renderer refuses rather than emitting `:` + an unreadable name; and a bare `:1.1` program term REFUSES (a coded parse refusal) instead of silently becoming the string `':1.1'` — the silent half of canonical.md §2.6a's kind-flip class, read at the atom. Fixture first: `code.cxd` cases for the three readings (a map value, a bare term, an attribute value) all answering one refusal; a module test that a minted atom with a bad name refuses at construction. **What this row does not decide:** `soap.md` §2.1 / §4.3 spell the version as `:1.1`, which under this row cannot be written — the page's spelling is the owner's letter (the string `'1.1'` recommended; an atom-shaped name is the alternative), and `cx-stdlib/soap` keeps passing the version as the string its builder already admits until it arrives. Rejected: (b) widening the atom-name production for one module's spelling; (c) the page's spelling alone, which leaves the renderer able to mint the unreadable. |

## What this page does not decide

`soap.md` §6's sentence "a Security member this module neither builds nor reads is CXER6608" against soap-003/005's deliberate decoy
inside `wsse:Security` — an owner letter is open ((a) carry unknown members and correct the sentence, recommended); and the version
spelling above.
