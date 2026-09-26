# Owner decisions 2026-09-26 — the four designs of Letters 26–29: the connector kit (KIT-1…KIT-6), cross-company (XCO-1…XCO-5), the minimal keystore (SEC-1), the host's four choices (HOST-1…HOST-4)

**Status: RULED (owner, 2026-09-26, in session, on the Letters L26–L29 posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 09:3xZ).**

## The owner's word, verbatim

"recommendations accepted" — answering Letters L26.1–L26.6, L27.1–L27.5, L28 and L29.1–L29.4, each
of which offered lettered options with one recommendation; every recommendation was (a). The
letters themselves were the owner's redirection of L21 ("this design is important — what is the
best design long term?"), L23 ("do not defer — what's the best long term for cx?"), L24 ("can we
design and implement a minimal key store that can be expanded later without impact?") and L25
("this is really important and must be ruled individually"). The full argument for each option is
the board comment; this page records what was ruled.

## KIT-1 — a reference connector declares one verb per kit mechanism it proves

`reference/connectors/crm-rest` keeps its six verbs (list-contacts: the page walk; create-contact:
the idempotent write; list-orders; list-events; list-audit: the offset walk; probe-flaky: retry and
the circuit), and its README §2.1 names the mechanism beside each verb. Rejected: four verbs as
designed; two reference connectors.

## KIT-2 — a tool is named by the composition-qualified verb

The `x/tools` projection names a feature verb's tool `feature/verb` — the same string the do-form
uses (`connector.md` §12.3) — and a lone feature export qualifies with its own feature name;
`x/tools.md`'s naming sentence is tightened to say so and the crm-rest scenario's expected output
is re-blessed, fixture first. Rejected: bare names disambiguated by metadata; `verb@feature`.

## KIT-3 — the fold example runs

The built readout call, `[$journal:fold <handle> <fn> <init> <stream> {valid-at: <t>}]`, is the
correct one; `connector.md` §13.2's `fold-value` example and cx-platform-xap's
`reference/acme/acme.cx` readout are corrected to it, fixture-backed (CXF-8: a spec example no
fixture backs). Rejected: a `fold-value` overload taking a handle.

## KIT-4 — a reference scenario runs under the real XAP host

The reference scenario is driven by the deployment host that will run the connector: the host
boots the connector's deployment binding, the scenario delivers through the host's ingress,
`expected.txt` stays the fixture, and `scenario/drive.cx` retires when it does — after SEC-1 (the
binding's credentials then resolve by handle through the host). Rejected: the stand-in driver as
the permanent one.

## KIT-5 — the binding's values are live

`attempts=` is recorded, and `delay=`, `[timeout]` and `[circuit-breaker]` are read from the
deployment binding rather than hard-coded: defects fixed fixture-first under FIX-1
(cx-platform-connector#2's three items), not design.

## KIT-6 — the design pages tell the truth

`reference/connectors/README.md` §2.1/§4 are rewritten to the ruled shape (this page's KIT rows),
`deployment-topology.md` §2.1's binding block becomes a citation of `connector.md` §4.6 (as 1466-a
already rules), and the handle spelling is `handle:` (SEC-1 below).

## XCO-1 — a did:web ack is verified under the key the session resolved at attach

The `[peer …]` resolver row the environment presents carries the responder key material the
XSP-AUTH attach already resolved (`kid=`, the key, the DID document's hash, `resolved-at=`); flow's
pure ack law verifies a did:web ack under that key exactly as it verifies did:key; the recorded
`step-ack` transition carries `kid=` and the document hash so a replay verifies the same bytes
under the same key whatever the domain publishes later. Flow dials nothing (S-42, S-43 hold); a
rotation ends the session and an ack under a retired key finds no row (CXER4963). Rejected: flow
calling `did-web resolve` at verification; did:key only.

## XCO-2 — a tier-2 ack is a co-signature set over one claim

The `step-ack` claim gains a `[signatures [signature by= kid= …]…]` set over ONE canonical claim
(the identity model's shape, no new envelope); the initiator's flow states what suffices —
`[ack tier=:t2 by=(…) m=N]` on the `:peer` step — and the pure law counts verified co-signers under
the key rows the environment presents; `:t1` stays one signature by the responder. Rejected: the
counterparty's published policy deciding M-of-N.

## XCO-3 — the counterparty half lives in the XAP host

The host receives a `[delegated-intent …]` over its responder session (an XSP message kind under
the `flow` token; `xsp.md` §6 gains the row), refuses it unless the session principal equals
`from=`, admits it at its own PEP as the initiator's authority, performs it in its own journal on
the `intent=` stream its `[on intent …]` row names, and answers a `:t1` `step-ack` signed by the
host's identity key — held by handle through SEC-1 (until then, the seed mechanism the store uses).
A late ack rides the same session or `/.cx/flow/act`. Rejected: the counterparty half in
`cx flow serve`.

## XCO-4 — the host is the initiator's session holder too

The host opens the outbound XSP-AUTH session for a `:peer` step's `to=` (did:web resolved through
`cx-platform/did-web` with the deployment's `trust-domains`), presents the `[peer]` row to its
embedded runner, and the runner emits the delegated intent through it; `cx flow run` and
`cx flow serve` stay session-less (CXER4962).

## XCO-5 — a host may be did:web

With XCO-1's row and SEC-1's handle-held signing key, the identity model's "offline-resolvable in
v1" restriction on a host's own identity lifts: a host may be did:web, its domain publishing the
document. Landed in the same wave as XCO-1…XCO-4.

## SEC-1 — the minimal keystore that expands without impact

Frozen now and never moved: (1) the handle grammar `handle:<provider>/<path>`; (2) ONE resolve
seam in `cx-platform/secrets` (ring 1, platform group; registry row first), internal, impure,
returning a `secret`-typed value alive for one operation at the effect point; (3) the PEP — every
resolution is an `authz check` on `secrets:resolve <handle>` for the consumer module, the third
call site of the one decision function; (4) the audit record `[secret-resolved handle= consumer=
at=]`, never the value; (5) the refusals in the registered band CXER7000–7099: 7000 handle
malformed, 7001 not granted, 7002 provider unbound, 7003 value absent, 7004 a provider that would
export a value, 7005 an `env` provider in a served profile; (6) rotation inside the provider
(`sso.md` §3.4's window), a handle resolving to the active value. The minimal implementation:
providers are deployment rows `[secrets [provider name= kind= …]]` beside `[journal]` and `[store]`;
two kinds now — `kind=sealed` (values encrypted under a master key only the client holds) and
`kind=env` (development profile only) — a `cx secrets` verb set (`put`, `rotate`, `list`; a value
is never printed), and `connector.md` §4.2 step 3 as the first consumer. Every later rung of the
custody ladder (OS keychain, KMS, tenant-scoped, vault/HSM/split custody) is a provider row;
handles, consumers, the PEP and the audit record never change. Spec first (the owner reads), then
one code branch; before XCO's wave and before the transports' code phases that need credentials.
Rejected: the OS keychain as the first provider; `env` only.

## HOST-1 — a projected command def's parameters are the intent list verbatim

`$store` is an environment-bound name the loader closes over ("the environment's store binding",
CK-3), reached the way a connector reaches `$host`; no parameter name is reserved and the
projection's parameter list is the verb's `[intent]` list verbatim. Found beside it and fixed in
the same branch under FIX-1: `f--child-opts` carries `store` but not `authz`, so a map child's
first act reached admission without a decision. Rejected: the trailing named `$store` parameter as
built; a journaled store reference.

## HOST-2 — one code for the host's internal boot faults

CXER4965 stays the caller-fault code for every binding-row and delivery-shape refusal (flow.md §8's
definition); the host's internal boot faults (runtime vanished, no journal handle, the driver
failing to load, register or boot) take ONE new code, `E_XAP_FLOW_HOST_FAULT`, allocated from xap's
reserved room 4907–4919 — the band decision governance.md §9.6 asks for, taken with knowledge of
what it is for. Rejected: one code for both facts; a code per refusal kind.

## HOST-3 — an act on an auth-enabled host is the session's

`/.cx/flow/act` stays the one act ingress on both faces; on an auth-enabled host an act's `actor=`
MUST be the session principal or a principal its chain delegates to, refused otherwise (xap.md's
"a claimed actor ≠ session principal refuses", applied); `cx flow serve` has no session and keeps
trusting the act body. Rejected: trusting the body on both faces.

## HOST-4 — both faces decide a feature verb the same way

The `[runner]` document gains an `[authz principal=…]` row naming the chain the standalone runner
acts under; `cx flow serve` passes `opts.authz` from it, and host and runner decide feature verbs
identically — the host-lane PEP case gets its serve counterpart and WF-28b's "admitted acts"
carve-out closes for this class; a `[runner]` without the row keeps today's behaviour. Rejected:
keeping the carve-out.

## Order

SEC-1 (spec, then one code branch) → HOST-1…HOST-4 as one flow/xap batch → KIT-2, KIT-3, KIT-5,
KIT-6 as one connector batch → XCO-1…XCO-5 as one wave → KIT-4 with the bulk-export connector. Every
ruled sentence lands under RS-38 with its case id.

## Note 2026-09-26 — Letters 30, 31 and 32 = (a): the SEC-1 spec's three questions, and the letter's details recorded

The owner's word, in session on the SEC-1 spec branch's READY report (#1591, 14:2xZ):
"recommendations accepted". What that rules, under SEC-1:

- **Letter 30 (a) — the band.** SEC-1 keeps `CXER7000–CXER7099`; `cx-stdlib/set`'s allocation
  from 1173-c (`CXER7000–7009`, never registered, the module unwritten) moves to
  `CXER7100–CXER7109`, written into the registry when that module is. Rejected: renumbering
  SEC-1; nesting set's codes inside secrets' band.
- **Letter 31 (a) — the owning repository.** `cx-platform/secrets` lives in a new component
  repository, `cx-home/cx-platform-secrets` (the extract recipe's shape, RS-36): the custody
  boundary is a repository boundary a client inspects, forks or replaces. Rejected: the front
  door; cx-platform-identity.
- **Letter 32 (a) — the six questions of `secrets.md` §9.2, each answered; the code branch writes
  the sentence under RS-38 with its case id:** (1) v0.18 ships `key-from=env:<VAR>` and
  `key-from=file:<path>` (a client-held master-key file under `read`, mode 0600 checked); the
  `keychain` kind arrives on the ladder's next rung together with its own capability row; (2) the
  PEP request is `[authz-request actor=module:<namespace> action=secrets:resolve
  resource=<handle>]` — the consumer MODULE is the actor, the handle the resource, grants in the
  deployment's authz document with a glob on the resource, the exact grammar authz.md §3.4's;
  (3) provider rows validate at boot (7004, 7005); at resolve the order is 7000 → 7002 → 7001 →
  7003, and EVERY refused resolution writes the audit record with `refused=<code>`; (4)
  `[secret-resolved …]` is the detail of an audit.md §2.1 `[audit module=secrets action=resolve]`
  record — one audit stream; (5) a deployment is served when its process listens (`[$xap:serve]`,
  the XAP host, `cx flow serve`); a one-shot `cx FILE`, `cx flow run` and `simulate` are
  development; (6) the sealed file is one CX document `[sealed-store v=1 alg=aes-256-gcm [entry
  handle= slot=active|next nonce= ct= …]…]`, each value sealed separately with the associated data
  = the handle string + the slot, AES-256-GCM only; `cx secrets put <handle>` reads the value from
  stdin or `--from-env <VAR>`, never an argument; `put` and `rotate` act on `sealed` only.
- **The letter's details are SEC-1's.** The owner accepted Letter 28 whole; its frozen details
  that the SEC-1 heading above abbreviates are ruled with it: the `sealed` kind's `path=` and
  `key-from=` attributes, the cryptography as crypto.md §3.7's AEAD (AES-GCM), and the seam's
  signature `resolve(handle, consumer) → secret | err`.
