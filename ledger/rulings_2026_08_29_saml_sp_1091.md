# Rulings — SAML 2.0 service-provider support (#1091)

2026-08-29, release/0.18. Campaign umbrella #1097, workstream C. Recorded
BEFORE the work, per the ledger discipline.

## S-0 — the premise that was wrong, and why it is recorded

The 2026-08-28 SSO survey scoped this issue as "does the CX standard
library carry SAML", and the first analysis recommended ruling it OUT on
two grounds: no live consumer, and XML-DSig being too hazardous to own.

**Both arguments depended on a false premise** — that CX is a language
shipping a stdlib, so a SAML checklist item is someone else's sales
problem. The owner corrected it 2026-08-29: **SaaS products will be built
on top of CX.** That inverts both:

- **seam-needs-live-consumer now argues FOR the surface.** The consumer is
  every feature and every product built on the platform — exactly the
  argument that made #1090 ONE reusable OIDC surface instead of a
  per-feature reimplementation. A platform that ships OIDC and not SAML
  hands every SaaS on it a choice between failing enterprise procurement
  and hand-rolling XML-DSig.
- **The XSW hazard argues FOR it too.** The alternative to a stdlib
  verifier is not "no XML-DSig"; it is N implementations of XML-DSig in
  feature code, written by people solving a login problem, with no
  conformance corpus and no attack-class fixtures. Concentrating it in one
  pinned surface is the SAFER outcome, which is the same reasoning that
  put jwt-verify in `crypto` rather than leaving features to check tokens.

Recorded because a future session reading only the issue would re-derive
the original, wrong conclusion.

## S-1 — posture (RULED: S-1 = b)

- (a) Full SP — XML-DSig, assertion validation, HTTP-POST + Redirect
  bindings, SP metadata emission. Rejected for v1: bindings and metadata
  are the EASY half and have no consumer yet; shipping them now is surface
  ahead of need, and they can follow the first feature that asks.
- (b) **Verify-only core** — XML-DSig verification + Response/Assertion
  validation as a PURE codec over the CXDM. No bindings, no metadata, no
  I/O. RECOMMENDED and taken. Same codec/transport split `zip` and
  `crypto` already draw, and the same one #1090 kept by leaving the
  redirect to the caller.
- (c) Ruled out entirely — rejected on S-0.

## S-2 — the attack corpus is written BEFORE the verifier (RULED: S-2 = a)

Non-negotiable, and the sequencing is the point: `conformance/stdlib/saml.cxd`
pins the known signature-wrapping families FIRST, and the verifier is
written against them — the `zip` hostile-container precedent, where the
adversarial cases existed before the decoder did.

Classes that must be pinned before any verify code lands:

- Classic XSW: the signed assertion relocated and an attacker assertion
  inserted as a sibling, as a child, and inside an `Extensions` element.
- `Reference URI` resolving to a DIFFERENT element than the one consumed.
- Duplicate `ID` attributes across the document.
- The XML-comment `NameID` truncation class (a comment splitting a text
  node so that verify and consume read different strings).
- Transform abuse: anything beyond enveloped-signature + exclusive C14N.
- A signed Assertion inside an unsigned Response, and a signed Response
  wrapping an unsigned Assertion — WHICH is authoritative must be a stated
  rule with a fixture, never an accident of traversal order.

## S-3 — the verified node IS the consumed node (RULED: S-3 = a)

The module's central invariant, and the reason CX can do this better than
a DOM-with-side-tables implementation can.

`verify` does NOT return a boolean beside a document. It returns **the
verified subtree itself**, and assertion validation consumes only what
verify returned. There is no API by which a caller can hold a "valid"
answer and then read a different node — which is what every signature
wrapping attack ultimately exploits.

CX makes this expressible because the document is one path-addressed tree
with a canonical form and content-addressed identity. Taking the property
seriously is what makes the surface worth owning at all; without it this
is just another XML-DSig library.

## S-4 — canonicalization (RULED: S-4 = a)

Exclusive C14N (`xml-exc-c14n`) with enveloped-signature transform only.
Inclusive C14N, XPath transforms, XSLT transforms: **refused loudly**, not
best-effort. A transform algebra is where XML-DSig implementations go to
die, and there is no consumer that needs one.

## S-5 — signature algorithms (RULED: S-5 = a)

Reuse `crypto` §3.8 rather than adding primitives: RSA PKCS#1 v1.5 and
PSS, and ECDSA over P-256/P-384/P-521, with SHA-256/384/512. **SHA-1
signatures are REFUSED** — a decision, not a gap, on the same footing as
crypto's HS\* refusal (J-4). Enterprises with SHA-1-only IdPs are asking
for a signature that is not one.

## S-6 — no bindings, no metadata, no I/O in v1 (RULED: S-6 = a)

HTTP-POST and Redirect binding decode is transport; features wire their
own HTTP, exactly as #1090 leaves the redirect to the caller. SP metadata
emission waits for a consumer. Revisit trigger recorded: the first feature
that needs to accept a real IdP POST.

## S-7 — error band (RULED: S-7 = a)

**`CXER5400–5499` allocated to `cx-stdlib/saml`** — the next free
hundred-block above oidc's `5300–5399`. Band-scan to confirm at
registration, and the row lands in `governance.md` §9.6 FIRST: that table
is the registry, and a module spec's own §N table is not.

## Execution order

Ruling (this file) → `spec/03-approved/std-lib/saml.md` at `status=new` →
the XSW corpus (S-2) → the verifier → flip `status=current` WITH the
module. The status flip belongs in the same commit as the implementation:
a `status=current` spec with no module turns stdlib-catalog-gate red.

Sequencing within the campaign is the owner's call. The recommendation is
after #1092 SCIM: an enterprise feels missing provisioning on day one
(every joiner and leaver manual), and feels missing SAML only if its IdP
mandates it.

---

# Amendments — recorded 2026-08-30, before implementation

Implementation began after #1092 SCIM landed, per the sequencing
recommendation above. Reading the substrate before writing the verifier
turned up one fact the ruling did not anticipate, and it changes the shape
of the work. Recorded here BEFORE the spec, per `ledger/` discipline.

## S-8 — the verifier parses XML ITSELF; `cx.parse_xml` is not infoset-faithful

S-3 and S-4 assume a tree whose canonicalization reproduces the bytes the
IdP signed. `cx.parse_xml` does not provide one. It is a **data-oriented
importer** — the right thing for the codec lanes it serves, and the wrong
thing to hang XML-DSig on. Measured on `release/0.18` @ 2550c768a:

- **Ignorable whitespace is STRIPPED.** An element with child elements has
  its whitespace-only text nodes filtered out (`xml_parser.v`, the
  `items.filter(...)` at the tail of the content loop). Inter-element
  whitespace is part of the canonical octet stream; dropping it changes
  the digest. This one is decisive on its own.
- **Text runs are autotyped.** A lone text run that parses as a number or
  bool becomes a typed scalar via `try_autotype(tv.trim_space())`.
- **Duplicate attribute names are ACCEPTED.** `<a ID="1" ID="2"/>` parses
  clean (exit 0). XML 1.0 §3.1 makes that ill-formed, and it is one of the
  attack classes S-2 requires. Filed separately against the core parser;
  the module does not wait on it. (Record, 2026-09-04: that filing was
  #1104, closed 2026-08-31 at d50a460d1 — the core reader refuses
  duplicates too now. S-9 stands regardless: well-formedness is this
  module's own decision, not an inherited one.)

What is GOOD, and why the CXDM is still the right home: attribute ORDER is
preserved, mixed content is preserved, comments survive as nodes (the
`NameID` truncation class is expressible — a comment splits the text into
two nodes, which is exactly the attack), entity refs are preserved as
`EntityRefNode` rather than eagerly flattened, and `resolve_namespaces`
already populates expanded names on elements AND attributes.

**Ruled:** `cx-stdlib/saml` carries its own infoset-faithful XML reader,
module-local, producing ordinary `cx.Element` values. Rejected
alternatives, with reasons:

- *Add a lossless mode to `cx.parse_xml`.* Rejected. That parser feeds
  every codec lane and the Tier-1 canonical image; autotyping and
  ignorable-whitespace stripping are deliberate CX data-model semantics,
  not bugs, and the canonical XML image is owner-ruled identity territory.
  Changing it to serve one module would put the whole codec surface at
  risk for a benefit only this module collects.
- *Verify over raw byte offsets.* Rejected: still needs a faithful parse
  to find the subtree, and it forfeits S-3 (there would be no verified
  NODE to return, only a byte range).

This does NOT weaken S-3. The reader emits `cx.Element` values, so `verify`
still returns a path-addressable verified subtree in the one document
model, and assertion validation still consumes only what `verify` returned.
The invariant is a property of the module's representation, and the module
now owns that representation end to end — which is the same argument S-0
makes for owning the surface at all: concentrate the hazard in one pinned,
fixture-covered place.

Scope effect, stated plainly: the module grows an XML reader it would not
otherwise need. That is a real cost and it is the honest one — a verifier
built on a tree that does not reproduce the signed bytes would pass its
own fixtures and fail against every real IdP.

## S-9 — well-formedness violations are the module's own refusal

Following from S-8: the reader REFUSES what XML 1.0 makes ill-formed
rather than inheriting the core parser's tolerance — duplicate attribute
names first among them, since S-2 lists duplicate `ID` as an attack class.
Under the #1100 rule these are the sender's fault: malformed, not
unsupported.

---

# Implementation record — 2026-09-04, at the spec commit

Recorded when the `status=new` spec was committed ahead of the
implementation, so the per-code registration and the stated authority rule
are on file before any verify code exists. None of these is a new ruling;
each executes one above.

- **S-7 per-code rows.** `5400–5408` as drafted, plus `5409 E_SAML_STATUS`
  (the IdP's own non-`Success` `Status`, surfaced verbatim), `5410
  E_SAML_ISSUER_MISMATCH` and `5411 E_SAML_UNSUPPORTED` (XML Encryption and
  non-`bearer` confirmation — valid SAML v1 declines, named rather than
  read past). `5412–5499` reserved. The three follow the #1100 blame split
  the band was allocated under; `5409`/`5410` are the SAML counterparts of
  oidc's `5303`/`5301`.
- **S-2 "which is authoritative" is a stated rule** (saml.md §4.2): a
  signature is admitted only as a child of the document element or of a
  top-level `Assertion`, must be enveloped in its own parent, every
  signature present must verify, and an `Assertion` outside the verified
  subtree is a refusal, not inert content. The fixture arms in §8 pin each
  clause.
- **S-1(b) "Response/Assertion validation"** is drawn as two verbs: the
  `Response` envelope (`Status`, `Issuer`, `InResponseTo`, `Destination`)
  in `assertion`, the assertion's own claims (`Issuer`, `Conditions`,
  `bearer` `SubjectConfirmation`) in `validate`. An unsigned `Response`'s
  envelope is unsigned data and is not read.
- **S-3 wording corrected.** The draft claimed a caller *cannot* hold an
  unverified assertion; the core XML reader makes that untrue. The spec now
  says what is true: this module never PRODUCES one, and the class it
  closes is the IdP-side document as adversary.
