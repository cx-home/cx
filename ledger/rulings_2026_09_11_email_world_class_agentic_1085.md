# RULED: 1085-a — v0.18 carries a WORLD-CLASS, AGENT-READY email system, client AND server: SMTP + IMAP as protocol modules with both halves, the mailbox as an XAP feature whose intents are the agent surface, delivery on the saga substrate

**Owner, 2026-09-11 ~04:15Z, direct**, on Fable's letters (worker A). Letter **(a)** chosen — the
protocol PAIR with client and server halves plus the four server-side pieces filed as Lane 1
issues — with the owner's own requirement added verbatim: *"this need to be world class and
agentic ready — can agents be plugged in to help manage email on server and client."*

Measured before the letters: no SMTP/IMAP code, spec or directive anywhere in the tree
(`ls stdlib/ x/ vcx/code/ vcx/platform/` for `smtp|imap|mail` → `email.cx`/`stdlib_email.v`
only; `git log -S'smtp-client'` → the `email.md` exclusion sentence only, unchanged since
v0.8.0); #1085 filed 2026-08-28 with zero comments; `net:resolve` answers addresses only
(`net.md` §3.1) — no MX/TXT records. What DOES exist and is reused: `cx-stdlib/email` (RFC 5322 +
MIME + DSN parse/build), `net` TCP/TLS dial AND listen with mTLS/ALPN, `store` (the S6 seam),
`flow` (sagas, retries, compensation, `[on kind=…]` bindings), `crypto` (RSA/Ed25519 sign,
HMAC, the JOSE stack), `session`/`authz` (principals, the PEP), and the XAP agent-tool
projection of feature verbs (RULED 1352-a…f).

## What "agent-ready" MEANS here — the design principle, so it is not an afterthought

Email is built as an **XAP feature** (`mail`), not as a daemon with a plugin API. Then every
agent property the platform already guarantees is inherited, not invented:

1. **Agent parity is structural** (`xap.md` §2.5): every mailbox operation is an INTENT —
   `compose`, `send`, `reply`, `forward`, `triage`, `label`, `archive`, `snooze`,
   `schedule-send`, `unsubscribe`, `search`, `rule-create` — so an agent and a human call the
   same verbs, and the agent-tool projection (1352) exposes them as tools with their own
   grammar (`xap_grammar_composition.md` §6.1) with no second API to keep in step.
2. **The PEP gates every intent** (`xap.md` §4.2): an agent's authority is an `authz` grant —
   "may draft, may not send", "may label, may not delete", "may send to internal domains
   only" — and a **send that needs a human is an approval act** on the same flow, never a
   flag on a config. Attribution is the journal's (`actor` = the agent's principal, `authority`
   = the delegation), so "which agent sent what, under whose grant" is a fold, not a log grep.
3. **Server-side agents plug in at delivery**: inbound mail is an intent on a committed
   stream (`mail/received`), so a `flow` binding `[on kind=intent intent="mail/received" …]`
   lets an agent classify, route, draft a reply, or open a ticket — with the saga's
   retries and compensation, and with `OneTimeUse`-style dedup by content address (WF-31).
   Spam/priority classification in v1 is exactly such a hook, not a built-in model.
4. **Client-side agents** get the same intents over the XAP bridge with a session (#1292 is
   therefore a dependency), plus the §21.1 agent-initiative spectrum (suggest → draft →
   act-with-approval → act) as the mailbox's default policy ladder.
5. **Everything is a value**: a message is `email`'s CX element, a mailbox is a `store`
   document set, a thread is a fold — agents query with CXPath, not with a vendor SDK.

## The work, filed as Lane 1 issues (titles; numbers on #1354)

| # | Piece | Owner module |
|---|---|---|
| 1 | **#1085 re-scoped** — `cx-stdlib/smtp` (client: submit over implicit TLS/STARTTLS, AUTH PLAIN/LOGIN/OAUTHBEARER (the oidc stack), PIPELINING, SIZE, 8BITMIME, SMTPUTF8, DSN; **server core**: ESMTP receive state machine, TLS-required policy, size/rate bounds, the same reader-bounds discipline as SAML) and `cx-stdlib/imap` (client: IMAP4rev2 RFC 9051, IDLE, SASL; **server core**: mailbox/flags/UID/UIDVALIDITY/MODSEQ semantics over a mailbox store). Fixture-first; graded by a two-process lane (our server + our client) exactly as S2 graded the IdP | new |
| 2 | Mailbox store — `store`-backed maildir-style document model with IMAP semantics, threading (`email.md` §5), search index | new, on the S6 store seam |
| 3 | Delivery queue + relay on `flow` — outbound spool as a saga: MX retry schedule, DSN generation (email.md already builds DSN), bounce handling, rate limits; inbound `mail/received` intent emission | `flow` |
| 4 | Authentication & deliverability — DKIM sign/verify, SPF, DMARC, ARC in a `cx-stdlib/dkim` (or `email` §8 extension); **`net:resolve` grows record types** (MX, TXT, A/AAAA — RFC 1035 wire) since it answers addresses only today; MTA-STS (RFC 8461) policy fetch | `crypto`/`email`/`net` |
| 5 | The `mail` XAP feature — the agentic surface above: intents, the authz policy ladder, approval acts, the `mail/received` hook, the agent-tool projection, journaled attribution; a web + terminal client face via `cx-x/ux` in ORIEL's pattern | `xap`/`x` |
| 6 | Mail interop lane + matrix — per-commit two-process lane; release-verify rows against real providers (Gmail, Microsoft 365, Fastmail via OAUTHBEARER — which needs the OAuth **device-code** flow, RFC 8628, for an agent with no browser: filed on #1409's list as SCHEDULED) with a compatibility matrix in the Operations guide, NOT YET VERIFIED until measured — the S2 discipline | tooling |

**Lane 1 order becomes: #1085 (+ pieces 2–6) → #1366 → #1096 → #1086 → #1087 → #1088.** The
owner's earlier 1097-b order put #1366/#1096 first; the owner has now named email a must, so
it moves ahead. The owner may re-order on #1354.

**World-class bar, stated so it can be measured**: RFC 9051 IMAP4rev2 not IMAP4rev1; SMTPUTF8;
TLS 1.2+ required by default with a loud opt-out; DKIM-signed outbound by default; every
protocol module fixture-first with an attack corpus (header injection, CRLF smuggling,
oversized lines, MIME bombs) before the parser — the SAML/zip precedent; real-provider rows in
the matrix. Nothing here is deferred; the device-code flow is SCHEDULED on the oidc list.

Rule each module's design immediately before its steward launches (the standing cadence);
this record fixes SCOPE and the agent-readiness principle, not verb signatures. No work
starts while the spend limit holds.
