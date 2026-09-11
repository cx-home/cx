# RULED: 1402-b and 1406-b — the SAML binding layer (S14) and the SCIM service-provider remainder (S15)

Fable, 2026-09-11 ~18:05Z, under the owner's delegation of 2026-09-09 05:50 ET. The owner may
override on #1354. Premises re-checked at `cff63e9a4`: `SAMLResponse`, `RelayState`,
`AuthnRequest`, `LogoutRequest` have zero occurrences outside the two issues; `deflate.decompress_raw`
exists in `vcx/code/stdlib_zip.v` and is not reachable from CX; `scim_map_key_ci` folds case only;
`scim_meta()` emits no `version`; `etag.supported` is an opt with nothing behind it.

## 1402-b — S14, `cx-stdlib/saml` and `cx-stdlib/bytes`

1. **ACS decode is a pure saml verb**, `saml:acs-decode $form-body $opts` → the Response bytes and
   the `RelayState` string: form-urlencoded (via `url:query-parse`), `SAMLResponse` base64 (the
   S-8 reader's byte bound applies before decoding), `RelayState` ≤ 80 bytes (the SAML binding
   spec's own limit). The HTTP route that calls it is S7's (`sso:acs`). **RelayState is a key,
   never a URL**: the deployment parks the return-to in session's pending table (S6 seam) under the
   `AuthnRequest` id and RelayState carries that id; a RelayState that is not a parked key is
   refused, so there is no open redirect by construction. Spec: `saml.md` §1.1 lifts the POST
   exclusion.
2. **Raw DEFLATE enters `bytes`**: `bytes:deflate-raw` and `bytes:inflate-raw` over the V
   primitive, `inflate-raw` bounded by `opts.max-bytes` (default 1 MiB; a stream that would exceed
   it is refused, the zip-bomb defense). Spec: `bytes.md`.
3. **The HTTP-Redirect binding carries REQUESTS and LOGOUT messages, never a Response**:
   `saml:redirect-encode` (deflate-raw → base64 → the `SAMLRequest`/`SAMLResponse` + `RelayState`
   query string) and `saml:redirect-decode`. A `Response` (assertion-bearing) arriving via
   Redirect is refused — its signature placement cannot be honored in the query string; POST is
   the only accepted binding for it (`saml.md` §4.4 already says signed-Assertion-only).
4. **`saml:authn-request $config $opts` emits an UNSIGNED `AuthnRequest`** in schema order,
   deterministic given `opts.id` and `opts.issue-instant` (byte-pinnable), with `Issuer`,
   `NameIDPolicy`, `AssertionConsumerServiceURL`, `ProtocolBinding` (POST). Request signing is not
   built (the module produces no signatures; `saml.md` S-6); trigger to reopen: the first IdP that
   requires signed requests (ADFS/Entra/Okta accept unsigned by default).
5. **Single Logout, both directions, minimal and graded**: `saml:logout-request` emits a
   `LogoutRequest` (NameID + SessionIndex, Redirect binding); `saml:logout-parse` reads an
   incoming `LogoutRequest`/`LogoutResponse` — a `LogoutRequest` MUST be signed (the module's
   posture: unsigned logout is a forced-logout DoS), signature verified with the IdP keys the
   deployment already holds; `saml:logout-response` emits the answer. Matching the session by
   SessionIndex/NameID and detaching it is S7's route.
6. **Codes**: `CXER5415 E_SAML_BINDING` (bad base64, RelayState over 80 bytes, DEFLATE bound
   exceeded, a Response via Redirect, malformed form body) and `CXER5416 E_SAML_LOGOUT` (an unsigned
   or unmatched logout message). Register in `governance.md` §9.6 (5415–5499 were reserved by
   1410-c).
7. Spec text, delegated G3 (flagged): `saml.md` §1.1, §3, §4.4, §7, §8, §9; `bytes.md` the two
   verbs and their bound; nothing in `session.md` (S7 owns the mounts).

Refused: (b) hand-rolled DEFLATE in CX — the primitive exists in V; (c) accepting a Response via
Redirect with signature over the deflated bytes — nobody's IdP does it and it widens the reader;
(d) unsigned LogoutRequest — forced logout of any user by anyone who knows a NameID.

## 1406-b — S15, `cx-stdlib/scim` (and one `session` row)

1. **Pagination reads the wire spellings**: `startIndex`/`start-index`, `count`, `totalResults`
   /`total-results` — case AND hyphen/camel folded; `count` clamps to the advertised
   `max-results`; the envelope SLICES; an unknown pagination key is refused with the module's
   existing argument-invalid row (never ignored — the measured failure is a client that stops
   after page one).
2. **`meta.version` is a strong ETag** — the content hash of the canonical resource (`"<sha2-256>"`,
   quoted per RFC 7232), with `meta.created`/`meta.lastModified` from the store record;
   `If-Match` on PUT/PATCH is honored (mismatch → the precondition-failed refusal, new row
   `CXER56xx E_SCIM_PRECONDITION` in the scim band, HTTP 412 at the mount); `If-None-Match` on GET
   → 304 at the mount. `/ServiceProviderConfig` `etag.supported` is TRUE and no longer an opt: a
   claim is backed by code or not made. Refused: (b) weak ETags — nothing here is byte-unstable.
3. **DELETE is answered, not silently ignored**: per 1406-a hard delete is not offered in v0.18,
   so `DELETE /Users/{id}` answers 501 Not Implemented with a SCIM error body whose `detail` names
   `active: false` as the deprovisioning path; `ServiceProviderConfig` does not advertise delete.
   Graded. Refused: (b) mapping DELETE to `active: false` — a client that sent DELETE believes the
   record is gone, and a later GET that answers 200 is a lie either way.
4. **Groups overage (Entra) is RECOGNIZED and fails closed**: `session:map-claims` reads
   `_claim_names`/`_claim_sources` for `groups` and, when present, records `[groups-overage
   source=<url>]` on the claim set and sets NO `groups`; an `authz` decision that needs groups
   over such a claim set is a refusal, never an empty-groups allow. Fetching the groups from
   Microsoft Graph with the access token is the DEPLOYMENT's step and is deferred with a recorded
   trigger: the first Entra tenant in the interop matrix with more than the overage threshold of
   groups; documented in the Entra matrix cell. Spec text, delegated G3 (flagged): `scim.md` §3
   pagination and §5 `meta`/preconditions/DELETE; `session.md` §4 `map-claims` the overage row.

Graders: one conformance case per refusal and per positive arm above; the SCIM cases at ring 1
(pure), the mounted behavior (412/304/501) in S7's deployment rows once `sso` lands — S15 lands
the verbs and their cases first.
