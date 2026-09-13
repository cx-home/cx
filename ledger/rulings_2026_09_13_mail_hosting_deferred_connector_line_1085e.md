# RULED: 1085-e — CX does not host mailboxes (now); CX owns protocols, not system connectors (owner, 2026-09-13)

Two owner decisions, recorded here as the decision of record for the mail epic (M) and the connector kit (#1430).
They narrow **1085-a** (`rulings_2026_09_11_email_world_class_agentic_1085.md`, "client AND server") and set the
line #1430 is built to. Tokens 1085-a…d are used; this is **1085-e**.

## Decision 1 — "Does CX need to be an IMAP server — to host mailboxes?" → "No, not now, we'll re-evaluate as needed."

| | 1085-a said | 1085-e says |
|---|---|---|
| SMTP / IMAP as protocol modules | client AND server | **client now** (`smtp.cx` submit/send, `imap.cx` connect/select/fetch/search/move/idle/sync, `email.cx` parse/build/reply/forward/DSN — landed, complete as protocol modules); the server halves stay as landed (`smtp:serve`/`listen`, `imap:serve`/`server-step`) — the IMAP server core has no store behind it and is **dormant, not broken** |
| the mailbox as an XAP feature (#1413, #1416) | in v0.18 (M2) | **deferred**: #1413 and #1416 leave the v0.18 release, stay OPEN at `prio:low`; their spec (`spec/03-approved/std-lib/mailbox.md` on `impl/cx-A-1413` @ `ac805a6ad`, 3106 lines, owner-approved 2026-09-12) stays unmerged — not merged, not deleted; nothing on `release/0.18` references it (no `mailbox.md`, no `mailbox:apply`, no `CXER61xx`) |
| the interop step (#1417) | our server + our client, plus the provider rows | the **provider rows stand and are the priority** (Gmail / Microsoft 365 / Fastmail, our client, OAUTHBEARER over the RFC 8628 device grant `oidc` already carries); the "boot our IMAP server and drive fetch/IDLE/flags against it" half has no store behind it — its shape is the owner's letter on #1417 |

**Trigger to re-evaluate:** *a consumer that needs CX to host mailboxes.* When it appears, #1413 and #1416 resume from the approved spec.

**Why:** 1085-a answered "what would a world-class mail system be"; the owner's question was "what does the consumer need". The consumer needs CX as the client of the mail providers it already has, not a second mailbox estate beside them.

## Decision 2 — "PB owns the creation of specific connectors it needs, not CX. CX provides the unified foundation for creating thousands of connectors, not the actual connectors. CX would own a specific protocol or method of connection — SOAP, GraphQL, HTTP, SFTP — but likely not a specific system connector except as an example or something CX needs internally."

Recorded as the **connector-kit rule** for #1430 (#728 component 2):

- CX owns the **protocol and connection-method modules** (HTTP, SOAP, GraphQL, SFTP, SMTP/IMAP client, …) and the **kit** — CK-9 pagination vocabulary, the engine (paginate / retry with the spec'd backoff / rate-limit loops driven by a connector's `[gateway]` data), the `cx-connector` library (CK-5), OpenAPI ingestion into a connector feature skeleton.
- CX ships **one example connector end to end** (#1430 item 4, against an in-tree mock endpoint) **plus anything CX needs internally** — and no more. #1430 item 6 ("the shipped connectors") narrows to exactly that.
- **System connectors** (a CRM, a ticketing API, a mail provider's proprietary API, a directory graph) are the **consumer's**, built on CX's protocol modules and the kit. CX names none of them as shipped.
- #1430's order line drops #1413 (deferred above).

**Why:** the kit's value is in making thousands of connectors cheap to write correctly; a connector CX shipped would be one the consumer still has to own operationally. The protocol modules are where CX's correctness bar (attack corpora, refusals, effects rows) pays back across every connector at once.

## Consequences filed with this record

- #1413, #1416: comment linking this record; `prio:high` → `prio:low`; OPEN; the trigger stated verbatim.
- #1417: scope note — provider rows stand; the server-half choice goes to the owner as a letter.
- #1430: order line and item 6 amended per decision 2.
- #1354: the 09-13 handoff's *Scope left* loses (4) M2 #1413 code; the connector kit stays, spec first, item 6 narrowed.

## Addendum — owner letters, 2026-09-13 (later the same day)

| Letter | Decision |
|---|---|
| **1(b)** | #1417's *boot our IMAP server and drive fetch/IDLE/flags against it* half **leaves the v0.18 scope**; #1417 is the provider rows only (Gmail / Microsoft 365 / Fastmail, our client, OAUTHBEARER over the RFC 8628 device grant). The dormant server core is graded again on the 1085-e trigger. |
| **2(a)** | #728 component 3 (incremental sync — the generic cursor/watermark contract, polling-diff baseline, log-based capture per engine) is filed as its own issue, sequenced after #1430; provider delta mechanisms stay the consumer's. |
| **3(b)** | #1430 keeps its order (after INT-2 and #1427): #1427 moves the tree the connector spec must be placed in (OL-15), so the spec is written once, in the new tree. |
