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
