# RULED: 1292-a — sessions on the served bridge: the request's session is the attribution; a bound runtime served without a session configuration refuses at boot; no configured stand-in principal

Fable, 2026-09-12 ~02:20Z, under the owner's delegation of 2026-09-09 05:50 ET. The owner may
override on #1354. Premises checked at `974cfe597`: `xap.md` §3.1.1 says an anonymous emit on a
journal-bound runtime refuses (right) and "sessions forthcoming"; S6 (#1395) landed store-backed
sessions with `session:pending-put/take`; S7 (#1394) mounts `sso:login`/`callback`/`acs` and
adds `session:attach-oidc`; nothing yet attributes a bridge POST.

**(a) — ruled (the issue's first ask, xap.md §3.1.1 / R-A3).** `[$xap:serve]` gains a
`session:` configuration (session's S6 seam: the store URL or handle, `pending-ttl`, `replay`).
The bridge resolves every request's session — the session cookie set by S7's `sso:callback`/`acs`
routes, or a bearer the session module minted for a non-browser client — and every intent over
the bridge is attributed as that session's **principal** (actor) with the session's grants as
the **authority basis**; the journal entry is the same one an in-process `[$xap:emit … {actor:}]`
writes. A request with no session on a bound runtime answers **401** with the login route
(never 403 `CXER4609`: the append is not attempted). A **bound runtime served without
`session:` refuses at boot** — new row in the xap band, `E_XAP_SERVE_UNATTRIBUTED` — so the
failure is at start, not on the first click (the issue's third ask, adopted as the guard, not
the answer). **Agent processes are principals too**: an agent authenticates as itself (XSP-AUTH
host-auth with its DID, or a bearer session minted for its service identity) and its acts fold
under `agent:<id>` — "what did the agent do last Tuesday" is a fold over one actor, which is the
second commenter's case. The §22.1 localhost dev floor stays for UNBOUND runtimes only; on a
bound runtime it no longer attributes anything.

**(b) a `serve` option naming one configured principal for all bridge posts — refused.** A
durable journal that records a principal nobody proved is the forgery the attribution rule
exists to refuse; "journaled honestly as that principal" is a contradiction once the entry is
read by anyone but its author. A dev deployment that wants a fixed identity mints a real
session for it (a bearer via S6) and gets exactly that, provably. **(c) sessions later,
403 now — refused:** that is today, and it is the defect.

**Order:** after S7 (#1394) merges — its routes set the cookie this decision reads. Spec text,
delegated G3 (flagged): `xap.md` §3.1.1 (sessions here, not forthcoming), §22.1 (the floor is
unbound-only), the serve options table, §8 the new row; `session.md` §3.x `resolve` (cookie or
bearer → the session record) if S7 has not added it; `governance.md` §9.6 the row. Graders: the
xap serve corpus (401 without a session; boot refusal without `session:`; an attributed intent
folds under the session's principal) and the S2/S7 interop step's two-process row (login → post
an intent → the journal names the principal).
