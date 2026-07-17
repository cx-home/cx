# CX Store, security — capabilities, encryption, RBAC, tenancy

Four independent layers, each fail-closed. Governing specs: the security spec
(`spec/03-approved/core/security.md`), the store spec (capabilities and
encryption-at-rest sections), and the CXStore service-tier spec (auth/RBAC/
tenancy).

## 1. Host capabilities — deny-by-default at the effect point

Every effectful store op runs under the caller's capability set; `mem://` is
capability-free, `file://` needs `read`/`write` by path, remote substrates
need `net` by host:port. Denial names the exact grant to add (verified):

```
$ cx program.cx          # opens file:// with no grant
[err code=cx-err:CXER0271 message='E_CAP_DENIED: write capability required
  for store open file:///…; none granted (grant via --allow-write)']
```

Narrow inside a program for untrusted sub-computations (verified):

```cx
[?with-caps [deny net]
  [$http:get "https://example.com" {}]]     # → CXER0271 even under --allow-all
```

Least-privilege habits: open registries/read paths with
`[map read-only="true"]` so `write` is never requested; scope net grants to
the daemon (`--allow-net=127.0.0.1:8443`), never bare `--allow-net`; reserve
`--allow-all` for trusted local runs.

## 2. Encryption-at-rest — sealed objects, plaintext identity

Open with `[opts encrypt-key-id=<tenant-key-id>]` and every object is sealed
at rest (AES-256-CBC-then-HMAC from audited primitives, per-object data keys
wrapped by a tenant KEK through a KMS seam). It is invisible to the object
graph — objects stay keyed by the **plaintext** hash, so dedup, structural
sharing, and replication are unchanged; only the bytes on the substrate are
ciphertext.

- Sealing substrates: `file://` (pack — the default — and object-per-key),
  `sqlite://`, `s3://`.
- **Mode is fixed at creation**, store-wide, declared durably. Mismatches are
  hard errors both directions: an encrypted store opened without its key
  never appears empty or corrupt, and encryption cannot be enabled in place
  on existing plaintext data.
- **Fail-closed everywhere**: a missing/malformed key is a hard error (never
  a silent ephemeral key); requesting encryption on a substrate that cannot
  seal is refused (verified):

```
[$store:open-opts "mem://" [map encrypt-key-id="tenant-a"]]
; → CXER1100 …refusing to store plaintext for mem://
```

The reference KMS provider resolves the KEK from the environment; a
production KMS implements the same seam. **KEK rotation is shipped**
(#287): `cx store-rotate-kek` on the CLI and `[$store:rotate-kek]` embedded —
re-wraps every DEK under the new KEK in place (see the guide's store page
for a verified end-to-end run).

## 3. Service-tier RBAC & tenancy

The daemon layers structured authZ over CSRP's permanent Bearer base
(details + verified 401/403 lanes in [store: service](store-service.md)):

- Four credential providers (static/JWT/DID/OIDC) → one principal shape
  `{id, kind, roles, tenant}`; deny-by-default — no role means only
  `capabilities`/`health`/`ready`.
- Permissions are the CSRP op classes (`read`/`write`/`delete`/`admin` +
  the `metrics` scrape scope); object-wire ops mirror their data-op peers.
- **Tenant boundary = store-per-tenant**: separate stores mean separate
  dedup pools — no cross-tenant existence oracle by construction. An op on
  a store outside the principal's tenant is `403 CXER1703`.
- Secrets hygiene: tokens hashed at rest; `${env:VAR}` config injection so
  key material is never inlined; logs carry the role, never the token.

## 4. XAP-layer authority (when the store backs a XAP)

Distribution-side: grants attach to features and principals at the PEP,
never to library code (invariant N-DIST-2); install-time consent is exactly
the manifest's `needs` set; entitlement checks are PEP checks. A feature's
store access is bounded by its granted slice — see
[marketplace](marketplace.md) and the trust-model part of the XAP spec.

## Fail-closed inventory (what refuses rather than degrades)

| Surface | Behavior |
|---|---|
| Missing capability | `CXER0271`, names the grant |
| Read-only store write | `CXER1110` |
| Integrity mismatch on read | `CXER1120` — never a silent wrong doc |
| Substrate persist failure | `CXER1116` — never a phantom success |
| Encrypted store, wrong/absent key | hard error, both mode directions |
| Unsupported compression request | rejected, never accept-and-ignore |
| Invalid/unknown daemon config attr | startup failure `CXER1711`; reload refused whole `CXER1712` |
| Anonymous/underprivileged wire op | `401 CXER1702` / `403 CXER1703` |
| Package verify failure at any stage | staged nothing; the stage's own error value |
