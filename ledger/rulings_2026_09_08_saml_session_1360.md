# Rulings — a verified SAML assertion becomes a session (#1360)

2026-09-08, release/0.18. Campaign umbrella #1097 (enterprise SSO), tracker
#1354. Ruled by Fable + owner at 15:20 ET; recorded here before the work,
per the ledger discipline. Commits carry `RULED: 1360-a, 1360-b`.

## The gap, measured

`stdlib/session.cx` had five attach paths (`attach`/`attach-token` Bearer
JWT via `crypto:jwt-verify`, `attach-did`, `attach-cookie`, `attach-xsp`,
`attach-guest`), all running verify → `map-claims` → bind → mirror-attach
fail-closed (session.md §2.2). `stdlib/saml.cx` had `verify → assertion →
validate → attributes / name-id` and, by design, no verb that yields an
unverified element (saml.md §4.4). **Nothing connected the two.**
Measured at `82f222963`: `grep -ci 'saml\|assertion' stdlib/session.cx` →
0, and `grep -rn 'attach-saml\|saml:claims'` over the whole tree → 0. So a
SAML-only enterprise IdP could be verified and could not become a session
principal in an XAP host.

## 1360-a — `saml:claims`, a PUBLIC PURE projection

`[$saml:claims $assertion $opts {}] -> element` yields the `[claims …]`
value in EXACTLY the shape `crypto:jwt-verify` yields (crypto.md §3.10):

| claim | source |
|---|---|
| `iss` | `Issuer` |
| `sub` | `Subject/NameID` value |
| `aud` | `AudienceRestriction/Audience` |
| `exp` | `Conditions/@NotOnOrAfter` |
| `nbf` | `Conditions/@NotBefore` |
| `iat` | `@IssueInstant` |

plus attribute-derived claims through `opts.attrs`, a map from claim name
to SAML attribute `Name` (e.g. `{tid: 'urn:acme:tenant', groups:
'urn:acme:groups'}`). A multi-valued attribute yields a sequence, a
single-valued one the scalar. Like `attributes` and `name-id` it PROJECTS
and does not verify; the fail-closed property lives in 1360-b. `crypto`'s
`claim` reads the result unchanged.

**Refused (b): a generic `attach-claims` that trusts pre-verified claims.**
It deletes the module's central property (session.md §2.2: attach RUNS
verify; nothing attaches a claim set it did not verify) and would be the
one entry point a fabricated `[claims]` could walk through.

**Refused (c): `attach-saml` with the mapping private.** The mapping is
where every SP login's correctness lives — tenant, groups, expiry — so it
must be a fixture-testable pure verb, reusable by a deployment's own ACS
handler and by SCIM correlation.

### Three points the ruling left open, settled here on the long-term-best standard

Recorded because they are decisions, not transcription, and a later reader
must be able to tell which is which.

1. **"EXACTLY the shape" is implemented as literal shared construction,
   not as an imitation.** `saml_claims_verb` builds the claim-set map and
   hands it to `crypto_build_claims` — the very function
   `crypto:jwt-verify` calls (`vcx/code/stdlib_crypto.v:2829`). The shape
   therefore cannot drift from the JWT one by construction, rather than by
   two code paths agreeing today. This also fixes the typing for free:
   `exp`/`nbf`/`iat` are **integers** (JWT NumericDate, epoch seconds), not
   xs:dateTime strings, because that is what the JWT shape carries and what
   `session_claims_exp` reads. A SAML xs:dateTime is converted at the
   boundary.

2. **A multi-valued claim is an attribute only when it is scalar.**
   That is not a new rule — `crypto_build_claims` lifts a registered claim
   to an attribute only through `crypto_jstr`, which answers `none` for a
   sequence, so a multi-valued value lives in the `[payload]` child and is
   read back by `crypto:claim`. `groups` therefore never appears as an
   attribute, and neither does an `aud` with two `Audience` children. This
   is inherited, not invented, and `session_claim_str`
   (`vcx/platform/stdlib_session.v:269`) already reads attribute-first with
   a payload fallback, so tenant resolution works either way.

3. **`opts.attrs` naming a registered claim is REFUSED (CXER5408), not
   silently overridden.** The ruling says "plus attribute-derived claims",
   which does not say what happens on a collision. Both orderings are
   implementable and both are wrong to leave silent: letting an attribute
   overwrite `sub` means an IdP attribute can redirect the principal with
   no diagnostic, and letting the registered claim win means a deployment
   that configured `{sub: 'urn:acme:uid'}` is quietly ignored. Refusing is
   the only total answer that cannot mint the wrong principal, and it is
   the caller's own error, which is what CXER5408 names.

## 1360-b — `session:attach-saml`, the fifth attach path, verification IN-PATH

`[$session:attach-saml $xml::string $keys::[sequence element] $cfg::map
$client::map {}] -> element`, impure. It runs `saml:verify → assertion →
validate → claims → map-claims → bind → mirror-attach` and refuses at the
FIRST fault with the saml module's own code (CXER5400…5411) or session's
(CXER48xx), exactly as `attach-token` refuses on `jwt-verify`'s.
`validate`'s `now`, `audience`, `recipient` and `in-response-to`, and
`claims`'s `attrs`, come from `cfg.saml`; `cfg.tenant-claim` keeps its
meaning. Replay defense (saml.md §9) stays the deployment's, stated in the
attach-path row.

**One point settled here:** the ruling's "with the saml module's own code
… exactly as `attach-token` refuses on `jwt-verify`'s" reads two ways,
because `attach-token` in fact WRAPS the crypto fault as CXER4801 with the
verbatim fault as a `[cause]` child (`stdlib_session.v:454`). The literal
sentence — saml's own code — is what ships: a saml refusal is returned
unchanged, and only faults arising in session's own half (tenant
unresolved, principal unresolved, insecure transport) carry a CXER48xx.
"Exactly as `attach-token`" is honored as the fail-closed MANNER (refuse at
the first fault, mint nothing), which is the part of that sentence that
carries the safety property. Stated out loud because the alternative
reading is defensible and a later reader should not have to guess which
one was taken.

## Fixtures owed (fixture-first, red at HEAD)

- SAML login → `[principal id=… [tenant id=…]]`, `groups` a sequence.
- `NotOnOrAfter` in the past → refused with saml's expiry code, NO session.
- `Audience` mismatch → refused.
- An unsigned assertion → refused by `verify`.
- `claims` over the corpus's canonical assertion pins the exact `[claims …]`
  bytes.

Blast radius MEDIUM. `spec-freeze-gate` + `docs-check` in the lane (two spec
files and two module headers move). `xap.md:57`'s stale "forthcoming" marker
on `cx-stdlib/session` is corrected in passing, as the issue asks.
