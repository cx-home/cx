# Rulings — reusable OIDC relying-party flow (#1090)

2026-08-28, release/0.18. Campaign umbrella #1097, workstream C. Filed
prio:high: this is the LOGIN half of enterprise SSO. The verify half is
already enterprise-grade (crypto.md §3.10), and #1093's J-3 signing work
removed the last blocker — `private_key_jwt` now has its primitive.

Recorded BEFORE the work, per the ledger discipline. Letters carry
recommendations and proceed under the standing letter-acceptance order
(feedback_standing_letter_acceptance_partition); an owner override
reverses the letter, not the process.

## O-0 — a correction the survey depends on

crypto.md §3.10 carries an "Implementation tier (this revision)" note
saying `jwks-fetch`'s live GET is deferred because http/net serve only a
"synthetic engine that returns no response body". **That note is stale.**
`crypto_jwks_fetch` routes through `http_request_verb`, and http.md's own
status checklist records the client as DONE — real HTTP/1.1 over the
`cx-stdlib/net` TCP core, real `https://` over the mbedTLS layer with
verification against the OS trust store. The stale note must be corrected
as part of this lane, because the whole shape of an OIDC RP depends on
whether discovery and token exchange can actually dial.

## O-1 — where the surface lives (RULED: O-1 = a)

- (a) **A new Ring-1 module `cx-stdlib/oidc`**, composing `http`,
  `crypto`, `json` and `random`. RECOMMENDED and taken: an OIDC flow is a
  sequence of value transformations — build a URL, exchange a code,
  validate a token — not control flow, and a module is what other
  features can `[?lib]` without taking on a directive.
- (b) A directive family `[?oidc-…]` — rejected. Directives are for
  control flow and binding forms. CX already has `[?http-client]` for
  directive-shaped transport, so a second transport directive family is
  exactly the "silent dual HTTP stack" http.md warns against.
- (c) Extend `cx-stdlib/session` — rejected. `session` is Ring 2 and is
  the claim-set CONSUMER; making it the IdP client inverts the dependency
  and drags Ring 2 into every relying party that only needs to log a user
  in.

## O-2 — the shape that makes the flow hard to get wrong (RULED: O-2 = a)

The single most common way an OIDC integration is broken is a forgotten
binding: no `nonce`, no PKCE verifier, no `at_hash` check. A surface of
loose helpers invites exactly that.

- (a) **Two composite verbs carry the whole dance, with the low-level
  verbs also exposed.** `begin` produces everything a redirect needs in
  ONE impure call; `complete` takes that value back with the callback
  parameters and will not proceed unless the bindings match. RECOMMENDED
  and taken — a caller cannot omit the nonce, because they never
  generated it separately.
- (b) Only low-level helpers — rejected: correct composition becomes the
  caller's problem, per feature, forever.

```
[?def begin    scope=public impure [returns element] ($config::element $opts::map {}) ...]
[?def complete scope=public impure [returns element] ($config::element $request::element $callback::map $client-auth::element $now::datetime $opts::map {}) ...]
```

`begin` returns `[auth-request url="…" state="…" nonce="…" code-verifier="…"]`;
the caller redirects to `url` and persists the rest. `complete` exchanges
the code, validates the ID token against `request`, and returns
`[tokens access="…" refresh="…" expires-at=… [claims …]]`.

## O-2b — discovery splits from configuration (RULED: O-2b = a)

- (a) **`discover` (impure) returns provider metadata; `config` (pure)
  combines it with the caller's own client identity.** RECOMMENDED and
  taken. `discover` fetches the well-known document AND the JWKS it
  names, so one value carries everything verification needs — the
  fetch-once / verify-many seam again. A deployment that already holds
  provider metadata (its own config, or a cached `discover` result)
  skips the network entirely and builds `[oidc-provider …]` directly.
  That is the whole point of the split, and it is what keeps the module
  usable in an air-gapped or fixture context.
- (b) One `discover` that also takes client-id/redirect-uri — rejected:
  it welds the caller's identity to a network fetch, so nothing can be
  cached and nothing can be built offline.

`discover` ALSO refuses when the document's own `issuer` does not equal
the requested issuer exactly (CXER5301). That is the IdP mix-up check,
and it is the reason discovery is a verb rather than a URL fetch.

## O-3 — the module stores nothing (RULED: O-3 = a)

No discovery cache, no state store, no token store. `begin` hands back
the values it generated; the caller persists them (that is what `session`
is for), and `discover` returns a value the caller may cache. Same
posture as #1093's J-3 on private keys: **lifecycle is not a codec's
job**, and a hidden cache would also break purity for the offline half.

## O-4 — the purity split (RULED: O-4 = a)

Mirrors the §3.10 fetch-once / verify-many seam, which is what lets the
security-critical half be tested hermetically:

- **Pure**: `authorize-url`, `pkce-challenge`, `validate-id-token`,
  `parse-callback`, `logout-url`, `verify-logout-token`. `now` is passed
  in; no clock read.
- **Impure (`net`)**: `discover`, `exchange-code`, `refresh`.
- **Impure (`random`)**: `begin` alone — it is the only source of the
  `state` / `nonce` / `code-verifier` triple, generated internally so
  reuse-by-mistake is structurally impossible (§3.7's AEAD-nonce
  reasoning, and #1093's RFC 6979 reasoning).

## O-5 — client authentication (RULED: O-5 = a)

Client auth is a VALUE, not a config flag:
`[client-auth method=:secret-basic secret="…"]`,
`[client-auth method=:secret-post secret="…"]`,
`[client-auth method=:private-key-jwt key=[ec-private-key …] kid="…"]`,
`[client-auth method=:none]` (public client — permitted ONLY with PKCE).
`private_key_jwt` composes `crypto:jwt-sign` (#1093 J-3) and is why that
item was sequenced first.

## O-6 — what is REFUSED, permanently (RULED: O-6 = a)

Recorded so these are decisions, not gaps:

- **Implicit and hybrid flows** — tokens in the URL fragment; removed by
  OAuth 2.1 and unsafe to make convenient.
- **Resource-owner password credentials grant** — hands the user's
  password to the RP, which is the thing OIDC exists to avoid.
- **Dynamic client registration** — no live consumer
  (seam-needs-live-consumer); registration is an operator step.
- **`alg: "none"` and HS\*** — inherited from #1093's J-4, unchanged.
- **PKCE `plain`** — S256 only.

## O-7 — ID-token validation beyond jwt-verify (RULED: O-7 = a)

`jwt-verify` answers "is this token validly signed and current". An RP
must additionally check, fail-closed: `nonce` equals the one `begin`
generated; `iss` matches the discovery document's issuer EXACTLY (not a
prefix); `aud` contains the client id; `azp` equals the client id when
`aud` has more than one value; `at_hash` / `c_hash` bind the ID token to
the access code and token; `auth_time` honours `max_age` when requested.
Each failure is its own code — an integration that cannot tell "wrong
nonce" from "expired" cannot be debugged.

## O-8 — error band (RULED: O-8 = a)

**`CXER5300–5399` allocated to `cx-stdlib/oidc`.** Verified free: the
occupied blocks stop at 52xx (zip, #1078).

## Execution order

Spec at `spec/03-approved/std-lib/oidc.md` + the README index row, then
`conformance/stdlib/oidc.cxd` fixture-first, then the implementation —
the #1078 order. The hermetic half (`authorize-url`, `pkce-challenge`,
`validate-id-token`, `verify-logout-token`) is fully testable offline and
carries the security weight; the three networked verbs are pinned against
a cx-served local IdP stub rather than a real tenant, so the corpus keeps
no external dependency.
