# Owner letter 2026-09-14 ~16:05Z — every kind ingests its declarative description at build time (RULED: 1430-g)

Owner, to "where is and is not code required to onboard a connector?" — letter **(a)**: *"absolutely need to
bring down the cost of per connection enablement and handle what we can in cx to minimize [the adopter's] cost."*

## What was measured first (head `1588c8d7b`)

`http` has an ingest: §6.3 turns an OpenAPI 3.1 document into a package skeleton at build time (CK-4), pure and
fixture-graded (connector-120 and its family, 134/134). Every other kind of 1430-c/1430-e had none: §3.9.3's
"discovery" declaration is the RUNTIME half (`describe`, validation against the live schema, never a grammar
change), so a `soap`, `graphql` or `db` connector's declaration would have been typed by hand from the vendor's
document — the divergence 1430-d was written against.

| Id | Decision |
|---|---|
| **1430-g** | **(owner, letter (a))** §3.9.7's template gains **step 9, the ingest**: every kind's section names the kind's declarative description and specifies the build-time, pure transform from it to a connector package skeleton, under §6.3's rules exactly — fixture in, canonical `[package]` out; what the description states becomes a declaration, what it does not state becomes an authoring TODO and never a guess (idempotency is always a TODO, I-8/CK-4b); the §6.3 refusals for a document over the §8 bounds, not accepted, or with an unnameable operation; re-ingest is the version loop and there is no runtime read (CK-4). A kind whose description describes no operations (`sftp`, `ftp`: a listing) says so and states what an author writes by hand. The descriptions: a WSDL for `soap`, an SDL or introspection result for `graphql`, an information-schema read for `db`, an AsyncAPI document for `webhook` and `stream`. §6.3 is `http`'s instance of the step. Onboarding ONE connector of ANY kind therefore costs a declaration (ingested where the kind has a description), the two three-line defs of §13.2 and a deployment binding — never protocol or engine code, which is the kit's, once per kind. The reference examples #1467 (orders-db), #1470 (legacy-soap), #1471 (graphql-catalog) and #1472 (inbound-webhook) each start from their kind's ingest and teach it. |

## Why

The kit's promise (1430-d) is that a kind costs one adapter and a connector costs a declaration. Without an ingest
per kind the second half held only for `http`; the per-connection cost of every other kind was a person reading a
vendor document and typing what it says — the cost the owner wants inside CX.
