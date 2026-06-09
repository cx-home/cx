# `cx-stdlib/session` — `(principal, tenant)` sessions

```cx
[module-meta name=session tier=D status=current
  [standard ref='OIDC' title='Identity']
  [standard ref='JWT' title='Tokens']
  [standard ref='JWKS' title='Key discovery']
  [standard ref='RFC 6265' title='Cookies']
  [standard ref='TLS' title='Transport']]
```

**Status:** Current for v0.8.0

Normative reference (on graduation) for the `cx-stdlib/session` sub-package: the
session layer of the XAP web stack — it sits **above** the L7 `cx-stdlib/http`
engine ([`http.md`](http.md), in review) and **above** the
`crypto` JWT/JWKS verify amendment ([`stdlib_crypto_jwt_amendment.md`](stdlib_crypto_jwt_amendment.md),
in review), and **below** `authz` ([`authz.md`](authz.md), the PEP)
and `xap` ([`xap.md`](xap.md), the orchestrator):

```
net (L4) → http (L7) → [?http-service] routing
  → session  (attach: verify token → (principal, tenant) bound over TLS)   THIS SPEC
    → authz  (PEP reads the session's actor-principal)                     authz.md
      → xap  (orchestrates the §2 cascade)                                 xap.md
```

## §0. Consistency with the in-review amendments (normative dependency)

Authored to be consistent with the same amendments `http` and `authz` align to. On
their approval the cited semantics are load-bearing here. If any is rejected or
changed at G3, the marked clauses are revisited.

| Amendment | What session relies on |
|---|---|
| [`stdlib_crypto_jwt_amendment.md`](stdlib_crypto_jwt_amendment.md) — **`crypto` JWT / JWKS verify** | the **sole** token-verification primitive. `attach` delegates *all* cryptography — signature verification against the IdP JWKS, `exp`/`nbf`/`iat`/`aud`/`iss` validation — to `[$crypto:jwt-verify …]`; session **adds no crypto of its own** (§2.2). **This holds for the cookie adapter too** (§2.8): a cookie session is *established* by the same verified token — the cookie carries an **opaque session id**, never the raw token, and `jwt-verify` still runs at attach. The IdP is **integrated, not built**: session never issues, signs, or refreshes an IdP token; it consumes a *verified claim-set* and maps it to a principal (§2.3). This is the load-bearing identity decision ([`xap.md`](xap.md) §22.1). |
| [`http.md`](http.md) — **the transport that carries attach** | attach is driven by a server-form `[request]` yielded by `[$http:serve]`/`accept-iter` (§3.2); the bearer token is read from its `Authorization` header, the session cookie from its `Cookie` header, and the response cookie written via `Set-Cookie` (`http` §3.4 `header`/response). session **never opens a socket** — it reads an already-parsed request and inherits `http`/`net`'s TLS posture (§2.4 TLS guarantee). |
| `code.md` §9.1.2 — **four-channel model** | a **missing / unattached** session rides the **absence channel** (empty node-set), *not* `null` and *not* a fault — `[$session:of …]` on an unknown handle yields the empty node-set (§2.5). A **rejected attach** (bad/expired/wrong-audience token) is a **failure** on the `[err]` channel (§2.6). An **established session** is a present `[session]` **value** that flows. No-conflation guard. |
| SAP §2 — **`[?try]`/`[catch]` retirement** | attach faults are handled with `[?match]` / `[?else]` / `[?fallback]` only; this spec never uses `[?try]`. Canonical call form is `[$session:attach …]` (`[head …]`), never an infix. |
| SAP §5 — **closeable contract + cancellation** | a `[session]` satisfies the `[?with-open]` closeable contract; `detach` is its `on-close`. Cancellation surfaces the core `CXER0260`, not a session code (§4.5). |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |

session does **not** re-specify JWT/JWKS verification (that is the crypto
amendment), HTTP/TLS transport (that is `http`/`net`), authorization decisions
(that is `authz`'s PEP, §6), or the event log (that is `journal`). It composes
them.

---

## §1. Scope

`cx-stdlib/session` provides the **server-held session** for a XAP app-role
runtime ([`xap.md`](xap.md) §14.1): a small, durable association between a
**verified external identity** and a **tenant-scoped principal**, established by
`attach`, looked up by `of`, torn down by `detach`, and capable of carrying
**multiple concurrent clients** (mirrored attach — the tmux model, [`xap.md`](xap.md)
§16) while **surviving the death of any individual client**.

**Layering (decision — XAP thin-module model).** session is a *thin stdlib
module*, **not** a framework and **not** a piece of `http`. It is the seam between
authentication (external IdP → verified token, done by `crypto`) and authorization
(the `authz` PEP, which reads the session's actor-principal, §6). The architecture
is: **`http` (transport) + `crypto` (token verify) → `session` (this spec) →
`authz` (PEP) → `xap` (orchestrator)**.

| Surface | Home | Role |
|---|---|---|
| **`cx-stdlib/session` module** (this spec) | `[?lib 'cx-stdlib/session']` | establishes & resolves the `(principal, tenant)` session; the **two attach transports** (Bearer §2.2, cookie §2.8) + **CSRF** defense (§2.9); the mirrored-attach lifecycle |
| `[$crypto:jwt-verify …]` | [`stdlib_crypto_jwt_amendment.md`](stdlib_crypto_jwt_amendment.md) | verifies the token; emits a claim-set |
| `[$authz:check …]` | [`authz.md`](authz.md) | reads the session's principal/tenant; decides intents |

**Two attach transports, one session model (decision — v1).** A `(principal, tenant)`
session is established by a verified IdP token (§2.2), but the *transport* that carries
the proof-of-session on subsequent requests is client-shaped:

- **Bearer** (§2.2) — for **agents, channels, and service clients** that hold a token
  and send it in `Authorization: Bearer …` on every request. No ambient credential, so
  **no CSRF surface** (§2.9).
- **Cookie session** (§2.8, NEW this revision) — for **browser human clients** (the
  HUMAN principal of [`xap.md`](xap.md) §16 attaches via a browser). On attach, session
  issues an **`HttpOnly; Secure; SameSite` cookie carrying an opaque server-issued
  session id** (never the raw token); subsequent requests resolve via the cookie.
  Because the cookie is an **ambient credential the browser attaches automatically**,
  this transport **requires CSRF protection** (§2.9) on state-changing intents.

Both transports converge on the **same** `[session]` model (§2.1) and the **same**
`(principal, tenant)` binding — they are two doors into one session, and a human's
browser (cookie) and their agent (Bearer) mirror-attach to it (§2.7).

Out of scope (and where it lives instead):

| Concern | Owner |
|---|---|
| Token signature / `exp`/`nbf`/`aud`/`iss` verification, JWKS fetch & key rotation | `crypto` JWT/JWKS amendment ([`stdlib_crypto_jwt_amendment.md`](stdlib_crypto_jwt_amendment.md)) |
| **Identity issuance** — login UI, password/credential storage, token *minting*, refresh, logout-at-IdP | the **external IdP** (OIDC/SAML) — XAP integrates, never builds it ([`xap.md`](xap.md) §22.1) |
| TCP/TLS sockets, the HTTP request/response transport | `cx-stdlib/net` / `cx-stdlib/http` |
| Authorization decisions (capabilities, delegations, guardian grants, the PEP) | `cx-stdlib/authz` ([`authz.md`](authz.md)) — session only *carries* the principal it checks (§6) |
| The append-only event log + audit chain | `cx-stdlib/journal` ([`xap.md`](xap.md) §25.1) — session emits attach/detach **as** events into it (§4.4) but does not own the log |
| The raw `Set-Cookie`/`Cookie` **header wire format** (attribute serialization, parsing, `__Host-` prefix rules) | `cx-stdlib/http` (`http` §3.4) — session *composes* it (writes/reads named cookies, §2.8); it does not re-implement cookie header (de)serialization |
| Step-up / re-authentication (`acr`/`amr` elevation for high-risk intents) | **noted future revision** (§13) — v1 rotates the session id on a privilege change (§2.8.4) but does not orchestrate an IdP step-up flow |
| The per-tenant process topology / worker supervision | the control-plane / gateway ([`xap.md`](xap.md) §14.1, §22.7) — session names the tenant a request routes to (§2.3), it does not spawn workers |
| Cross-channel session continuity (email/chat/voice channels as clients) | the channel adapters ([`xap.md`](xap.md) §16) — they attach as clients (§3.3); session treats every client uniformly |

`cx-stdlib/session` is **Tier-B runtime — necessarily impure**: `attach` reaches
the network (through `crypto`'s JWKS fetch and inherits its `net` need), and all
session lookups/mutations touch shared server-held state. It introduces **no new
capability** — it requires the **`net`** capability transitively via the JWKS fetch
(§5) and nothing more. Pure claim-mapping and the read-only accessors
(`principal`/`tenant`/`clients`/`valid`) are **pure** and capability-free.

## §2. Conceptual model

### §2.1. The `[session]` handle, ownership, and lifecycle

One impure handle kind wraps the server-held session state:

```cx
[session id="s-7b3f…" state="attached"            ; the session — server-held; id doubles as the opaque cookie value (§2.8)
  on-close="session/detach"
  [principal id="dana" [tenant acme]]             ; the bound (principal, tenant) — IMMUTABLE for the session's life (§2.3)
  [established-at "2026-06-06T18:04:11Z"]
  [clients                                        ; ZERO-or-more attached clients (mirrored attach, §2.7)
    [client id="c-web-1"   channel=http via=cookie attached-at="…" last-seen="…"]   ; browser, cookie transport (§2.8) → CSRF-guarded (§2.9)
    [client id="c-agent-1" channel=cx   via=bearer attached-at="…" last-seen="…"]]  ; agent, Bearer transport (§2.2) → CSRF-exempt
  [csrf-token "…opaque server-held secret…"]]     ; per-session synchronizer CSRF token (§2.9); present once any cookie client attaches
```

The per-client **`via`** marker records the attach transport (`bearer` §2.2 / `cookie`
§2.8) — it is what keys the CSRF exemption (N-SESSION-7), never a client-supplied flag.
The `[csrf-token …]` is server-held session state (§2.9); it is **not** the same as the
opaque session id (the cookie value) and is never `HttpOnly` (the front-end must read it
to echo it back).

Ownership model (the load-bearing concurrency contract):

- A **`[session]` is server-held and concurrency-safe**: multiple workers MAY read
  it (`of`, `principal`, `tenant`, `clients`, `valid`) and MAY attach/detach
  *clients* to it simultaneously; the handle wraps state under internal
  synchronization. The session is **not** single-owner — that is the whole point of
  mirrored attach (§2.7).
- The **`(principal, tenant)` binding is immutable** for the session's life: it is
  fixed at the first `attach` and **never re-bound** — a later attach with a token
  resolving to a *different* `(principal, tenant)` is **rejected**, not a re-bind
  (`CXER4805`, §2.7). Re-keying the subject means a *new* session.
- **`state`** ∈ `"attached" | "detached" | "expired"`:
  - `"attached"` — ≥ 0 clients *may* be present and the binding is live within the
    token's validity window. **A session with zero clients is still `"attached"`**
    (it survives client death, §2.7) until it `detach`es or `expire`s.
  - `"detached"` — torn down by `detach` (the whole session, §3.2); terminal.
  - `"expired"` — the token validity window lapsed (§2.6); terminal. An op on an
    expired/detached session → `cx-err:CXER4804 E_SESSION_INVALID`.
- A `[session]` carries the **closeable contract** (`on-close="session/detach"`,
  [`code.md`](../core/code.md) §8.10.7): it is `[?with-open]`-able and never raises
  `CXER0108`; close = full `detach` (§3.2). `detach` is **idempotent**.
- **There is no ambient "current session."** A session is always reached
  explicitly by handle or by `of` over a request/connection (§3.3) — never an
  implicit global. (This keeps the per-tenant process model honest: the resolver
  cannot accidentally read another tenant's session, §10.6.)

### §2.2. `attach` verifies a token; it does not mint one (IdP integrated, not built)

`attach` takes a **bearer token** (a signed JWT from the external IdP) and a
**verification config** (the IdP's issuer + audience + JWKS source), and produces a
session **iff the token verifies**. The hard rule:

> **N-SESSION-1 (token verification is delegated; identity is never issued here).**
> `attach` performs **no cryptography itself**. It calls
> `[$crypto:jwt-verify $token $verify-cfg]` (the JWT/JWKS amendment) and acts only
> on the *result*: a verified claim-set, or a verification fault. session **never**
> mints, signs, refreshes, or stores a credential — the IdP owns identity issuance
> ([`xap.md`](xap.md) §22.1). session owns only the *mapping* of a verified subject
> to a tenant-scoped principal (§2.3) and the *lifecycle* of the resulting session.

So the trust chain is: **IdP signs → `crypto` verifies → `session` maps & binds →
`authz` authorizes**. session is exactly the third link and nothing more.

A token that fails verification (bad signature, expired, wrong `aud`/`iss`,
malformed) surfaces as a **failure** (`CXER4801`, §2.6), carrying the underlying
`crypto` fault as a child for diagnostics — never a partially-established session.

### §2.3. Subject → tenant-scoped principal mapping; tenant is a hard partition

A verified claim-set names an **external subject** (e.g. the OIDC `sub` + `iss`).
session maps it to a **tenant-scoped principal** via a caller-supplied
**claim-mapping** (part of the attach config, §3.1):

- **tenant resolution** — which tenant this subject belongs to, derived from a
  claim (e.g. a `tid`/`org` claim, or the `iss`) per the mapping. The resolved
  tenant is **load-bearing**: it selects the per-tenant worker the request routes
  to ([`xap.md`](xap.md) §14.1) and roots every state slice ([`xap.md`](xap.md)
  §22.6).
- **principal resolution** — the stable tenant-scoped principal id for the subject
  (e.g. `sub` namespaced under the tenant).

> **N-SESSION-2 (tenant is a hard partition; binding is exact).** A session is
> bound to **exactly one** `(principal, tenant)` pair. There is no cross-tenant
> session and no multi-tenant session: the tenant is fixed at attach and the slice
> namespace is tenant-rooted, so a session **structurally cannot** read or act
> across tenants ([`xap.md`](xap.md) §22.6). A claim-set that resolves to **no
> tenant**, or to a tenant the runtime does not host, → `cx-err:CXER4802
> E_SESSION_TENANT_UNRESOLVED`. A claim-set that resolves to **no principal**
> (subject present, mapping yields nothing) → `cx-err:CXER4803
> E_SESSION_PRINCIPAL_UNRESOLVED`.

The mapping is **pure data + a pure transform** ([$session:map-claims …], §3.4):
the same claim-set always maps to the same `(principal, tenant)` — so the mapping
is independently testable without a live IdP.

### §2.4. The session is bound over TLS (a transport guarantee, inherited)

> **N-SESSION-3 (TLS-bound attach).** A session **MUST** be established over a TLS
> transport. session does not implement TLS — it **requires** that the carrying
> `[$http:serve]` listener bound a `tls://` URL ([`http.md`](http.md)
> §3.5) (or that the control-plane gateway terminated TLS upstream and attests it).
> `attach` over a non-TLS request → `cx-err:CXER4806 E_SESSION_INSECURE_TRANSPORT`
> (off only under an explicit dev-mode opt, `allow-insecure=true`, §3.1 — never the
> default). The bearer token is a credential; carrying it in clear is a
> bright-line refusal.

This is the [`xap.md`](xap.md) §22.1 "*a session bound to (principal, tenant) over
TLS*" guarantee, realized as an attach-time precondition on the inherited transport
posture. session adds no TLS code — it **refuses** to attach when the inherited
posture is insecure.

### §2.5. Absence vs present — the empty session is not `null` (SAP §1)

`of` resolves the session for a request/connection. When **no session is
established** for it, `of` returns the **absence channel (empty node-set)**, which
flows inertly — **not** `null` and **not** a fault. An unattached request is a
*normal, expected* state (the principal has not authenticated yet), distinct from a
*broken* one. So:

```cx
[?match [$session:of $req]
  [case []   [$http:respond $ex [response status=401 …]]]   ; absence → not yet authenticated
  [case $s   …authorized work with $s…]]                    ; present → a [session] value
```

There is **no `principal-or-null` accessor**: the principal is reached through a
present session, and the absence of a session is the absence of a principal,
carried structurally by the empty node-set (no conflation).

### §2.6. A verification/expiry failure is a fault; an unauthenticated request is not

The two "no session" outcomes are distinct channels (SAP §1):

- **No session yet** (the request carried no token, or `of` finds none) → **absence**
  (§2.5). This is `[$session:of …]` returning empty; it is **not** an error. The
  caller decides the response (typically 401).
- **A token was presented but is invalid** → **fault** on the `[err]` channel:
  - signature / `exp` / `nbf` / `aud` / `iss` / malformed-token → `cx-err:CXER4801
    E_SESSION_TOKEN_REJECTED`, carrying the verbatim `crypto` JWT fault as a child;
  - no resolvable tenant → `CXER4802`; no resolvable principal → `CXER4803` (§2.3);
  - insecure transport → `CXER4806` (§2.4).

An **established session whose token validity window later lapses** transitions to
`state="expired"` (§2.1); a subsequent op on it → `cx-err:CXER4804
E_SESSION_INVALID`. Expiry is evaluated against the verified claim `exp` at attach
and re-checked lazily on each `of`/accessor (no background sweeper is required;
§4.3).

### §2.7. Mirrored attach — many clients, one session, survives client death (the tmux model)

This is the [`xap.md`](xap.md) §16 contract, realized here:

- **A session is established once** (the first `attach` mints the `[session]` and
  binds `(principal, tenant)`). Subsequent `attach`es for the **same** subject
  **add a client** to the existing session rather than minting a new one — *iff* the
  re-presented token resolves to the **same** `(principal, tenant)` (else
  `CXER4805`, §2.1). This is **mirrored attach**: a human's browser and their agent
  attach to **one** session and see the **same** surface ([`xap.md`](xap.md) §21
  over-the-shoulder collaboration). attach returns the (possibly pre-existing)
  `[session]` plus the new `[client]` id (§3.2).
- **Client identity is separate from session identity.** Each attached client gets
  a `[client id=… channel=… …]` entry (§2.1). `detach-client` removes one client;
  `detach` tears down the whole session (§3.2).
- **The session survives the death of any client.** A client's transport dropping
  (connection close, missed heartbeat) removes *that client* from `clients` but
  **does not** detach the session — `state` stays `"attached"` with the remaining
  (possibly zero) clients. A returning client **re-attaches to the same live
  session** (presenting a token that resolves to the same `(principal, tenant)`).
  This is the tmux invariant: the server owns the state; clients are ephemeral
  views onto it.

> **N-SESSION-4 (session ⊥ client lifetime).** Session lifetime is governed by the
> token validity window + explicit `detach`, **never** by client liveness. Zero
> attached clients is a valid `"attached"` state. Reaping a dead session is a
> *separate* concern from reaping a dead client (§4.3).

The **`session-lost`** incapacity predicate of [`xap.md`](xap.md) §22.8 reads
*this* model: "session dropped / no heartbeat" is evaluated over the session's
client set + last-seen marks, and is falsifiable-by-presence (a client re-attaching
makes it immediately false). session exposes the read-model (`clients`, last-seen)
the predicate folds over; the predicate itself lives in `authz`'s library, not here.

### §2.8. The cookie-session adapter — opaque session id for browser human clients (NEW)

Bearer attach (§2.2) suits clients that hold and send a token. A **browser** does not:
the HUMAN principal of [`xap.md`](xap.md) §16 authenticates once and the browser must
carry the proof-of-session on every subsequent request **without** JavaScript holding a
token (an XSS-exfiltratable design). The cookie adapter is the v1 mechanism for this
client shape; it **complements** Bearer, it does not replace it (§1, two transports).

> **N-SESSION-5 (the cookie carries an opaque session id, never the token).** On a
> cookie-mode `attach`, after the **same** `[$crypto:jwt-verify]`-backed verification
> and `(principal, tenant)` binding as Bearer (§2.2 — the cookie adapter adds **no** new
> identity path), session mints an **opaque, high-entropy session id** (≥128 bits CSPRNG,
> server-side; it is the `[session] id`) and writes it to the response as a
> **`Set-Cookie`**. The **raw IdP token is NEVER placed in a cookie** — the cookie is a
> *reference* to server-held session state (§2.1), not a self-contained credential.
> Compromising the cookie yields a session-id handle (revocable by `detach`/expiry,
> §2.8.4), not a replayable signed token. The server-side state is the existing
> tenant-rooted session store (§9); the cookie is just its key.

**Cookie default flags (and why).** The issued cookie carries, by default:

| Attribute | Default | Why (security rationale) |
|---|---|---|
| `HttpOnly` | **on** | the session id is unreadable from JavaScript — an XSS bug cannot exfiltrate it. Non-negotiable for a session credential; turning it off is **refused** (`CXER4811`, §2.8.3). |
| `Secure` | **on** | the cookie is only ever sent over TLS — consistent with the TLS-bound attach (§2.4, N-SESSION-3). A cookie attach attempted over a non-TLS request → `CXER4806` (same bright-line as Bearer); issuing a `Secure` cookie in a non-TLS context → `CXER4810` (§2.8.3). |
| `SameSite` | **`Lax`** | the browser withholds the cookie on **cross-site state-changing** (POST/PUT/DELETE) navigations — the first-line CSRF mitigation — while still sending it on top-level GET navigations (so a user following a link into the app stays logged in). `Strict` is available (a config opt) and recommended for pure-API/no-inbound-link deployments, but `Lax` is the default because it preserves normal link-in UX; `None` requires `Secure` and is refused unless an explicit cross-site embedding opt is set (`CXER4811`). **`SameSite` is defense-in-depth, not the whole defense** — the synchronizer CSRF token (§2.9) is still required, because `Lax` still permits same-site forgery and older browsers under-enforce `SameSite`. |
| `Path` | `/` | scope to the app root (config-overridable). |
| `Max-Age` | the verified token's remaining `exp` window | the cookie's browser-side lifetime tracks the session validity window (§2.6) so a stale cookie does not outlive its session; server-side expiry (§2.6) is authoritative regardless. |
| name | `__Host-cxsid` | the `__Host-` prefix (requires `Secure`, `Path=/`, no `Domain`) hardens against subdomain cookie-injection — the attack double-submit CSRF is vulnerable to (§2.9). Config-overridable for deployments that cannot meet the prefix's constraints, which then fall back to a plain `cxsid` name. |

The wire (de)serialization of these attributes is `http`'s (§1 out-of-scope row); session
*chooses* the attributes and hands `http` a named cookie to write.

#### §2.8.1. Cookie attach — `attach-cookie`
`attach-cookie $req $cfg` runs the **identical** verify → map → bind → mirror-attach
pipeline as `attach` (§2.2/§2.7) — same token source (a one-time bearer/credential on
the auth route, or the IdP redirect's code-exchange result the integration supplies),
same `[$crypto:jwt-verify]`, same `(principal,tenant)`, same `CXER4801`–`CXER4806`
faults — and then **additionally**: (a) mints the opaque session id (N-SESSION-5),
(b) returns the `[session]` paired with the `Set-Cookie` directive to write (the session
cookie **and** a readable CSRF cookie/token, §2.9), via `set-cookie` (§3.5). The
attaching client is recorded with `channel=http` (a browser client, §2.1).

#### §2.8.2. Cookie resolve — `from-cookie`
`from-cookie $req` reads the session-id cookie from the request's `Cookie` header,
looks up the live `[session]` by that id (the `by-id` path, §3.3), and returns it — or
the **absence channel (empty)** when the cookie is missing, unknown, or names an
expired/detached session (§2.5; an unauthenticated browser request is *normal*, not a
fault — exactly the §2.6 split). It is the cookie-transport analogue of `of` (§3.3) and
is what the request pipeline calls for a browser client. Like `of`, it never re-binds and
performs no effect beyond an internal `touch`.

#### §2.8.3. Insecure-cookie refusals (bright lines)
Mirroring the TLS bright line (§2.4), the cookie adapter **refuses** to issue an
unsafe cookie:

- issuing the session cookie over a **non-TLS** request (so `Secure` could not be
  honored end-to-end) → `cx-err:CXER4810 E_SESSION_COOKIE_INSECURE_CONTEXT` (unless the
  same `allow-insecure=true` dev opt, §3.1, which also relaxes §2.4);
- a config that would drop `HttpOnly`, or set `SameSite=None` without the explicit
  cross-site embedding opt → `cx-err:CXER4811 E_SESSION_COOKIE_UNSAFE_FLAGS` (the adapter
  will not mint a session credential a script can read or a foreign site can ambiently
  send).

#### §2.8.4. Cookie lifecycle — rotation, expiry, secure invalidation
- **Rotation on privilege change (session fixation defense).** Whenever the session's
  effective authority changes — re-authentication, an `acr`/`amr` elevation, or any
  privilege-level transition the integration signals via `rotate` (§3.5) — session mints
  a **new** opaque session id, writes the new `Set-Cookie`, and invalidates the old id
  server-side. The `(principal, tenant)` binding is **unchanged** (it is immutable,
  §2.3/N-SESSION-2) — only the *cookie credential* rotates. This defeats session
  **fixation** (an attacker who planted a pre-auth cookie value cannot ride it post-auth)
  and is the standard rotate-on-elevation hygiene. Rotation also re-issues the CSRF token
  (§2.9). A rotation on a non-cookie (Bearer-only) session is a no-op.
- **Expiry.** The cookie's `Max-Age` tracks the token `exp` window (table above), but the
  **server-side** session expiry (§2.6) is authoritative: a request bearing a cookie for
  an `expired`/`detached` session resolves to **absence** via `from-cookie` (§2.8.2) — the
  client is treated as unauthenticated, and the pipeline issues a clearing `Set-Cookie`
  (below). Lazy expiry (§4.3) applies unchanged.
- **Secure invalidation on detach.** `detach` (§3.2) tears down server-held state
  **and** emits a **clearing `Set-Cookie`** (empty value, `Max-Age=0`, same name/`Path`/
  `Secure`/`HttpOnly`) so the browser drops the cookie immediately; the server-side id is
  invalidated regardless of whether the client honors the clear (server state is
  authoritative — a stolen cookie cannot outlive `detach`). `clear-cookie` (§3.5) is the
  standalone form. As with all detach, true IdP logout is the IdP's concern (§1).

### §2.9. CSRF protection — synchronizer token bound to the session (NEW)

A cookie is an **ambient credential**: the browser attaches it to *every* request to the
origin, including requests a malicious third-party page forges (a cross-site form POST,
an image GET). That is the cross-site request forgery (CSRF) problem, and it exists
**only** for cookie-ambient credentials. Bearer clients (§2.2) send their token
explicitly per request — a foreign page cannot read or set another origin's
`Authorization` header — so **Bearer attach is structurally CSRF-exempt** (N-SESSION-7).
CSRF defense is therefore scoped to the cookie transport.

> **N-SESSION-6 (CSRF: the synchronizer-token pattern, bound to the session).** session
> uses the **synchronizer-token** pattern (a server-issued, per-session secret stored in
> the session state, §2.1), **not** stateless double-submit-cookie. On a cookie `attach`
> (§2.8.1) session mints a high-entropy CSRF token, **stores it in the server-held
> session**, and exposes it to the trusted front-end (a non-`HttpOnly` companion cookie
> and/or a `[$session:csrf-token]` read for embedding in a page/meta tag, §3.5). Every
> **state-changing intent** from a **cookie-authenticated** client MUST carry that token
> (in an `X-CSRF-Token` header or a form field); `csrf-verify` (§3.5) **constant-time**
> compares the submitted value against the session-stored one. A missing token →
> `cx-err:CXER4808 E_SESSION_CSRF_MISSING`; a present-but-wrong one → `cx-err:CXER4809
> E_SESSION_CSRF_MISMATCH`. Read-only/safe intents (the GET/HEAD/OPTIONS equivalents) do
> not require it.

**Why synchronizer-token, not double-submit (justification).** Double-submit stores the
CSRF secret only in a second cookie and trusts that a forger cannot *read* it to echo it
back. That assumption breaks under (a) **subdomain cookie injection** (a compromised or
attacker-controlled sibling subdomain can *write* a cookie onto the parent domain,
letting the attacker fix both halves of the double-submit), and (b) any cookie-tossing /
prefix-confusion variant. The synchronizer token avoids both because the authoritative
copy lives in **server-held session state** the attacker cannot write — and session
**already holds** that state (§2.1), so the pattern costs nothing extra here and is
strictly stronger. (The `__Host-` cookie prefix, §2.8, further hardens against the
injection vector, but the server-stored token is the actual guarantee.) The CSRF token
is bound to the **session**, so it is naturally tenant-scoped and dies with the session.

> **N-SESSION-7 (Bearer is CSRF-exempt; the exemption is by credential shape, not a
> bypass).** `csrf-verify` (§3.5) is a **no-op pass** for a session attached via Bearer
> (§2.2): the absence of an ambient cookie credential means there is nothing for a
> cross-site page to ride. The exemption is keyed on **how the session authenticated**
> (Bearer vs cookie, recorded on the `[session]`), never on a client-supplied flag — a
> cookie-authenticated request cannot opt out of CSRF by claiming to be Bearer. A
> request presenting **both** a session cookie and a Bearer token is treated as
> **cookie-authenticated** for CSRF purposes (the ambient credential is present), the
> safe default.

**Lifecycle.** The CSRF token is issued with the session, **rotated together with the
session id** on a privilege change (§2.8.4 — a rotated session gets a fresh CSRF token),
and invalidated on `detach`/expiry (it lives in the session state, so it dies with it).
It is **not** retained across sessions.

## §3. Public function surface

Signature notation matches [`cx-stdlib/io`](../std-lib/io.md) and
[`http.md`](http.md). `::map` is an options/claim record;
`::element` is a `[session]` handle, a `[request]`, or a claim-set value; an optional
read that may be absent is typed `[returns element]` and yields the **absence
channel** (empty) when nothing is present (§2.5). The defaulted trailing
`$opts::map {}` is a **defaulted positional parameter** (`grammar.ebnf [153b]` — a
bare space-separated VALUE after the type, exactly as `http` §3.1), so the caller
MAY omit it.

### §3.1. Attach config (the verify + mapping record)

`attach` takes a config `::map` (built once per IdP integration, reused per
request) with these keys:

| Key | Default | Meaning |
|---|---|---|
| `issuer` | — (required) | expected IdP `iss`; passed to `[$crypto:jwt-verify]` |
| `audience` | — (required) | expected `aud`; passed to `[$crypto:jwt-verify]` |
| `jwks` | — (required) | the JWKS source the crypto amendment fetches keys from (a URL, or a literal key-set); reaches the network via `net` (§5) |
| `tenant-claim` | `"tid"` | claim naming the tenant (§2.3); a `[?def]` mapping fn MAY override (`tenant-map`) |
| `principal-claim` | `"sub"` | claim naming the subject → principal id (§2.3) |
| `tenant-map` | identity | optional pure `[?def]` `claim-set → tenant-id` (overrides `tenant-claim`) |
| `principal-map` | identity | optional pure `[?def]` `claim-set → principal-id` (overrides `principal-claim`) |
| `leeway` | `60s` | clock-skew leeway forwarded to `[$crypto:jwt-verify]` for `exp`/`nbf` |
| `allow-insecure` | `false` | dev-only: permit attach over a non-TLS transport (§2.4) **and** issue a cookie in a non-TLS context (§2.8.3); **never true in app-role** |
| `cookie-name` | `"__Host-cxsid"` | the session cookie name (§2.8); falls back to `"cxsid"` if the `__Host-` constraints are not met |
| `cookie-same-site` | `"Lax"` | `"Lax"` \| `"Strict"` \| `"None"`; `"None"` requires the cross-site embedding opt or `CXER4811` (§2.8/§2.8.3) |
| `cookie-path` | `"/"` | the session cookie `Path` (§2.8) |
| `csrf-cookie-name` | `"cx-csrf"` | the **non-`HttpOnly`** companion cookie carrying the CSRF token for the front-end to echo (§2.9) |
| `csrf-header` | `"X-CSRF-Token"` | the request header `csrf-verify` reads the submitted token from (§2.9) |
| `allow-cross-site-cookie` | `false` | explicit opt permitting `SameSite=None` (third-party embedding); otherwise `SameSite=None` → `CXER4811` (§2.8.3) |

### §3.2. Lifecycle — attach / detach (impure)

```
[?def attach        scope=public impure [returns element] ($req::element $cfg::map) ...]
[?def attach-token  scope=public impure [returns element] ($token::string $cfg::map $client::map {}) ...]
[?def attach-cookie scope=public impure [returns element] ($req::element $cfg::map) ...]
[?def detach        scope=public impure [returns null]    ($session::element) ...]
[?def detach-client scope=public impure [returns element] ($session::element $client-id::string) ...]
[?def touch         scope=public impure [returns element] ($session::element $client-id::string) ...]
```

- **`attach $req $cfg`** — the high-level path. Reads the bearer token from `$req`'s
  `Authorization: Bearer …` header (`[$http:header $req 'Authorization']`, §0
  transport dependency), checks the transport is TLS (§2.4), verifies via
  `[$crypto:jwt-verify]`, maps the claim-set to `(principal, tenant)` (§2.3), and
  **mirror-attaches** (§2.7): mints a new `[session]` on first attach for the
  subject, or adds a client to the existing one. Returns the `[session]` (whose
  freshly-added `[client …]` is the last entry of `clients`). A missing/blank
  `Authorization` header → **absence** is *not* returned here (attach is an
  affirmative act); instead it is `cx-err:CXER4807 E_SESSION_NO_TOKEN` — callers who
  want the "no token = unauthenticated, not an error" posture call `of` first (§2.5),
  and only call `attach` once a token is present. Faults per §2.6.
- **`attach-token $token $cfg $client`** — the low-level path (channels/tests that
  hold the raw token, not an `[http]` `[request]`): same semantics minus the header
  read; `$client` is an optional `{channel: …, id: …}` record describing the
  attaching client (defaults: an impl-assigned id, `channel=cx`). The TLS
  precondition (§2.4) is the caller's attestation here (`$cfg.allow-insecure` or a
  transport-attested flag), since there is no `[request]` to inspect.
- **`attach-cookie $req $cfg`** — the **browser** path (§2.8). Runs the **identical**
  verify → map → bind → mirror-attach pipeline as `attach` (same `[$crypto:jwt-verify]`,
  same `(principal,tenant)`, same `CXER4801`–`CXER4807` faults), then mints the opaque
  session id (N-SESSION-5) and the per-session CSRF token (§2.9), records the client with
  `via=cookie`, and returns the `[session]` **paired with the `Set-Cookie` directives** to
  write (the `HttpOnly; Secure; SameSite` session cookie + the readable CSRF companion
  cookie). Refuses an insecure cookie context → `CXER4810`; refuses unsafe flags →
  `CXER4811` (§2.8.3). TLS precondition is `attach`'s (§2.4 → `CXER4806`).
- **`detach $session`** — tears the **whole** session down: removes all clients,
  sets `state="detached"` (terminal), releases server-held state, **emits a clearing
  `Set-Cookie` for any cookie-transport client** (§2.8.4 secure invalidation), emits the
  detach event (§4.4). **Idempotent**; the `[?with-open]` `on-close`. Detaching at the IdP
  (true logout) is the IdP's concern (§1) — `detach` ends the *local* session only.
- **`detach-client $session $client-id`** — removes **one** client (mirrored-attach
  teardown of a single view); the session survives if other clients remain, and
  **survives even at zero clients** (§2.7, N-SESSION-4). Returns the updated
  `[session]`. Unknown `client-id` → **absence** (idempotent removal), not a fault.
- **`touch $session $client-id`** — refreshes a client's `last-seen` mark (heartbeat
  liveness, feeding the `session-lost` read-model, §2.7). Returns the updated
  `[session]`; unknown client → absence.

### §3.3. Resolve — `of` (impure read of server state)

```
[?def of        scope=public impure [returns element] ($req-or-conn::element) ...]
[?def by-id     scope=public impure [returns element] ($session-id::string) ...]
[?def by-client scope=public impure [returns element] ($client-id::string) ...]
```

- **`of $req-or-conn`** — the resolver the request pipeline calls: given a
  server-form `[request]` (or a connection/exchange handle), returns the established
  `[session]` for it, or the **absence channel (empty)** when none is established
  (§2.5). Resolution is by the request's session reference — the bearer token's
  verified subject (re-verified or matched against a live session), or an opaque
  session id the transport carries; the binding mechanism is impl-internal but the
  result is exactly "the `[session]` for this request, or absence." It does **not**
  attach (no side effect on the client set beyond an internal `touch`); to establish
  a session, call `attach` (§3.2).
- **`by-id` / `by-client`** — direct lookups by session id or client id (for
  admin/audit surfaces and the resolver); absence when unknown. `of` is the request
  path; these are the explicit-id paths.

`of`/`by-id`/`by-client` are **impure** (they read mutable server-held state) but
**effect-free** beyond an internal last-seen `touch`; they require **no
capability** (§5).

### §3.4. Accessors (pure)

```
[?def principal   scope=public pure [returns element]            ($session::element) ...]
[?def tenant      scope=public pure [returns element]            ($session::element) ...]
[?def clients     scope=public pure [returns [sequence element]] ($session::element) ...]
[?def valid       scope=public pure [returns bool]               ($session::element) ...]
[?def claims      scope=public pure [returns element]            ($session::element) ...]
[?def map-claims  scope=public pure [returns element]            ($claim-set::element $cfg::map) ...]
```

All operate on the materialized `[session]` / claim-set value — **pure**, no
capability, referentially transparent.

- **`principal`** — the bound `[principal id=… [tenant …]]` element. **This is the
  actor-principal the `authz` PEP reads** (§6). On a `[session]` only.
- **`tenant`** — the bound `[tenant …]` element (the hard-partition key, §2.3).
- **`clients`** — the `[client …]` set in attach order (the mirrored-attach
  read-model + the `session-lost` predicate's input, §2.7); empty sequence for a
  zero-client session (present-empty, not absence — the session *has* a client set,
  it is just empty).
- **`valid`** — `true` iff `state="attached"` **and** the token validity window has
  not lapsed (re-checks `exp` against the clock + `leeway`, §2.6). `false` for
  expired/detached. Total; never faults.
- **`claims`** — the verified claim-set captured at attach (read-only; for the
  resolver/audit). Carries **no secret** — the raw token is **not** retained (§10.6
  hygiene).
- **`map-claims $claim-set $cfg`** — the **pure** subject→`(principal, tenant)`
  mapping (§2.3), exposed standalone so the mapping is testable without a live IdP
  or a session. Returns `[principal id=… [tenant …]]`, or raises `CXER4802`/`CXER4803`
  on an unresolvable claim-set (the same mapping `attach` runs internally).

### §3.5. Cookie transport + CSRF (the browser surface, NEW)

```
[?def from-cookie  scope=public impure [returns element] ($req::element $cfg::map {}) ...]
[?def set-cookie   scope=public impure [returns element] ($session::element $cfg::map {}) ...]
[?def clear-cookie scope=public pure   [returns element] ($cfg::map {}) ...]
[?def rotate       scope=public impure [returns element] ($session::element) ...]
[?def csrf-token   scope=public pure   [returns string]  ($session::element) ...]
[?def csrf-verify  scope=public impure [returns element] ($req::element $session::element $cfg::map {}) ...]
```

- **`from-cookie $req $cfg`** (§2.8.2) — the cookie-transport resolver: reads the
  session-id cookie from `$req`'s `Cookie` header, returns the live `[session]` by that id,
  or the **absence channel (empty)** when the cookie is missing/unknown/expired/detached
  (§2.5). The cookie analogue of `of` (§3.3); never re-binds, never faults on a missing
  cookie. Impure (reads server state) but capability-free.
- **`set-cookie $session $cfg`** — produces the **`Set-Cookie` directive(s)** for the
  session (the `HttpOnly; Secure; SameSite` session cookie + the readable CSRF companion
  cookie, §2.8/§2.9) to hand to `[$http:respond …]`. Issued automatically by
  `attach-cookie`; exposed standalone for pipelines that write the response separately.
  Refuses an insecure context → `CXER4810`, unsafe flags → `CXER4811` (§2.8.3).
- **`clear-cookie $cfg`** — produces a **clearing `Set-Cookie`** (empty value,
  `Max-Age=0`, matching name/`Path`/`Secure`/`HttpOnly`) for the detach/expiry path
  (§2.8.4). **Pure** — it builds a directive from config only (no session, no state).
- **`rotate $session`** (§2.8.4) — mints a **new** opaque session id (session-fixation
  defense) **and** a fresh CSRF token, invalidates the old id server-side, leaves the
  `(principal, tenant)` binding **unchanged** (§2.3), and returns the updated `[session]`
  (whose new `set-cookie` the caller writes). A no-op on a Bearer-only session.
- **`csrf-token $session`** (§2.9) — the **pure** read of the session's synchronizer CSRF
  token, for the front-end to embed in a page/meta tag/header. On a `[session]` only;
  absence (empty) for a Bearer-only session that never minted one.
- **`csrf-verify $req $session $cfg`** (§2.9) — **constant-time** compares the
  CSRF token submitted on `$req` (the `csrf-header`, default `X-CSRF-Token`, or a form
  field) against the session-stored one. Returns the `[session]` (a present value) on a
  pass; raises `cx-err:CXER4808 E_SESSION_CSRF_MISSING` (no token) / `cx-err:CXER4809
  E_SESSION_CSRF_MISMATCH` (wrong token). A **no-op pass for a Bearer-authenticated
  session** (N-SESSION-7 — keyed on the session's `via`, never a client flag). Impure
  (reads server-held session state).

## §4. Semantics & guarantees (soundness)

### §4.1. Deny-by-default; no identity issuance; no ambient session
No session exists until an `attach` verifies a token (§2.2); there is no
auto-login, no anonymous principal, no ambient "current session" (§2.1). A request
with no token resolves to **absence** (§2.5), never a default principal.

### §4.2. The binding is exact and immutable (hard partition)
`(principal, tenant)` is fixed at first attach and never re-bound (§2.1/§2.3);
the tenant is a hard partition (N-SESSION-2). A mirrored attach that resolves to a
*different* binding is `CXER4805`, not a silent re-key.

### §4.3. Expiry & reaping (lazy; client-independent)
Session validity is bounded by the **verified token `exp`** (plus `leeway`), checked
lazily on `of`/`valid`/accessors — an expired session reports `valid=false` and ops
raise `CXER4804` (§2.6). **Reaping is two independent concerns** (N-SESSION-4):
(a) a **dead client** is removed from `clients` by the transport's
disconnect/heartbeat-miss (a `touch` lapse) — the session is untouched; (b) an
**expired/detached session**'s server state is released on its terminal transition
(`detach`) or on the first post-`exp` access (lazy), with an optional impl
background sweep — but **never** triggered by clients reaching zero. There is no
required background timer; the model is correct under pure lazy evaluation.

### §4.4. attach/detach are auditable events (into `journal`, not owned here)
Every `attach` / `detach` / `detach-client` is emitted as an event into the XAP
`journal` ([`xap.md`](xap.md) §25.1, §22.6), carrying `:actor` (the resolved
principal), `:tenant`, and the client id — so "who attached when, from what client"
is in the hash-chained audit trail for free. session **produces** these events; it
does **not** own the log (no double-implementation of the journal). When run
outside a XAP `journal` context (e.g. a bare unit test), emission is a no-op
(the events have nowhere to go) — the session semantics are unchanged.

### §4.5. Cancellation & closeable contract
A `[session]` satisfies the `[?with-open]` closeable contract (§2.1); its
`on-close` is `detach` (idempotent). An `attach` cancelled mid-JWKS-fetch by a
wrapping `[?timeout]`/`[?cancel]` surfaces the **core `cx-err:CXER0260`** (SAP
§5.2), not a session code; no half-session is established (attach is all-or-nothing,
§2.2). A raw effect after cancel hits `CXER0271` (the `net` effect point, §5).

### §4.6. Token & claim hygiene
The **raw token is never retained** on the `[session]` (only the verified claim-set
is, via `claims`, §3.4) — minimizing credential blast-radius if a session value is
logged or serialized. The `claims` element MUST NOT surface a secret claim; an
integration that needs to strip claims does so in its `principal-map`/`tenant-map`.
A serialized `[session]` is safe to put in the journal (§4.4) precisely because it
carries no live credential.

### §4.7. Cookie credential hygiene + CSRF soundness
The session cookie carries an **opaque session id, never the IdP token** (N-SESSION-5):
a leaked cookie is a revocable handle to server state (killed by `detach`/expiry/`rotate`,
§2.8.4), not a self-contained replayable credential. `HttpOnly` keeps it out of script
reach; `Secure` keeps it off the wire in clear (the §2.4 TLS bright line, extended to the
cookie by `CXER4810`). The CSRF synchronizer token (N-SESSION-6) lives in **server-held
session state** — not derivable from a cookie a forger can write — so cross-site forgery
is defeated even under subdomain cookie-injection (§2.9 justification). **CSRF and
session-auth are orthogonal channels:** a valid session cookie with a missing/wrong CSRF
token is a `CXER4808`/`CXER4809` *fault* (the request is authenticated but unauthorized
to mutate), distinct from an unauthenticated request (absence, §2.5) — no conflation.
Bearer sessions are CSRF-exempt by credential shape (N-SESSION-7), not by a bypass flag.

## §5. Capability integration

Gated transitively by the existing **`net`** capability
([`security.md`](../core/security.md) §2–§4) — **no new capability**, consistent
with `http` ([`http.md`](http.md) §5).

| Operation | Capability | Resource matched |
|---|---|---|
| `attach` / `attach-token` / `attach-cookie` | `net` (transitive, via `crypto`'s JWKS fetch) | the **JWKS source host:port** — matched by `crypto`/`net` when the key-set is fetched over the network (§3.1 `jwks` URL). A literal in-memory `jwks` key-set needs **no** `net` grant (no fetch). The cookie adapter (§2.8) adds **no** new network reach — the cookie/CSRF state is server-held. |
| `detach` / `detach-client` / `touch` / `rotate` | — | server-held state only (no network); `detach` additionally builds a clearing `Set-Cookie` (no I/O of its own) |
| `of` / `by-id` / `by-client` / `from-cookie` / `set-cookie` / `csrf-verify` | — | read/write of server-held session state (no network); cookie (de)serialization is `http`'s |
| `principal` / `tenant` / `clients` / `valid` / `claims` / `map-claims` / `csrf-token` / `clear-cookie` | — | **pure** (§3.4/§3.5) |

session adds **nothing** to the capability model: the only network reach is the
JWKS fetch, which is `crypto`'s effect point under `net`. A denial there raises
`cx-err:CXER0271 E_CAP_DENIED` naming the missing `net` grant + the JWKS host:port,
exactly as `http`/`crypto` surface it. CLI: `cx run --allow-net=idp.example.com:443
FILE`. **Cancellation + revocation** follow `net` / SAP §5.2 (§4.5).

> **session never gains a capability the IdP/crypto layer does not already need.**
> If the JWKS is supplied as a literal key-set (the air-gapped / test posture),
> attach is capability-free — there is no socket to gate.

## §6. Composition with the integration layer

Canonical call form is `[$session:VERB …]` (`[head …]`); this module uses no infix.
The composition with the rest of the XAP stack:

**session feeds `authz` the actor-principal.** The `authz` PEP ([`xap.md`](xap.md)
§22.3, [`authz.md`](authz.md)) decides every intent by checking the
**actor-principal's** authority over a slice in a tenant. That principal comes from
**this module**: the request pipeline resolves the session, reads its principal, and
hands it to the PEP.

```cx
[?match [$session:of $req]
  [case []  [response status=401 …]]                              ; not attached → absence (§2.5)
  [case $s
    [?match [$authz:check                                          ; the PEP reads session's principal/tenant
              {actor:    [$session:principal $s]
               tenant:   [$session:tenant $s]
               intent:   $do
               over:     $slice}]
      [case [err @code='cx-err:CXER4810'] [response status=403 …]] ; authz denial (its band)
      [case $grant …commit the intent…]]]]
```

- **session : authz :: identity : authorization.** session establishes *who*
  (verified, tenant-scoped); authz decides *what they may do*. The two are separate
  modules with separate error bands — session never makes an authorization decision
  (the §6 example's 403 is `authz`'s `CXER48xx` code, not session's).
- **`xap` orchestrates.** The `[$xap:serve]` request pipeline ([`xap.md`](xap.md)
  §25.1) wires `attach`/`of` into the cascade: terminate TLS (gateway) → `of` (or
  `attach` on the auth route) → `authz:check` at the bus PEP → commit. session is a
  step in that pipeline, not the driver.
- **Mirrored attach + collaboration.** A human client and an agent client attach to
  one session (§2.7); both read the same surface ([`xap.md`](xap.md) §21). The
  agent's `[do …]` intents and the human's are authorized against the **same**
  session principal — agent-parity holds at the identity layer too.
- **Browser pipeline (cookie + CSRF).** A browser human client resolves via
  `from-cookie` (§3.5); a state-changing intent then passes `csrf-verify` (a no-op for a
  Bearer client, N-SESSION-7) before the `authz` PEP runs:

```cx
[?match [$session:from-cookie $req]
  [case []  [response status=401 …]]                              ; no/invalid cookie → absence (§2.8.2)
  [case $s
    [?match [$session:csrf-verify $req $s]                        ; CSRF gate (cookie clients; no-op for Bearer)
      [case [err @code='cx-err:CXER4808'] [response status=403 …]]; missing CSRF token
      [case [err @code='cx-err:CXER4809'] [response status=403 …]]; CSRF mismatch
      [case $s2
        [?match [$authz:check {actor: [$session:principal $s2] …}] ; then the usual PEP (§6)
          …]]]]]
```

- **Resilience / lifecycle.** A wrapping `[?timeout]` over `attach` cancels
  cooperatively → `CXER0260` (§4.5); `[?with-open] [session …] $s … ` auto-`detach`es,
  emitting the clearing `Set-Cookie` for a cookie client (§2.8.4).
- **Recovery is `[?else]`/`[?fallback]`/`[?match]`** (SAP §2) — never `[?try]`. A
  rejected token (`CXER4801`) is a *fault* handled by shape; an unattached request
  (absence) is *not* a fault and flows to a 401 by the caller's choice (§2.5/§2.6).

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | TLS transport | non-TLS transport | literal JWKS (no net) |
|---|:--:|:--:|:--:|
| `attach` / `attach-token` / `attach-cookie` | ✅ | ❌ ¹ | ✅ ² |
| `of` / `by-id` / `by-client` / `from-cookie` | ✅ | ✅ ³ | ✅ |
| `detach` / `detach-client` / `touch` / `rotate` / `set-cookie` / `clear-cookie` | ✅ | ✅ ³ | ✅ |
| `principal` / `tenant` / `clients` / `valid` / `claims` / `map-claims` / `csrf-token` | ✅ | — ⁴ | — ⁴ |

| Attach shape | first attach (mint) | mirrored attach (add client) | rebind to different `(principal,tenant)` |
|---|:--:|:--:|:--:|
| same subject, same binding | ✅ (new `[session]`) | ✅ (add `[client]`) | — |
| different binding | — | — | ❌ ⁵ |

| Token outcome | verified | expired/bad-sig/wrong-aud | no token presented |
|---|:--:|:--:|:--:|
| `attach` | ✅ session | ❌ ⁶ `CXER4801` | ❌ ⁷ `CXER4807` |
| `of` (resolve only) | ✅ session | — ⁸ | — ⁸ (absence, §2.5) |

| Identity concern | session | external IdP |
|---|:--:|:--:|
| token *verify* | ✅ (delegated to `crypto`) | — |
| token *mint* / login / refresh / IdP-logout | ❌ ⁹ | ✅ |

| Attach transport | session cookie issued | CSRF token issued | `csrf-verify` on state-changing intent |
|---|:--:|:--:|:--:|
| **cookie** (`attach-cookie`, browser §2.8) | ✅ (`HttpOnly; Secure; SameSite=Lax`) | ✅ (synchronizer, §2.9) | ✅ required (`CXER4808`/`CXER4809` on miss/mismatch) |
| **Bearer** (`attach`/`attach-token`, agent §2.2) | — ¹⁰ | — ¹⁰ | ✅ no-op pass ¹¹ (CSRF-exempt, N-SESSION-7) |

| Cookie issuance context | TLS + safe flags | non-TLS | `HttpOnly` off / `SameSite=None` (no opt) |
|---|:--:|:--:|:--:|
| `attach-cookie` / `set-cookie` | ✅ | ❌ ¹² `CXER4810` | ❌ ¹³ `CXER4811` |

Footnotes: **1** non-TLS attach → `CXER4806` (§2.4); only `allow-insecure=true`
dev-mode bypasses, never the app-role default — pinned by a negative fixture.
**2** a literal in-memory JWKS needs no `net` grant (§5) — the air-gapped/test
posture. **3** resolve/detach/touch read or release already-held state; they need no
secure transport (the *attach* that established it did). **4** pure accessors over a
materialized value — transport-independent. **5** a mirrored attach resolving to a
different `(principal, tenant)` → `CXER4805` (§2.1/§4.2); the binding is immutable,
never re-keyed. **6** verification fault → `CXER4801` carrying the `crypto` fault
(§2.6). **7** `attach` with no `Authorization` token → `CXER4807` (attach is
affirmative; callers gate on `of` first, §3.2/§2.5). **8** `of` never faults on a
missing/bad token — it returns **absence** (§2.5); only the affirmative `attach`
faults. **9** identity issuance is the IdP's, never session's (N-SESSION-1, §1).
**10** a Bearer client sends its token per request and holds no ambient cookie, so no
session cookie / CSRF token is issued for it (§2.2/§2.9). **11** `csrf-verify` is a
no-op pass for a Bearer-authenticated session — the exemption is keyed on the session's
`via` marker (§2.1), never a client-supplied flag (N-SESSION-7); a cookie request cannot
opt out by claiming Bearer, and a request with **both** is treated as cookie-auth (the
safe default). **12** issuing a `Secure` cookie over a non-TLS request → `CXER4810`
(§2.8.3), the cookie-side of the §2.4 TLS bright line; only `allow-insecure=true`
dev-mode bypasses. **13** dropping `HttpOnly` or setting `SameSite=None` without the
explicit cross-site embedding opt → `CXER4811` (§2.8.3) — the adapter refuses to mint a
script-readable or ambiently-cross-site session credential.

Cognate-coverage: every lifecycle verb ships for the `[request]`-driven
(`attach`/`of`), raw-token (`attach-token`/`by-id`), **and browser-cookie**
(`attach-cookie`/`from-cookie`) paths; every accessor works on a materialized
`[session]`; the cookie transport ships its full lifecycle (issue `set-cookie`, resolve
`from-cookie`, rotate `rotate`, clear `clear-cookie`) and its CSRF pair
(`csrf-token`/`csrf-verify`). The intentional asymmetries (non-TLS attach refused,
insecure/unsafe cookie refused, Bearer CSRF-exempt by credential shape, no identity
issuance, no rebind) are justified above and each is a **documented guarantee of this
revision**, pinned by a negative fixture — not an open cell.

## §8. Error codes — `CXER4800–CXER4849` band (proposed allocation)

`CXER4800–CXER4849` is the **proposed allocation** for `cx-stdlib/session` in the
governance registry ([`governance.md`](../process/governance.md) §9.6) — the next
free block above `cx-stdlib/http`'s `CXER4525–4543` (this draft does **not** edit
the registry; the allocation is reserved at graduation, §11). All values use
`cx-err:` notation; symbolic↔wire is 1:1 (governance invariant). **Cancellation is
the core `CXER0260`, not a session code** (§4.5); **capability denial is the core
`CXER0271`** (§5).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4801` | `E_SESSION_TOKEN_REJECTED` | the presented token failed `[$crypto:jwt-verify]` — bad signature / `exp` / `nbf` / `aud` / `iss` / malformed; carries the verbatim `crypto` JWT fault as a child (§2.2/§2.6) |
| `cx-err:CXER4802` | `E_SESSION_TENANT_UNRESOLVED` | a verified claim-set resolves to no tenant, or a tenant the runtime does not host (§2.3) |
| `cx-err:CXER4803` | `E_SESSION_PRINCIPAL_UNRESOLVED` | a verified claim-set resolves to no principal (§2.3) |
| `cx-err:CXER4804` | `E_SESSION_INVALID` | an op on an `expired` or `detached` session (§2.1/§2.6) |
| `cx-err:CXER4805` | `E_SESSION_REBIND_REFUSED` | a mirrored attach whose token resolves to a *different* `(principal, tenant)` than the live session's immutable binding (§2.1/§2.7/§4.2) |
| `cx-err:CXER4806` | `E_SESSION_INSECURE_TRANSPORT` | `attach` over a non-TLS transport without `allow-insecure=true` (§2.4, N-SESSION-3) |
| `cx-err:CXER4807` | `E_SESSION_NO_TOKEN` | `attach $req …` with no `Authorization: Bearer` token (affirmative attach; the no-token=unauthenticated posture is `of`'s **absence**, not this fault — §2.5/§3.2) |
| `cx-err:CXER4808` | `E_SESSION_CSRF_MISSING` | a state-changing intent from a **cookie-authenticated** client carries **no** CSRF token (`csrf-verify`, §2.9/N-SESSION-6) |
| `cx-err:CXER4809` | `E_SESSION_CSRF_MISMATCH` | the submitted CSRF token does not match the session-stored synchronizer token (constant-time compare, §2.9) |
| `cx-err:CXER4810` | `E_SESSION_COOKIE_INSECURE_CONTEXT` | issuing the session cookie over a **non-TLS** request (so `Secure` cannot be honored) without `allow-insecure=true` (§2.8.3, the cookie-side of the §2.4 TLS bright line) |
| `cx-err:CXER4811` | `E_SESSION_COOKIE_UNSAFE_FLAGS` | a cookie config that would drop `HttpOnly`, or set `SameSite=None` without the explicit `allow-cross-site-cookie` opt (§2.8.3) — refusing a script-readable / ambiently-cross-site session credential |

`CXER4800` is **reserved** as the band's `E_SESSION_*` anchor (unused this revision,
held for a future generic session fault). `CXER4812–CXER4849` are **unallocated**
(reserved for the band; e.g. a future step-up / re-authentication flow, §13).

**Shared/core codes session surfaces (not in its band):** `cx-err:CXER0271`
(capability denial on the JWKS fetch, §5); `cx-err:CXER0260` (cancellation, §4.5);
`cx-err:CXER0108` never raised (the session is closeable, §2.1). **Inherited faults
(propagate as-is, not remapped):** the **`crypto` JWT verify** fault wrapped inside
`CXER4801` (its own band, per [`stdlib_crypto_jwt_amendment.md`](stdlib_crypto_jwt_amendment.md));
**`net` transport faults** from the JWKS fetch (`CXER45xx`, via `crypto`/`http`);
**`authz`** denials (`CXER48xx` in its own band — the PEP's, §6, never session's).

session owns **identity-session** faults only; it raises **no** authorization fault
(that is `authz`'s, §6) and **no** transport/crypto fault (those are inherited,
above) — the band stays thin, matching the thin module.

## §9. Implementation notes (non-normative) — composing crypto + http + journal

| session surface | Building block | Note |
|---|---|---|
| `attach`/`attach-token` token verify | `[$crypto:jwt-verify $token $cfg]` ([`stdlib_crypto_jwt_amendment.md`](stdlib_crypto_jwt_amendment.md)) | the **only** crypto; JWKS fetch + key rotation + cache are the amendment's, gated by `net` |
| token read from request | `[$http:header $req 'Authorization']` (`http` §3.4) + `Bearer ` strip | latin-1 header value, single header; obs-fold already rejected by `http` |
| TLS precondition (§2.4) | inspect the carrying `[$http:serve]` listener's bind scheme (`tls://`) or a gateway TLS-attested marker | session reads the posture; it never wraps TLS |
| session store (server-held state) | an in-process tenant-rooted map keyed by session id, under internal sync; per-tenant worker owns its own ([`xap.md`](xap.md) §14.1/§22.7) | mirrored-attach client set is a sub-map; `touch` updates last-seen; the opaque session id (§2.8) is the map key |
| opaque session id (§2.8) + CSRF token (§2.9) | ≥128-bit CSPRNG via `cx-stdlib/crypto` random bytes → base64url | the id is the cookie value + store key; the CSRF token is a sibling secret held in the session record (not `HttpOnly`-restricted on the wire — the front-end reads it) |
| session/CSRF cookie wire | `cx-stdlib/http` `Set-Cookie`/`Cookie` (de)serialization (`http` §3.4) | session chooses the attributes (`HttpOnly; Secure; SameSite; __Host-`); http serializes; `from-cookie` parses the named cookie out of the request |
| `csrf-verify` compare | `cx-stdlib/crypto` constant-time `bytes` compare | gated on the session's `via=cookie`; a `via=bearer` session is a no-op pass (N-SESSION-7) |
| expiry / reaping (§4.3) | lazy `exp` check on access; optional background sweep | no required timer; client-reap is the transport's heartbeat, independent of session reap |
| attach/detach audit events (§4.4) | emit into `cx-stdlib/journal` `[$journal:append …]` | no-op when no journal context; session does not own the log |
| `session-lost` read-model (§2.7) | expose `clients` + last-seen | the predicate itself is `authz`'s signed library ([`xap.md`](xap.md) §22.8), not here |

Spec is implementation-agnostic; only surface + guarantees are normative. The
per-tenant worker owning its own session store is what makes the tenant hard
partition (N-SESSION-2) structural rather than checked: a worker has no map for
another tenant's sessions to begin with ([`xap.md`](xap.md) §22.6/§22.7).

## §10. Conformance fixtures (to author on graduation)

Hermetic, loopback-only (a test IdP signing a JWT with a local key; a literal JWKS
key-set so most fixtures need **no** `net`). **Every matrix ✅ has ≥1 positive
fixture; every justified ❌ a negative fixture.**

Positives: a valid token → `attach` mints a `[session]` bound to the mapped
`(principal, tenant)`; `principal`/`tenant`/`valid`/`claims` read back the binding;
`map-claims` is **pure** (same claim-set → same `(principal, tenant)`, no IdP);
**`of` on an attached request returns the `[session]` value**, **`of` on an
unattached request returns absence (empty node-set), NOT `null` and NOT an error**
(§2.5); **mirrored attach** — a second `attach` for the **same** subject adds a
`[client]` to the **same** session (not a new one) and `clients` lists both in
order; **session survives client death** — `detach-client` (or a transport drop)
removes one client, the session stays `"attached"` at one and then **zero** clients,
and a re-attach lands on the **same** live session; `detach` tears the whole session
down (terminal `"detached"`), idempotent; `touch` updates last-seen; `[?with-open]`
auto-`detach`; **literal JWKS attach is capability-free** (no `net` grant needed);
attach/detach **emit journal events** carrying `:actor`/`:tenant`/client-id (when a
journal context is present).

**Cookie transport (§2.8):** a valid token → `attach-cookie` mints a `[session]` bound
to the mapped `(principal,tenant)` **and** returns a `Set-Cookie` carrying an **opaque id
(NOT the raw token)** with the default `HttpOnly; Secure; SameSite=Lax; __Host-cxsid`
flags; **`from-cookie` on a request carrying that cookie returns the same `[session]`**,
and **`from-cookie` with no/unknown/expired cookie returns absence (empty), NOT `null`
and NOT an error**; `rotate` mints a **new** id (old id no longer resolves) while
`principal`/`tenant` are **unchanged** (binding immutable); `detach` emits a **clearing
`Set-Cookie`** (`Max-Age=0`) and the old id no longer resolves; a browser cookie client
and a Bearer agent **mirror-attach to the same session** (§2.7) with distinct `via`
markers.

**CSRF (§2.9):** a cookie-authenticated state-changing intent with a **matching** CSRF
token (in `X-CSRF-Token`) → `csrf-verify` **passes** (returns the `[session]`); the
`csrf-token` read returns the embeddable token; rotation re-issues it (old token no
longer verifies). **Bearer-exempt:** a Bearer-authenticated session → `csrf-verify` is a
**no-op pass** even with **no** CSRF token present (N-SESSION-7), and a request carrying
both a cookie and a Bearer token is treated as cookie-auth (CSRF required).

Negatives: bad-signature / expired (`exp` past) / wrong-`aud` / wrong-`iss` /
malformed token → **`CXER4801` carrying the verbatim `crypto` JWT fault**;
claim-set with no resolvable tenant → `CXER4802`; with no resolvable principal →
`CXER4803`; op on an **expired** session (token window lapsed) → `CXER4804` +
`valid=false`; op on a **detached** session → `CXER4804`; **mirrored attach
resolving to a different `(principal, tenant)`** → **`CXER4805`** (binding immutable,
no silent re-key); **non-TLS attach** without `allow-insecure` → **`CXER4806`**;
**`attach` with no `Authorization` token** → `CXER4807` (and contrast: `of` with no
token → **absence**, not a fault); **JWKS fetch with no `net` grant** → `CXER0271`
naming the IdP host:port; `[?timeout]` cancellation mid-attach → inner `CXER0260`
(no half-session established). Inherited transport negatives (JWKS host unreachable
`CXER45xx`) exercised through `net`/`crypto`. **Cookie/CSRF negatives:** a
cookie-authenticated state-changing intent with **no** CSRF token → **`CXER4808`**; with
a **wrong** CSRF token → **`CXER4809`** (and contrast a *matching* token → pass);
`attach-cookie` over a **non-TLS** request without `allow-insecure` → **`CXER4810`**; a
cookie config dropping `HttpOnly` or setting `SameSite=None` without
`allow-cross-site-cookie` → **`CXER4811`**.

## §11. Graduation checklist (executor → user G3)

- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6):
      add `CXER4800–CXER4849 | cx-stdlib/session | spec/std-lib/session.md` (the
      next free block above http's `CXER4525–4543`); re-run the band scan (confirm
      no overlap with http's band or `authz`'s allocation).
- [ ] **Module index + count.** Add a `session` row to
      [`spec/std-lib/README.md`](../std-lib/README.md) §3 (Tier-B) and bump the
      module count by **+1 on the then-current count** (order-independent with the
      other in-review XAP modules — `bus`/`journal`/`authz`/`xap` — and with
      `net`/`fp`/`http`; each graduation applies +1 to whatever the count is then).
      Add `'cx-stdlib/session'` to the skeleton test
      (`vcx/tests/v08_stdlib_skeleton_test.v`) bundled-name list + bump its assert.
- [ ] **Add the stub / real bodies** for the full §3 surface:
      `attach`/`attach-token`/**`attach-cookie`**/`detach`/`detach-client`/`touch`;
      `of`/`by-id`/`by-client`/**`from-cookie`**; `principal`/`tenant`/`clients`/`valid`/
      `claims`/`map-claims`; **`set-cookie`/`clear-cookie`/`rotate`/`csrf-token`/
      `csrf-verify`** (the cookie + CSRF surface, §3.5).
- [ ] **Cookie/CSRF dependencies:** confirm `cx-stdlib/http` exposes `Set-Cookie`/`Cookie`
      header (de)serialization (incl. `__Host-` prefix attributes) for `set-cookie`/
      `from-cookie` to compose (§2.8), and that `cx-stdlib/crypto` exposes CSPRNG bytes
      (opaque id + CSRF token, §9) and a constant-time `bytes` compare (`csrf-verify`,
      §2.9). The cookie adapter adds **no new capability** (server-held state only, §5).
- [ ] Confirm session's reliance on the §0 in-review amendments survived their G3
      (the **`crypto` JWT/JWKS amendment** — hard dependency; the four-channel model
      incl. **absence-vs-fault**; `[?try]` retirement; `CXER0260` cancellation;
      orthogonality-guard home).
- [ ] **`cx-stdlib/crypto` JWT/JWKS amendment must graduate first** (hard dependency
      — `attach` is meaningless without it) — as must **`cx-stdlib/http`** (transport)
      and **`cx-stdlib/net`** (capability layer).
- [ ] Coordinate with **`cx-stdlib/authz`** ([`authz.md`](authz.md)):
      confirm the PEP reads `[$session:principal]`/`[$session:tenant]` as its
      actor/tenant inputs (§6), and that the `session-lost` incapacity predicate
      ([`xap.md`](xap.md) §22.8) folds over this module's `clients`/last-seen
      read-model.
- [ ] Coordinate with **`cx-stdlib/journal`**: attach/detach event shape (§4.4) +
      no-op-without-context behavior.
- [ ] Author §10 fixtures; wire into the gate.
- [ ] Validate repo-relative cross-references render (note: several siblings —
      `stdlib_crypto_jwt_amendment.md`, `authz.md`, `xap.md` — are
      themselves in-review; cross-refs resolve once they land).
- [ ] Move `spec/02-inprogress/xap/session.md` → `spec/std-lib/session.md`
      (user-only).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states how `session` affects the module count; per Rule G3 it makes
**no edits**.

`session` is one of the **five new thin XAP modules** ([`xap.md`](xap.md) §25.1) —
a genuine **+1** to the bundled-name surface at its graduation (unlike `http`, which
was already a bundled name and is a *reconciliation*; [`http.md`](http.md)
§12). It is **not yet bundled** (absent from the skeleton test's expected list
today), so at graduation it adds its name to
`vcx/tests/v08_stdlib_skeleton_test.v`'s list **and** bumps that test's assert by 1,
and adds a README §3 Tier-B row + bumps the README intro/frozen-surface counts — all
+1 on whatever the count is at that moment (order-independent with the other XAP
modules and the in-review `net`/`fp`). **No edits are made by this draft** (G3) — the
graduation PR (§11) applies them.

## §13. Noted future revision — step-up / re-authentication (NOT this revision)

**Step-up authentication** (forcing a fresh, higher-assurance re-auth — a second factor,
a recent-login check — before a high-risk intent, surfaced via the OIDC `acr`/`amr`
claims) is a **noted future revision**, not in v1. The v1 hook that makes it cheap to
add later already exists: `rotate` (§2.8.4) re-keys the session id + CSRF token on a
privilege change, so a step-up flow would (a) drive an IdP re-auth (the IdP's job, §1),
(b) re-`attach`/`attach-cookie` with the elevated token, and (c) `rotate`. What v1 does
**not** do is *orchestrate* the IdP step-up handshake or carry an `acr`/`amr` policy
gate — that is the integration's / a future revision's concern, reserving
`CXER4812–CXER4849` (§8). v1 ships the **session-fixation** half (rotate-on-elevation)
without the IdP-flow half.

---

### Review questions — RESOLVED (user G3, 2026-06-07)

**All resolved (a) as drafted:** (1) a no-token `attach` faults `CXER4807` while `of` returns absence — keep the act-vs-query split; (2) the Bearer→live-session mechanism stays impl-internal (the cookie path is already settled to an opaque server-issued id); (3) the `session-lost` *predicate* stays in `authz`'s one signed library, session exposes only the `clients`/last-seen read-model; (4) CSRF uses the **synchronizer-token** pattern (server-stored, constant-time); (5) the session cookie defaults to `SameSite=Lax` with `Strict` available via `cookie-same-site`. Rationale for each below.


1. **`attach` no-token: fault vs absence (`CXER4807` vs empty).** This draft makes
   the **affirmative `attach`** raise `CXER4807` when no `Authorization` token is
   present, while **`of`** returns absence (§2.5/§3.2) — the split being "`of` is a
   *query* (no token = not-yet-authenticated = absence), `attach` is an *act* (you
   asked to attach but gave nothing = a usage fault)." (a) **Keep the split** (a
   no-token `attach` is a fault; callers gate on `of` first) — *recommended*, it
   keeps `attach` an unambiguous affirmative and reserves the absence channel for the
   query path, matching `http`'s "an affirmative op faults; the inspect path flows."
   (b) Make `attach` *also* return absence on no-token (drop `CXER4807`) — simpler
   one-call pipelines but conflates "you didn't authenticate" with "you called attach
   wrong," and weakens the §2.5 no-conflation guard. **Recommend (a).**

2. **`of` (Bearer) resolution mechanism — token re-verify vs opaque session id.** §3.3
   leaves *how* a **Bearer** request maps to its live session impl-internal (re-verify
   the bearer token each request, or carry an opaque server-issued session id). (Note:
   the **cookie** transport is now settled — `from-cookie` resolves via the opaque
   server-issued session id, §2.8; this question is only about the Bearer path.) (a)
   **Leave the Bearer mechanism impl-internal** (this draft) — *recommended*; the surface
   guarantee ("`of` → the `[session]` or absence") is stable either way, and pinning it
   now pre-empts the `authz`/`xap` pipeline design. (b) Mandate re-verify-per-request
   (stateless-ish, no server session id) — strong revocation story but taxes every
   request with a crypto verify and complicates mirrored-attach client tracking. (c)
   Mandate an opaque session id for Bearer too (header-carried) — cheap per-request and
   symmetric with the cookie path, but loses Bearer's stateless-verify option.
   **Recommend (a)** and let the `xap` pipeline spec settle it.

4. **CSRF pattern — synchronizer-token (this draft) vs double-submit-cookie.** §2.9
   adopts the **synchronizer-token** pattern (server-stored CSRF secret, constant-time
   compared) over stateless double-submit. (a) **Synchronizer-token** (this draft) —
   *recommended*; session already holds server-side state (§2.1), so the authoritative
   CSRF copy lives where a forger cannot write it, defeating subdomain cookie-injection
   that breaks double-submit (§2.9 justification); zero extra infra here. (b)
   Double-submit-cookie — stateless and simpler for a stateless backend, but session is
   *not* stateless (it holds the session store), and double-submit's read-the-cookie
   assumption fails under cookie-tossing / sibling-subdomain injection. **Recommend (a).**

5. **CSRF `SameSite` default — `Lax` (this draft) vs `Strict`.** §2.8 defaults the
   session cookie to `SameSite=Lax`. (a) **`Lax`** (this draft) — *recommended*; it
   blocks cross-site state-changing requests (the CSRF vector) while preserving
   top-level link-in UX (a user following a link into the app stays logged in), and the
   synchronizer token (§2.9) is the actual guarantee regardless. (b) **`Strict`** —
   marginally stronger (withholds the cookie even on top-level inbound navigation) but
   breaks the common "click a link in an email → land logged-in" flow; offered as a
   per-deployment opt (`cookie-same-site`), recommended for pure-API origins.
   **Recommend (a)** with `Strict` available by config.

3. **`session-lost` read-model ownership.** §2.7/§9 put the `clients`+last-seen
   *read-model* here and the `session-lost` *predicate* in `authz`'s signed library
   ([`xap.md`](xap.md) §22.8). Confirm that division at G3 — (a) **as drafted**
   (session exposes data, authz owns the predicate) — *recommended*, it keeps the
   safety-critical predicate in the one signed/vetted library per `xap.md` §22.8 and
   session thin. (b) Move the predicate evaluation into session — rejected: it would
   split the incapacity-predicate trusted surface across two modules, against
   `xap.md` §22.8's "one signed library." **Recommend (a).**
