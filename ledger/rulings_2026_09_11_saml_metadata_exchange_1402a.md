# RULED: 1402-a — SAML metadata exchange: `saml:metadata` parses an IdP's (or SP's) `EntityDescriptor` into keys + endpoints; `saml:sp-metadata` emits ours

**Fable, 2026-09-11 01:3xZ, under the owner's delegation of 2026-09-09 05:50 ET**; the
owner may override on #1354. Lane S item S3, split out of #1402 by the owner's scope
statement (*"participate in their SSO / IdP without ceremony"*): metadata exchange is the
one mechanism that turns four bespoke onboardings into one configuration step.

Premises re-verified before ruling: `IDPSSODescriptor`, `SPSSODescriptor`,
`EntityDescriptor`, `KeyDescriptor` — zero occurrences in `stdlib/`, `vcx/code/`,
`conformance/`, `spec/03-approved/std-lib/` (grep at `19af3b349`). `saml.md` §1.1
excludes SP metadata **emission** (RULED S-6, *"no consumer has asked"*) and never mentions
parsing. `crypto_x509.v:166-215` reads SubjectPublicKeyInfo only — no `Validity` symbol in
the file. The xml codec emits a namespace-prefixed `md:`/`ds:` tree faithfully (measured:
`cx --from=cx --to=xml` on a hand-built `md:EntityDescriptor` renders schema-shaped XML).

## The fork

- **(a) two verbs in `cx-stdlib/saml`, backed by the module's own strict reader: `metadata` (parse either role) and `sp-metadata` (emit ours), plus `certificate-validity` in `crypto` so the parser can report each key's window.** Lifts the S-6 emission exclusion by ruling; adds parsing, which S-6 never excluded. DELETES: the sentence *"The easy half, and no consumer has asked"* — a consumer has asked (the owner, by name: Entra, Okta, Ping, ADFS).
- **(b) parse with the core `cx.parse_xml` data importer and emit with a CX template in the deployment.** DELETES the S-8 reason the module owns its reader: metadata is attacker-reachable input when fetched from a URL, and the data importer tolerates duplicate attributes, autotypes text, and strips whitespace — a certificate body split across lines is exactly what it would mangle. Refused.
- **(c) leave both to the S7 deployment module as hand-written CX.** Puts XML-schema knowledge (element ORDER matters to ADFS's validator) in a place with no conformance corpus. Refused — the same reasoning that put `verify` in a module rather than in feature code.

**Ruled (a).**

## The surface

```
[?def metadata     scope=public pure [returns element] ($xml::string $opts::map {}) …]
[?def keys         scope=public pure [returns [sequence element]] ($entity::element $use::string 'signing') …]
[?def sp-metadata  scope=public pure [returns string]  ($sp::element $opts::map {}) …]
```

**`metadata`** reads one `md:EntityDescriptor` with the §2.1 reader (so `DOCTYPE`, duplicate
attributes, a non-UTF-8 declaration are `CXER5400` as everywhere else) and yields

```
[entity entity-id="…" valid-until=… cache-duration=…
  [idp want-authn-requests-signed=false
    [sso binding="urn:…:HTTP-Redirect" location="…"] [sso binding="urn:…:HTTP-POST" location="…"]
    [slo binding="…" location="…"]…
    [name-id-format "urn:…:persistent"]…
    [key use=signing not-before=<datetime> not-after=<datetime> [rsa-public-key n= e=]]…]
  [sp authn-requests-signed=… want-assertions-signed=…
    [acs binding="…" location="…" index=0 default=true]… [slo …]… [name-id-format …]… [key …]…]]
```

- Either role or both; a document with neither `IDPSSODescriptor` nor `SPSSODescriptor` is
  **`CXER5412 E_SAML_METADATA`** (new code; IdP/administrator's fault). An `EntitiesDescriptor`
  is refused with the same code unless it holds exactly one `EntityDescriptor` — picking is how
  the wrong entity gets trusted (the §4.2 rule again).
- Every `KeyDescriptor` becomes a `[key]`; a `KeyDescriptor` with no `use` is **both** signing
  and encryption (SAML Metadata §2.4.1.1) and carries `use=both`. The key element inside is
  what `crypto:certificate-key` yields for the `ds:X509Certificate` body (whitespace stripped),
  so the result feeds `verify` unchanged; `not-before`/`not-after` come from the new
  `crypto:certificate-validity`. An `X509Certificate` that does not parse is `CXER5412` naming
  the key's index — never skipped.
- **`opts.now`** (optional; the verb reads no clock): when supplied, a `use=signing`/`both` key
  whose certificate is outside its validity window at `now` is refused with `CXER5412` naming
  the key and its `not-after` — this is RULED 1410-b's *configuration-time* expiry check, and
  it is where the deployment tooling performs it. Without `now`, the windows are reported and
  nothing is refused.
- **Metadata signatures are not verified in v1.** A `ds:Signature` on the `EntityDescriptor`
  is left in place and ignored; the trust anchor for a metadata signer is a federation
  concept (InCommon-style) none of the four named IdPs use for a single tenant, and the
  metadata is obtained from the administrator over TLS — the same posture RULED 1287-Q1 gives
  the certificate itself. Recorded in `saml.md` §1.1 with the trigger: the first federation
  deployment.

**`keys`** answers the key elements of a role for a use — `signing` (which includes `both`)
or `encryption` — as the sequence `verify` takes. It exists so the common call is one line and
so nobody writes the `both` rule by hand.

**`sp-metadata`** takes

```
[sp entity-id="https://rp.example" authn-requests-signed=false want-assertions-signed=true
  [acs binding=HTTP-POST location="https://rp.example/saml/acs" index=0 default=true]
  [slo binding=HTTP-Redirect location="…"]?
  [name-id-format "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"]?
  [signing-certificate "<PEM | base64 DER>"]? [encryption-certificate "…"]?]
```

and emits the `md:EntityDescriptor` XML string, **in schema order** (`KeyDescriptor`,
`SingleLogoutService`, `NameIDFormat`, `AssertionConsumerService`), with `md:` and `ds:`
declared on the root, bindings accepted as `HTTP-POST` / `HTTP-Redirect` / `HTTP-Artifact` or
the full URN and emitted as the URN, certificates emitted as the bare base64 body (PEM armor
stripped). `opts.valid-until` (datetime) and `opts.cache-duration` (duration) are emitted when
given. A missing `entity-id` or no `[acs]` is `CXER5408` (the caller's). Deterministic: equal
input, byte-identical output — which is what lets the corpus pin it byte-for-byte and what an
administrator diffing two exports needs.

**`crypto:certificate-validity`** `($cert) -> map {not-before: datetime, not-after: datetime}`,
pure, the same DER walk as `certificate-key` extended to the `Validity` SEQUENCE
(`UTCTime` and `GeneralizedTime`, RFC 5280 §4.1.2.5). It reports; it never decides — the
1287-Q1 contract (*"a verb that did SOME of them would read as if it did all of them"*) holds
because this verb does exactly one named thing and `certificate-key` still does exactly its
one.

## Spec text (delegated G3, flagged)

- `saml.md` §1.1: the S-6 bullet becomes *"HTTP-POST and Redirect bindings"* only; a new
  bullet records metadata: parse + emit are IN (RULED: 1402-a), metadata-signature
  verification is OUT with its trigger. §3 gains the three rows. §7 gains 5412. §8 names the
  cases. §9 gains the metadata-trust paragraph and moves the 1410-b expiry position here.
- `crypto.md` §3.x: `certificate-validity` beside `certificate-key`.
- `governance.md` §9.6: `5412 E_SAML_METADATA` registered in the 5400 row; "5413–5499 reserved".
- Every spec-touching commit carries `RULED: 1402-a`.

## Conformance (in `conformance/stdlib/saml.cxd`, plus `crypto.cxd` for the validity verb)

Parse: an Entra-shaped IdP `EntityDescriptor` (two `KeyDescriptor`s, one `use=signing`, one
use-less; `SingleSignOnService` Redirect + POST; `SingleLogoutService`; two `NameIDFormat`s)
pinned as the exact `[entity …]` bytes; `keys … 'signing'` answers two keys, `'encryption'`
one; a certificate body wrapped across lines parses; `opts.now` past `not-after` refuses 5412
naming the key; `opts.now` inside the window passes; the same certificate through
`certificate-key` and through `metadata` yields equal `n`/`e` (the plumbing pin);
`EntitiesDescriptor` with two entities → 5412; a document with neither role → 5412; a
`DOCTYPE` → 5400; an ADFS-shaped document (`WantAuthnRequestsSigned="true"`, `use=encryption`
key) → `want-authn-requests-signed=true`. Emit: the minimal SP pinned byte-for-byte; the full
SP (both certificates, SLO, two formats, two ACS) pinned byte-for-byte and in schema order;
`HTTP-POST` expands to the URN; PEM armor stripped; a missing `entity-id` → 5408; the emitted
XML re-parsed by `metadata` yields an `[sp …]` whose `acs`/`key` rows equal the input — the
round trip that grades the emitter against the parser. Validity: the fn-doc EC certificate
(`stdlib/crypto.cx:314`) answers `2026-09-05T14:25:37Z` / `2036-09-02T14:25:37Z`; a truncated
DER → `CXER3700`.

Nothing here is deferred. The ACS route that CONSUMES the emitted `Location` is S7 (#1394);
`AuthnRequest` emission that consumes `[sso]` is S14 (#1402b).
