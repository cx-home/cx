# RULED: 1394-b — the SSO deployment surface is complete for an enterprise security review: an XML signer enters crypto, SP-initiated SAML and SLO are routes, agents and CLIs get sessions (client credentials, device flow), multi-tenant and rotation are first-class, identity linking and grant mapping are normative, and the interop step grades the SAML accept path live

Fable, 2026-09-12 ~05:10Z, under the owner's delegation and his words on `sso.md` @ `e2e1f9dc5`:
"is what in the sso spec really up to par for our enterprise implementation or should some items
be brought out of deferment? get it right. this effort has been undershot like the mailbox again
and again." Audit of the current spec, the head's modules and the four named IdPs (Entra, Okta,
Ping, ADFS) follows; every row below is measured against what exists on `974cfe597`.

## What the current `sso.md` has
Ten routes: `login`, `callback`, `acs`, `metadata`, `logout`, `front-channel-logout`,
`back-channel-logout`, `scim-route`, `bearer-ok`, `form`; `session:attach-oidc`; a pending
table; a `return-to` allow-list; constant-time bearer; one refusal band. §1.1 defers SP-initiated
SAML and SLO (both delivered by S14 the same day), rate limiting (to `[?rate-limit]`), and
§9.4 admits the SAML ACS **accept** path is graded only offline because "saml is a verify core
with no signer".

## Ruled in — the undershoot, item by item

1. **An XML signer enters `crypto`** (`crypto:xml-sign`: enveloped XML-DSig, exclusive C14N
   the verifier already has, RSA-SHA256 and ECDSA-SHA256, `KeyInfo` by reference). It unlocks:
   signed `AuthnRequest` and `LogoutRequest` from the SP (Ping and federation deployments
   require them; SP metadata can say `AuthnRequestsSigned="true"` truthfully), signed SP
   metadata, and — decisive for grading — an **in-tree IdP that mints live, correctly-dated
   assertions**, so the interop step grades the ACS accept path over the wire and §9.4's
   admission disappears. saml.md S-6 ("nothing here produces a signature") is amended: the
   verify core stays a verify core; the signer is crypto's, and saml's emitters call it.
2. **Routes brought in:** `saml-login` (SP-initiated: `saml:authn-request` — with `ForceAuthn`
   and `RequestedAuthnContext` for step-up — Redirect binding, request id parked, RelayState =
   the key), `slo` (IdP-initiated `LogoutRequest` via POST or Redirect → detach by
   `SessionIndex`/`NameID` → `LogoutResponse`; SP-initiated SLO on `logout` when the IdP
   advertises it), `token` (client credentials with `client_secret_*` or `private_key_jwt` →
   a session for a SERVICE IDENTITY — the agent path of 1292-a; `oidc:client-credentials`
   exists), `device` (RFC 8628 device authorization: `begin` renders the code and URL, `poll`
   completes → a session — the terminal face's and a CLI agent's login; new in oidc),
   `health` and `ready` (the deployment's liveness for a load balancer, capability-free),
   and the **operator verbs** (list and revoke a principal's sessions, refresh IdP metadata,
   rotate a client secret or SP key with a dual-validity window) with their agent-tool
   projection behind the PEP and the §21.1 ladder.
3. **Multi-tenant is first-class:** one deployment, many tenants, chosen by host, path prefix or
   `login_hint` domain (the spec fixes the order); per-tenant IdP config; **Entra's templated
   issuer** (`https://login.microsoftonline.com/{tenantid}/v2.0`) validated by substituting the
   token's `tid` and checking it against the tenant's allowed-`tid` list — a multi-tenant app
   that skips this accepts any Entra tenant, which is the classic Entra breach.
4. **Configuration from IdP metadata with refresh and rollover:** `saml:metadata` and OIDC
   discovery at boot and on a schedule; two signing keys valid during rollover; certificate
   windows refused at import (1410-b); JWKS re-fetch once (1405-a).
5. **Rotation with dual validity:** client secret, `private_key_jwt` key, SP signing and
   encryption keys, the SCIM bearer — each rotates with an overlap window and an audit entry.
6. **Reverse-proxy awareness:** an explicit external base URL and a trusted-proxy list decide
   `redirect_uri`, ACS URL and metadata URLs; `X-Forwarded-*` is read only from trusted proxies.
7. **Cookies and sessions, normative:** `__Host-` prefix, `Secure`, `HttpOnly`, `SameSite=Lax`
   (the callback is a top-level navigation), a NEW session id at every attach (fixation), idle
   and absolute lifetimes, a concurrent-sessions-per-principal bound, step-up per resource
   (`acr`/`max_age`/`ForceAuthn`) and the resulting re-authentication path.
8. **Rate limiting is normative in the deployment template:** `[?rate-limit]` rows on `login`,
   `callback`, `acs`, `token`, `device`, the SCIM set, with the bounds stated; a template
   without them is not the graded deployment.
9. **Identity linking and provisioning policy:** ONE principal across an OIDC `iss`+`sub`, a
   SAML persistent `NameID`, and a SCIM `externalId`, through an explicit link table in the
   session store; **JIT provisioning vs SCIM-only** is a per-tenant policy (default SCIM-only:
   a first login for an unprovisioned identity is refused, not silently created); the
   **claims → grants mapping** (groups, roles, `tid`, `acr`) per tenant is normative here via
   `session:map-claims` + `authz`; SCIM provisions **service identities** (agents) too — an
   agent is a directory object with a type, provisioned and deprovisioned like a person.
10. **Break-glass local login:** an explicit per-deployment policy, default OFF, `authz`-gated,
    time-boxed, every use audited and surfaced in the operator view — because an IdP outage
    that locks every operator out is how deployments grow unaudited backdoors.
11. **Audit and operations:** every decision (login, refusal, logout, revocation, rotation,
    metadata refresh, break-glass) is a journal entry with actor/authority; the operator view
    is a set of records read by CXPath (tenants, IdPs, last success, pending requests, replay
    refusals, active sessions); metrics are records, not a new subsystem.
12. **Boundaries, invariants, deferrals:** ownership stated as ownership (IdP integrated never
    built; verification is oidc's/saml's; policy is authz's; provisioning semantics scim's);
    §1.2 → invariants; deferrals with honest triggers only: PAR/JAR/DPoP/FAPI (first FAPI
    tenant), ID-token JWE (first tenant refusing plaintext), SAML Artifact binding (first
    tenant that cannot POST), WS-Federation (first tenant that cannot do SAML or OIDC — ADFS does
    both), Kerberos/IWA (first on-network SSO requirement), CIBA (first decoupled-auth tenant).
13. **Integration map** (session, oidc, saml, scim, authz, xap/#1292, flow, journal, store,
    crypto, http, net) and a **completeness checklist** graded against the readiness rubric;
    the interop matrix rows for Entra/Okta/Ping/ADFS cover every route including SLO and signed
    requests.

Refused: keeping the SAML accept path graded offline (a security surface graded against a
stale fixture is not graded); a deployment template without rate limits; silent JIT creation
by default; a break-glass path that is not audited.

Order: spec revision (this record's items), the owner reads, then phase 2: `crypto:xml-sign`
(Ring 1, its own corpus first) → saml emitters signed → the in-tree IdP mints live assertions →
the sso routes → the interop rows; band `CXER6000–6099` stays sso's (mailbox moved to 6100).
