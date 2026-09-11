# RULED: 1085-b — the ten open rulings in the `smtp.md` / `imap.md` working drafts, plus `cx-stdlib/sasl` as a shared module

**Fable, 2026-09-11 ~05:2xZ, under the owner's delegation of 2026-09-09 05:50 ET** (the owner
may override on #1354). Letters drafted by the M1 spec steward in `spec/02-working/smtp.md`
and `spec/02-working/imap.md` at `d15790dba` (`impl/cx-F-mail`), each with what it DELETES;
premises measured by the drafter and spot-checked here: no SASL anywhere in `spec/03-approved/`
(grep `SASL|OAUTHBEARER|XOAUTH2` → 0); Gmail and Microsoft 365 advertise `IMAP4rev1` + extensions,
Fastmail advertises `IMAP4rev2`; bands `CXER5700–5999` free repo-wide.

| Ruling | Letter | One line, with the deletion accepted |
|---|---|---|
| **R-SMTP-1** where SASL lives | **(a)** a shared **`cx-stdlib/sasl`** module | one mechanism registry (PLAIN, LOGIN, OAUTHBEARER RFC 7628, XOAUTH2), one gs2/base64 framing, one `[sasl-auth]` credential value; DELETES the per-module `[smtp-auth]`/`[imap-auth]` elements — both specs collapse onto `[sasl-auth]` and keep only per-protocol mechanism-preference rules. Band **`CXER5900–5999`** (`E_SASL_*`), proposed, scan free. The `saml`/`oidc`-share-`crypto` precedent: a one-line-wrong-forever framing gets exactly one implementation and one attack corpus |
| **R-SMTP-2** per-`RCPT` verdict | **(a)** optional `opts.rcpt-handler` | a public MX must refuse an unknown recipient IN the dialogue (`550 5.1.1`) — the only refusal that generates no backscatter; additive, the end-of-`DATA` handler unchanged |
| **R-SMTP-3** `CHUNKING`/`BDAT` | **(a)** server accepts, client never sends | Exchange prefers `BDAT` when offered; client-side `BDAT` is surface with no reachable benefit. Revisit trigger recorded: a line > 998 octets that must be sent, or a smarthost refusing `DATA` |
| **R-SMTP-4** UTF-8 vs no `SMTPUTF8` | **(a)** refuse `CXER5712` before sending | the module NEVER modifies a message (§6.4; DKIM survives); the agent surface gets an actionable fact |
| **R-SMTP-5** client URL schemes | **(a)** `smtp://`/`smtps://` for the client, `tcp://`/`tls://` for the bind | the `http.md` split: a client URL names a service, a bind URL names a socket |
| **R-IMAP-1** rev1-only servers | **(a)** rev2 as the single vocabulary + a thin ENUMERATED rev1 wire shim | (b) deletes Gmail and M365 from the matrix — the evidence the world-class bar is measured by. Every shim arm (`LSUB`, rev1 `SEARCH`, modified UTF-7 names, `RECENT`/`\Recent`/`[UNSEEN]` tolerance, `STATUS` for `LIST-STATUS`) is a NAMED fixture so "thin" is measured; `CXER5810` when a rev2-mandatory capability has no rev1 equivalent offered (`MOVE`, `UIDPLUS` — all three providers have both). Revisit trigger: every matrix row advertising rev2 |
| **R-IMAP-2** server handler shape | **(b)** a store-OPERATION contract (`[op kind=…] → value`), the module renders every wire byte | the 1085-a split made concrete: #1413's store knows no IMAP syntax; ONE renderer is what makes #1417's lane meaningful. (c)'s escape hatch is additive later if ever needed |
| **R-IMAP-3** `\Recent` | **(a)** tolerate and discard | never in our value model; `status :unseen` / `search [not [flag "\\Seen"]]` / `sync` are the portable answers |
| **R-IMAP-4** client UID-only | **(a)** yes | stable addresses across runs are what an agent needs; the SERVER speaks both because the protocol requires it |
| **R-IMAP-5** large body sections | **(a)** in memory, bounded `max-fetch-bytes` (64 MiB), partial fetch as the escape | keeps every verb value-in/value-out (§7's first agent obligation). Revisit trigger: a mail-archive exporter — #1414's tooling |

## Consequences for the drafts (the steward applies them; each block becomes decided text citing `RULED: 1085-b`)

1. New `spec/02-working/sasl.md` — the mechanism registry, `[sasl-auth]` (mechanism, authcid,
   authzid, secret or bearer token + host/port for OAUTHBEARER's gs2 header), `initial-response`
   / `step` pure verbs so the corpus replays offline, the `E_SASL_*` band, an attack corpus
   (malformed gs2, NUL placement in PLAIN, base64 padding, mechanism downgrade).
2. `smtp.md` §3.3 and `imap.md` §3.2 reference `sasl.md` and keep only preference/downgrade
   policy; `[smtp-auth]`/`[imap-auth]` removed everywhere.
3. `smtp.md` §3.6 gains `opts.rcpt-handler`; §4.4 states server-accepts/client-never-sends;
   §4.5 the `CXER5712` refusal; §6.1 the scheme split. `imap.md` §5.6 becomes the shim
   specification with the enumerated arms + fixture names; §3.6 the `[op]` contract; §5.5
   tolerate-and-discard; §2.3 UID-only; §3.4 the bound.
4. `imap.md` §12 "Open rulings, collected" becomes "Rulings, collected" pointing here.

## Graduation

The owner's standing rule makes G3 owner-only; the 2026-09-09 delegation hands it to Fable with
the obligation to flag it. **Path:** the steward applies 1085-b; Fable reads the three documents
end to end; if they meet the 1085-a bar they move to `spec/03-approved/std-lib/` with
`status=current` in ONE spec-only commit whose pass note on #1354 says "delegated G3 — the
owner may send them back". Implementation (M1) starts only after that commit; fixture corpus
(attack corpus first) before any V.

---

# 1085-c — implementation rulings

Recorded 2026-09-11 by Fable under the owner's delegation of 2026-09-09, posted on #1085;
the owner may override on #1354. These are the five STOP items the `cx-stdlib/smtp`
implementation lane raised against the approved `smtp.md`, ruled so the steward could land
option (a) — continue to green — rather than pause. Each lands as spec text in the smtp
implementation commit under `RULED: 1085-a`.

| Id | The STOP item | Ruled |
|---|---|---|
| **1085-c-1** server STARTTLS | no server-role TLS handshake over an accepted socket exists in the V fork (`net` dials TLS and binds TLS; there is no `tls-accept-wrap`) | land the HONEST posture: a `tcp://` bind carrying `opts.tls` is **refused at bind time** `CXER5706` naming the gap, and a `tcp://` bind advertises no `STARTTLS` at all — never advertise an upgrade that cannot be performed, because §6.2 says a failed upgrade never falls back to cleartext and the client has already committed by then. `smtp.md` §3.6 says so and cites **#1421** (`net:tls-accept-wrap`, V-fork change + pin bump, prio:high). `tls://` implicit TLS, and BOTH client paths (STARTTLS and implicit), are unaffected and fully implemented |
| **1085-c-2** the audit channel | `smtp.md` §6.2 point 2 cites "`security.md` §2's audit channel"; §2 is the capability CATEGORY table and names no such channel, and no audit sink exists anywhere in the tree | the `:none`/`:opportunistic` startup event rides the **effects-trace witness channel under an `audit:` prefix** (`effects_trace_note`) — a prefix that is deliberately not a capability name, so it can never be read as a charge against the capability mirror `check-effect-alignment` folds over. `smtp.md` §6.2 point 2 (and `imap.md` §6.2 when it lands) names that channel instead of the phantom. The audit sink proper — durable, structured, queryable, shareable with the `authz` PEP and XAP's approval acts — is **#1422**, prio:low |
| **1085-c-3** server credential verification | the server half had no way to verify an `AUTH` credential: no store, and no auth handler in §3.6 | **`[credential authcid= secret=]` children on `[smtp-policy]`** — a VALUE, not a callback, so §7.1's value-in/value-out holds and an authenticating session replays in a fixture with no store and no socket. §3.6's opts table gains the row. **A policy declaring no `[credential]` authenticates nobody**: `AUTH` is not advertised and is answered `535 5.7.8` if attempted. Store-backed verification (an account record, `crypto:password-hash`, per-account policy) is **#1413**/**#1416**'s and is named as such in the spec |
| **1085-c-4** client AUTH-downgrade rows | §9.1 asks for the CLIENT's mechanism refusal and also states every case in it is `server-step`/`parse-reply`; both cannot hold, because client mechanism selection has no pure verb in §3.4 | accepted as the steward did it: the rows are pinned through the exact composition §3.3 names — `parse-ehlo` → the `[ext name="AUTH" [mech …]]` children → `[$sasl:mechanisms]` — asserting `sasl`'s `CXER5901` there, with the smtp-side wrapper (`CXER5709` carrying it as `[cause]`) pinned on the SERVER path offline and on the CLIENT path in the real-socket test. Recorded in the corpus header, not silently dropped |
| **1085-c-5** the six peer-needing codes | `5700`/`5704`/`5705`/`5707`/`5708`/`5714` cannot be raised without a peer, and `cxer-registry-gate` wants an `out-err` case per code | accepted — they ride `vcx/tests/smtp_real_socket_test.v`, which is §9.3's own split. Each also gets a `parse-reply`/`server-step` arm **where one is expressible** (a scripted `421`/`5xx` reply through `parse-reply` reaches 5704; a stream truncated mid-transaction through `server-step` reaches 5705's server-side twin), and where none is, the registry row cites the V test |

Option (a) — the steward continues to green — was taken; nothing here reduces the spec's
demands, and #1421 and #1422 carry the two real gaps with their own triggers.

---

# 1085-d — `[delivery]` carries BOTH the parsed `[message …]` and the raw `[body <bytes>]`

Recorded 2026-09-11 by Fable under the owner's delegation of 2026-09-09, posted on #1085;
the owner may override on #1354. Raised by the `cx-stdlib/smtp` implementation lane, which
had shipped only `[body]`. Lands as spec text and one corpus case in the smtp implementation
commit under `RULED: 1085-a`.

| The question | Ruled |
|---|---|
| The delivery handed to a `serve` handler: the parsed `[message …]` element, the raw `[body <bytes>]`, or both? | **both**, and the parse happens **once, in the server core** |

**Why neither alone.** `smtp.md` §2.3 promises the handler `[$email:parse]`'s element — "there
is no `smtp` message shape", one message model, `email`'s. A delivery carrying only `[body]`
leaves that promise unimplemented and pushes a parse into every handler, which is a second
place where *what this message says* is decided: exactly the two-readings disagreement §2.1
exists to prevent, and the same argument that gives the module ONE reply serializer and ONE
reply parser. A delivery carrying only `[message]` fails the other half: §6.4's
no-modification invariant is stated over **octets** ("the only transformation is dot-unstuffing
and the single prepended `Received:`"), §9.2 grades it as a byte equality, and both #1414's
relay and #1415's DKIM verifier must forward precisely what arrived — re-emitting a signed
message from its parse breaks the signature, which is the whole reason §6.4 exists.

These are **not** the "raw plus parsed pair" §2.3 refuses. That sentence refuses a second
*message model*; there is still exactly one. This is one message plus the bytes it arrived as.

**Where the parse happens.** In the pure state machine (`smtp_finish_message`), not in `serve`:
the corpus reaches the same `[message]` child through `server-step` with no socket, no port and
no capability, which is what makes §2.3's promise gradable offline rather than only on #1417's
two-process lane. Ring 1 reaches `email-parse` through the ring-2 registry seam, the seam
`sched` already uses for `journal-append`.

**A message `email:parse` rejects carries no `[message]` child** — not a synthesized one and not
an `[err]` one. The octets are still exact and the handler can still refuse; inventing a message
shape for input the parser rejected would be the one "helpful" transformation §6.4 forbids.

Normative in `smtp.md` §2.2 (the `[delivery …]` line, which had also omitted `[received]`), §2.3
and §3.6. Graded by `smtp-123`.

Also recorded from the same lane, as traps rather than rulings: an **inline**
`[out-err cx-err:CXERnnnn]` is not read by the fixture parser — only the heredoc form
`[out-err [#…#]]` grades, and ten smtp rows had silently run as `out-text` cases against an
empty expectation; §5.6's `Received:` is now PREPENDED into the delivered octets rather than
riding a sidecar child alone, without which §9.2's invariant was unmeasurable; §4.3 client
pipelining and §4.1's DSN drop-and-report were missing and were implemented.
