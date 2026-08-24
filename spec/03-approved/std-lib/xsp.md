# `cx-stdlib/xsp` — XSP frame codec (catalog entry)

```cx
[module-meta name=xsp tier=D status=current]
```

**Status:** Current (owner ruling 2026-07-12, #363 item 4(a))

Catalog entry for the `stdlib/xsp.cx` bundle. The normative reference is
[`xap/xsp.md`](../xap/xsp.md) — the XSP frame + session layer v1 and the
profile model (generic since the stream-4 split, #676: the frame carries
negotiated profiles — XAP, STORE — not XAP alone; the frame codec is shipped
and conformance-tested). This file exists because the stdlib-catalog-gate
reads module-meta blocks from `spec/03-approved/std-lib/*.md` only — the same
thin-pointer pattern as [`sql.md`](sql.md) / [`redis.md`](redis.md) (#294).
Spec content lives in the normative reference, not here.
