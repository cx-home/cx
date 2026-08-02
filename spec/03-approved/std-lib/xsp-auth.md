# `xsp-auth` — XSP-AUTH handshake calculus (catalog entry)

```cx
[module-meta name=xsp_auth tier=D status=current]
```

**Status:** Current (owner G3 2026-07-18, #519/#116)

Catalog entry for the `xsp_auth_stdlib_builtin` dispatch family — the
SIGMA-style mutual proof-of-control handshake over XSP frames:
`auth-hello` / `auth-challenge` / `auth-prove` / `auth-confirm` /
`auth-finish` / `auth-transcript` / `auth-keys` / `auth-verify`, plus the
per-request `auth-proof` / `auth-proof-verify` and the rotation-continuity
`auth-rotate` / `auth-rotate-verify`. The normative reference is
[`xap/xap_identity_model.md`](../xap/xap_identity_model.md) §4 (handshake),
§5.1 (error registry), §6.3 (rotation); frames are
[`xap/xsp.md`](../xap/xsp.md). Conformance:
`conformance/stdlib/xsp-auth.cxd` (24 enforced offline lanes) plus the
live-channel engine tests (`vcx/tests/xap_host_auth_test.v`).

This file exists because the stdlib-catalog-gate reads module-meta blocks
from `spec/03-approved/std-lib/*.md` only — the same thin-pointer pattern as
[`xap.md`](xap.md) / [`sql.md`](sql.md) / [`redis.md`](redis.md). Spec
content lives in the normative reference, not here.
