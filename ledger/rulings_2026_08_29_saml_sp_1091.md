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
